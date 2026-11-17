#!/bin/sh
set -eu

if ! printf '%s\n' "$MONGO_IMAGE" |
  grep -Eq '^mongo:[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
  echo 'Set MONGO_IMAGE to a version tag, for example mongo:8.0.' >&2
  exit 1
fi

if ! printf '%s\n' "$TARGET_INSTANCE" | grep -Eq '^i-[a-f0-9]{17}$'; then
  echo 'Set NIGHTSCOUT_INSTANCE_ID to a valid EC2 instance ID.' >&2
  exit 1
fi
IMAGE_DIGEST=
if [ -n "$IMAGE_TAG" ]; then
  if ! printf '%s\n' "$IMAGE_TAG" |
    grep -Eq '^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$'; then
    echo 'Provide a valid ECR image tag.' >&2
    exit 1
  fi
  IMAGE_DIGEST=$(aws ecr batch-get-image \
    --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=$IMAGE_TAG" \
    --query 'images[0].imageId.imageDigest' --output text)
  if ! printf '%s\n' "$IMAGE_DIGEST" | grep -Eq '^sha256:[a-f0-9]{64}$'; then
    echo "No image digest found for tag $IMAGE_TAG." >&2
    exit 1
  fi
  printf 'Deploying %s (%s)\n' "$IMAGE_TAG" "$IMAGE_DIGEST"
fi

if ! settings=$(printf '%s\n%s\n' "$RUNTIME_CONFIG" "$RUNTIME_SECRET" |
  jq -cse --arg mongo "$MONGO_IMAGE" '
    def valid:
      type == "object"
      and all(.[]; type == "string"
        and (explode | all(. != 0 and . != 10 and . != 13)));
    def has_values($keys):
      . as $object | all($keys[]; ($object[.] | strings | length > 0) // false);
    def permits($keys): (keys_unsorted - $keys | length) == 0;
    if length == 2 and all(.[]; valid) then . else error("Invalid JSON") end
    | .[0] as $config | .[1] as $secret
    | ["CONNECT_LINK_UP_USERNAME", "CONNECT_LINK_UP_PASSWORD"] as $keys
    | if ($secret | permits($keys
          + ["API_SECRET", "BRIDGE_USER_NAME", "BRIDGE_PASSWORD"]))
         and ($config | permits([
           "ENABLE", "TIME_FORMAT", "DISPLAY_UNITS", "DEVICESTATUS_ADVANCED",
           "CONNECT_SOURCE", "CONNECT_LINK_UP_REGION",
           "CONNECT_LINK_UP_SENSOR_INFO", "CONNECT_LINK_UP_INTERVAL",
           "BRIDGE_SERVER"
         ]))
         and ($secret.API_SECRET | strings | length >= 12)
         and ($config.CONNECT_SOURCE != "linkup"
              or ($secret | has_values($keys)))
         and (($secret | has_values(["BRIDGE_USER_NAME"]))
              == ($secret | has_values(["BRIDGE_PASSWORD"])))
      then $config + $secret + {MONGO_IMAGE: $mongo}
      else error("Invalid Nightscout settings")
      end
  ' 2>/dev/null); then
  echo 'Check NIGHTSCOUT_RUNTIME_OPTIONS_JSON.' >&2
  echo 'Check NIGHTSCOUT_RUNTIME_JSON.' >&2
  exit 1
fi
unset RUNTIME_SECRET
version=$(printf '%s' "$settings" |
  aws ssm put-parameter --name /nightscout/production/nightscout \
    --type SecureString --tier Standard --value file:///dev/stdin \
    --overwrite --query Version --output text)
unset settings

parameters=$(jq -cn --arg image "$IMAGE_DIGEST" --arg version "$version" '
  {configVersion: [$version]}
  + (if $image == "" then {} else {image: [$image]} end)')
command=$(aws ssm send-command --document-name NightscoutDeployApplication \
  --instance-ids "$TARGET_INSTANCE" --parameters "$parameters" \
  --query Command.CommandId --output text)
echo "SSM command $command"

attempt=0
while [ "$attempt" -lt 170 ]; do
  status=$(aws ssm get-command-invocation --command-id "$command" \
    --instance-id "$TARGET_INSTANCE" --query Status --output text \
    2>/dev/null) || status=Pending
  case "$status" in
    Success) echo 'Nightscout deployed successfully.'; exit 0 ;;
    Pending|InProgress|Delayed|Cancelling) sleep 5 ;;
    *) echo "Nightscout deployment ended with status $status." >&2; exit 1 ;;
  esac
  attempt=$((attempt + 1))
done
echo 'Nightscout deployment timed out.' >&2
exit 1
