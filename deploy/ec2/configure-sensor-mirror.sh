#!/bin/sh
set -eu

state_directory=$1
mongo_container=$2
unit_directory=${SYSTEMD_UNIT_DIRECTORY:-/etc/systemd/system}
mkdir -p "$unit_directory"

cat > "$unit_directory/nightscout-mirror-sensor.service" <<UNIT
[Unit]
Description=Mirror LibreLinkUp sensor start for Nightguard
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh "$state_directory/current/mirror-sensor-change.sh" \\
  "$mongo_container"
UNIT

cat > "$unit_directory/nightscout-mirror-sensor.timer" <<'UNIT'
[Unit]
Description=Refresh Nightguard sensor age

[Timer]
OnCalendar=*:0/5

[Install]
WantedBy=timers.target
UNIT

chmod 644 "$unit_directory"/nightscout-mirror-sensor.*
systemctl daemon-reload
systemctl enable --now nightscout-mirror-sensor.timer
