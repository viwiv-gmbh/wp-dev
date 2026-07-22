#!/bin/bash
set -eo pipefail

if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

# Use with defaults
APP_USER=${APP_USER:-dev}
APP_UID=${APP_UID:-1000}
APP_GID=${APP_GID:-1000}
CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION:-none}

# Optionale Flags
NO_CACHE="${1:-}"
PUSH="${2:-}"
IMAGE_NAME="viwiv/wp-dev"
VERSION_TAG="${WP_VERSION}-php${PHP_VERSION}-apache-node${NODE_VERSION}"

docker build ${NO_CACHE:+--no-cache} \
    --build-arg NODE_VERSION=$NODE_VERSION \
    --build-arg PHP_VERSION=$PHP_VERSION \
    --build-arg WP_VERSION=$WP_VERSION \
    --build-arg VERSION=$VERSION \
    --build-arg APP_USER=$APP_USER \
    --build-arg APP_UID=$APP_UID \
    --build-arg APP_GID=$APP_GID \
    --build-arg CLAUDE_CODE_VERSION=$CLAUDE_CODE_VERSION \
    -t "${IMAGE_NAME}:${VERSION_TAG}" \
    -t "${IMAGE_NAME}:latest" . || {
    echo "❌ Docker build failed"
    exit 1
}

echo "✅ Docker build successful"

if [ "$PUSH" == "push" ]; then
    docker push "${IMAGE_NAME}:${VERSION_TAG}" && \
    docker push "${IMAGE_NAME}:latest" && \
        echo "✅ Docker push successful" || {
        echo "❌ Docker push failed"
        exit 1
    }
fi