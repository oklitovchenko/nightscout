#!/bin/sh
set -eu

release=$1
base=$2/api/v2/authorization
bundle=$(CDPATH= cd "$(dirname "$0")" && pwd)
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' 0
jq -ce -f "$bundle/validate-nightscout-access.jq" \
  "$release/access.json" > "$work/access"
secret=$(sed -n 's/^API_SECRET=//p' "$release/nightscout.env")
hash=$(printf '%s' "$secret" | openssl dgst -sha1 -r | cut -d ' ' -f 1)
unset secret
printf 'api-secret: %s\nContent-Type: application/json\n' "$hash" \
  > "$work/headers"
unset hash

request() {
  method=$1
  collection=$2
  shift 2
  curl --silent --show-error --fail --max-time 15 \
    -H "@$work/headers" -X "$method" "$base/$collection" "$@"
}
request GET roles > "$work/roles"
request GET subjects > "$work/subjects"

# Validate the entire adoption before changing any role or subject.
jq -e --slurpfile roles "$work/roles" \
  --slurpfile subjects "$work/subjects" '
  . as $config
  | all(.subjects[];
      . as $s
      | ([$subjects[0][] | select(.name == $s.name)] | length) == 1
      and all($s.roles[];
        . as $r | any($roles[0][]; .name == $r)
          or any($config.roles[]; .name == $r)))
  and all(.roles[];
    .name as $role
    | ([$roles[0][] | select(.name == $role)] | length) <= 1
    and all($subjects[0][] | select(.roles | index($role));
      .name as $name
      | any($config.subjects[];
          .name == $name and (.roles | index($role)) != null)))
' "$work/access" > /dev/null || {
  echo 'Access adoption needs existing subjects and exclusive roles.' >&2
  exit 1
}

for collection in roles subjects; do
  jq -c ".$collection[]" "$work/access" > "$work/desired"
  while IFS= read -r desired; do
    name=$(printf '%s' "$desired" | jq -r .name)
    current=$(jq -c --arg name "$name" \
      'map(select(.name == $name)) | .[0] // {}' "$work/$collection")
    # Subject identity and all unrelated role bindings stay intact.
    payload=$(printf '%s\n%s\n' "$current" "$desired" |
      jq -cs --arg collection "$collection" '
        if $collection == "subjects" then
          .[0] + {roles: ((.[0].roles + .[1].roles) | unique)}
          | del(.accessToken, .accessTokenDigest, .digest)
        else .[0] + .[1] end')
    field=permissions
    [ "$collection" != subjects ] || field=roles
    if printf '%s\n%s\n' "$current" "$payload" |
      jq -es --arg field "$field" \
        '(.[0][$field] // [] | sort) == (.[1][$field] | sort)' \
        > /dev/null; then
      continue
    fi
    method=PUT
    [ "$current" != '{}' ] || method=POST
    printf '%s' "$payload" > "$work/payload"
    request "$method" "$collection" \
      --data-binary "@$work/payload" > /dev/null
    request GET "$collection" > "$work/verified"
    jq -e --arg name "$name" --arg field "$field" \
      --slurpfile expected "$work/payload" '
      map(select(.name == $name)) | length == 1 and
        (.[0][$field] | sort) == ($expected[0][$field] | sort)
    ' "$work/verified" > /dev/null
  done < "$work/desired"
done
echo 'Nightscout access configuration verified.'
