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
