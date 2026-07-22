# wp-dev Handbook

This handbook documents the operational setup for the public Docker image `viwiv/wp-dev`.

## 1) Purpose

`wp-dev` is a development-oriented WordPress image based on the official WordPress Apache image, extended with Node.js tooling and developer utilities.

Current default versions are controlled in `.env`:

- `WP_VERSION`
- `PHP_VERSION`
- `NODE_VERSION`
- `APP_USER`
- `APP_UID`
- `APP_GID`
- `CLAUDE_CODE_VERSION`

Current defaults:

- `NODE_VERSION=22.0.0`
- `CLAUDE_CODE_VERSION=latest`

## 2) Image Naming and Tag Strategy

Docker Hub repository:

- `viwiv/wp-dev`

Published tags:

- `latest`
- `{WP_VERSION}-php{PHP_VERSION}-apache-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-apache`

Example with current defaults:

- `viwiv/wp-dev:7.0.2-php8.4-apache-node22.0.0`
- `viwiv/wp-dev:7.0.2-php8.4-node22.0.0`
- `viwiv/wp-dev:7.0.2-php8.4-apache`
- `viwiv/wp-dev:latest`

## 3) Repository Structure

Key files:

- `Dockerfile`: image build definition.
- `build.sh`: local build and optional push script.
- `docker-compose.yml`: local runtime configuration.
- `.env`: version and build parameters.
- `.github/workflows/publish-image.yml`: GitHub Actions publish pipeline.
- `.dockerignore` and `.gitignore`: build context and secret hygiene.

## 4) Local Build and Runtime

Build locally:

```bash
./build.sh
```

Build without cache:

```bash
./build.sh no-cache
```

Build and push manually:

```bash
./build.sh "" push
```

Run locally:

```bash
docker compose up -d
```

## 5) GitHub Actions Publish Pipeline

Workflow file:

- `.github/workflows/publish-image.yml`

Triggers:

- Push to `main`
- Manual run via `workflow_dispatch`

Variable precedence for build values (`WP_VERSION`, `PHP_VERSION`, `NODE_VERSION`, `APP_USER`, `APP_UID`, `APP_GID`, `CLAUDE_CODE_VERSION`):

1. `workflow_dispatch` input value
2. Existing workflow/job environment variable
3. Repository variable (`vars.*`)
4. `.env` default value

Required GitHub secrets:

- `DOCKERHUB_TOKEN`

Optional fallback secret:

- `DOCKERHUB_PASSWORD`

Docker Hub username location:

- Secret: `DOCKERHUB_USERNAME`
- Variable: `DOCKERHUB_USERNAME`

## 6) Claude Code Behavior

Default behavior:

- Installs `@anthropic-ai/claude-code@latest`.

Disable explicitly:

- `CLAUDE_CODE_VERSION=none` or `off`

Compatibility guard:

- If `CLAUDE_CODE_VERSION` is enabled but Node major is below 22, install is skipped with an informational message.

## 7) Release Process

1. Update `.env` or set workflow overrides.
2. Build locally and smoke test.
3. Push to `main`.
4. Verify workflow success.
5. Verify tags in Docker Hub.

Suggested checks:

```bash
docker pull viwiv/wp-dev:7.0.2-php8.4-apache-node22.0.0
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node22.0.0 php -v
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node22.0.0 wp --info
docker run --rm viwiv/wp-dev:7.0.2-php8.4-apache-node22.0.0 node -v
```

## 8) Security

- No private keys or certs in repository.
- Keep credentials in GitHub Secrets.
- Rotate Docker Hub token if exposure is suspected.

## 9) Troubleshooting

If publish fails:

- Confirm `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are configured.
- Confirm resolved version variables are non-empty.
- Check Buildx logs for architecture-specific failures.

## 10) Ownership

- Docker Hub repo should remain under company namespace.
- Keep at least two maintainers with admin access.
