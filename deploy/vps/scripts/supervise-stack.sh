#!/usr/bin/env bash
set -euo pipefail

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly maintenance_lock="/run/petmagic/maintenance.lock"
readonly unhealthy_limit=3
readonly starting_limit=12
readonly monitor_interval_seconds=5

cd "$deploy_root"
compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)

short_timeout() {
  local status=0
  /usr/bin/systemd-notify WATCHDOG=1 >/dev/null 2>&1 || true
  timeout --foreground --kill-after=5s 15s "$@" || status=$?
  /usr/bin/systemd-notify WATCHDOG=1 >/dev/null 2>&1 || true
  return "$status"
}

fail() {
  echo "$1" >&2
  short_timeout "${compose[@]}" ps >&2 || true
  exit 1
}

check_service() {
  local service="$1"
  local container_ids_raw container_id state health count
  local -a container_ids=()

  if ! container_ids_raw="$(short_timeout "${compose[@]}" ps --all --quiet "$service")"; then
    fail "Failed to inspect Compose service: $service"
  fi
  mapfile -t container_ids < <(printf '%s\n' "$container_ids_raw" | sed '/^$/d')
  if (( ${#container_ids[@]} != 1 )); then
    fail "Expected exactly one container for service: $service"
  fi

  container_id="${container_ids[0]}"
  if ! state="$(short_timeout docker inspect --format '{{.State.Status}}' "$container_id")"; then
    fail "Failed to inspect container state: $service"
  fi
  if ! health="$(short_timeout docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")"; then
    fail "Failed to inspect container health: $service"
  fi

  if [[ "$state" != "running" ]]; then
    fail "PetMagic container is not running: $service ($state)"
  fi

  if [[ "$health" == "healthy" || ( "$service" == "mailpit" && "$health" == "none" ) ]]; then
    nonhealthy_counts[$service]=0
    return 0
  fi

  count=$(( ${nonhealthy_counts[$service]:-0} + 1 ))
  nonhealthy_counts[$service]="$count"
  if [[ "$health" == "starting" && "$count" -lt "$starting_limit" ]]; then
    return 0
  fi
  if [[ "$health" == "unhealthy" && "$count" -lt "$unhealthy_limit" ]]; then
    return 0
  fi
  fail "PetMagic container health check did not recover: $service ($health)"
}

trap 'exit 0' TERM INT

exec 8>"$maintenance_lock"
flock -x 8
timeout --foreground --kill-after=30s 330s \
  "${compose[@]}" up -d --remove-orphans --wait --wait-timeout 300
flock -u 8
/usr/bin/systemd-notify --ready --status="PetMagic containers are healthy."

declare -A nonhealthy_counts=()
while true; do
  for service in postgres mailpit admin-web; do
    check_service "$service"
  done

  if flock -s -n 8; then
    check_service backend
    check_service generation-worker
    flock -u 8
  else
    nonhealthy_counts[backend]=0
    nonhealthy_counts[generation-worker]=0
  fi

  /usr/bin/systemd-notify WATCHDOG=1
  sleep "$monitor_interval_seconds"
done
