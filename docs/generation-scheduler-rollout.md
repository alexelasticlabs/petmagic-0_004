# Generation Scheduler Rollout

## Scheduler V2 runtime model

Scheduler V2 separates cheap provider orchestration from Render process scaling. Production and
staging run exactly one `Standard` generation worker (`numInstances: 1`). The committed Blueprints
start with `Templates__GenerationSchedulerV2Enabled=false`; while false, the worker uses the V1
compatibility loop so migration/backfill/canary can complete safely. When the flag is enabled and the
worker redeployed, that process starts four independent bounded lanes:

| Lane | Concurrency | Responsibility |
| --- | ---: | --- |
| Dispatch | 4 | Reserve durable provider capacity and submit the next image/preprocessing/motion stage. |
| Provider reconciliation | 4 | Drain the verified webhook inbox and poll only attempts whose `NextPollAtUtc` is due. |
| Media import | 1 | Import provider output, R2 objects, watermark and preview without blocking dispatch/polling. |
| Maintenance | 1 | Cancellation, refund, stale-lock recovery and cleanup. |

`templates_generation_jobs`, `templates_generation_provider_attempts`, and
`templates_provider_webhook_inbox` in PostgreSQL are the durable source of truth. Process-local
signals may wake a lane, but they must never own queue state. The public generation endpoints,
`TemplateGenerationStatus` wire values, and mobile/admin generation DTOs remain compatible.

The video pipeline remains stage-safe:

```text
source photo -> video_preprocessing -> NormalizedImageUrl -> video_generation
             -> media import -> watermark/thumbnail -> Completed
```

Finishing preprocessing does not authorize motion submit after a cancellation. A cancellation in
that inter-stage window completes locally. Provider submit reservations are created before the fal
HTTP request; a lost submit response becomes `SubmissionUnknown` and must be reconciled instead of
being blindly submitted again.

The one-worker topology is a cost and orchestration choice, not a fal concurrency limit. Add a
second Render worker only for HA or after evidence shows actionable dispatch/reconciliation backlog
while fal capacity is still free. Do not add Render replicas merely because more users are queued.

## Migration lock strategy

Migration `20260630234809_AddGenerationSchedulerQueueFields` adds queue snapshot columns to
`templates_generation_jobs` and backfills existing rows before scheduler rollout.

Column changes are safe for existing rows:

- `CancelledAtUtc`, `EstimatedCompletionAtQueueUtc`, and `EstimatedWaitSecondsAtQueue` are nullable.
- `QueueMediaType` is `NOT NULL` with default `image`, then backfilled to `video` for video templates.
- `QueueTier` is `NOT NULL` with default `free`, then admin test rows are backfilled to `admin`.
- Existing `Queued`, `Processing`, `Completed`, `Failed`, and `Cancelled` jobs keep valid snapshots after the backfill.

The queue hot-path indexes are created with PostgreSQL `CREATE INDEX CONCURRENTLY IF NOT EXISTS`
through raw SQL and `suppressTransaction: true`. This avoids the long write lock that regular
`CREATE INDEX` can take on a production-size `templates_generation_jobs` table.

Operational notes:

- Run the migration through the normal backend migration flow; do not wrap it in an external
  transaction.
- If deployment tooling wraps all SQL in a single transaction, run the two concurrent index
  commands as a separate manual step instead.
- Rollback drops the same indexes with `DROP INDEX CONCURRENTLY IF EXISTS`, then removes the
  added columns.
- There are no new unique indexes in this scheduler migration, so duplicate legacy values do not
  block rollout.

Migration `20260728231704_AddGenerationControlFoundation` is additive and introduces the V2 durable
control plane:

- `templates_generation_provider_attempts` with unique stage attempt, provider request id, and
  submission token constraints;
- `templates_provider_webhook_inbox` for verified, idempotent, deferred callback processing;
- `templates_generation_control_policy` plus idempotent admin command receipts;
- `templates_provider_runtime_snapshots` for fal balance state and refresh leasing;
- media-import retry/checkpoint columns on `templates_generation_jobs`;
- `AppliedPolicyRevision` and `LastProgressAtUtc` on worker runtime fingerprints.

The migration bootstraps policy revision `1` with confirmed fal limit `10`, headroom `2`, hard
ceiling `38`, and the base Balanced profile `8/3/3/7/2/4/2/1`. It also backfills legacy jobs in
`SubmittingToProvider`, `ProviderQueued`, and `ProviderProcessing` into provider attempts without
deleting the legacy provider fields. Scheduler V2 continues dual-writing those fields so the
previous worker build can consume the queue during rollback.

Before applying this migration to production:

- take and verify a PostgreSQL backup;
- inspect active legacy provider jobs and record their counts by status/stage;
- run clean-database migration tests and an existing-database upgrade/backfill test;
- keep the schema after rollback. Roll back the application and policy, not this additive migration.

## Staging rollout gate

Use a production-like PostgreSQL copy and run migrations with the same application startup flow used
for production: start the API host with `ASPNETCORE_ENVIRONMENT=Staging` and a staging
`ConnectionStrings__DefaultConnection`; do not apply a separately edited SQL file unless production
will use that same file.

Before traffic:

- Confirm the staging database is a restored production-like copy, not an empty development schema.
- Confirm the first additive-schema deploy keeps `Templates__GenerationSchedulerV2Enabled=false`.
  Enable it only through a reviewed Blueprint commit that changes the shared value to `true` after
  migration/backfill inspection and a compatibility-loop canary; run the Blueprint gate, push the
  commit, then Manual Sync/redeploy. A Dashboard-only override is not a rollout mechanism because a
  later Blueprint sync restores the committed value.
- Confirm `20260728231704_AddGenerationControlFoundation` is applied and its legacy active-job
  backfill was inspected before the new worker is started.
- Confirm the runtime policy row has the operator-confirmed fal limit, `ReservedHeadroom=2`,
  `ApplicationHardCeiling=38`, and an expected revision. API admission and worker dispatch read this
  shared PostgreSQL policy; they do not infer capacity from Render instance count.
- Confirm Render has one `Standard` generation-worker instance and Dashboard autoscaling is disabled.
  `numInstances: 1` in the Blueprint does not prove that an existing Dashboard scaling override is
  off.
- Confirm the worker-only static lane settings are `Dispatch=4`, `ProviderReconciliation=4`,
  `MediaImport=1`, and `Maintenance=1`.
- Confirm wait thresholds are fixed for staging:
  `FreeImageMaxEstimatedWaitSeconds=1800`, `PremiumImageMaxEstimatedWaitSeconds=900`,
  `FreeVideoMaxEstimatedWaitSeconds=3600`, `PremiumVideoMaxEstimatedWaitSeconds=1800`.
- Confirm realtime retention is fixed for staging:
  `RealtimeEventRetentionMinutes=60`, `RealtimeEventCleanupIntervalMinutes=10`,
  `RealtimeEventCleanupBatchSize=1000`.
- Confirm API and generation worker startup logs contain the same sanitized scheduler fingerprint
  line: `Template scheduler config startup fingerprint`, with the same `ProfileName` and `Checksum`.
- Confirm `/health` reports a healthy `templates_scheduler_config` check for the API process.
  Detailed `schedulerConfig` fields such as `checksum` are intentionally redacted from the public
  anonymous response and should be verified with an authenticated admin `/health` request or from
  `templates_runtime_config_fingerprints`.
- Confirm the latest rows in `templates_runtime_config_fingerprints` contain matching checksums for
  `Component='api'` and `Component='generation-worker'` in the same `ProfileName`.

After the API host applies migrations, verify the concurrent indexes exist:

```sql
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'templates_generation_jobs'
  AND indexname IN (
    'IX_tgj_Status_QueueMediaType_QueueTier_QueuedAtUtc',
    'IX_tgj_Status_QueueMediaType_StartedAtUtc'
  )
ORDER BY indexname;
```

The migration source must continue to use `suppressTransaction: true` for every
`CREATE INDEX CONCURRENTLY` and `DROP INDEX CONCURRENTLY` command:

```powershell
rg -n "CONCURRENTLY|suppressTransaction" src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260630234809_AddGenerationSchedulerQueueFields.cs
```

Expected evidence: both concurrent index commands and both rollback commands include
`suppressTransaction: true`; deployment logs do not contain PostgreSQL errors saying
`CREATE INDEX CONCURRENTLY cannot run inside a transaction block`.

Dangerous static mismatches are API/worker differences in the normalized shared fingerprint: queue
admission limits, elastic borrowing behavior, SLA thresholds, queue priority/aging, provider
timeouts/polling, and retry/recovery settings. Runtime capacity itself is versioned in
`templates_generation_control_policy`; the worker reports `AppliedPolicyRevision` in its heartbeat.
Worker lane concurrency and poll-loop cadence are intentionally worker-only and are not part of
cross-role fingerprint parity. The API reports static mismatch through degraded/unhealthy evidence;
the generation worker treats a current API fingerprint mismatch as fatal.

Render deploys the API and generation worker sequentially. During that rolling window the newly
started API may initially observe the previous worker fingerprint and remain degraded. Its heartbeat
must keep re-evaluating the latest active worker fingerprint and clear the mismatch only after the
matching worker revision has started. The postdeploy gate must wait for this convergence; a healthy
API `/health` response by itself is not sufficient release evidence.

## Staging smoke matrix

Create 50-100 fake generations across:

- media type: image and video;
- tier: free and premium;
- lifecycle: accepted, rejected, cancelled, completed, and failed.

Use the public generation API for accepted/rejected/cancelled/completed paths where possible. Use the
same worker image and staging config that production will use; only the AI provider may be fake if
the explicit purpose is scheduler smoke instead of provider validation.

For deterministic failed-state evidence with `Templates:AiProvider=Fake`, create one active staging
template whose image prompt, image model, preprocessing prompt/model, Kling prompt/model, or
reference media URL contains `__petmagic_fake_fail__`. Fake image generation, video preprocessing,
and video motion generation return `templates.ai_provider_failed` when that sentinel is present.
Do not use this sentinel on production templates.

Required checks:

- `GENERATION_WAIT_TOO_LONG` returns before charge; wallet balance and generation refund ledger do
  not change for the rejected request.
- Cancelling a queued charged generation refunds once. Repeating the cancel request must not create a
  second `economy_wallet_ledger` row with `Source='generation_refund'` for the same generation.
- Admin cancellation of a validated FAL `ProviderQueued` or `ProviderProcessing` generation refunds
  only after FAL confirms `202 CANCELLATION_REQUESTED`; `ALREADY_COMPLETED` and `NOT_FOUND` restore
  the active state without a refund.
- Completed and failed generations publish realtime status changes and terminal analytics.
- Failed charged generations are refunded by the worker retry/refund path.
- `templates_realtime_events` remains bounded by retention during active event flow.

Useful SQL probes:

```sql
SELECT "Status", "QueueMediaType", "QueueTier", count(*)
FROM templates_generation_jobs
GROUP BY "Status", "QueueMediaType", "QueueTier"
ORDER BY "QueueMediaType", "QueueTier", "Status";

SELECT count(*) AS realtime_events,
       min("CreatedAtUtc") AS oldest_event_utc,
       max("CreatedAtUtc") AS newest_event_utc
FROM templates_realtime_events;

SELECT "Source", "Reason", count(*)
FROM economy_wallet_ledger
WHERE "Source" = 'generation_refund'
GROUP BY "Source", "Reason"
HAVING count(*) > 1;
```

Prometheus/dashboard checks:

- `histogram_quantile(0.95, sum by (le)(rate(generation_queue_depth_bucket[5m])))` for queue depth.
- `histogram_quantile(0.95, sum by (le)(rate(generation_oldest_queued_job_age_seconds_bucket[5m])))`
  for oldest queued age.
- `sum(rate(generation_jobs_rejected_total[10m]))` for rejected jobs.
- `increase(generation_fal_timeouts_total[15m])` for FAL timeouts.
- `histogram_quantile(0.95, sum by (le, media_type, tier, lane)(rate(generation_active_jobs_bucket[5m])))`
  split by `media_type`, `tier`, and `lane`.

## Local smoke vs Staging smoke

Local smoke is a development-only check for the generation scheduler against the local Docker Compose
stack. It may use localhost, Development environment settings, local JWTs, and local template IDs. It
must not be used as staging or production rollout evidence.

Staging smoke is the production-readiness gate. It must use a production-like staging database,
real staging API and generation-worker processes, real staging JWTs and template IDs, and reachable
staging Prometheus. The staging runner continues to reject localhost by default.

Use local smoke when iterating on scheduler behavior:

```powershell
Copy-Item .env.local-smoke.example .env.local-smoke
# Fill LOCAL_* values locally; do not commit .env.local-smoke.
node scripts/qa/run-local-generation-scheduler-smoke.mjs
```

Local smoke writes artifacts under `artifacts/local-generation-scheduler-smoke/<run>/` and every
summary includes `LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE`.

For a clean local Compose startup proof before running scheduler smoke, use an isolated
project and host ports so long-running developer containers cannot hide a broken fresh start:

```powershell
$env:BACKEND_HOST_PORT = "5601"
$env:ADMIN_WEB_HOST_PORT = "3600"
$env:POSTGRES_HOST_PORT = "56543"
$env:MAILPIT_SMTP_HOST_PORT = "1625"
$env:MAILPIT_WEB_HOST_PORT = "8625"
docker compose -p petmagic_goal_probe --env-file .env.local-smoke.example up -d --build --wait --wait-timeout 240
curl http://localhost:5601/health
curl "http://localhost:5601/api/templates/feed?limit=3"
curl http://localhost:3600
```

Local smoke data setup:

- Start local Docker Compose with `ASPNETCORE_ENVIRONMENT=Development` and the separate
  `backend`, `generation-worker`, and `postgres` services running. For deterministic queue-state
  checks, set `PETMAGIC_QA_FIXTURES_ENABLED=true` on the backend before startup.
- Create or reuse one Free local test user and one Premium local test user, then put their local JWTs
  into `.env.local-smoke` as `LOCAL_FREE_JWT` and `LOCAL_PREMIUM_JWT`.
- Create or reuse one active image template and one active video template, then put their IDs into
  `LOCAL_IMAGE_TEMPLATE_ID` and `LOCAL_VIDEO_TEMPLATE_ID`.
- Create one active controlled failing template for the Fake AI provider with
  `__petmagic_fake_fail__` in a prompt, model, or reference media URL, then put its ID into
  `LOCAL_FAILING_TEMPLATE_ID`.
- Keep all values local; do not use production secrets and do not commit `.env.local-smoke`.

Use staging smoke only when the real staging inputs exist:

```powershell
Copy-Item .env.staging.local.example .env.staging.local
# Fill real STAGING_* values from secret storage; do not commit .env.staging.local.
node scripts/qa/run-staging-generation-scheduler-smoke.mjs
```

## Deterministic QA generation fixtures

QA fixtures are allowed only in `Development` and `Staging`. They are disabled by default and require
`PETMAGIC_QA_FIXTURES_ENABLED=true` on the API host. Production startup rejects this flag. The
fixture worker guard excludes jobs with `InputSourceType='qa_fixture'`, so controlled jobs stay in
the requested queue/provider/import/failure state until the fixture cleanup endpoint deletes them.

The authenticated QA endpoints are:

- `POST /api/templates/qa/generation-fixtures`
- `DELETE /api/templates/qa/generation-fixtures`

Create all UI-state fixtures:

```powershell
$body = @{
  imageTemplateId = $env:STAGING_IMAGE_TEMPLATE_ID
  videoTemplateId = $env:STAGING_VIDEO_TEMPLATE_ID
  scenarios = @('queued', 'providerQueued', 'providerProcessing', 'importingMedia', 'failed')
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$env:STAGING_API_BASE_URL/api/templates/qa/generation-fixtures" `
  -Headers @{ Authorization = "Bearer $env:STAGING_ADMIN_AUTH_TOKEN" } `
  -ContentType 'application/json' `
  -Body $body
```

Supported scenarios:

- `queued`: charged image job that remains `Queued`; cancel is available and should refund once.
- `providerQueued`: video job in `ProviderQueued`; the admin cancel route is available only when its
  FAL model, request id and trusted cancellation URL validate.
- `providerProcessing`: video job in `ProviderProcessing`; polling and realtime status evidence are
  available, and the same validated admin cancellation rule applies.
- `importingMedia`: video job in `ImportingMedia`; cancel is unavailable.
- `failed`: charged image job in `Failed` with a user-facing provider error and an immediate refund.
- `waitTooLongImage` / `waitTooLongVideo`: system-owned backlog jobs that make the next normal
  generation start return `GENERATION_WAIT_TOO_LONG` before charge.

Create deterministic overload for Android QA:

```powershell
$body = @{
  imageTemplateId = $env:STAGING_IMAGE_TEMPLATE_ID
  videoTemplateId = $env:STAGING_VIDEO_TEMPLATE_ID
  scenarios = @('waitTooLongImage', 'waitTooLongVideo')
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$env:STAGING_API_BASE_URL/api/templates/qa/generation-fixtures" `
  -Headers @{ Authorization = "Bearer $env:STAGING_ADMIN_AUTH_TOKEN" } `
  -ContentType 'application/json' `
  -Body $body
```

Then start a normal image or video generation with the same staging user. The expected API response
is HTTP 503 with `code=GENERATION_WAIT_TOO_LONG`, structured `mediaType`, `tier`,
`estimatedWaitSeconds`, `maxAllowedWaitSeconds`, `retryAfterSeconds`, `canRetry`, and
`canUpgradeForPriority` metadata, no wallet charge, and no active job for that idempotency key.

Cleanup:

```powershell
Invoke-RestMethod `
  -Method Delete `
  -Uri "$env:STAGING_API_BASE_URL/api/templates/qa/generation-fixtures" `
  -Headers @{ Authorization = "Bearer $env:STAGING_ADMIN_AUTH_TOKEN" }
```

The cleanup endpoint refunds any still-charged fixture job before deleting fixture jobs, fixture
media records, and matching realtime events for the caller plus system-owned wait-too-long backlog.
Fixtures use `InputSourceType='qa_fixture'`, so they are not part of normal production feed content
and must never be enabled in Production.

## Automated smoke runner

Use `scripts/qa/run-staging-generation-scheduler-smoke.mjs` to collect repeatable evidence from
staging. It uses the real HTTP API for generation starts/cancel, `psql` for read-only database
assertions, SSE for realtime delivery, and Prometheus HTTP API for metric visibility.

Required inputs:

```env
STAGING_API_BASE_URL=
STAGING_DATABASE_URL=
STAGING_IMAGE_TEMPLATE_ID=
STAGING_VIDEO_TEMPLATE_ID=
STAGING_FAILING_TEMPLATE_ID=
STAGING_FREE_JWT=
STAGING_PREMIUM_JWT=
STAGING_PROMETHEUS_BASE_URL=
STAGING_API_PROCESS_ID=
STAGING_WORKER_PROCESS_ID=
STAGING_MIGRATION_TOOLING_LABEL=
```

When the same file is also used as the Docker Compose staging env file, keep the
deployment keys from `.env.staging.local.example` filled as well: `POSTGRES_PASSWORD`,
`NEXT_PUBLIC_API_BASE_URL`, `INTERNAL_API_BASE_URL`, `BACKEND_PUBLIC_BASE_URL`,
`BACKEND_ALLOWED_HOSTS`, `BACKEND_HEALTHCHECK_HOST`, `JWT_SIGNING_KEY`, and the
monitoring profile keys when that profile is enabled.

Store those values only in local `.env.staging.local`, CI secrets, 1Password/Vault, or another
approved secret store. `.env.staging.local` is ignored by git; do not paste JWTs or database URLs
into README files, issues, pull requests, or Codex prompts. Copy `.env.staging.local.example` to
`.env.staging.local` on the machine that will run the smoke test and fill it there. The runner loads
`.env.staging.local` by default; set `STAGING_ENV_FILE` to use a different local secret file.

Before running the smoke:

- Confirm staging migrations are applied by the same tooling used for production.
- Confirm staging API and generation worker run as separate processes or containers.
- Confirm both processes have already started once after the latest deployment, so
  `templates_runtime_config_fingerprints` has fresh API and worker rows.
- Confirm the staging database is a production-like copy or has enough historical generation rows to
  exercise queue depth, realtime cleanup, and refund queries.
- Confirm the image and video template IDs are active and generate successfully with the staging AI
  provider configuration.
- Confirm the failing template is active and configured with `__petmagic_fake_fail__` in a prompt,
  model, or reference media URL.
- Confirm the Free and Premium JWTs belong to different staging test users and are not expired.
- Confirm `STAGING_PROMETHEUS_BASE_URL` is reachable from the runner host.
- Confirm `prometheus.required_generation_metrics_present` passes. The required metric-name gate is
  defined in `docs/observability/generation-release-gate.md` and is production-blocking.
- Keep `STAGING_MIN_EXISTING_GENERATIONS=100` unless the production-like staging copy has a documented
  lower but still representative generation history.
- To use deterministic cancel, provider-state, and overload probes, enable
  `PETMAGIC_QA_FIXTURES_ENABLED=true` on the staging API and set `STAGING_USE_QA_FIXTURES=true` for
  the runner. The local wrapper defaults `LOCAL_USE_QA_FIXTURES=true`.
- Optionally set `STAGING_MIGRATION_LOG_PATH` to a local deployment log; the runner stores only
  boolean evidence about the scheduler migration and transaction-block errors.

The runner fails `runtime_config.api_worker_scheduler_fingerprints_match` when the latest API and
generation-worker rows for the same profile are missing, have different checksums, or were marked as
mismatched at startup.

Run:

```powershell
node scripts/qa/run-staging-generation-scheduler-smoke.mjs
```

The runner writes:

- `artifacts/staging-generation-scheduler-smoke/<run>/evidence.json`
- `artifacts/staging-generation-scheduler-smoke/<run>/summary.md`

The artifact directory is ignored by git. The report anonymizes user ids and does not write JWTs or
database connection strings.

Default checks:

- required scheduler migrations are applied;
- concurrent indexes exist and are `indisvalid`/`indisready`;
- the migration source uses `suppressTransaction: true` for every `CONCURRENTLY` command;
- 50-100 generation attempts are made across image/video and free/premium tokens;
- accepted, cancelled, completed, queue-rejected, and media/tier DB evidence is collected;
- when `STAGING_FAILING_TEMPLATE_ID` is set, one extra generation is submitted and must reach
  terminal `failed` status;
- when QA fixtures are enabled, deterministic `ProviderQueued`, `ProviderProcessing`,
  `ImportingMedia`, `Failed`, queued cancel, validated provider-cancel outcomes, and
  `GENERATION_WAIT_TOO_LONG` fixture probes are created and cleaned up through the API;
- `GENERATION_WAIT_TOO_LONG`, when observed, does not change the submitting user's wallet balance;
- `GENERATION_WAIT_TOO_LONG` includes structured queue metadata and does not create an active job;
- confirmed cancellation refund ledger rows are not duplicated and charged cancels refund exactly once;
- the failing template reaches terminal `failed`, is refund-safe, and has no duplicate refund ledger
  rows;
- Premium queue evidence is not worse than comparable Free work for image and video lanes;
- `/api/templates/events` SSE connects and receives at least one generation status event from the run;
- `templates_realtime_events` growth stays within the configured smoke budget and persisted events
  cross-check with SSE delivery;
- Prometheus queries for queue depth, active jobs, rejected jobs, cancelled jobs, refund counters,
  duplicate refund attempts, FAL timeouts, and SSE delivery failures return non-empty results.

If the failing template is created manually outside the smoke script, set
`STAGING_EXPECT_FAILED_STATUS=true` to require failed DB status evidence even without submitting
`STAGING_FAILING_TEMPLATE_ID`.

## Queue capacity configuration

The authoritative capacity is the revisioned row in `templates_generation_control_policy`, not a
Render replica/loop formula and not the fal credit balance:

```text
effectiveGlobal = min(ApplicationHardCeiling,
                      ConfirmedFalConcurrencyLimit - ReservedHeadroom)
```

The operator enters the concurrency displayed in the fal dashboard and reconfirms it after account
changes. A warning becomes active after seven days without confirmation. The default hard ceiling is
`38`, and two provider slots stay outside PetMagic. A confirmed fal limit of `10` therefore yields
`8`; a confirmed limit of `40` yields `38`.

The Balanced profile scales each base value with
`roundAwayFromZero(baseValue * effectiveGlobal / 8)`, applies the defined minimums, and validates the
global/lane invariants:

| Parameter | Effective global 8 | Effective global 38 |
| --- | ---: | ---: |
| Image reserved/protected | 3 | 14 |
| Image opportunistic max | 7 | 33 |
| Video guaranteed | 2 | 10 |
| Video max | 4 | 19 |
| Video borrow max | 2 | 10 |
| Video preprocessing max | 1 | 5 |

When video backlog exists, dispatch does not start a new image attempt if doing so would leave less
than the guaranteed video capacity. Existing image work is never cancelled. Without video backlog,
image can use opportunistic capacity. Tier priority, aging, and per-tier user round-robin are applied
after these capacity rules.

When all effective fal slots are occupied, admission is not rejected merely because the provider is
full. The job stays durably queued in PostgreSQL and dispatch waits for a slot. Pre-charge admission
still rejects a full local queue, a per-user quota breach, a stage-aware ETA outside SLA, missing
provider configuration, paused admission, or critical/unknown balance.

The supported SLA thresholds are:

- `FreeImageMaxEstimatedWaitSeconds = 1800`
- `PremiumImageMaxEstimatedWaitSeconds = 900`
- `PrivilegedImageMaxEstimatedWaitSeconds = 900`
- `FreeVideoMaxEstimatedWaitSeconds = 3600`
- `PremiumVideoMaxEstimatedWaitSeconds = 1800`
- `PrivilegedVideoMaxEstimatedWaitSeconds = 1800`
- `QueuePriorityAgingBoost = 500`

ETA includes the remaining pipeline stages. Image fallback is `90 + 30` seconds; video fallback is
`90 + 420 + 120` seconds. Rolling p90 completion history replaces the fallback after enough recent
samples. Admission rejects outside the SLA before PawSpark charge.

## Scheduler V2 capacity profiles

The current bootstrap assumption is a dashboard-confirmed fal concurrency of `10`, but that value is
operator-owned and can change. Purchase or balance amounts are not valid evidence of the limit. Use
`PUT /api/admin/templates/generation-control/policy` with `expectedRevision`, a non-empty operational
`reason`, and `Idempotency-Key` to confirm a new value. The update and admin audit outbox are atomic;
a stale revision returns `409`, and reusing a key for a different payload is a conflict.

Shared Render environment values remain a bootstrap/fallback contract for API and worker. Runtime
capacity changes are applied through the PostgreSQL policy revision; they do not require more Render
worker instances. Host role flags may differ to keep background ownership single-writer.

| Setting | Staging API env value | Staging worker env value | Docker/env override | Effective staging value |
| --- | ---: | ---: | --- | ---: |
| `GlobalMaxConcurrentGenerations` | 8 | 8 | `GENERATION_GLOBAL_MAX_CONCURRENT=8` | 8 |
| `ImageReservedConcurrentGenerations` | 3 | 3 | `GENERATION_IMAGE_RESERVED_CONCURRENT=3` | 3 |
| `ImageProtectedConcurrentGenerations` | 3 | 3 | `GENERATION_IMAGE_PROTECTED_CONCURRENT=3` | 3 |
| `ImageMaxConcurrentGenerations` | 7 | 7 | `GENERATION_IMAGE_MAX_CONCURRENT=7` | 7 |
| `VideoReservedConcurrentGenerations` | 2 | 2 | `GENERATION_VIDEO_RESERVED_CONCURRENT=2` | 2 |
| `VideoMaxConcurrentGenerations` | 4 | 4 | `GENERATION_VIDEO_MAX_CONCURRENT=4` | 4 |
| `VideoBorrowMaxConcurrentGenerations` | 2 | 2 | `GENERATION_VIDEO_BORROW_MAX_CONCURRENT=2` | 2 |
| `EnableElasticLaneBorrowing` | true | true | `GENERATION_ENABLE_ELASTIC_LANE_BORROWING=true` | true |
| `AllowVideoBorrowWhenImageQueueEmpty` | true | true | `GENERATION_ALLOW_VIDEO_BORROW_WHEN_IMAGE_QUEUE_EMPTY=true` | true |
| `AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds` | 120 | 120 | `GENERATION_ALLOW_VIDEO_BORROW_IMAGE_WAIT_BELOW_SECONDS=120` | 120 |
| `FalProviderConcurrencyLimit` | 10 | 10 | `FAL_PROVIDER_CONCURRENCY_LIMIT=10` | 10 |
| `FalProviderReservedConcurrency` | 2 | 2 | `FAL_PROVIDER_RESERVED_CONCURRENCY=2` | 2 |
| `QueueMaxSize` | 1000 | 1000 | `GENERATION_QUEUE_MAX_SIZE:-1000` | 1000 |
| `EstimatedImageGenerationSeconds` | 90 | 90 | `GENERATION_ESTIMATED_IMAGE_SECONDS:-90` | 90 |
| `EstimatedVideoGenerationSeconds` | 420 | 420 | `GENERATION_ESTIMATED_VIDEO_SECONDS:-420` | 420 |
| `FreeImageMaxEstimatedWaitSeconds` | 1800 | 1800 | `GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS:-1800` | 1800 |
| `PremiumImageMaxEstimatedWaitSeconds` | 900 | 900 | `GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=900` | 900 |
| `FreeVideoMaxEstimatedWaitSeconds` | 3600 | 3600 | `GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS:-3600` | 3600 |
| `PremiumVideoMaxEstimatedWaitSeconds` | 1800 | 1800 | `GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS:-1800` | 1800 |
| `QueuePriorityAgingBoost` | 500 | 500 | `GENERATION_PRIORITY_AGING_BOOST:-500` | 500 |

`MaxConcurrentJobsPerWorker` and `GENERATION_WORKER_MAX_CONCURRENT_JOBS` are Scheduler V1 sizing
settings. They no longer determine provider capacity and must not be reintroduced into the shared
API/worker fingerprint. Worker-only V2 lane concurrency is `4/4/1/1`.

Local docker-compose defaults may remain conservative unless overrides are set. Staging and
production bootstrap values must remain explicit, but the applied runtime revision is authoritative.

Scaled Balanced profiles (all use one Render worker):

| Confirmed fal limit | Effective global | Image reserved/protected/max | Video guaranteed/max/borrow | Video preprocessing | Render worker |
| ---: | ---: | ---: | ---: | ---: | --- |
| 10 | 8 | 3 / 3 / 7 | 2 / 4 / 2 | 1 | `1 x Standard` |
| 18 | 16 | 6 / 6 / 14 | 4 / 8 / 4 | 2 | `1 x Standard` |
| 26 | 24 | 9 / 9 / 21 | 6 / 12 / 6 | 3 | `1 x Standard` |
| 40 | 38 | 14 / 14 / 33 | 10 / 19 / 10 | 5 | `1 x Standard` |

Provider capacity is occupied by durable active attempts, not by long-running local loops. Dispatch
submits asynchronously and releases its local lane; reconciliation and import proceed independently.
Before adding a second worker for HA, verify DB connection pool headroom and prove that one worker
cannot drain actionable orchestration backlog while fal capacity is free.

Supported max-wait thresholds do not expand when fal capacity increases:

| Tier | Image | Video |
| --- | ---: | ---: |
| Free | 1800s | 3600s |
| Premium | 900s | 1800s |
| Privileged | 900s | 1800s |

Set privileged waits equal to Premium or lower; startup validation requires
`Privileged <= Premium <= Free` for each media type.

The following simulation tables are retained only as historical Scheduler V1 evidence. Their old
`FalConcurrency20/30/40` caps and replica assumptions are not deployment instructions and must not be
used to configure Scheduler V2. Rerun the load model against the V2 durable-attempt implementation
before replacing them with current acceptance evidence.

Historical simulation assumptions:

- simultaneous arrivals;
- `image avg = 90 seconds`;
- `video avg = 420 seconds`;
- admission uses current media-lane ETA logic;
- drain simulation applies both global and media caps;
- provider failures, retries, and billing failures are not injected.

Simulation summary:

| Profile | Scenario | Accepted | Rejected | p95 wait | p99 wait | Notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `FalConcurrency10` | 100 image | 100 | 0 | 19.5m | 21.0m | good image launch baseline |
| `FalConcurrency10` | 100 video | 18 | 82 | 56.0m | 56.0m | rejects long Free video backlog |
| `FalConcurrency10` | 1000 image | 141 | 859 | 28.5m | 28.5m | still conservative |
| `FalConcurrency10` | 1000 video | 18 | 982 | 56.0m | 56.0m | intentionally strict |
| `FalConcurrency20` | 100 image | 100 | 0 | 9.0m | 10.5m | image wait improves materially |
| `FalConcurrency20` | 100 video | 43 | 57 | 49.0m | 56.0m | still protects video queue |
| `FalConcurrency20` | 1000 image | 281 | 719 | 28.5m | 28.5m | more image revenue accepted |
| `FalConcurrency20` | 1000 video | 43 | 957 | 49.0m | 56.0m | no multi-hour accepted Free video |
| `FalConcurrency30` | 100 image | 100 | 0 | 6.0m | 6.0m | recommended for $500 deposit launch |
| `FalConcurrency30` | 100 video | 100 | 0 | 1.3h | 1.4h | acceptable only with visible video wait copy |
| `FalConcurrency30` | 1000 image | 631 | 369 | 42.0m | 43.5m | strong image acceptance |
| `FalConcurrency30` | 1000 video | 103 | 897 | 1.4h | 1.4h | bounded video acceptance |
| `FalConcurrency40` | 100 image | 100 | 0 | 4.5m | 4.5m | recommended for $1000+ deposit launch |
| `FalConcurrency40` | 100 video | 100 | 0 | 1.1h | 1.1h | video remains slow by nature |
| `FalConcurrency40` | 1000 image | 1000 | 0 | 49.5m | 52.5m | accepts burst without image rejection |
| `FalConcurrency40` | 1000 video | 172 | 828 | 1.9h | 1.9h | rejects before multi-hour video debt |

Mixed and starvation checks:

| Profile | Scenario | Result |
| --- | --- | --- |
| `FalConcurrency10` | 500 image + 500 video | 159 accepted, 841 rejected, image avg 14.4m, video avg 41.2m |
| `FalConcurrency20` | 500 image + 500 video | 324 accepted, 676 rejected, image avg 14.3m, video avg 42.8m |
| `FalConcurrency30` | 500 image + 500 video | 603 accepted, 397 rejected, image avg 17.1m, video avg 1.0h |
| `FalConcurrency40` | 500 image + 500 video | 672 accepted, 328 rejected, image avg 12.6m, video avg 1.2h |
| `FalConcurrency10` | 100 Premium + 900 Free image | Premium avg 6.9m, Free avg 22.0m |
| `FalConcurrency30` | 100 Premium + 900 Free image | Premium avg 2.9m, Free avg 25.4m |
| `FalConcurrency40` | 100 Premium + 900 Free image | Premium avg 2.0m, Free avg 28.7m |
| all profiles | continuous video + new image | image still starts; effective image slots are `global - video cap` when video is saturated |
| all profiles | continuous Premium + old Free sample | no hard starvation; Free aging keeps old Free work competitive |

Operational recommendation:

- Start staging and production canary with confirmed fal limit `10`, effective global `8`, and one
  `Standard` Render worker.
- If the dashboard later confirms `40`, increase the policy in observed steps `8 -> 16 -> 24 -> 38`.
  Check queue age, media-import age, worker CPU/RAM, errors, and DB connections between steps.
- Decreasing the policy does not cancel active provider work. New reservations stop until natural
  drain brings in-flight attempts below the new effective limit.
- Keep `ReservedHeadroom=2`; do not infer or auto-increase concurrency from credits purchased.

## fal.ai operational guardrails

PetMagic refreshes `GET https://api.fal.ai/v1/account/billing?expand=credits` independently every
60 seconds. fal requires an Admin-capable backend key for account billing. Keep using the existing
server-only `FAL_AI_API_KEY` secret, but ensure that key has the required fal account permission; do
not add a second client-visible key and never expose it to admin-web or mobile.

Balance states and effects:

| State | Rule | New admission/submission |
| --- | --- | --- |
| `fresh` | Balance is at least `$10` | Allowed subject to queue/SLA/policy. |
| `low` | Balance is below `$10` and above `$5` | Allowed with warning. |
| `critical` | Balance is at or below `$5` | Stopped; active fal work is not cancelled. |
| `stale` | Refresh failed, last success is no older than five minutes | Last-known-good continues with warning. |
| `unknown` | No usable success or older than five minutes | Stopped; queued jobs stay cancellable/refundable. |

Account concurrency still has no runtime discovery path in this integration. The admin confirms the
dashboard value and timestamp. PetMagic applies:

```text
ConfirmedFalConcurrencyLimit = operator-confirmed dashboard value
ReservedHeadroom = 2
ApplicationHardCeiling = 38
FalProviderBalanceLowThresholdUsd = 10
FalProviderBalanceCriticalThresholdUsd = 5
FalProviderSpendDailyLimitUsd = 0  # retained compatibility option, intentionally unused
```

`FalProviderSpendDailyLimitUsd` is not a Scheduler V2 control and is excluded from the scheduler
fingerprint. There is no automatic daily-spend cap in this release. Use balance thresholds, provider
dashboard billing controls, and operator alerts instead.

Provider attempt safety rules:

- a scheduler advisory lock and transaction reserve `SubmitReserved` before fal HTTP submit;
- the external request runs outside the DB transaction;
- request id/status/response/cancel URLs are persisted after acceptance and dual-written to legacy
  job fields;
- a lost response becomes `SubmissionUnknown`; no blind resubmit or refund occurs while paid remote
  work might still be running;
- verified callbacks are deduplicated into `templates_provider_webhook_inbox` and reconciled later;
- polling runs only when `NextPollAtUtc` is due, with queue/progress backoff and jitter;
- before a stage timeout, perform final reconciliation and validated provider cancellation;
- duplicate/out-of-order webhook and webhook/poll races cannot overwrite a terminal attempt.

Low-balance runbook:

1. Open `/generations` in admin and inspect balance freshness, effective limit, in-flight attempts,
   queue stages, heartbeat, applied policy revision, and active alerts.
2. Use `POST /api/admin/templates/generation-control/provider/refresh` after fixing key/balance; do
   not repeatedly call fal billing from user requests.
3. If `critical` or `unknown`, keep admission paused, top up/fix the Admin-capable key, and verify a
   fresh snapshot before resuming.
4. Confirm existing provider attempts reconcile and queued cancellation still produces exactly one
   generation-scoped refund.
5. If the dashboard concurrency changed, update the policy with revision/idempotency controls and
   observe natural drain. Do not change Render worker instance count.

## Rollout and rollback

1. Before the first V2 deploy, inspect the currently failed Render worker logs. The repository does
   not contain live Render log/metric proof.
2. Run the Blueprint/predeploy gates, then manually verify autoscaling is disabled for API, worker,
   and admin. Blueprint `numInstances: 1` does not clear an existing Dashboard override.
3. Apply the additive migration and inspect bootstrap/backfill rows. The bootstrap preserves
   `AdmissionEnabled=true` so a schema-only deploy cannot unexpectedly stop the legacy V1 queue.
   Before the planned maintenance window, explicitly pause admission through the revisioned Admin
   API with a recorded reason and verify `AdmissionEnabled=false` before draining.
4. Start the API, then the one worker with `Templates__GenerationSchedulerV2Enabled=false`. Let
   legacy active jobs drain/reconcile while admission remains explicitly paused, then run the
   compatibility-loop canary.
5. Create and review a rollout commit changing the shared Blueprint value to `true`, run the
   Blueprint gate, push it, and Manual Sync/redeploy. Then require fresh worker heartbeat, recent
   `LastProgressAtUtc`, matching static fingerprints, and
   `AppliedPolicyRevision` equal to the current DB revision.
6. In staging, run fake-provider image/video/crash/race tests first. A real fal canary is separate and
   remains blocked until credits and production provider configuration exist.
7. Enable admission at effective global `8`, verify image plus every video-template flow, and only
   then use the stepped `8 -> 16 -> 24 -> 38` policy rollout when fal confirms higher capacity.
8. Run for one production-observation week before opening advertising traffic.

Rollback pauses admission, uses a reviewed Blueprint commit to set
`Templates__GenerationSchedulerV2Enabled=false`, runs the gate, then Manual Sync/redeploys the
compatibility worker and restores the bootstrap policy profile. Do not roll back
the additive schema. Dual-written provider fields let the previous worker continue existing jobs.
Do not cancel active remote work or refund it until reconciliation/cancel proves it can no longer
incur provider cost.

## `GENERATION_WAIT_TOO_LONG` API contract

When the queue rejects a generation before charge, the API returns `503 ProblemDetails` with safe
queue metadata in extensions:

- `code`: `GENERATION_WAIT_TOO_LONG`
- `mediaType`: `image` or `video`
- `tier`: `free`, `premium`, `privileged`, or `admin`
- `estimatedWaitSeconds`
- `maxAllowedWaitSeconds`
- `retryAfterSeconds`
- `canRetry`
- `canUpgradeForPriority`

These fields are intentionally coarse. They do not expose queue depth, user counts, worker lock ids,
provider rate-limit internals, or exact capacity decisions.

Flutter should keep old-client compatibility by treating unknown `ProblemDetails` fields as optional.
New clients can show high-load copy, an approximate wait, a retry-after hint, and Premium priority
messaging when `canUpgradeForPriority` is `true`.
