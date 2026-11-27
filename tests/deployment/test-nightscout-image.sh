#!/bin/sh
set -eu

cleanup() {
  docker rm -f nightscout-ci-app nightscout-ci-db >/dev/null 2>&1 || :
  docker network rm nightscout-ci >/dev/null
}

docker network create nightscout-ci
trap cleanup 0
docker run -d --name nightscout-ci-db --network nightscout-ci "$MONGO_IMAGE"
host_address=$(ip -4 route get 169.254.169.254 |
  awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
test -n "$host_address"
api_secret=$(openssl rand -hex 16)
api_hash=$(printf '%s' "$api_secret" | openssl dgst -sha1 -r | cut -d ' ' -f 1)

docker run -d --name nightscout-ci-app --network nightscout-ci \
  -p 127.0.0.1:1337:1337 \
  -p "$host_address:1337:1337" \
  -e MONGODB_URI=mongodb://nightscout-ci-db:27017/ci \
  -e AUTH_DEFAULT_ROLES=denied -e INSECURE_USE_HTTP=true -e PORT=1337 \
  -e API_SECRET="$api_secret" nightscout:ci

url=http://$host_address:1337/api/v1/entries.json?count=1
attempt=1
while [ "$attempt" -le 45 ]; do
  anonymous=$(curl -s --max-time 3 -o /dev/null \
    -w '%{http_code}' "$url" || :)
  authenticated=$(curl -s --max-time 3 -H "api-secret: $api_hash" \
    -o /dev/null -w '%{http_code}' "$url" || :)
  if [ "$anonymous/$authenticated" = 401/200 ]; then
    echo 'Nightscout API ready: anonymous 401, authenticated 200'
    sh tests/deployment/test-sensor-mirror.sh nightscout-ci-db
    TEST_API_SECRET=$api_secret sh \
      tests/deployment/test-nightscout-access-api.sh \
      "http://$host_address:1337"
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 2
done

echo "Unexpected API responses: $anonymous/$authenticated"
docker logs --tail 50 nightscout-ci-app
exit 1
