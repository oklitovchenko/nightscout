'use strict';

const start = db.treatments.find({
  eventType: 'Sensor Start', enteredBy: 'librelinkup'
}).sort({created_at: -1}).limit(1).toArray()[0];
if (!start) quit(0);

const change = db.treatments.find({eventType: 'Sensor Change'})
  .sort({created_at: -1}).limit(1).toArray()[0];
if (change && change.created_at >= start.created_at) quit(0);

const now = Date.now();
const identifier = 'librelinkup:nightguard-sensor-change:' +
  start._id.toString();
db.treatments.updateOne({identifier}, {$setOnInsert: {
  identifier,
  eventType: 'Sensor Change',
  created_at: start.created_at,
  date: Date.parse(start.created_at),
  enteredBy: 'librelinkup-nightguard',
  notes: 'Mirrors the LibreLinkUp sensor activation for Nightguard',
  srvCreated: now,
  srvModified: now,
  isValid: true
}}, {upsert: true});
