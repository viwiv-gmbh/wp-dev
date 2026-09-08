#!/bin/sh
# echo "Arguments passed to entrypoint.sh: $@"

# Keep the writable known_hosts store usable even when /var/lib/ssh comes from a
# fresh volume or bind mount. Without it ssh falls back to the home directory,
# which is frequently mounted read-only (Lima/virtiofs) and cannot persist host
# keys, so the confirmation prompt would return in every session.
if mkdir -p /var/lib/ssh 2>/dev/null; then
    [ -f /var/lib/ssh/known_hosts ] || : > /var/lib/ssh/known_hosts
    chown root:www-data /var/lib/ssh /var/lib/ssh/known_hosts 2>/dev/null || true
    chmod 0775 /var/lib/ssh 2>/dev/null || true
    chmod 0664 /var/lib/ssh/known_hosts 2>/dev/null || true
fi

exec /usr/local/bin/docker-entrypoint.sh apache2-foreground
