#!/bin/sh
set -eu

base=$1
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' 0
printf 'API_SECRET=%s\n' "$TEST_API_SECRET" > "$work/nightscout.env"
hash=$(printf '%s' "$TEST_API_SECRET" |
  openssl dgst -sha1 -r | cut -d ' ' -f 1)
printf 'api-secret: %s\nContent-Type: application/json\n' "$hash" \
  > "$work/headers"
unset TEST_API_SECRET hash
curl -fsS -H "@$work/headers" \
  --data '{"name":"ci-uploader","roles":["readable"]}' \
  "$base/api/v2/authorization/subjects" > /dev/null
curl -fsS -H "@$work/headers" \
  "$base/api/v2/authorization/subjects" > "$work/before"
cat > "$work/access.json" <<'JSON'
{"roles":[{"name":"ci-sync","permissions":["api:devicestatus:create",
  "api:devicestatus:read","api:devicestatus:update"]}],
 "subjects":[{"name":"ci-uploader","roles":["ci-sync"]}]}
JSON
sh deploy/ec2/reconcile-nightscout-access.sh "$work" "$base"
sh deploy/ec2/reconcile-nightscout-access.sh "$work" "$base"
curl -fsS -H "@$work/headers" \
  "$base/api/v2/authorization/subjects" > "$work/after"
jq -e --slurpfile before "$work/before" '
  .[] | select(.name == "ci-uploader")
  | . as $after | $before[0][] | select(.name == $after.name)
  | ._id == $after._id and .accessToken == $after.accessToken
    and ($after.roles | sort) == ["ci-sync", "readable"]
' "$work/after" > /dev/null
echo 'Live API access adoption and token preservation passed.'
