# Generation Scheduler Rollout

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

## Staging rollout gate

Use a production-like PostgreSQL copy and run migrations with the same application startup flow used
for production: start the API host with `ASPNETCORE_ENVIRONMENT=Staging` and a staging
`ConnectionStrings__DefaultConnection`; do not apply a separately edited SQL file unless production
will use that same file.

Before traffic:

- Confirm the staging database is a restored production-like copy, not an empty development schema.
- Confirm API and generation worker use the same image/video/global caps:
  `GlobalMaxConcurrentGenerations=3`, `ImageMaxConcurrentGenerations=2`,
  `VideoMaxConcurrentGenerations=1`.
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

Dangerous scheduler mismatches are any API/worker difference in the normalized fingerprint: global,
image, video, preprocessing, reserved, protected, or provider concurrency; elastic lane borrowing;
max-wait thresholds; queue priority and aging; queue size and active-generation admission limits;
provider timeout and polling settings; worker polling; retry, stale-lock, orphan-queue, and refund
retry settings. The API reports these through degraded/unhealthy health evidence. The generation
worker treats a mismatch against the latest API fingerprint as fatal and fails startup, because the
worker is the component that actually consumes the queue.

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

`GlobalMaxConcurrentGenerations` is the hard upper bound for active provider/in-flight generation
jobs. `ImageMaxConcurrentGenerations` and `VideoMaxConcurrentGenerations` are hard lane caps.
`ImageReservedConcurrentGenerations`, `ImageProtectedConcurrentGenerations`,
`VideoReservedConcurrentGenerations`, and `VideoBorrowMaxConcurrentGenerations` control elastic
lane borrowing.

Startup validation rejects either media lane cap when it is greater than the global cap. A sum such
as `ImageMaxConcurrentGenerations + VideoMaxConcurrentGenerations > GlobalMaxConcurrentGenerations`
is allowed: it means both lanes can compete for the shared global pool, but the global cap still
limits total processing jobs.

When `EnableElasticLaneBorrowing=true`, video always consumes `VideoReservedConcurrentGenerations`
first. It can borrow up to `VideoBorrowMaxConcurrentGenerations` additional slots only while global
capacity is free, active video is below `VideoMaxConcurrentGenerations`, and the image lane is either
empty or its estimated wait is at or below
`AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds`. Running borrowed video is released by natural
completion; new borrowed video stops when an image backlog appears.

Pre-production defaults intentionally reject Free video work earlier than image work during overload:

- `FreeVideoMaxEstimatedWaitSeconds = 3600`
- `PremiumVideoMaxEstimatedWaitSeconds = 1800`
- `PrivilegedVideoMaxEstimatedWaitSeconds = 1800`
- `QueuePriorityAgingBoost = 500`

This preserves Premium advantage while avoiding very long Free video queues that would be accepted
but wait for hours under sustained video overload. With the default priority gap, Free jobs gain
enough aging priority to compete with new Premium jobs after roughly six minutes instead of roughly
thirty minutes.

## fal.ai concurrency profiles

fal.ai dashboard evidence for launch planning:

- Current account limit: 10 concurrent requests.
- With roughly $500 purchased credits in the last four weeks, expected limit can be 30.
- With roughly $1000+ purchased credits in the last four weeks, expected limit can be 40.

The scheduler must not consume the entire fal.ai limit. Keep headroom for retries, admin tests,
manual operations, and provider-side variance. Configure API and GenerationWorker with the same
queue and wait values. Host role flags such as `Templates:GenerationWorkerEnabled`,
`Templates:MediaCleanupWorkerEnabled`, and `Templates:TemplateOfTheDayAutoPickWorkerEnabled` may
differ by process role to keep background job ownership single-writer.

Current selected staging profile after the 2026-07-01 fal.ai dashboard check:

- Dashboard concurrency limit: 10.
- Selected profile: `FalConcurrency10`.
- Staging API and GenerationWorker environment overrides must be pinned to the same scheduler values.
- Production must still set the same values explicitly in the production secret/env store before
  rollout; do not rely on local docker defaults for production.

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
| `MaxConcurrentJobsPerWorker` | 2 | 2 | `GENERATION_WORKER_MAX_CONCURRENT_JOBS=2` | 2 |
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

Local docker-compose defaults intentionally remain conservative (`3/2/1`) unless these env vars are
set. Staging and production deployments must set the selected profile explicitly.

Production-like deployment profiles with elastic video borrowing:

| Profile | fal.ai limit | Global cap | Image reserved/protected/max | Video reserved/max/borrow | Worker loops target | Recommended worker layout |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `FalConcurrency10` | 10 | 8 | 3 / 3 / 7 | 2 / 4 / 2 | >= 8 | 4 replicas x 2 loops |
| `FalConcurrency30` | 30 | 24 | 8 / 6 / 21 | 5 / 14 / 9 | >= 24 | 6 replicas x 4 loops |
| `FalConcurrency40` | 40 | 32 | 12 / 8 / 28 | 8 / 20 / 12 | >= 32 | 8 replicas x 4 loops |

Worker capacity rule:

```text
total_worker_loops = worker_replicas * MaxConcurrentJobsPerWorker
total_worker_loops >= GlobalMaxConcurrentGenerations
```

Before increasing worker replicas, verify DB connection pool headroom. PostgreSQL advisory locks
and `FOR UPDATE SKIP LOCKED` make multi-worker claiming safe, but each loop can hold a database
connection while processing or checking provider state. In the async provider pipeline, local
generation slots are released after fal submit, but provider in-flight jobs still count as active
for ETA/backpressure.

Recommended max-wait thresholds:

| Profile | Free image | Premium image | Free video | Premium video |
| --- | ---: | ---: | ---: | ---: |
| `FalConcurrency10` | 1800s | 900s | 3600s | 1800s |
| `FalConcurrency20` | 1800s | 900s | 3600s | 1800s |
| `FalConcurrency30` | 2700s | 1200s | 5400s | 2700s |
| `FalConcurrency40` | 3600s | 1500s | 7200s | 3600s |

Set privileged waits equal to Premium or lower; startup validation requires
`Privileged <= Premium <= Free` for each media type.

Simulation assumptions:

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

- Current verified limit 10: use `FalConcurrency10` for staging and controlled production rollout.
- $500 deposit / expected limit 30: use `FalConcurrency30`.
- $1000+ deposit / expected limit 40: use `FalConcurrency40`, with explicit monitoring on fal
  timeout rate, provider queue time, refunds, rejected jobs, and old queued age.

Example environment for current limit `10` / `FalConcurrency10`:

```env
GENERATION_GLOBAL_MAX_CONCURRENT=8
GENERATION_IMAGE_MAX_CONCURRENT=7
GENERATION_VIDEO_MAX_CONCURRENT=4
GENERATION_WORKER_MAX_CONCURRENT_JOBS=2
GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS=1800
GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS=3600
GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS=1800
GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS=1800
FAL_PROVIDER_CONCURRENCY_LIMIT=10
FAL_PROVIDER_RESERVED_CONCURRENCY=2
```

Run exactly 4 generation-worker replicas for this profile.

Example environment for `$500` / `FalConcurrency30`:

```env
GENERATION_GLOBAL_MAX_CONCURRENT=24
GENERATION_IMAGE_MAX_CONCURRENT=21
GENERATION_VIDEO_MAX_CONCURRENT=14
GENERATION_WORKER_MAX_CONCURRENT_JOBS=4
GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS=2700
GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=1200
GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS=1200
GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS=5400
GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS=2700
GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS=2700
```

Run at least 6 worker replicas for this profile.

Example environment for `$1000+` / `FalConcurrency40`:

```env
GENERATION_GLOBAL_MAX_CONCURRENT=32
GENERATION_IMAGE_MAX_CONCURRENT=28
GENERATION_VIDEO_MAX_CONCURRENT=20
GENERATION_WORKER_MAX_CONCURRENT_JOBS=4
GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS=3600
GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=1500
GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS=1500
GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS=7200
GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS=3600
GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS=3600
```

Run at least 8 worker replicas for this profile.

Do not set `GlobalMaxConcurrentGenerations` equal to the full fal.ai account limit. Keep the
remaining provider capacity for retries, admin tests, manual jobs, and provider-side bursts. Free
video should still reject earlier than image during overload; accepting video work with 5-10 hour
waits is worse than a clear pre-charge rejection.

## fal.ai operational guardrails

Official fal.ai automation coverage:

- Balance/credits: available through `GET https://api.fal.ai/v1/account/billing?expand=credits`.
  PetMagic reads `credits.current_balance` with a backend-only fal API key.
- Concurrency: fal.ai documents the account concurrency model, but there is no documented endpoint
  in the public docs for reading the current account concurrency limit at runtime. Keep this as an
  operator-supplied deployment value until fal exposes a current-limit API.
- Queue behavior: fal.ai queues requests above the account limit instead of rejecting them. PetMagic
  must therefore apply its own pre-charge backpressure and provider guardrails.

Provider capacity settings:

```text
FalProviderConcurrencyLimit          # operator-entered fal.ai account limit
FalProviderReservedConcurrency       # headroom for retries, admin tests, manual runs
FalProviderBalanceLowThresholdUsd    # alert threshold, does not block admission
FalProviderBalanceCriticalThresholdUsd # hard pre-charge rejection threshold
FalProviderSpendDailyLimitUsd        # manual budget guard until daily spend API is wired
```

Admission behavior for `AiProvider=Fal`:

- if `FalProviderConcurrencyLimit` is missing or `0`, reject before charge with
  `PROVIDER_CAPACITY_UNAVAILABLE`;
- if PetMagic provider in-flight requests are at or above
  `FalProviderConcurrencyLimit - FalProviderReservedConcurrency`, reject before charge;
- if balance cannot be read from fal.ai Account Billing API, reject before charge;
- if balance is at or below `FalProviderBalanceCriticalThresholdUsd`, reject before charge;
- if balance is below `FalProviderBalanceLowThresholdUsd` but above critical, keep accepting and alert.

Required launch values:

```env
FAL_PROVIDER_CONCURRENCY_LIMIT=30
FAL_PROVIDER_RESERVED_CONCURRENCY=2
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=150
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=50
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=150
```

For a `$500` pre-launch top-up, start with `FAL_PROVIDER_CONCURRENCY_LIMIT=30` only after the fal.ai
dashboard shows the increased concurrency. For `$1000+`, use `40` only after the dashboard confirms
the account limit. Do not infer the limit from purchase amount alone.

Low-balance runbook:

1. Check `fal_provider_balance_usd`, `fal_provider_balance_low`, and `fal_provider_balance_critical`.
2. Open the fal.ai dashboard and confirm the displayed balance and account concurrency.
3. If balance is critical, top up before re-enabling generation admission. PetMagic should already
   be rejecting new generation requests before charge.
4. After top-up, wait for `fal_provider_balance_usd` to update or restart API pods to clear the
   short balance cache if needed.
5. Confirm `fal_provider_rejected_due_to_capacity` stops increasing and no new charged jobs are
   stuck without provider request ids.
6. If concurrency dropped, lower `GlobalMaxConcurrentGenerations`, media caps, and
   `FAL_PROVIDER_CONCURRENCY_LIMIT` together before accepting more traffic.

Manual daily ops checklist until daily spend automation is wired:

- record fal.ai dashboard balance at start/end of day;
- record dashboard concurrency limit;
- compare daily spend against `FAL_PROVIDER_SPEND_DAILY_LIMIT_USD`;
- check `fal_provider_queue_wait_seconds` p95 and `generation_jobs_rejected_total`;
- confirm no unexpected spike in `fal_provider_submit_failures` or `fal_provider_rate_limit_errors`.

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
