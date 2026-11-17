#!/bin/sh
set -eu

url="http://$3:$2/api/v1/entries.json?count=1"
anonymous=$(curl -s --max-time 3 -o /dev/null -w '%{http_code}' "$url")
[ "$anonymous" = 401 ] || exit 1
secret=$(sed -n 's/^API_SECRET=//p' "$1/nightscout.env")
hash=$(printf '%s' "$secret" | openssl dgst -sha1 -r | cut -d ' ' -f 1)
unset secret
authenticated=$(curl -s --max-time 3 \
  -H "api-secret: $hash" -o /dev/null -w '%{http_code}' "$url")
[ "$authenticated" = 200 ]
