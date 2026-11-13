# Independent Nightscout development

Create feature branches from `independent-dev` in [this fork](https://github.com/oklitovchenko/nightscout). Open pull requests against `independent-dev` in the same fork. CI runs the existing server and client tests with Node.js 22 and an isolated MongoDB. It also builds and starts the Docker image on both AMD64 and ARM64, then checks API authorization. A push to `independent-dev` runs the same checks for the merged commit.

After staging has been provisioned and its instance ID is configured, a push to `independent-dev` runs **Deploy Nightscout staging**. After CI passes, the workflow builds that commit and deploys the two pinned container images to the ARM64 staging host. Use the `staging` GitHub environment for deployment configuration. See the [infrastructure deployment guide](https://github.com/oklitovchenko/nightscout-infra/tree/main/staging) for setup.

The development CI runs with an isolated MongoDB and test credentials. The deployment job uses the staging AWS OIDC role and the `STAGING_RUNTIME_JSON` environment secret.
