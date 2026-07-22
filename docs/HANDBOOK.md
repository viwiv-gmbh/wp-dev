# wp-dev Handbook

This handbook documents the full operational setup for the public Docker image `viwiv/wp-dev`.

## 1) Purpose

`wp-dev` is a development-oriented WordPress image based on the official WordPress Apache image, extended with Node.js tooling and developer utilities.

Current base and runtime versions are controlled in `.env`:

- `WP_VERSION`
- `PHP_VERSION`
- `NODE_VERSION`
- `APP_USER`
- `APP_UID`
- `APP_GID`

## 2) Image Naming and Tag Strategy

Docker Hub repository:

- `viwiv/wp-dev`

Published tags:

- `latest`
- `{WP_VERSION}-php{PHP_VERSION}-apache-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-apache`

Example with current `.env` values:

- `viwiv/wp-dev:7.0.2-php8.4-apache-node20.11.0`
- `viwiv/wp-dev:7.0.2-php8.4-node20.11.0`
- `viwiv/wp-dev:7.0.2-php8.4-apache`
- `viwiv/wp-dev:latest`

Why both styles exist:

- `...-apache-node...` is the most explicit and should be treated as the canonical tag for this project.
- `...-apache` and `...-node...` are compatibility-oriented convenience tags.

## 3) Repository Structure

Key files:

- `Dockerfile`: image build definition.
- `build.sh`: local build and optional push script.
- `docker-compose.yml`: local runtime configuration.
- `.env`: version and build parameters.
- `.github/workflows/publish-image.yml`: GitHub Actions publish pipeline.
- `.dockerignore` and `.gitignore`: build context and secret hygiene.

## 4) Local Build and Local Runtime

Build locally:

```bash
./build.sh
```

Build without cache:

```bash
./build.sh no-cache
```

Build and push (manual local push):

```bash
./build.sh "" push
```

Run local container:

```bash
docker compose up -d
```

Inspect image tags:

```bash
docker image ls | grep "viwiv/wp-dev"
```

## 5) GitHub Actions Publish Pipeline

Workflow file:

- `.github/workflows/publish-image.yml`

Triggers:

- Push to `main`
- Manual run via `workflow_dispatch`

What the workflow does:

1. Checks out repository.
2. Loads variables from `.env`.
3. Sets up QEMU and Buildx for multi-arch builds.
4. Authenticates to Docker Hub.
5. Generates tags.
6. Builds and pushes `linux/amd64` and `linux/arm64` images.

Variable precedence for build values (`WP_VERSION`, `PHP_VERSION`, `NODE_VERSION`, `APP_USER`, `APP_UID`, `APP_GID`):

1. `workflow_dispatch` input value
2. Existing workflow/job environment variable
3. Repository variable (`vars.*`)
4. `.env` default value

Required GitHub repository secrets:

- `DOCKERHUB_TOKEN`

Optional fallback secret:

- `DOCKERHUB_PASSWORD`

Username location:

- `DOCKERHUB_USERNAME` can be provided as either a repository secret or a repository variable.

Notes:

- `DOCKERHUB_TOKEN` should be a Docker Hub access token, not your account password.
- If only `DOCKERHUB_PASSWORD` is set, the workflow uses it as fallback.
- If `DOCKERHUB_USERNAME` is set as a variable (not a secret), the workflow resolves it correctly.
- Pipeline pushes public image tags directly to Docker Hub.

## 6) Release Process

Recommended process for a new image release:

1. Update `.env` versions.
2. Run local build and smoke test.
3. Commit and push to `main`.
4. Verify GitHub Actions workflow success.
5. Verify tags on Docker Hub.
6. Pull and test published image by exact tag.

Suggested verification commands:

```bash
docker pull viwiv/wp-dev:7.0.2-php8.4-apache-node20.11.0
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node20.11.0 php -v
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node20.11.0 wp --info
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node20.11.0 node -v
```

## 7) Rollback Strategy

If a newly published tag is broken:

1. Do not modify immutable versioned tags if avoidable.
2. Publish a corrected patch tag (for example, update version and republish).
3. Move `latest` only after validation.
4. Communicate the known-good tag to users.

## 8) Security and Compliance

Repository hardening already applied:

- No private SSH keys in repository.
- No private TLS key material in repository.
- Secret-like files ignored via `.gitignore` and `.dockerignore` patterns.
- Legacy branch history was rewritten and replaced by a clean public `main` history.

Operational rules:

- Never commit credentials, private keys, TLS keys, or `.env` secrets.
- Use GitHub Secrets for pipeline credentials.
- Rotate Docker Hub token if exposure is suspected.

## 9) Maintenance Checklist

For each maintenance cycle:

1. Check upstream WordPress and PHP patch versions.
2. Check Node.js LTS updates.
3. Build locally and run basic runtime checks.
4. Push to `main` and verify multi-arch publish.
5. Validate final tags on Docker Hub.
6. Update `README.md` if tag or workflow behavior changed.

## 10) Troubleshooting

Docker Hub login issues in Actions:

- Ensure `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` exist in repo secrets.
- Ensure token has permission to push to `viwiv/wp-dev`.

Tag mismatch or missing tags:

- Check `.env` values used by workflow.
- Confirm workflow run used the latest commit from `main`.

Architecture-specific failures:

- Review Buildx output in workflow logs.
- Retry after clearing cache if needed.

## 11) Ownership and Support

Recommended ownership model:

- Docker Hub repository owned by company account namespace.
- GitHub repository owned by company organization.
- At least two maintainers with admin access to both platforms.

This reduces single-person risk and simplifies long-term maintenance.
