#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="/etc/puppetlabs/code/environments/production/modules/jenkins_master"

cd "${MODULE_DIR}"

echo "Running Puppet validation for jenkins_master..."

if command -v puppet >/dev/null 2>&1; then
  puppet parser validate manifests/*.pp
else
  echo "puppet command not found on remote host" >&2
  exit 1
fi

echo "jenkins_master module deployment completed successfully."
