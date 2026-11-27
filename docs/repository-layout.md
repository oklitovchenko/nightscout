# Repository layout

The fork retains the upstream application structure. Personal release
changes are maintained on `my-main`; upstream fixes remain independently
reviewable. Use the existing subsystem directory before adding a new one.

| Location | Responsibility |
| --- | --- |
| `lib/` | Server, APIs, authorization, plugins, and client application code. |
| `static/`, `views/` | Browser assets and rendered page templates. |
| `bundle/`, `webpack/` | Browser bundle inputs and build configuration. |
| `assets/`, `translations/` | Shared resources and translations. |
| `bin/`, `scripts/`, `tools/` | Existing upstream utilities; inspect callers. |
| `tests/` | Application tests, fixtures, hooks, and existing test suites. |
| `tests/deployment/` | EC2 release, image, access, and sensor-adapter tests. |
| `testing/` | Existing upstream test support; preserve current consumers. |
| `deploy/ec2/` | Production release scripts packaged inside the image. |
| `.github/scripts/` | CI test invocation, build, publication, and deployment. |
| `.github/workflows/` | Workflow events, jobs, permissions, and settings. |
| `docs/` | Application documentation, contracts, and maintenance guides. |
| `Dockerfile`, `.dockerignore` | Image stages and Docker build context. |
| `.browserslistrc`, `.babelrc` | Browser targets and compilation. |
| `package.json`, `package-lock.json` | Commands and pinned dependency tree. |
| `AGENTS.md` | Development, delivery, validation, and commit agreements. |

[EC2 deployment](../deploy/ec2/README.md) describes runtime configuration,
image selection, rollback, and application access reconciliation.
[Deployment tests](../tests/deployment/README.md) lists test entry points.
Infrastructure and AWS account operations live in separate repositories;
this repository does not contain their Terraform or CloudFormation stacks.
