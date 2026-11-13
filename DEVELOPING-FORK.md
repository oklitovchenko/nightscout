# Independent Nightscout development

Create feature branches from `main` in [this fork](https://github.com/oklitovchenko/nightscout). Open pull requests against `main` in the same fork. CI runs the existing server and client tests with Node.js 22 and an isolated MongoDB. It also builds and starts the Docker image on both AMD64 and ARM64, then checks API authorization. A push to `main` runs the same checks for the merged commit.

After the replacement server has been provisioned and its instance ID is configured, a push to `main` runs **Deploy Nightscout server**. After CI passes, the workflow builds that commit and deploys the two pinned container images to the ARM64 replacement host. Use the `production` GitHub environment for deployment configuration. See the [infrastructure deployment guide](https://github.com/oklitovchenko/nightscout-infra/tree/main/server) for setup.

The development CI runs with an isolated MongoDB and test credentials. The deployment job uses the AWS OIDC deployment role and the `NIGHTSCOUT_RUNTIME_JSON` environment secret.
