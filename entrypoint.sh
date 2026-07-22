#!/bin/sh
# echo "Arguments passed to entrypoint.sh: $@"
exec /usr/local/bin/docker-entrypoint.sh apache2-foreground