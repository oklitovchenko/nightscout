#!/bin/sh
set -eu

release=$1
settings=$(cat "$release/settings.json")
rm "$release/settings.json"
printf '%s' "$settings" | jq -er --arg mongo "$2" --arg port "$3" '
  def selected($keys):
    with_entries(select(.key as $key | $keys | index($key)));
  def has_values($keys):
    . as $object | all($keys[]; ($object[.] | strings | length > 0) // false);
  def enable($plugin):
    .ENABLE = (
      [(.ENABLE // "" | scan("\\S+")), $plugin]
      | reduce .[] as $item
          ([]; if index($item) == null then . + [$item] else . end)
      | join(" ")
    );
  . as $settings
  | ["BRIDGE_USER_NAME", "BRIDGE_PASSWORD"] as $bridge
  | ["CONNECT_LINK_UP_USERNAME", "CONNECT_LINK_UP_PASSWORD"] as $linkup
  | if (.API_SECRET | type == "string" and length >= 12) then .
    else error("Server API_SECRET must be at least 12 characters") end
  | selected([
      "DISPLAY_UNITS", "TIME_FORMAT", "DEVICESTATUS_ADVANCED", "ENABLE"
    ])
    + {
        API_SECRET: $settings.API_SECRET,
        AUTH_DEFAULT_ROLES: "denied",
        INSECURE_USE_HTTP: "true",
        MONGODB_URI: ("mongodb://" + $mongo + ":27017/server"),
        PORT: $port
      }
  | if any($bridge[]; ($settings[.] // "") != "") then
      if ($settings | has_values($bridge)) then
        . + ($settings | selected($bridge))
        | enable("bridge")
        | .BRIDGE_SERVER = (
            if $settings | has("BRIDGE_SERVER")
            then $settings.BRIDGE_SERVER else "EU" end
          )
      else error("Dexcom requires both username and password") end
    elif (.ENABLE // "" | [scan("\\S+")] | index("bridge")) != null then
      .ENABLE = (.ENABLE | [scan("\\S+") | select(. != "bridge")] | join(" "))
    else . end
  | if $settings.CONNECT_SOURCE == "linkup" then
      if ($settings | has_values($linkup)) then
        . + ($settings | selected($linkup + [
          "CONNECT_SOURCE", "CONNECT_LINK_UP_REGION",
          "CONNECT_LINK_UP_SENSOR_INFO", "CONNECT_LINK_UP_INTERVAL"
        ]))
        | enable("connect")
      else error("Nightscout Connect needs LibreLinkUp credentials") end
    else . end
  | if all(.[]; type == "string"
      and (explode | all(. != 0 and . != 10 and . != 13))) then
      to_entries[] | "\(.key)=\(.value)"
    else error("Expected single-line strings in server configuration") end
' > "$release/nightscout.env"
