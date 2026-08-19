#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly import_root="/opt/petmagic/shared/backups/import"
readonly dump_path="${1:-}"
readonly expected_sha="${2:-}"
extract_dir=""

if [[ -z "$dump_path" || ! -f "$dump_path" || ! "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Usage: $0 /opt/petmagic/shared/backups/import/<render-export> <expected-sha256>" >&2
  exit 1
fi

resolved_dump="$(realpath "$dump_path")"
case "$resolved_dump" in
  "$import_root"/*) ;;
  *)
    echo "Refusing to restore a dump outside $import_root." >&2
    exit 1
    ;;
esac

actual_sha="$(sha256sum "$resolved_dump" | awk '{print $1}')"
if [[ "${actual_sha,,}" != "${expected_sha,,}" ]]; then
  echo "Render export SHA-256 does not match the source manifest." >&2
  exit 1
fi

cd "$deploy_root"
/usr/bin/bash deploy/vps/scripts/preflight.sh "$env_file"

compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)
for service in backend generation-worker admin-web; do
  container_id="$("${compose[@]}" ps -q "$service")"
  if [[ -n "$container_id" && "$(docker inspect -f '{{.State.Running}}' "$container_id")" == "true" ]]; then
    echo "Refusing restore while $service is running." >&2
    exit 1
  fi
done

restore_source="$resolved_dump"
if [[ "$resolved_dump" == *.tar.gz ]]; then
  mapfile -t archive_entries < <(tar -tzf "$resolved_dump")
  if [[ "${#archive_entries[@]}" -eq 0 ]]; then
    echo "Render export archive is empty." >&2
    exit 1
  fi
  while IFS= read -r metadata; do
    case "${metadata:0:1}" in
      -|d) ;;
      *)
        echo "Render export contains a non-regular archive entry." >&2
        exit 1
        ;;
    esac
  done < <(tar -tvzf "$resolved_dump")
  for entry in "${archive_entries[@]}"; do
    normalized="${entry#./}"
    if [[ "$entry" == /* || "/$normalized/" == */../* ]]; then
      echo "Render export contains an unsafe path." >&2
      exit 1
    fi
  done
  extract_dir="$(mktemp -d "$import_root/.render-restore.XXXXXX")"
  tar -xzf "$resolved_dump" -C "$extract_dir"
  mapfile -t toc_files < <(find "$extract_dir" -type f -name toc.dat -print)
  if [[ "${#toc_files[@]}" -ne 1 ]]; then
    echo "Render directory export must contain exactly one toc.dat." >&2
    exit 1
  fi
  restore_source="$(dirname "${toc_files[0]}")"
fi

cleanup() {
  if [[ -n "$extract_dir" && -d "$extract_dir" ]]; then
    rm -rf -- "$extract_dir"
  fi
}
trap cleanup EXIT

pg_restore --list "$restore_source" >/dev/null
"${compose[@]}" up -d postgres

for _ in $(seq 1 60); do
  if "${compose[@]}" exec -T postgres pg_isready --username=petmagic_user --dbname=petmagic_db >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
"${compose[@]}" exec -T postgres pg_isready --username=petmagic_user --dbname=petmagic_db >/dev/null

relative_restore_source="${restore_source#"$import_root"/}"
container_restore_source="/var/lib/petmagic-import/$relative_restore_source"

"${compose[@]}" exec -T postgres pg_restore \
  --username=petmagic_user \
  --dbname=petmagic_db \
  --clean \
  --if-exists \
  --exit-on-error \
  --single-transaction \
  --no-owner \
  --no-privileges \
  "$container_restore_source"

table_count="$("${compose[@]}" exec -T postgres psql --username=petmagic_user --dbname=petmagic_db --tuples-only --no-align --command="SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public';")"
if [[ ! "$table_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "Restore verification failed: public schema has no tables." >&2
  exit 1
fi

migration_count="$("${compose[@]}" exec -T postgres psql --username=petmagic_user --dbname=petmagic_db --tuples-only --no-align --command='SELECT count(*) FROM "__EFMigrationsHistory";')"
if [[ ! "$migration_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "Restore verification failed: EF migration history is empty." >&2
  exit 1
fi

printf 'restoredAtUtc=%s\nsourceFile=%s\nsha256=%s\npublicTableCount=%s\nmigrationCount=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$resolved_dump")" "$actual_sha" "$table_count" "$migration_count" \
  > /opt/petmagic/shared/backups/render-restore.marker

echo "Render PostgreSQL restore verified; public tables: $table_count; migrations: $migration_count"
