#!/usr/bin/env bash
set -euo pipefail

# Install selected skills once per user profile.
SKILL_MARKER="${HOME}/.claude/.skills-installed"
mkdir -p "${HOME}/.claude"

if [[ -f "${SKILL_MARKER}" ]]; then
  echo "Claude skills already installed."
  exit 0
fi

npx --yes skills add pbakaus/impeccable
npx --yes skills add https://github.com/wordpress/agent-skills

touch "${SKILL_MARKER}"
echo "Claude skills installed successfully."
