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
- SSH-Host-Keys von GitHub fest im Image, plus beschreibbarer `known_hosts`-Pfad
- Multi-Arch Build (amd64/arm64) via Buildx

## Voraussetzungen

- Docker Desktop oder Docker Engine
- macOS (Apple Silicon/Intel), Linux oder Windows (WSL2)

## Konfiguration

Alle Versionen und Build-Parameter werden über `.env` gesteuert:

```bash
NODE_VERSION=22.0.0
PHP_VERSION=8.4
WP_VERSION=7.0.2
VERSION=1.0.0
APP_USER=dev
APP_UID=1000
APP_GID=1000
CLAUDE_CODE_VERSION=latest
```

Hinweis zu Claude Code:

- Standard ist `CLAUDE_CODE_VERSION=latest` bei `NODE_VERSION=22.0.0`.
- Deaktivieren: `CLAUDE_CODE_VERSION=none` oder `off`.

## Build

### Mit Makefile

```bash
make build
make build-no-cache
make build-push
```

Optionaler Check des aufgeloesten WordPress-Base-Images:

```bash
make check-base-image
```

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
| `/etc/ssh/ssh_known_hosts` | Fest eingebackene SSH-Host-Keys (u.a. `github.com`) |
| `/var/lib/ssh/known_hosts` | Beschreibbarer `known_hosts` fuer alle weiteren Hosts |

## SSH Host Keys

Home-Verzeichnisse werden haeufig read-only in den Container gemountet
(z.B. `lima-... on /root/.ssh type virtiofs (ro,relatime)`). SSH kann einen
bestaetigten Host-Key dann nicht in `~/.ssh/known_hosts` schreiben
(`tee: /root/.ssh/known_hosts: Read-only file system`), weshalb die
Bestaetigungsabfrage bei `git push` / `git clone` in jeder Session erneut kommt.

Das Image loest das zweifach:

1. **Fest eingebacken:** Die Host-Keys von `github.com` (ed25519, ecdsa, rsa)
   liegen in `/etc/ssh/ssh_known_hosts` — unabhaengig vom Host-Mount. Die Keys
   stehen versioniert in `ssh/ssh_known_hosts`; ihre SHA256-Fingerprints sind im
   `Dockerfile` (`EXPECTED_SSH_FINGERPRINTS`) gepinnt und werden zur Build-Zeit
   geprueft. Ein veraenderter oder unbekannter Key laesst den Build fehlschlagen.
2. **Beschreibbarer Pfad:** `/etc/ssh/ssh_config.d/10-known-hosts.conf` setzt

   ```text
   UserKnownHostsFile /var/lib/ssh/known_hosts ~/.ssh/known_hosts
   ```

   SSH schreibt neue Eintraege immer in die **erste** Datei, also nach
   `/var/lib/ssh/known_hosts` ausserhalb des read-only Mounts. `~/.ssh/known_hosts`
   bleibt lesend eingebunden. In `docker-compose.yml` liegt darauf das Volume
   `ssh-known-hosts`, damit die Eintraege ein Neuerstellen des Containers ueberleben.

Pruefen im Container:

```bash
ssh -G github.com | grep -i knownhostsfile
ssh -T -o BatchMode=yes git@github.com   # kein Host-Key-Prompt mehr
```

Weiteren Host fest einbacken:

```bash
ssh-keyscan -t ed25519 example.com >> ssh/ssh_known_hosts
ssh-keygen -lf ssh/ssh_known_hosts       # Fingerprint gegen die Quelle pruefen
# Fingerprint zusaetzlich in EXPECTED_SSH_FINGERPRINTS im Dockerfile eintragen
```

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

Override-Reihenfolge fuer Build-Variablen in GitHub Actions:

1. `workflow_dispatch` Inputs
2. Bereits gesetzte Job/Workflow-Umgebungsvariablen
3. Repository Variables (`vars.*`)
4. `.env` (Default)

Das gilt auch fuer `CLAUDE_CODE_VERSION`.

## Security Hinweis

Private Schluessel, Zertifikate und andere Secrets gehoeren nicht ins Repository.
Nutzen Sie lokale, nicht versionierte Dateien oder Secret-Management in CI.

Hinweis zu MailHog/mhsendmail:

- Die Installation von `mhsendmail` ist im Build als best-effort konfiguriert.
- Wenn fuer eine Architektur im gewaehlten Release kein Binary existiert, wird der Build nicht abgebrochen.
