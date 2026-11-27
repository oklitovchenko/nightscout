#!/bin/sh
set -eu

if ! printf '%s\n' "$ROLE_ARN" |
  grep -Eq '^arn:aws:iam::[0-9]{12}:role/.+$'; then
  echo 'AWS_ECR_ROLE_ARN must identify an AWS IAM role.' >&2
  exit 1
fi
if [ -z "$REGION" ] || [ -z "$REPOSITORY" ]; then
  echo 'Set AWS_REGION and ECR_REPOSITORY in GitHub Actions Variables.' >&2
  exit 1
fi

role_suffix=${ROLE_ARN#arn:aws:iam::}
account_id=${role_suffix%%:*}
printf 'account-id=%s\n' "$account_id" >> "$GITHUB_OUTPUT"
