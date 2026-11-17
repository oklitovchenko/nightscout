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
