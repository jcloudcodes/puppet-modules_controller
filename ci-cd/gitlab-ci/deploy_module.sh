#!/usr/bin/env bash
set -euo pipefail

MODULE_SOURCE="${1:?module source path is required}"
REMOTE_PATH="${2:?remote path is required}"
REMOTE_USER="${3:?remote user is required}"
REMOTE_HOST="${4:?remote host is required}"
REMOTE_VALIDATION_SCRIPT="${5:?remote validation script path is required}"
REVISION="${6:-unknown}"

backup_remote_module() {
  ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "if [ -d ${REMOTE_PATH} ]; then backup_dir=/tmp/$(basename "${REMOTE_PATH}")_backup_${REVISION}_\$(date +%Y%m%d%H%M%S); mkdir -p \"\$backup_dir\"; rsync -az ${REMOTE_PATH}/ \"\$backup_dir\"/; echo \"Backup created at \$backup_dir\"; fi"
}

prepare_remote_path() {
  ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "sudo mkdir -p ${REMOTE_PATH} && sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_PATH}"
}

sync_module() {
  rsync -az --delete \
    "${MODULE_SOURCE}/" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"
}

run_remote_validation() {
  local remote_script
  remote_script="/tmp/$(basename "${REMOTE_VALIDATION_SCRIPT}")"

  rsync -az \
    "${REMOTE_VALIDATION_SCRIPT}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${remote_script}"

  ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "chmod +x ${remote_script} && GITHUB_SHA=${REVISION} /bin/bash ${remote_script} && rm -f ${remote_script}"
}

backup_remote_module
prepare_remote_path
sync_module
run_remote_validation
