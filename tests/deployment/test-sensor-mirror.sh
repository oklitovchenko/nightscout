#!/bin/sh
set -eu

container=$1
query=deploy/ec2/mirror-sensor-change.js
mongo() {
  docker exec -i "$container" mongosh sensor_mirror_ci --quiet --file /dev/stdin
}
mirror() {
  mongo < "$query"
}

mongo <<'JS'
db.treatments.drop();
db.treatments.insertMany([
  {eventType: 'Sensor Start', enteredBy: 'librelinkup',
    created_at: '2026-01-02T10:00:00Z'},
  {eventType: 'Sensor Change', created_at: '2026-01-01T10:00:00Z'}
]);
JS
mirror
mirror
mongo <<'JS'
const changes = db.treatments.find({
  enteredBy: 'librelinkup-nightguard'
}).toArray();
const assert = require('node:assert/strict');
assert.equal(changes.length, 1);
assert.equal(changes[0].created_at, '2026-01-02T10:00:00Z');
assert.equal(changes[0].eventType, 'Sensor Change');
db.treatments.insertMany([
  {eventType: 'Sensor Start', enteredBy: 'librelinkup',
    created_at: '2026-01-03T10:00:00Z'},
  {eventType: 'Sensor Change', created_at: '2026-01-04T10:00:00Z'}
]);
JS
mirror
mongo <<'JS'
const assert = require('node:assert/strict');
assert.equal(db.treatments.countDocuments({
  enteredBy: 'librelinkup-nightguard'
}), 1);
db.treatments.drop();
JS
mirror
mongo <<'JS'
const assert = require('node:assert/strict');
assert.equal(db.treatments.countDocuments({}), 0);
db.dropDatabase();
JS
echo 'Passed sensor mirroring: insertion, repeat, newer change, no start'
