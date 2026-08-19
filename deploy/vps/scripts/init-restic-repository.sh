#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly restic_password_file="/opt/petmagic/shared/env/restic-password"

if [[ "$#" -ne 1 || "$1" != "--confirm-new-repository" ]]; then
  echo "Usage: $0 --confirm-new-repository" >&2
  echo "This is a one-time operation. Scheduled backups never initialize repositories." >&2
  exit 2
fi

env_value() {
  local key="$1"
  local value
  value="$(sed -n "s/^${key}=//p" "$env_file" | tail -n 1)"
  if (( ${#value} >= 2 )); then
    if [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]] \
      || [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

cd "$deploy_root"
/usr/bin/bash deploy/vps/scripts/preflight.sh "$env_file"

if [[ ! -f "$restic_password_file" || "$(stat -c '%a' "$restic_password_file")" != "600" ]]; then
  echo "Missing mode-0600 restic password file: $restic_password_file" >&2
  exit 1
fi
if ! command -v restic >/dev/null 2>&1; then
  echo "restic is required for off-site backups." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$(env_value R2_ACCESS_KEY)"
export AWS_SECRET_ACCESS_KEY="$(env_value R2_SECRET_KEY)"
export AWS_DEFAULT_REGION=auto
export RESTIC_PASSWORD_FILE="$restic_password_file"
export RESTIC_REPOSITORY="s3:https://$(env_value R2_ACCOUNT_ID).r2.cloudflarestorage.com/$(env_value PETMAGIC_BACKUP_R2_BUCKET)/petmagic-vps"

restic init
restic snapshots >/dev/null
echo "Encrypted off-site backup repository initialized."
