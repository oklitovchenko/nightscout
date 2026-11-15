#!/bin/sh
set -eu

docker run --rm -i --network host -v "$PWD:/app" -w /app \
  node:22-bookworm sh -e <<'CI'
npm ci
npm run test:unit:ci -- --ignore ./tests/verifyauth.test.js
npx --no-install env-cmd -f ./tests/ci.test.env mocha \
  --require ./tests/hooks.js --exit ./tests/verifyauth.test.js
npm run test:core
npm run test:integration:ci
CI
