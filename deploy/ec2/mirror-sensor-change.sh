#!/bin/sh
set -eu

directory=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec docker exec -i "$1" mongosh server --quiet --file /dev/stdin \
  < "$directory/mirror-sensor-change.js"
