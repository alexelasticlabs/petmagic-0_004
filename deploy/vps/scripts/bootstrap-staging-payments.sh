#!/usr/bin/env bash
set -euo pipefail

repo_root="/opt/petmagic/current"
staging_root="/opt/petmagic-staging"
env_file="$staging_root/env/.env.staging"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if [[ ! -f "$env_file" ]]; then
  echo "Missing staging environment file: $env_file" >&2
  exit 1
fi

for directory in \
  "$staging_root/shared/postgres" \
  "$staging_root/shared/api-data/DataProtection-Keys" \
  "$staging_root/shared/api-data/wwwroot/templates-media" \
  "$staging_root/shared/api-data/wwwroot/support-attachments" \
  "$staging_root/shared/api-data/wwwroot/user-avatars"; do
  install -d -m 0700 "$directory"
done

compose=(
  docker compose
  --project-name petmagic-staging
  --env-file "$env_file"
  -f docker-compose.yml
  -f deploy/vps/compose.staging.vps.yaml
)

cd "$repo_root"
"${compose[@]}" config --quiet
"${compose[@]}" up -d --no-build --wait --wait-timeout 180 postgres mailpit backend
"${compose[@]}" ps
