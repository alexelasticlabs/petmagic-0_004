#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$ROOT_DIR/artifacts/query-plans}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="$ARTIFACT_ROOT/$RUN_ID"

POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-petmagic_user}"
POSTGRES_DB="${POSTGRES_DB:-petmagic_db}"
POSTGRES_HOST="${POSTGRES_HOST:-}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
SAMPLE_USER_ID="${SAMPLE_USER_ID:-00000000-0000-0000-0000-000000000000}"
SAMPLE_TEMPLATE_ID="${SAMPLE_TEMPLATE_ID:-00000000-0000-0000-0000-000000000000}"
SAMPLE_GENERATION_ID="${SAMPLE_GENERATION_ID:-00000000-0000-0000-0000-000000000000}"
SAMPLE_IDEMPOTENCY_KEY="${SAMPLE_IDEMPOTENCY_KEY:-query-plan-idempotency-key}"
SAMPLE_REQUEST_HASH="${SAMPLE_REQUEST_HASH:-query-plan-request-hash}"

mkdir -p "$RUN_DIR"

run_psql_script() {
  local output="$1"
  local sql="$2"

  if [[ -n "$POSTGRES_HOST" ]]; then
    PGPASSWORD="$POSTGRES_PASSWORD" psql \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -U "$POSTGRES_USER" \
      -d "$POSTGRES_DB" \
      -v ON_ERROR_STOP=1 \
      -v sample_user_id="$SAMPLE_USER_ID" \
      -v sample_template_id="$SAMPLE_TEMPLATE_ID" \
      -v sample_generation_id="$SAMPLE_GENERATION_ID" \
      -v sample_idempotency_key="$SAMPLE_IDEMPOTENCY_KEY" \
      -v sample_request_hash="$SAMPLE_REQUEST_HASH" \
      -f - > "$output" 2>&1 <<< "$sql"
    return
  fi

  docker compose exec -T "$POSTGRES_SERVICE" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      -v ON_ERROR_STOP=1 \
      -v sample_user_id="$SAMPLE_USER_ID" \
      -v sample_template_id="$SAMPLE_TEMPLATE_ID" \
      -v sample_generation_id="$SAMPLE_GENERATION_ID" \
      -v sample_idempotency_key="$SAMPLE_IDEMPOTENCY_KEY" \
      -v sample_request_hash="$SAMPLE_REQUEST_HASH" \
      -f - > "$output" 2>&1 <<< "$sql"
}

capture_plan() {
  local name="$1"
  local sql="$2"
  local output="$RUN_DIR/$name.sqlplan.txt"

  if ! run_psql_script "$output" "$sql"; then
    echo "Failed to capture $name. See $output" >&2
    return 1
  fi
}

cat > "$RUN_DIR/query-plan-metadata.env" <<EOF
RUN_ID=$RUN_ID
POSTGRES_SERVICE=$POSTGRES_SERVICE
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=$POSTGRES_PORT
POSTGRES_DB=$POSTGRES_DB
SAMPLE_USER_ID=$SAMPLE_USER_ID
SAMPLE_TEMPLATE_ID=$SAMPLE_TEMPLATE_ID
SAMPLE_GENERATION_ID=$SAMPLE_GENERATION_ID
SAMPLE_IDEMPOTENCY_KEY=$SAMPLE_IDEMPOTENCY_KEY
SAMPLE_REQUEST_HASH=$SAMPLE_REQUEST_HASH
EOF

capture_plan "templates_generation_claim" '
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
UPDATE templates_generation_jobs
SET "Status" = 2,
    "AttemptCount" = "AttemptCount" + 1,
    "LastAttemptAtUtc" = now(),
    "StartedAtUtc" = COALESCE("StartedAtUtc", now()),
    "LockedAtUtc" = now(),
    "LockedBy" = '\''query-plan-worker'\'',
    "UpdatedAtUtc" = now()
WHERE "Id" = (
    SELECT "Id"
    FROM templates_generation_jobs
    WHERE "Status" = 1
      AND ("ChargedAtUtc" IS NOT NULL OR "UserId" = '\''00000000-0000-0000-0000-000000000000'\''::uuid)
      AND "AttemptCount" < 3
    ORDER BY "QueuedAtUtc"
    FOR UPDATE SKIP LOCKED
    LIMIT 1
);
ROLLBACK;
'

capture_plan "templates_generation_history_by_user" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "TemplateId", "Status", "ResultUrl", "CreatedAtUtc", "UpdatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "HiddenByUserAtUtc" IS NULL
ORDER BY "CreatedAtUtc" DESC
LIMIT 30;
'

capture_plan "templates_generation_history_queued_by_user" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "TemplateId", "Status", "ResultUrl", "CreatedAtUtc", "UpdatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "HiddenByUserAtUtc" IS NULL
  AND "Status" = 1
ORDER BY "CreatedAtUtc" DESC
LIMIT 30;
'

capture_plan "templates_generation_history_active_by_user" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "TemplateId", "Status", "ResultUrl", "CreatedAtUtc", "UpdatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "HiddenByUserAtUtc" IS NULL
  AND "Status" IN (1, 2)
ORDER BY "CreatedAtUtc" DESC
LIMIT 30;
'

capture_plan "templates_generation_history_completed_by_user" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "TemplateId", "Status", "ResultUrl", "CreatedAtUtc", "UpdatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "HiddenByUserAtUtc" IS NULL
  AND "Status" = 4
ORDER BY "CreatedAtUtc" DESC
LIMIT 30;
'

capture_plan "templates_generation_status_by_user" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "TemplateId", "Status", "ResultUrl", "LastErrorCode", "UpdatedAtUtc"
FROM templates_generation_jobs
WHERE "Id" = :'\''sample_generation_id'\''::uuid
  AND "UserId" = :'\''sample_user_id'\''::uuid
  AND "HiddenByUserAtUtc" IS NULL
LIMIT 1;
'

capture_plan "templates_generation_active_count" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT count(*)
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "Status" IN (1, 2);
'

capture_plan "templates_generation_duplicate_idempotency" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "Status", "QueuedAtUtc", "CreatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "Status" IN (1, 2)
  AND "IdempotencyKey" = :'\''sample_idempotency_key'\''
ORDER BY "CreatedAtUtc"
LIMIT 1;
'

capture_plan "templates_generation_duplicate_request_hash" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "Status", "QueuedAtUtc", "CreatedAtUtc"
FROM templates_generation_jobs
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "Status" IN (1, 2)
  AND "RequestHash" = :'\''sample_request_hash'\''
ORDER BY "CreatedAtUtc"
LIMIT 1;
'

capture_plan "templates_generation_queue_position" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT count(*)
FROM templates_generation_jobs
WHERE "Status" = 1
  AND "QueuedAtUtc" <= now();
'

capture_plan "templates_provider_rpm_permit" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
WITH available AS (
    SELECT permit_number
    FROM generate_series(1, 60) AS permits(permit_number)
    WHERE NOT EXISTS (
        SELECT 1
        FROM templates_ai_provider_request_permits existing
        WHERE existing."Provider" = '\''fal'\''
          AND existing."BucketUtc" = date_trunc('\''minute'\'', now()) AT TIME ZONE '\''UTC'\''
          AND existing."PermitNumber" = permit_number
    )
    ORDER BY permit_number
    LIMIT 1
)
SELECT permit_number
FROM available;
'

capture_plan "identity_email_dispatch_claim" '
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
UPDATE email_dispatch_jobs
SET "Status" = 2,
    "AttemptCount" = "AttemptCount" + 1,
    "LastAttemptAtUtc" = now(),
    "UpdatedAtUtc" = now(),
    "FailureCode" = NULL,
    "FailureMessage" = NULL
WHERE "Id" = (
    SELECT "Id"
    FROM email_dispatch_jobs
    WHERE "Status" = 1
      AND ("NextAttemptAtUtc" IS NULL OR "NextAttemptAtUtc" <= now())
      AND "AttemptCount" < 3
    ORDER BY "QueuedAtUtc"
    FOR UPDATE SKIP LOCKED
    LIMIT 1
);
ROLLBACK;
'

capture_plan "support_admin_inbox" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "Status", "Priority", "AssignedAdminId", "UpdatedAtUtc"
FROM support_conversations
WHERE "Status" IN (1, 2, 3)
ORDER BY "Priority" DESC, "UpdatedAtUtc" DESC
LIMIT 50;
'

capture_plan "economy_user_subscription_status" '
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT "Id", "UserId", "Status", "CurrentPeriodEndUtc", "UpdatedAtUtc"
FROM economy_user_subscriptions
WHERE "UserId" = :'\''sample_user_id'\''::uuid
  AND "ExternalSubscriptionId" IS NOT NULL
  AND "Status" IN ('\''Active'\'', '\''GracePeriod'\'', '\''Canceled'\'')
  AND ("CurrentPeriodEndUtc" IS NULL OR "CurrentPeriodEndUtc" >= now())
ORDER BY "CurrentPeriodEndUtc" DESC
LIMIT 5;
'

{
  echo "# Hot Query Plan Capture"
  echo
  echo "- Run: $RUN_ID"
  echo "- Database: $POSTGRES_DB"
  echo "- Sample user id: $SAMPLE_USER_ID"
  echo "- Sample template id: $SAMPLE_TEMPLATE_ID"
  echo "- Sample generation id: $SAMPLE_GENERATION_ID"
  echo
  echo "## Files"
  echo
  find "$RUN_DIR" -maxdepth 1 -type f -name "*.sqlplan.txt" -print | sort | sed "s#^$RUN_DIR/#- #"
} > "$RUN_DIR/query-plan-report.md"

echo "Query plan artifacts written to $RUN_DIR"
