# wp-dev

Entwicklungs-optimiertes WordPress Docker Image für schnelle und konsistente lokale Entwicklung und CI-Builds.

## Dokumentation

- Vollstaendiges Betriebs- und Publish-Handbuch: `docs/HANDBOOK.md`

## Features

- WordPress Basis-Image mit Apache
- Konfigurierbare PHP- und WordPress-Versionen über `.env`
- Node.js via nvm inkl. Yarn
- Composer und WP-CLI vorinstalliert
- MailHog Integration (`mailhog:1025`)
- yq für YAML-Verarbeitung (architekturabhängige Installation)
- Claude Code CLI vorinstalliert
- Multi-Arch Build (amd64/arm64) via Buildx

## Voraussetzungen

- Docker Desktop oder Docker Engine
- macOS (Apple Silicon/Intel), Linux oder Windows (WSL2)

## Konfiguration

Alle Versionen und Build-Parameter werden über `.env` gesteuert:

```bash
NODE_VERSION=20.11.0
PHP_VERSION=8.4
WP_VERSION=7.0.2
VERSION=1.0.0
APP_USER=dev
APP_UID=1000
APP_GID=1000
```

## Build

### Standard Build

```bash
./build.sh
```

### Build ohne Cache

```bash
./build.sh no-cache
```

### Build und Push

```bash
./build.sh "" push
```

Das Script erzeugt folgende Tags:

```text
viwiv/wp-dev:{WP_VERSION}-php{PHP_VERSION}-apache-node{NODE_VERSION}
viwiv/wp-dev:latest
```

## Verwendung

### Lokal starten

```bash
docker run -d \
  --name wordpress \
  -p 8080:80 \
  -p 3000:3000 \
  -v "$HOME/.claude:/home/dev/.claude" \
  viwiv/wp-dev:${WP_VERSION}-php${PHP_VERSION}-apache-node${NODE_VERSION}
```

### Mit Docker Compose

```bash
docker compose up -d
```

### In den Container gehen

```bash
docker exec -it wordpress bash
```

### Claude Code im Container

```bash
claude --version
claude-bootstrap
```

## Wichtige Pfade

| Pfad | Beschreibung |
|------|-------------|
| `/var/www/html` | WordPress Root (www-data:www-data, 775) |
| `/home/dev` | Benutzer-Home im Standard-Setup |
| `/usr/local/nvm` | Node Version Manager |
| `/usr/bin/yq` | YAML Query Tool |

## Berechtigungen

Das Image konfiguriert automatisch:

- Benutzer: `dev` (standardmaessig)
- Gruppe: `www-data` für `/var/www`
- Berechtigungen: `775` mit setgid auf `/var/www`

## Backup und Restore

```bash
docker exec wordpress wp --allow-root db export backup.sql
docker compose cp backup/backup.sql wordpress:/var/www/html/
docker compose exec wordpress wp --allow-root db import backup.sql
```

## Troubleshooting

### Berechtigungsfehler

```bash
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress chmod -R 775 /var/www/html
```

## CI/CD

GitHub Actions verwendet Docker Buildx mit Registry-Cache:

- Push auf `main`: Multi-Arch Build (`linux/amd64,linux/arm64`) mit Push nach Docker Hub
- Build Cache: GitHub Actions Cache
- Workflow-Datei: `.github/workflows/publish-image.yml`

Benötigte GitHub Secrets:

- `DOCKERHUB_TOKEN`

Optionaler Fallback (falls kein Token genutzt wird):

- `DOCKERHUB_PASSWORD`

Docker Hub Username kann als Repository Secret oder Repository Variable gesetzt werden:

- Secret: `DOCKERHUB_USERNAME`
- Variable: `DOCKERHUB_USERNAME`

Typische publizierte Tags:

- `latest`
- `{WP_VERSION}-php{PHP_VERSION}-apache-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-node{NODE_VERSION}`
- `{WP_VERSION}-php{PHP_VERSION}-apache`

## Security Hinweis

Private Schluessel, Zertifikate und andere Secrets gehoeren nicht ins Repository.
Nutzen Sie lokale, nicht versionierte Dateien oder Secret-Management in CI.
