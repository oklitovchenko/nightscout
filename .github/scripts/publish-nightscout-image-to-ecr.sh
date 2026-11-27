#!/bin/sh
set -eu

registry="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
version=$(jq -er '.version' package.json)
tag="$version-my.$GITHUB_RUN_NUMBER"
if [ "$GITHUB_RUN_ATTEMPT" -gt 1 ]; then
  tag="$tag.$GITHUB_RUN_ATTEMPT"
fi
image="$registry/$ECR_REPOSITORY:$tag"
password=$(aws ecr get-login-password)
printf '%s\n' "$password" |
  docker login --username AWS --password-stdin "$registry"
unset password

docker tag nightscout:ci "$image"
docker push "$image"
reference=$(docker inspect --format '{{index .RepoDigests 0}}' "$image")
digest=${reference##*@}
if ! printf '%s\n' "$digest" | grep -Eq '^sha256:[a-f0-9]{64}$'; then
  echo "Couldn't read the published image digest." >&2
  exit 1
fi
{
  printf 'Image tag: `%s`\n\n' "$tag"
  printf 'Image digest: `%s`\n' "$digest"
} >> "$GITHUB_STEP_SUMMARY"
