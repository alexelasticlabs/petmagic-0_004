#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_ARTIFACT_ROOT="$ROOT_DIR/artifacts/load"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$CANONICAL_ARTIFACT_ROOT}"
RUN_ID="${RUN_ID:-scheduler-v2-acceptance-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="$ARTIFACT_ROOT/$RUN_ID"
BASE_URL="${BASE_URL:-http://host.docker.internal:5001}"
PROFILE="${PROFILE:-mixed-acceptance}"
MODE="${MODE:-user}"
VUS="${VUS:-50}"
ITERATIONS="${ITERATIONS:-200}"
WORKER_COUNT="${WORKER_COUNT:-1}"
OBSERVATION_SECONDS="${OBSERVATION_SECONDS:-60}"
SAMPLE_INTERVAL_SECONDS="${SAMPLE_INTERVAL_SECONDS:-2}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-petmagic_user}"
POSTGRES_DB="${POSTGRES_DB:-petmagic_db}"
K6_IMAGE="${K6_IMAGE:-grafana/k6:0.49.0}"
K6_DOCKER_NETWORK="${K6_DOCKER_NETWORK:-}"

fail() {
  echo "$1" >&2
  exit 2
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing required environment variable: $name"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

[[ "$WORKER_COUNT" == "1" ]] || fail "Scheduler V2 acceptance evidence requires WORKER_COUNT=1; received $WORKER_COUNT."
[[ "$RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$ ]] || fail "RUN_ID must contain only letters, digits, dots, underscores, or hyphens."
[[ "$ARTIFACT_ROOT" == "$CANONICAL_ARTIFACT_ROOT" ]] || fail "ARTIFACT_ROOT must remain $CANONICAL_ARTIFACT_ROOT so k6 and the verifier use the same mounted artifact directory."
[[ "$PROFILE" == "mixed-acceptance" ]] || fail "Scheduler V2 acceptance requires PROFILE=mixed-acceptance."
[[ "$MODE" == "user" ]] || fail "Scheduler V2 acceptance requires MODE=user."
[[ "$VUS" == "50" ]] || fail "Scheduler V2 acceptance requires exactly VUS=50."
[[ "$ITERATIONS" == "200" ]] || fail "Scheduler V2 acceptance requires exactly ITERATIONS=200."
is_positive_integer "$OBSERVATION_SECONDS" || fail "OBSERVATION_SECONDS must be a positive integer."
is_positive_integer "$SAMPLE_INTERVAL_SECONDS" || fail "SAMPLE_INTERVAL_SECONDS must be a positive integer."

require_env IMAGE_TEMPLATE_ID
require_env VIDEO_TEMPLATE_ID
require_env AUTH_TOKENS
[[ "$IMAGE_TEMPLATE_ID" != "$VIDEO_TEMPLATE_ID" ]] || fail "IMAGE_TEMPLATE_ID and VIDEO_TEMPLATE_ID must be different templates."
is_uuid "$IMAGE_TEMPLATE_ID" || fail "IMAGE_TEMPLATE_ID must be a UUID."
is_uuid "$VIDEO_TEMPLATE_ID" || fail "VIDEO_TEMPLATE_ID must be a UUID."

command -v node >/dev/null 2>&1 || fail "node is required."
if ! AUTH_SUBJECT_COUNT="$(
  AUTH_TOKENS="$AUTH_TOKENS" node "$ROOT_DIR/scripts/load/validate-generation-load-auth-subjects.mjs"
)"; then
  fail "AUTH_TOKENS did not pass the 50-unique-JWT-sub preflight."
fi
[[ "$AUTH_SUBJECT_COUNT" == "50" ]] || fail "Scheduler V2 acceptance requires exactly 50 unique JWT sub claims."
AUTH_TOKEN_COUNT=50

command -v docker >/dev/null 2>&1 || fail "docker is required."
docker compose version >/dev/null 2>&1 || fail "docker compose is required."

read -r -d '' TEMPLATE_ROLE_SQL <<SQL || true
SELECT (SELECT count(*) FROM templates_items WHERE "Id" = '$IMAGE_TEMPLATE_ID'::uuid AND "TemplateType" = 1),
       (SELECT count(*) FROM templates_items WHERE "Id" = '$VIDEO_TEMPLATE_ID'::uuid AND "TemplateType" = 2);
SQL
if ! template_role_counts="$(
  docker compose exec -T "$POSTGRES_SERVICE" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -F ',' -v ON_ERROR_STOP=1 -c "$TEMPLATE_ROLE_SQL"
)"; then
  fail "Template role preflight failed against PostgreSQL."
fi
[[ "$template_role_counts" == "1,1" ]] || fail "Expected one Image template and one Video template; PostgreSQL returned $template_role_counts."

RUN_STARTED_AT_UTC="$(node -e "process.stdout.write(new Date().toISOString())")"
IDEMPOTENCY_PREFIX="coreload-$RUN_ID"
mkdir -p "$RUN_DIR"
COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$RUN_DIR/acceptance-metadata.env" <<EOF
RUN_ID=$RUN_ID
GIT_COMMIT=$COMMIT
PROFILE=$PROFILE
MODE=$MODE
VUS=$VUS
ITERATIONS=$ITERATIONS
WORKER_COUNT=$WORKER_COUNT
AUTH_TOKEN_COUNT=$AUTH_TOKEN_COUNT
AUTH_SUBJECT_COUNT=$AUTH_SUBJECT_COUNT
DISTINCT_TEMPLATE_ROLES=true
RUN_STARTED_AT_UTC=$RUN_STARTED_AT_UTC
IDEMPOTENCY_PREFIX=$IDEMPOTENCY_PREFIX
SCOPE=core_load_only
FULL_ACCEPTANCE=false
OBSERVATION_SECONDS=$OBSERVATION_SECONDS
SAMPLE_INTERVAL_SECONDS=$SAMPLE_INTERVAL_SECONDS
POSTGRES_DB=$POSTGRES_DB
EOF

docker compose ps > "$RUN_DIR/docker-compose-ps-before.txt"
docker stats --no-stream > "$RUN_DIR/docker-stats-before.txt" || true

RUNTIME_SERIES="$RUN_DIR/runtime-series.csv"
SAMPLER_ERROR="$RUN_DIR/runtime-sampler-error.txt"
SAMPLER_FAILED="$RUN_DIR/runtime-sampler.failed"
printf '%s\n' 'sampled_at_utc,active_provider_attempts,queue_depth,postgres_connections,effective_global,active_worker_count,scheduler_v2_enabled_worker_count,dispatch_concurrency,reconciliation_concurrency,media_import_concurrency,maintenance_concurrency,worker_last_progress_epoch_ms' > "$RUNTIME_SERIES"

read -r -d '' RUNTIME_SQL <<SQL || true
WITH latest_worker AS (
  SELECT "GenerationSchedulerV2Enabled",
         "GenerationDispatchConcurrency",
         "ProviderReconciliationConcurrency",
         "MediaImportConcurrency",
         "GenerationMaintenanceConcurrency",
         "LastProgressAtUtc"
  FROM templates_runtime_config_fingerprints
  WHERE "Component" = 'generation-worker'
    AND "LastSeenAtUtc" >= clock_timestamp() - interval '2 minutes'
  ORDER BY "LastSeenAtUtc" DESC, "StartedAtUtc" DESC, "Id" DESC
  LIMIT 1
)
SELECT to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
       (SELECT count(*)
        FROM templates_generation_provider_attempts attempt
        JOIN templates_generation_jobs job ON job."Id" = attempt."GenerationJobId"
        WHERE attempt."State" IN (1, 2, 3, 4, 5)
          AND job."IdempotencyKey" LIKE '$IDEMPOTENCY_PREFIX-%'
          AND job."CreatedAtUtc" >= '$RUN_STARTED_AT_UTC'::timestamptz),
       (SELECT count(*)
        FROM templates_generation_jobs
        WHERE "Status" IN (1, 6)
          AND "IdempotencyKey" LIKE '$IDEMPOTENCY_PREFIX-%'
          AND "CreatedAtUtc" >= '$RUN_STARTED_AT_UTC'::timestamptz),
       (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()),
       COALESCE((
         SELECT LEAST("ApplicationHardCeiling", GREATEST(0, "ConfirmedFalConcurrencyLimit" - "ReservedHeadroom"))
         FROM templates_generation_control_policy
         ORDER BY "Revision" DESC
         LIMIT 1
       ), 0),
       (SELECT count(*)
        FROM templates_runtime_config_fingerprints
        WHERE "Component" = 'generation-worker'
          AND "LastSeenAtUtc" >= clock_timestamp() - interval '2 minutes'),
       COALESCE((SELECT CASE WHEN "GenerationSchedulerV2Enabled" IS TRUE THEN 1 ELSE 0 END FROM latest_worker), 0),
       COALESCE((SELECT "GenerationDispatchConcurrency" FROM latest_worker), 0),
       COALESCE((SELECT "ProviderReconciliationConcurrency" FROM latest_worker), 0),
       COALESCE((SELECT "MediaImportConcurrency" FROM latest_worker), 0),
       COALESCE((SELECT "GenerationMaintenanceConcurrency" FROM latest_worker), 0),
       COALESCE((SELECT (EXTRACT(EPOCH FROM "LastProgressAtUtc") * 1000)::bigint FROM latest_worker), 0);
SQL

sample_runtime_once() {
  docker compose exec -T "$POSTGRES_SERVICE" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -F ',' -v ON_ERROR_STOP=1 -c "$RUNTIME_SQL"
}

if ! initial_sample="$(sample_runtime_once 2> "$SAMPLER_ERROR")"; then
  fail "Runtime sampler preflight failed. See $SAMPLER_ERROR"
fi
printf '%s\n' "$initial_sample" >> "$RUNTIME_SERIES"

sampler_pid=''
run_sampler() {
  while true; do
    sleep "$SAMPLE_INTERVAL_SECONDS"
    if ! sample="$(sample_runtime_once 2>> "$SAMPLER_ERROR")"; then
      printf '%s\n' 'runtime sampler query failed' > "$SAMPLER_FAILED"
      return 1
    fi
    printf '%s\n' "$sample" >> "$RUNTIME_SERIES"
  done
}

stop_sampler() {
  if [[ -n "$sampler_pid" ]] && kill -0 "$sampler_pid" 2>/dev/null; then
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
  fi
  sampler_pid=''
}

abort_run() {
  stop_sampler
  trap - EXIT
  exit 130
}

trap stop_sampler EXIT
trap abort_run INT TERM
run_sampler &
sampler_pid="$!"

docker_run_args=(--rm)
if [[ -n "$K6_DOCKER_NETWORK" ]]; then
  docker_run_args+=(--network "$K6_DOCKER_NETWORK")
fi

set +e
AUTH_TOKENS="$AUTH_TOKENS" docker run "${docker_run_args[@]}" \
  -v "$ROOT_DIR:/work" \
  -w /work \
  -e BASE_URL="$BASE_URL" \
  -e IMAGE_TEMPLATE_ID="$IMAGE_TEMPLATE_ID" \
  -e VIDEO_TEMPLATE_ID="$VIDEO_TEMPLATE_ID" \
  -e AUTH_TOKENS \
  -e MODE="$MODE" \
  -e PROFILE="$PROFILE" \
  -e IDEMPOTENCY_PREFIX="$IDEMPOTENCY_PREFIX" \
  -e VUS="$VUS" \
  -e ITERATIONS="$ITERATIONS" \
  -e ACCEPTANCE_MAX_DURATION="${ACCEPTANCE_MAX_DURATION:-10m}" \
  -e SUMMARY_JSON="artifacts/load/$RUN_ID/k6-template-generation-summary.json" \
  -e SUMMARY_MD="artifacts/load/$RUN_ID/k6-template-generation-summary.md" \
  -e WORKER_COUNT="$WORKER_COUNT" \
  -e GIT_COMMIT="$COMMIT" \
  "$K6_IMAGE" run scripts/k6/template-generation-load-test.js
k6_status="$?"
set -e

# Preserve post-submit evidence even when k6 reports a threshold failure after
# having accepted some or all requests.
sleep "$OBSERVATION_SECONDS"
stop_sampler

docker compose ps > "$RUN_DIR/docker-compose-ps-after.txt" || true
docker stats --no-stream > "$RUN_DIR/docker-stats-after.txt" || true

set +e
node "$ROOT_DIR/scripts/load/verify-generation-scheduler-v2-acceptance.mjs" --run-dir "$RUN_DIR"
verifier_status="$?"
set -e

{
  echo "# Generation Scheduler V2 Core Load Evidence"
  echo
  echo "- Run: $RUN_ID"
  echo "- Git commit: $COMMIT"
  echo "- Topology: 1 worker"
  echo "- Scope: core_load_only"
  echo "- Full acceptance: false"
  echo "- Load: 50 VUs / 200 jobs (100 image + 100 video)"
  echo "- Runtime sampling: every ${SAMPLE_INTERVAL_SECONDS}s plus ${OBSERVATION_SECONDS}s post-submit observation"
  echo "- k6 exit code: $k6_status"
  echo "- Verifier exit code: $verifier_status"
  echo "- Sampler failed: $([[ -f "$SAMPLER_FAILED" ]] && echo true || echo false)"
  echo
  echo "> This run covers the 50-user/200-job core load gate only. It does not by itself prove the full Scheduler V2 acceptance matrix."
} > "$RUN_DIR/acceptance-run-report.md"

if [[ "$k6_status" -ne 0 || "$verifier_status" -ne 0 || -f "$SAMPLER_FAILED" ]]; then
  echo "Scheduler V2 core load evidence failed. Artifacts: $RUN_DIR" >&2
  exit 1
fi

echo "Scheduler V2 core load evidence passed. Full acceptance still requires the reserve, blocked-import, restart, resource, and exactly-once scenarios. Artifacts: $RUN_DIR"
