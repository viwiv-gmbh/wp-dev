#!/usr/bin/env bash
# Prüft Spec 017 (WPorbit) an einem gebauten Image:
#   ./tests/no-root.sh viwiv/wp-dev:<tag>
# Braucht nur Docker, kein Netz (der Container läuft mit --network none).
set -euo pipefail
IMAGE="${1:?Image angeben, z. B. viwiv/wp-dev:7.1.2-php8.5-apache}"
C="wp-dev-no-root-test-$$"
fails=0

docker run -d --rm --name "$C" --network none --entrypoint sleep "$IMAGE" 600 >/dev/null
trap 'docker rm -f "$C" >/dev/null 2>&1 || true' EXIT

check() { # Beschreibung, Erwartung, Befehl…
    local name="$1" expected="$2"; shift 2
    local out
    out="$("$@" 2>&1 || true)"
    if grep -qE -- "$expected" <<<"$out"; then
        echo "✔ $name"
    else
        echo "✘ $name"; echo "    erwartet: $expected"; echo "    bekommen: ${out//$'\n'/ | }"
        fails=$((fails + 1))
    fi
}
as() { local user="$1"; shift; docker exec -u "$user" -e HOME=/tmp -w /tmp "$C" sh -c "$*"; }
# Ohne Shell dazwischen: Argumente gehen unverändert an das Programm.
asx() { local user="$1"; shift; docker exec -u "$user" -e HOME=/tmp -w /tmp "$C" "$@"; }

PROBE='echo posix_getpwuid(posix_geteuid())["name"];'

check "wp als www-data läuft als www-data"        '^www-data$' asx www-data wp --skip-wordpress eval "$PROBE"
check "wp als dev läuft als www-data (sudo)"      '^www-data$' asx dev      wp --skip-wordpress eval "$PROBE"
check "wp als root läuft als www-data (setpriv)"  '^www-data$' asx root     wp --skip-wordpress eval "$PROBE"
check "--allow-root wird geschluckt"              '^www-data$' asx root     wp --allow-root --skip-wordpress eval "$PROBE"
check "stdin kommt durch"                          '^hallo$'    as dev      "echo hallo | wp --skip-wordpress eval 'echo trim(stream_get_contents(STDIN));'"
check "sudo -l als dev: nur wp-cli.phar"          '\(www-data\) NOPASSWD: /usr/local/bin/wp-cli.phar' as dev "sudo -n -l"
check "sudo -l als dev: keine weitere Regel"      '^1$'        as dev      "sudo -n -l | grep -c NOPASSWD"
check "dev wird nicht root"                        'password is required|not allowed|a password' as dev "sudo -n -u root true"
check "dev startet keine Shell als www-data"      'password is required|not allowed|a password' as dev "sudo -n -u www-data /bin/sh -c id"
check "claude als root ohne Variable: Warnung"    'Hinweis: Claude läuft hier als root' as root "claude --version"
check "claude als root ohne Variable: läuft"      '[0-9]+\.[0-9]+\.[0-9]+' as root "claude --version"
check "claude als root mit WPORBIT_CONTAINER_USER=dev: abgewiesen" '›Terminal‹ statt ›Terminal \(root\)‹' \
    as root "WPORBIT_CONTAINER_USER=dev claude --version; echo exit=\$?"
check "claude als dev läuft"                       '[0-9]+\.[0-9]+\.[0-9]+' as dev "WPORBIT_CONTAINER_USER=dev claude --version"

if [ "$fails" -gt 0 ]; then echo "$fails Prüfung(en) fehlgeschlagen."; exit 1; fi
echo "Alle Prüfungen bestanden."
