# Independent Nightscout development

Create feature branches from `independent-dev` in [this fork](https://github.com/oklitovchenko/cgm-remote-monitor). Open pull requests against `independent-dev` in the same fork. CI runs the existing server and client tests with Node.js 22 and an isolated MongoDB. It also builds and starts the Docker image on both AMD64 and ARM64, then checks API authorization. A push to `independent-dev` runs the same checks for the merged commit.

After staging has been provisioned, copy the full SHA of a successful commit into the `nightscout_sha` field of **Deploy Nightscout staging** in the private infrastructure repository. That workflow builds and deploys that exact revision to the ARM64 staging host. The public fork's CI needs no AWS credentials, production data, or deployment secrets.
