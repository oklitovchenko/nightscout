#!/bin/sh
set -eu

repository=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' 0
export ACCESS_TEST_STATE="$workspace"
mkdir "$workspace/bin"
printf 'API_SECRET=fixture-secret-1234\n' > "$workspace/nightscout.env"
cat > "$workspace/roles" <<'JSON'
[{"_id":"role-id","name":"uploader","permissions":["api:devicestatus:read"]},
 {"_id":"other-role","name":"other","permissions":["api:entries:read"]}]
JSON
cat > "$workspace/subjects" <<'JSON'
[{"_id":"subject-id","name":"phone","roles":["uploader","other"],
  "accessToken":"fixture-token"},
 {"_id":"other-client","name":"viewer","roles":["other"]}]
JSON
cat > "$workspace/access.json" <<'JSON'
{"roles":[{"name":"uploader","permissions":["api:devicestatus:read",
  "api:devicestatus:create","api:devicestatus:update"]}],
 "subjects":[{"name":"phone","roles":["uploader"]}]}
JSON
cp "$workspace/subjects" "$workspace/subjects-before"
cat > "$workspace/bin/curl" <<'MOCK'
#!/bin/sh
set -eu
method=GET
payload=
collection=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift ;;
    -H|--max-time) shift ;;
    --data-binary) payload=${2#@}; shift ;;
    http://*) collection=${1##*/} ;;
  esac
  shift
done
file="$ACCESS_TEST_STATE/$collection"
if [ "$method" = GET ]; then cat "$file"; exit; fi
[ ! -f "$ACCESS_TEST_STATE/no-writes" ]
printf '%s\n' "$method $collection" >> "$ACCESS_TEST_STATE/writes"
if [ "$collection" = subjects ]; then
  jq -e 'has("accessToken") | not' "$payload" > /dev/null
fi
jq --slurpfile body "$payload" '
  map(if ._id == $body[0]._id then . + $body[0] else . end)
' "$file" > "$file.new"
mv "$file.new" "$file"
echo '{}'
MOCK
chmod +x "$workspace/bin/curl"
export PATH="$workspace/bin:$PATH"
script="$repository/deploy/ec2/reconcile-nightscout-access.sh"
sh "$script" "$workspace" http://fixture
[ "$(cat "$workspace/writes")" = 'PUT roles' ]
cmp "$workspace/subjects" "$workspace/subjects-before"

# Adding an existing role preserves tokens, unrelated bindings and clients.
jq '.[0].roles = ["other"]' "$workspace/subjects" > "$workspace/subjects.new"
mv "$workspace/subjects.new" "$workspace/subjects"
sh "$script" "$workspace" http://fixture
jq -e '.[0].roles == ["other", "uploader"]
  and .[0].accessToken == "fixture-token"
  and .[1].name == "viewer" and .[1].roles == ["other"]' \
  "$workspace/subjects" > /dev/null
touch "$workspace/no-writes"
sh "$script" "$workspace" http://fixture

# A managed role shared with an undeclared client must fail before writes.
jq '. + [{name:"unexpected",roles:["uploader"]}]' \
  "$workspace/subjects" > "$workspace/subjects.new"
mv "$workspace/subjects.new" "$workspace/subjects"
if sh "$script" "$workspace" http://fixture 2>/dev/null; then exit 1; fi

for invalid in '{}' '{"roles":[],"subjects":[] ,"token":"forbidden"}'; do
  if printf '%s' "$invalid" | jq -e \
    -f "$repository/deploy/ec2/validate-nightscout-access.jq" \
    > /dev/null 2>&1; then exit 1; fi
done
echo 'Passed access adoption, idempotency, and exclusive-role checks.'
