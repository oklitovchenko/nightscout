#!/bin/sh
set -eu

docker run --rm -i --network host -e VERIFYAUTH_TIMEOUT_SECONDS \
  -v "$PWD:/app" -w /app \
  node:22-bookworm sh -e <<'CI'
npm ci
npx --no-install env-cmd -f ./tests/ci.test.env mocha \
  --require ./tests/hooks.js \
  --require ./.github/scripts/verifyauth-timeout.cjs \
  --exit ./tests/verifyauth.test.js
npm run test:unit:ci -- --grep '^verifyauth ' --invert
npm run test:core
npm run test:integration:ci
CI
