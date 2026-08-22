#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly restic_password_file="/opt/petmagic/shared/env/restic-password"
readonly backup_dir="/opt/petmagic/shared/backups/postgres"
readonly api_data_dir="/opt/petmagic/shared/api-data"
readonly api_snapshot_dir="/opt/petmagic/shared/backups/api-data"
readonly backup_job_lock="/run/petmagic/backup-job.lock"
readonly maintenance_lock="/run/petmagic/maintenance.lock"
readonly retention_days="${PETMAGIC_API_DATA_BACKUP_RETENTION_DAYS:-14}"
api_snapshot_partial=""
services_resumed=false
maintenance_lock_held=false
shutdown_requested=false

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

if [[ ! -f "$restic_password_file" || "$(stat -c '%a' "$restic_password_file")" != "600" ]]; then
  echo "Missing mode-0600 restic password file: $restic_password_file" >&2
  exit 1
fi
if ! command -v restic >/dev/null 2>&1; then
  echo "restic is required for off-site backups." >&2
  exit 1
fi
if ! [[ "$retention_days" =~ ^[1-9][0-9]*$ ]]; then
  echo "PETMAGIC_API_DATA_BACKUP_RETENTION_DAYS must be a positive integer." >&2
  exit 1
fi

cd "$deploy_root"
/usr/bin/bash deploy/vps/scripts/preflight.sh "$env_file"
compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)

exec 9>"$backup_job_lock"
if ! flock -n 9; then
  echo "Another PetMagic backup is already running." >&2
  exit 1
fi

service_is_healthy() {
  local service="$1"
  local container_id state health
  container_id="$("${compose[@]}" ps -q "$service")"
  [[ -n "$container_id" ]] || return 1
  state="$(docker inspect -f '{{.State.Status}}' "$container_id")"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"
  [[ "$state" == "running" && "$health" == "healthy" ]]
}

backend_was_running=false
worker_was_running=false

resume_services() {
  if [[ "$services_resumed" == true ]]; then
    return 0
  fi
  if [[ "$backend_was_running" == true ]]; then
    "${compose[@]}" up -d --no-deps --wait --wait-timeout 180 backend
  fi
  if [[ "$worker_was_running" == true ]]; then
    "${compose[@]}" up -d --no-deps --wait --wait-timeout 180 generation-worker
  fi
  services_resumed=true
}

release_maintenance_lock() {
  if [[ "$maintenance_lock_held" == true ]]; then
    flock -u 8
    exec 8>&-
    maintenance_lock_held=false
  fi
}

cleanup() {
  local status=$?
  set +e
  if [[ -n "$api_snapshot_partial" ]]; then
    rm -f -- "$api_snapshot_partial"
  fi
  local resume_status=0
  if [[ "$maintenance_lock_held" == true && "$shutdown_requested" != true ]]; then
    resume_services
    resume_status=$?
  fi
  if [[ "$maintenance_lock_held" == true ]]; then
    release_maintenance_lock
  fi
  if (( status == 0 && resume_status != 0 )); then
    status=$resume_status
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'shutdown_requested=true; exit 143' TERM
trap 'shutdown_requested=true; exit 130' INT

exec 8>"$maintenance_lock"
flock -x 8
maintenance_lock_held=true

if ! systemctl is-active --quiet petmagic-compose.service; then
  echo "PetMagic Compose supervisor must be active before a backup." >&2
  exit 1
fi
if ! service_is_healthy backend || ! service_is_healthy generation-worker; then
  echo "Backend and generation worker must both be running and healthy before a backup." >&2
  exit 1
fi
backend_was_running=true
worker_was_running=true

if [[ "$worker_was_running" == true ]]; then
  "${compose[@]}" stop -t 300 generation-worker
fi
if [[ "$backend_was_running" == true ]]; then
  "${compose[@]}" stop -t 60 backend
fi

backup_started_at="$(date +%s)"
/usr/bin/bash deploy/vps/scripts/backup-postgres.sh

latest_dump="$(find "$backup_dir" -maxdepth 1 -type f -name 'petmagic-vps-*.custom.dump' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [[ -z "$latest_dump" || ! -s "$latest_dump" || ! -s "$latest_dump.sha256" ]]; then
  echo "Verified local PostgreSQL backup was not found." >&2
  exit 1
fi
if (( $(stat -c '%Y' "$latest_dump") < backup_started_at )); then
  echo "The PostgreSQL backup was not created by this run." >&2
  exit 1
fi

mkdir -p "$api_snapshot_dir"
find "$api_snapshot_dir" -maxdepth 1 -type f -name 'petmagic-api-data-*' -mtime "+$retention_days" -delete
snapshot_id="$(basename "$latest_dump" .custom.dump)"
snapshot_id="${snapshot_id#petmagic-vps-}"
api_snapshot="$api_snapshot_dir/petmagic-api-data-$snapshot_id.tar.gz"
api_snapshot_partial="$api_snapshot.partial"
api_snapshot_sha="$api_snapshot.sha256"
api_data_bytes="$(du -sb "$api_data_dir" | awk '{print $1}')"
available_bytes="$(df --output=avail -B1 "$api_snapshot_dir" | tail -n 1 | tr -d ' ')"
if (( available_bytes < api_data_bytes * 2 + 536870912 )); then
  echo "Insufficient free space for an API-data snapshot." >&2
  exit 1
fi
tar -czf "$api_snapshot_partial" -C "$api_data_dir" .
test -s "$api_snapshot_partial"
tar -tzf "$api_snapshot_partial" >/dev/null
mv "$api_snapshot_partial" "$api_snapshot"
api_snapshot_partial=""
sha256sum "$api_snapshot" | awk -v name="$(basename "$api_snapshot")" '{print $1 "  " name}' > "$api_snapshot_sha"
(
  cd "$api_snapshot_dir"
  sha256sum -c "$(basename "$api_snapshot_sha")" >/dev/null
)

resume_services
release_maintenance_lock

backup_r2_access_key="$(env_value PETMAGIC_BACKUP_R2_ACCESS_KEY)"
backup_r2_secret_key="$(env_value PETMAGIC_BACKUP_R2_SECRET_KEY)"
if [[ -z "$backup_r2_access_key" && -z "$backup_r2_secret_key" ]]; then
  backup_r2_access_key="$(env_value R2_ACCESS_KEY)"
  backup_r2_secret_key="$(env_value R2_SECRET_KEY)"
fi
export AWS_ACCESS_KEY_ID="$backup_r2_access_key"
export AWS_SECRET_ACCESS_KEY="$backup_r2_secret_key"
export AWS_DEFAULT_REGION=auto
export RESTIC_PASSWORD_FILE="$restic_password_file"
export RESTIC_REPOSITORY="s3:https://$(env_value R2_ACCOUNT_ID).r2.cloudflarestorage.com/$(env_value PETMAGIC_BACKUP_R2_BUCKET)/petmagic-vps"

if ! restic snapshots >/dev/null; then
  echo "The configured restic repository is unavailable; refusing to create or replace it during a scheduled backup." >&2
  exit 1
fi

restic backup \
  --tag production \
  --tag "$(hostname)" \
  "$latest_dump" \
  "$latest_dump.sha256" \
  "${latest_dump%.custom.dump}.restore-list.txt" \
  "$api_snapshot" \
  "$api_snapshot_sha" \
  /opt/petmagic/shared/backups/render-restore.marker \
  /opt/petmagic/shared/backups/render-disk-restore.marker

restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune
restic check
trap - EXIT
echo "Encrypted off-site backup completed."
