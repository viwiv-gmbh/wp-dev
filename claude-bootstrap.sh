#!/usr/bin/env bash
set -euo pipefail

# Install selected skills once per user profile — outside of WPorbit.
#
# In a WPorbit project the app manages the skills: pinned versions with a
# checksum, in the volume all projects share (WPorbit Spec 006). This script
# instead fetches unpinned code at runtime (`npx --yes`) and would put folders
# next to the managed ones. So in WPorbit it does nothing.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

if [[ -n "${WPORBIT_PROJECT:-}" || -f "${CLAUDE_DIR}/skills/.wporbit-official" ]]; then
  echo "Skills are managed by WPorbit (${CLAUDE_DIR}/skills) — claude-bootstrap does nothing here."
  exit 0
fi

SKILL_MARKER="${CLAUDE_DIR}/.skills-installed"
mkdir -p "${CLAUDE_DIR}"

if [[ -f "${SKILL_MARKER}" ]]; then
  echo "Claude skills already installed."
  exit 0
fi

npx --yes skills add pbakaus/impeccable
npx --yes skills add https://github.com/wordpress/agent-skills

touch "${SKILL_MARKER}"
echo "Claude skills installed successfully."
