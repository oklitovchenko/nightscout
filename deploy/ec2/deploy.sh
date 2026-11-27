#!/bin/sh
set -eu

docker_network=nightscout-server
ipv6_network=nightscout-server-ipv6
app_port=1337
health_poll_interval=4
mongo_container=nightscout-server-mongo
uploader_container=nightscout-server-libre
private_address=$(ip -4 route get 169.254.169.254 |
  awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
test -n "$private_address"

umask 077
release=$(mktemp -d "$PWD/release.XXXXXXXX")
keep_release=false
cleanup_release() {
  if ! "$keep_release"; then
    rm -f current.new
    rm -rf "$release"
  fi
}
trap cleanup_release EXIT
cp "$bundle"/mirror-sensor-change.* "$release/"

start_nightscout() (
  directory=$1
  image_file="$directory/image"
  if [ ! -f "$image_file" ]; then
    # The combined launcher recorded Nightscout on the first line.
    image_file="$directory/images"
  fi
  read -r release_image < "$image_file" || exit 1
  if docker container inspect "$container" >/dev/null 2>&1; then
    docker rm -f "$container" >/dev/null || exit 1
  fi
  docker run -d --restart unless-stopped --network "$docker_network" \
    --log-opt max-size=10m --log-opt max-file=2 --name "$container" \
    --env-file "$directory/nightscout.env" \
    -p "127.0.0.1:$app_port:$app_port" \
    -p "$private_address:$app_port:$app_port" "$release_image" \
    >/dev/null || exit 1
  if docker network inspect "$ipv6_network" >/dev/null 2>&1; then
    docker network connect "$ipv6_network" "$container"
  fi
)

wait_for_nightscout() {
  max_attempts=36
  attempt=0
  while [ "$attempt" -lt "$max_attempts" ]; do
    if sh "$bundle/check-nightscout-api.sh" \
      "$1" "$app_port" "$private_address"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep "$health_poll_interval"
  done
  return 1
}

aws ssm get-parameter --region "$aws_region" \
  --name "$settings_parameter:$SSM_configVersion" \
  --with-decryption --query Parameter.Value --output text \
  > "$release/settings.json"
printf '%s\n' "$image" > "$release/image"
mongo_image=$(jq -er '.MONGO_IMAGE' "$release/settings.json")
jq -ce '.NIGHTSCOUT_ACCESS' "$release/settings.json" > "$release/access.json"
jq -e -f "$bundle/validate-nightscout-access.jq" \
  "$release/access.json" > /dev/null
sh "$bundle/write-nightscout-environment.sh" \
  "$release" "$mongo_container" "$app_port"

# Only one LibreLinkUp connector may upload readings at a time.
if grep -qx 'CONNECT_SOURCE=linkup' "$release/nightscout.env" &&
  [ "$(docker inspect --format '{{.State.Running}}' "$uploader_container" \
    2>/dev/null || true)" = true ]; then
  echo "Stop the separate LibreLinkUp uploader before enabling Connect." >&2
  exit 1
fi

docker network inspect "$docker_network" >/dev/null 2>&1 ||
  docker network create "$docker_network"
if ! docker container inspect "$mongo_container" >/dev/null 2>&1; then
  docker pull -q "$mongo_image"
  docker run -d --restart unless-stopped --network "$docker_network" \
    --name "$mongo_container" -v "$mongo_container:/data/db" "$mongo_image" \
    --wiredTigerCacheSizeGB 0.25 >/dev/null
fi
docker start "$mongo_container" >/dev/null

previous=$(readlink current || true)
if start_nightscout "$release" && wait_for_nightscout "$release" &&
  sh "$bundle/reconcile-nightscout-access.sh" \
    "$release" "http://127.0.0.1:$app_port" &&
  ln -sfn "$release" current.new && mv -Tf current.new current; then
  keep_release=true
  sh "$bundle/configure-sensor-mirror.sh" "$state_directory" "$mongo_container"
  if [ -n "$previous" ]; then rm -rf "$previous"; fi
  echo "Server API authenticated check passed"
else
  if [ -n "$previous" ]; then
    start_nightscout "$previous" && wait_for_nightscout "$previous"
  else
    docker rm -f "$container" >/dev/null 2>&1 || true
  fi
  exit 1
fi
