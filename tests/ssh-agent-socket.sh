#!/usr/bin/env bash
# Prüft Spec 030 A (WPorbit) an einem gebauten Image:
#   ./tests/ssh-agent-socket.sh viwiv/wp-dev:<tag>
# /ssh-agent gehört dem Benutzer dev (Modus 600); www-data (Apache, PHP) kommt
# nicht heran. Braucht nur Docker, kein Netz.
set -euo pipefail
IMAGE="${1:?Image angeben, z. B. viwiv/wp-dev:7.1.2-php8.5-apache}"
C="wp-dev-ssh-agent-test-$$"
fails=0
docker run -d --rm --name "$C" --network none --entrypoint sleep "$IMAGE" 600 >/dev/null
trap 'docker rm -f "$C" >/dev/null 2>&1 || true' EXIT

check() { # Beschreibung, Erwartung, Befehl…
    local name="$1" expected="$2"; shift 2
    local out
    out="$("$@" 2>&1 || true)"
    if grep -qE -- "$expected" <<<"$out"; then echo "✔ $name"
    else
        echo "✘ $name"; echo "    erwartet: $expected"; echo "    bekommen: ${out//$'\n'/ | }"
        fails=$((fails + 1))
    fi
}
root() { docker exec -u root "$C" sh -c "$*"; }
as()   { local user="$1"; shift; docker exec -u "$user" -e HOME=/tmp -e SSH_AUTH_SOCK=/ssh-agent "$C" sh -c "$*"; }

# Der Socket der VM, wie WPorbit ihn mountet: nur root erreicht ihn.
root 'ssh-agent -a /run/ssh-agent-host.sock >/dev/null && chmod 600 /run/ssh-agent-host.sock'
root 'APP_USER=dev /usr/local/bin/wporbit-ssh-agent-proxy; sleep 1'

check "/ssh-agent gehört dev, Modus 600"          '^srw------- 1 dev '            root 'ls -l /ssh-agent'
check "dev erreicht den Agent"                    'no identities|SHA256'          as dev 'ssh-add -l'
check "www-data kommt nicht an den Agent"         'Permission denied|Error connecting' as www-data 'ssh-add -l'
check "zweiter Lauf: genau ein socat"             '^1$'                           root 'APP_USER=dev /usr/local/bin/wporbit-ssh-agent-proxy; sleep 1; pgrep -xc socat'
check "ssh bindet /etc/wporbit-ssh/config ein"    'wporbit-ssh/config'            root 'cat /etc/ssh/ssh_config.d/20-wporbit.conf'
root 'rm -f /run/ssh-agent-host.sock /ssh-agent; pkill socat || true; pkill ssh-agent || true'
check "ohne Host-Socket: kein /ssh-agent, kein Fehler" 'ok'                       root 'APP_USER=dev /usr/local/bin/wporbit-ssh-agent-proxy && test ! -e /ssh-agent && echo ok'

[ "$fails" -eq 0 ] || { echo "$fails Prüfung(en) fehlgeschlagen"; exit 1; }
echo "Alles in Ordnung."
