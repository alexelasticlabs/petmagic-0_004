#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$ROOT_DIR/artifacts/load}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="$ARTIFACT_ROOT/$RUN_ID"

BASE_URL="${BASE_URL:-http://host.docker.internal:5001}"
PROFILE="${PROFILE:-generation}"
MODE="${MODE:-user}"
VUS="${VUS:-50}"
ITERATIONS="${ITERATIONS:-100}"
DURATION="${DURATION:-2m}"
RATE="${RATE:-100}"
WORKER_COUNT="${WORKER_COUNT:-3}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-petmagic_user}"
POSTGRES_DB="${POSTGRES_DB:-petmagic_db}"
K6_IMAGE="${K6_IMAGE:-grafana/k6:0.49.0}"
K6_DOCKER_NETWORK="${K6_DOCKER_NETWORK:-}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

require_auth() {
  if [[ -n "${AUTH_TOKEN:-}" || -n "${AUTH_TOKENS:-}" ]]; then
    return
  fi

  if [[ -n "${LOGIN_EMAIL:-}" && -n "${LOGIN_PASSWORD:-}" ]]; then
    return
  fi

  echo "Set AUTH_TOKEN/AUTH_TOKENS or LOGIN_EMAIL + LOGIN_PASSWORD." >&2
  exit 2
}

capture_postgres() {
  local query="$1"
  local output="$2"

  if ! docker compose exec -T "$POSTGRES_SERVICE" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$query" > "$output" 2>&1; then
    echo "Postgres capture failed. See $output" >&2
  fi
}

require_env TEMPLATE_ID
require_auth

mkdir -p "$RUN_DIR"

COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"

cat > "$RUN_DIR/baseline-metadata.env" <<EOF
RUN_ID=$RUN_ID
GIT_COMMIT=$COMMIT
BASE_URL=$BASE_URL
PROFILE=$PROFILE
MODE=$MODE
VUS=$VUS
ITERATIONS=$ITERATIONS
DURATION=$DURATION
RATE=$RATE
WORKER_COUNT=$WORKER_COUNT
K6_DOCKER_NETWORK=$K6_DOCKER_NETWORK
POSTGRES_SERVICE=$POSTGRES_SERVICE
POSTGRES_DB=$POSTGRES_DB
EOF

docker compose ps > "$RUN_DIR/docker-compose-ps-before.txt"
docker stats --no-stream > "$RUN_DIR/docker-stats-before.txt" || true
capture_postgres \
  'select "Status", count(*) from templates_generation_jobs group by "Status" order by "Status";' \
  "$RUN_DIR/queue-depth-before.txt"
capture_postgres \
  "select count(*) from pg_stat_activity where datname = '$POSTGRES_DB';" \
  "$RUN_DIR/postgres-connections-before.txt"

docker_run_args=(--rm)
if [[ -n "$K6_DOCKER_NETWORK" ]]; then
  docker_run_args+=(--network "$K6_DOCKER_NETWORK")
fi

docker run "${docker_run_args[@]}" \
  -v "$ROOT_DIR:/work" \
  -w /work \
  -e BASE_URL="$BASE_URL" \
  -e TEMPLATE_ID="$TEMPLATE_ID" \
  -e AUTH_TOKEN="${AUTH_TOKEN:-}" \
  -e AUTH_TOKENS="${AUTH_TOKENS:-}" \
  -e LOGIN_EMAIL="${LOGIN_EMAIL:-}" \
  -e LOGIN_PASSWORD="${LOGIN_PASSWORD:-}" \
  -e MODE="$MODE" \
  -e PROFILE="$PROFILE" \
  -e VUS="$VUS" \
  -e ITERATIONS="$ITERATIONS" \
  -e DURATION="$DURATION" \
  -e RATE="$RATE" \
  -e POLL_ATTEMPTS="${POLL_ATTEMPTS:-10}" \
  -e POLL_SLEEP_SECONDS="${POLL_SLEEP_SECONDS:-1}" \
  -e GENERATION_ID="${GENERATION_ID:-}" \
  -e SUMMARY_JSON="artifacts/load/$RUN_ID/k6-template-generation-summary.json" \
  -e SUMMARY_MD="artifacts/load/$RUN_ID/k6-template-generation-summary.md" \
  -e WORKER_COUNT="$WORKER_COUNT" \
  -e GIT_COMMIT="$COMMIT" \
  "$K6_IMAGE" run scripts/k6/template-generation-load-test.js

docker compose ps > "$RUN_DIR/docker-compose-ps-after.txt"
docker stats --no-stream > "$RUN_DIR/docker-stats-after.txt" || true
capture_postgres \
  'select "Status", count(*) from templates_generation_jobs group by "Status" order by "Status";' \
  "$RUN_DIR/queue-depth-after.txt"
capture_postgres \
  "select count(*) from pg_stat_activity where datname = '$POSTGRES_DB';" \
  "$RUN_DIR/postgres-connections-after.txt"

{
  echo "# PetMagic Template Generation Baseline"
  echo
  echo "- Run: $RUN_ID"
  echo "- Git commit: $COMMIT"
  echo "- Profile: $PROFILE"
  echo "- Mode: $MODE"
  echo "- Workers: $WORKER_COUNT"
  echo "- K6 Docker network: ${K6_DOCKER_NETWORK:-default}"
  echo "- VUs: $VUS"
  echo "- Iterations: $ITERATIONS"
  echo "- Duration: $DURATION"
  echo "- Rate: $RATE"
  echo
  echo "## Files"
  echo
  find "$RUN_DIR" -maxdepth 1 -type f -print | sort | sed "s#^$RUN_DIR/#- #"
} > "$RUN_DIR/baseline-report.md"

echo "Baseline artifacts written to $RUN_DIR"
