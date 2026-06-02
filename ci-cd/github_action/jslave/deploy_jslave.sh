#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="/etc/puppetlabs/code/environments/production/modules/jslave"

cd "${MODULE_DIR}"

echo "Deployment timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Target module directory: ${MODULE_DIR}"
echo "GitHub revision: ${GITHUB_SHA:-unknown}"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Remote git revision: $(git rev-parse HEAD)"
else
  echo "Remote git revision: unavailable (module path is not a git checkout)"
fi

echo "Running Puppet validation for jslave..."

if command -v puppet >/dev/null 2>&1; then
  puppet parser validate manifests/*.pp
else
  echo "puppet command not found on remote host" >&2
  exit 1
fi

echo "jslave module deployment completed successfully."
