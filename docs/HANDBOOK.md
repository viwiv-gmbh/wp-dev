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
- `ssh/ssh_known_hosts`: pinned SSH host keys baked into the image.
- `ssh/10-known-hosts.conf`: ssh client drop-in pointing at a writable `known_hosts`.
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

## 7) SSH Host Keys

Problem: home directories are frequently mounted read-only into the container
(`lima-... on /root/.ssh type virtiofs (ro,relatime)`). ssh cannot append an
accepted host key to `~/.ssh/known_hosts` (`tee: /root/.ssh/known_hosts:
Read-only file system`), so the host key confirmation prompt for `git push` /
`git clone` returns in every session.

Image-side resolution:

- `/etc/ssh/ssh_known_hosts` contains GitHub's ed25519, ecdsa and rsa host keys,
  baked in at build time and independent of any host mount. Source of truth is
  the versioned file `ssh/ssh_known_hosts`.
- The pinned SHA256 fingerprints live in the `Dockerfile` build arg
  `EXPECTED_SSH_FINGERPRINTS` and are verified during the build. A modified or
  unpinned key fails the build.
- `/etc/ssh/ssh_config.d/10-known-hosts.conf` sets
  `UserKnownHostsFile /var/lib/ssh/known_hosts ~/.ssh/known_hosts`. ssh writes
  new entries to the first file, so everything else lands in
  `/var/lib/ssh/known_hosts`, outside the read-only mount. The directory is
  `root:www-data 0775`, the file `0664`, so both `root` and `APP_USER` can write.
- `entrypoint.sh` recreates that file and its permissions on start, so a fresh
  volume or bind mount over `/var/lib/ssh` stays functional.
- `docker-compose.yml` mounts the named volume `ssh-known-hosts` on
  `/var/lib/ssh` so accepted keys survive container recreation.

Verification:

```bash
docker compose exec wordpress ssh -G github.com | grep -i knownhostsfile
docker compose exec wordpress ssh -T -o BatchMode=yes git@github.com
```

The second command must fail with `Permission denied (publickey)` when no key is
mounted - and must not ask about the host key authenticity.

Adding another host key:

1. `ssh-keyscan -t ed25519 example.com >> ssh/ssh_known_hosts`
2. Verify `ssh-keygen -lf ssh/ssh_known_hosts` against the operator's published
   fingerprint.
3. Append the fingerprint to `EXPECTED_SSH_FINGERPRINTS` in the `Dockerfile`.

Key rotation (e.g. GitHub replacing a host key) requires the same steps plus a
rebuild and publish of the image.

## 8) Release Process

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

## 9) Security

- No private keys or certs in repository.
- Keep credentials in GitHub Secrets.
- Rotate Docker Hub token if exposure is suspected.

## 10) Troubleshooting

If publish fails:

- Confirm `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are configured.
- Confirm resolved version variables are non-empty.
- Check Buildx logs for architecture-specific failures.

SSH host key prompt returns in every session:

- Confirm `/etc/ssh/ssh_known_hosts` exists in the image and contains the host.
- Confirm `ssh -G <host>` lists `/var/lib/ssh/known_hosts` first.
- Confirm `/var/lib/ssh/known_hosts` is writable (`root:www-data`, `0664`); a
  bind mount over `/var/lib/ssh` with wrong ownership on the host overrides the
  image defaults.

MailHog/mhsendmail 404 notes:

- Upstream release assets may be incomplete for some architectures.
- Build is configured to continue if `mhsendmail` binary is unavailable.
- If strict MailHog sendmail behavior is required, pin a release that ships both amd64 and arm64 binaries.

## 11) Ownership

- Docker Hub repo should remain under company namespace.
- Keep at least two maintainers with admin access.
