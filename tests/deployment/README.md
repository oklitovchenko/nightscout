# Deployment tests

Run from the repository root. These tests cover delivery behavior without
changing production resources.

- `test-nightscout-deployment.sh`: host deployment and image rollback using
  command mocks; requires `jq` and OpenSSL.
- `test-nightscout-access.sh`: access validation, adoption, idempotency and
  preservation of unrelated clients and tokens using a mock API.
- `test-nightscout-image.sh`: starts the built `nightscout:ci` image and
  MongoDB, checks authenticated access, and runs both integration tests
  below. Requires Docker, Linux networking tools and `MONGO_IMAGE`.
- `test-nightscout-access-api.sh`: role creation and adoption against the
  disposable test server API; called by the image test.
- `test-sensor-mirror.sh`: sensor-event compatibility and deduplication in
  the disposable test MongoDB; called by the image test.

The CI entry point is `.github/scripts/build-and-check-nightscout-image.sh`.
It runs the mock tests, builds the image, and starts the image test.
