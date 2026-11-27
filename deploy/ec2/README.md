# EC2 deployment

The image packages these files under `/opt/deploy`. Systems Manager
extracts them from the selected image and runs `deploy.sh` on EC2.
The script reads the requested settings version from Parameter Store,
starts the container, and restores the previous release on failure.

Successful builds publish ECR tags such as `15.0.9-my.22`, using the package
version and workflow run number. Retries append the attempt, for example
`15.0.9-my.22.2`. The run summary shows both the tag and digest.
For manual deployment, enable `deploy` and enter the published `image_tag`.
The workflow resolves the tag to an immutable digest before deployment.
Leave the tag empty to reuse the running image and update its settings.

Set the GitHub Actions repository variable `MONGO_IMAGE` to a version tag,
for example `mongo:8.0` or a specific patch version. CI uses the same image.
The workflow includes it in the versioned settings passed through SSM.
It is used when creating MongoDB; changing it does not upgrade an existing
MongoDB container.

The release includes the Nightguard sensor-event adapter. Connect records
LibreLinkUp activation as `Sensor Start`; the original Nightguard client
reads `Sensor Change`. After a successful deployment, a systemd timer runs
the adapter every five minutes. It inserts a matching change only when
there is no newer one, preserves manually recorded changes and avoids
duplicates. The adapter and its query are versioned with the release.
It does not need an API token.

## Application access

Set `NIGHTSCOUT_ACCESS_OPTIONS_JSON` in the GitHub `production` environment
variables. It contains `roles` (name and permissions) and `subjects` (name
and roles). Client tokens and API_SECRET must never appear in this value.

Deployment validates the configuration and reconciles it through the local
Nightscout administration API after the authenticated health check. Existing
subjects keep their identities, tokens, and unrelated role bindings. Only
declared roles are managed; every existing user of those roles must be
declared. Subjects must already exist. Nothing is automatically deleted.
Empty arrays explicitly leave application access unmanaged.

Repeated deployment skips matching records and verifies changed records.
An API failure fails deployment. Access writes are not a transaction and
are not undone by container rollback; correct the variable and redeploy to
converge after a partial failure. Review permission removals before release.
Deploy an image containing this reconciler for its first activation;
reusing an older image cannot apply access configuration.
