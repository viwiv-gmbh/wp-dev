SHELL := /bin/bash

.DEFAULT_GOAL := help

BUILD_SCRIPT := ./build.sh

# Fallbacks used by check-base-image if .env does not set values.
DEFAULT_WP_VERSION := 6.6.2
DEFAULT_PHP_VERSION := 8.2

.PHONY: help build build-no-cache build-push check-base-image print-config

help:
	@echo "Available targets:"
	@echo "  make build           - Run ./build.sh"
	@echo "  make build-no-cache  - Run ./build.sh no-cache"
	@echo "  make build-push      - Run ./build.sh '' push"
	@echo "  make check-base-image - Validate wordpress base image tag"
	@echo "  make print-config    - Show resolved WP/PHP versions"

build: check-base-image
	@$(BUILD_SCRIPT)

build-no-cache: check-base-image
	@$(BUILD_SCRIPT) no-cache

build-push: check-base-image
	@$(BUILD_SCRIPT) "" push


print-config:
	@set -euo pipefail; \
	WP_VERSION="$$(grep -E '^WP_VERSION=' .env 2>/dev/null | cut -d'=' -f2 || true)"; \
	PHP_VERSION="$$(grep -E '^PHP_VERSION=' .env 2>/dev/null | cut -d'=' -f2 || true)"; \
	WP_VERSION="$${WP_VERSION:-$(DEFAULT_WP_VERSION)}"; \
	PHP_VERSION="$${PHP_VERSION:-$(DEFAULT_PHP_VERSION)}"; \
	echo "WP_VERSION=$$WP_VERSION"; \
	echo "PHP_VERSION=$$PHP_VERSION"; \
	echo "BASE_IMAGE=wordpress:$$WP_VERSION-php$$PHP_VERSION-apache"

check-base-image:
	@set -euo pipefail; \
	WP_VERSION="$$(grep -E '^WP_VERSION=' .env 2>/dev/null | cut -d'=' -f2 || true)"; \
	PHP_VERSION="$$(grep -E '^PHP_VERSION=' .env 2>/dev/null | cut -d'=' -f2 || true)"; \
	WP_VERSION="$${WP_VERSION:-$(DEFAULT_WP_VERSION)}"; \
	PHP_VERSION="$${PHP_VERSION:-$(DEFAULT_PHP_VERSION)}"; \
	BASE_IMAGE="wordpress:$$WP_VERSION-php$$PHP_VERSION-apache"; \
	echo "Checking $$BASE_IMAGE"; \
	MANIFEST_OUT="$$(docker manifest inspect "$$BASE_IMAGE" 2>&1)"; MANIFEST_EXIT=$$?; \
	if [ $$MANIFEST_EXIT -eq 0 ]; then \
		echo "Base image exists"; \
	else \
		echo "Base image not found or registry check failed: $$BASE_IMAGE"; \
		echo "docker manifest inspect output:"; \
		echo "$$MANIFEST_OUT"; \
		echo "Set valid WP_VERSION/PHP_VERSION values in .env and try again"; \
		echo "If this still fails for known-valid tags, check Docker network/auth access"; \
		exit 1; \
	fi
