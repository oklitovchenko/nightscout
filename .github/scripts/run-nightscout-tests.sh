#!/bin/sh
set -eu

docker run --rm -i --network host -e VERIFYAUTH_TIMEOUT_SECONDS \
  -v "$PWD:/app" -w /app \
  node:22-bookworm sh -e <<'CI'
npm ci
hook_directory=$(mktemp -d)
trap 'rm -rf "$hook_directory"' 0
cat > "$hook_directory/verifyauth-timeout.cjs" <<'JAVASCRIPT'
'use strict';

const configuredSeconds = process.env.VERIFYAUTH_TIMEOUT_SECONDS;
const seconds = Number(configuredSeconds);
const milliseconds = seconds * 1000;

if (configuredSeconds && (!Number.isInteger(seconds) || seconds < 1 ||
    milliseconds > 2 ** 31 - 1)) {
  throw new Error('VERIFYAUTH_TIMEOUT_SECONDS must be between 1 and 2147483');
}

exports.mochaHooks = {
  beforeEach() {
    if (configuredSeconds) {
      this.currentTest.timeout(milliseconds);
    }
  }
};
JAVASCRIPT
npx --no-install env-cmd -f ./tests/ci.test.env mocha \
  --require ./tests/hooks.js \
  --require "$hook_directory/verifyauth-timeout.cjs" \
  --exit ./tests/verifyauth.test.js
npm run test:unit:ci -- --grep '^verifyauth ' --invert
npm run test:core
npm run test:integration:ci
CI
