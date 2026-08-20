#!/usr/bin/env bash
set -euo pipefail

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly maintenance_lock="/run/petmagic/maintenance.lock"

cd "$deploy_root"
compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)

exec 8>"$maintenance_lock"
if ! flock -x -w 60 8; then
  echo "Timed out waiting for the PetMagic maintenance lock." >&2
  exit 1
fi

timeout --foreground --kill-after=30s 330s "${compose[@]}" stop -t 300
