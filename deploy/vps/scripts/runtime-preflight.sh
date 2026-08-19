#!/usr/bin/env bash
set -euo pipefail

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"

cd "$deploy_root"
/usr/bin/bash deploy/vps/scripts/preflight.sh "$env_file"

for marker in \
  /opt/petmagic/shared/backups/render-restore.marker \
  /opt/petmagic/shared/backups/render-disk-restore.marker; do
  if [[ ! -s "$marker" ]]; then
    echo "Missing verified restore marker: $marker" >&2
    exit 1
  fi
done

compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)
"${compose[@]}" config --quiet
for service in postgres backend generation-worker admin-web; do
  if [[ -z "$("${compose[@]}" images -q "$service")" ]]; then
    echo "Missing built/pulled image for service: $service" >&2
    exit 1
  fi
done

source_revision="$(git -c safe.directory="$deploy_root" -C "$deploy_root" rev-parse HEAD)"
for service in backend generation-worker admin-web; do
  image_id="$("${compose[@]}" images -q "$service")"
  image_revision="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image_id")"
  if [[ "$image_revision" != "$source_revision" ]]; then
    echo "Image revision does not match the deployed Git checkout: $service" >&2
    exit 1
  fi
done

echo "VPS runtime preflight passed."
