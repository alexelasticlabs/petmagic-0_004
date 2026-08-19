#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly backup_dir="/opt/petmagic/shared/backups/postgres"
readonly retention_days="${PETMAGIC_POSTGRES_BACKUP_RETENTION_DAYS:-14}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing VPS environment file: $env_file" >&2
  exit 1
fi

if ! [[ "$retention_days" =~ ^[1-9][0-9]*$ ]]; then
  echo "PETMAGIC_POSTGRES_BACKUP_RETENTION_DAYS must be a positive integer." >&2
  exit 1
fi

mkdir -p "$backup_dir"
find "$backup_dir" -maxdepth 1 -type f -name 'petmagic-vps-*' -mtime "+$retention_days" -delete

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
final_dump="$backup_dir/petmagic-vps-$timestamp.custom.dump"
partial_dump="$final_dump.partial"
final_list="$backup_dir/petmagic-vps-$timestamp.restore-list.txt"
partial_list="$final_list.partial"
final_sha="$final_dump.sha256"
partial_sha="$final_sha.partial"

cleanup() {
  rm -f "$partial_dump" "$partial_list" "$partial_sha"
}
trap cleanup EXIT

compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)

cd "$deploy_root"
postgres_container="$("${compose[@]}" ps -q postgres)"
if [[ -z "$postgres_container" || "$(docker inspect -f '{{.State.Running}}' "$postgres_container")" != "true" ]]; then
  echo "PostgreSQL is not running; refusing to start the application stack from the backup job." >&2
  exit 1
fi

database_bytes="$("${compose[@]}" exec -T postgres psql --username=petmagic_user --dbname=petmagic_db --tuples-only --no-align --command="SELECT pg_database_size('petmagic_db');")"
available_bytes="$(df --output=avail -B1 "$backup_dir" | tail -n 1 | tr -d ' ')"
minimum_bytes="$((database_bytes * 2 + 536870912))"
if (( available_bytes < minimum_bytes )); then
  echo "Insufficient free space for a verified PostgreSQL backup." >&2
  exit 1
fi

"${compose[@]}" exec -T postgres pg_dump \
  --username=petmagic_user \
  --dbname=petmagic_db \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="/tmp/petmagic-vps-$timestamp.custom.dump"

"${compose[@]}" cp "postgres:/tmp/petmagic-vps-$timestamp.custom.dump" "$partial_dump"
"${compose[@]}" exec -T postgres rm -f "/tmp/petmagic-vps-$timestamp.custom.dump"

test -s "$partial_dump"
pg_restore --list --file="$partial_list" "$partial_dump" >/dev/null
test -s "$partial_list"
dump_sha="$(sha256sum "$partial_dump" | awk '{print $1}')"
printf '%s  %s\n' "$dump_sha" "$(basename "$final_dump")" >"$partial_sha"

mv "$partial_list" "$final_list"
mv "$partial_sha" "$final_sha"
mv "$partial_dump" "$final_dump"
trap - EXIT

(
  cd "$backup_dir"
  sha256sum -c "$(basename "$final_sha")" >/dev/null
)
echo "Verified PostgreSQL backup: $final_dump"
