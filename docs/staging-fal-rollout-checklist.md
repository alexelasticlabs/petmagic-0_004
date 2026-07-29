# Staging fal.ai Rollout Checklist

Use this checklist to move from local smoke evidence to staging evidence without changing production
configuration automatically. The source of truth for the selected profile is the current staging
settings plus the fal.ai dashboard check recorded on 2026-07-01.

## Selected Profile

- Profile: Scheduler V2 Balanced bootstrap.
- fal.ai account concurrency confirmed for staging: `10`.
- Runtime policy: confirmed `10`, reserved headroom `2`, hard ceiling `38`, effective global `8`.
- Worker layout: exactly one `Standard` GenerationWorker instance with bounded lanes `4/4/1/1`.
- PostgreSQL provider attempts occupy effective capacity; Render process loops do not define it.
- Rollout flag: `Templates__GenerationSchedulerV2Enabled=false` for the first migration/backfill
  deploy, then `true` only after compatibility-loop canary and explicit Manual Sync/redeploy.

Do not increase the confirmed policy until the fal.ai dashboard explicitly shows the new account
concurrency. Purchase amount alone is not evidence. Apply increases in effective steps
`8 -> 16 -> 24 -> 38` with observation between steps.

## API Env Pack

Set these in the staging API environment:

```env
ASPNETCORE_ENVIRONMENT=Staging
DOTNET_ENVIRONMENT=Staging
Templates__GenerationWorkerEnabled=false
Templates__GenerationSchedulerV2Enabled=false
TEMPLATES_AI_PROVIDER=Fal
TEMPLATES_WATERMARK_ENABLED=true
GENERATION_GLOBAL_MAX_CONCURRENT=8
GENERATION_IMAGE_RESERVED_CONCURRENT=3
GENERATION_IMAGE_PROTECTED_CONCURRENT=3
GENERATION_IMAGE_MAX_CONCURRENT=7
GENERATION_VIDEO_RESERVED_CONCURRENT=2
GENERATION_VIDEO_MAX_CONCURRENT=4
GENERATION_VIDEO_BORROW_MAX_CONCURRENT=2
GENERATION_ENABLE_ELASTIC_LANE_BORROWING=true
GENERATION_ALLOW_VIDEO_BORROW_WHEN_IMAGE_QUEUE_EMPTY=true
GENERATION_ALLOW_VIDEO_BORROW_IMAGE_WAIT_BELOW_SECONDS=120
GENERATION_VIDEO_BORROW_RELEASE_MODE=natural_completion
GENERATION_BORROWED_VIDEO_MAX_AGE_SECONDS=0
GENERATION_BORROWING_PRIORITY_TIERS=premium,privileged,admin,free
GENERATION_VIDEO_PREPROCESSING_MAX_CONCURRENT=1
GENERATION_QUEUE_MAX_SIZE=1000
GENERATION_ESTIMATED_IMAGE_SECONDS=90
GENERATION_ESTIMATED_VIDEO_SECONDS=420
GENERATION_ESTIMATED_VIDEO_PREPROCESSING_SECONDS=90
GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS=1800
GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS=3600
GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS=1800
GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS=1800
GENERATION_PRIORITY_AGING_INTERVAL_SECONDS=60
GENERATION_PRIORITY_AGING_BOOST=500
GENERATION_CANCEL_QUEUED_ENABLED=true
TEMPLATES_REALTIME_EVENT_RETENTION_MINUTES=60
TEMPLATES_REALTIME_EVENT_CLEANUP_INTERVAL_MINUTES=10
TEMPLATES_REALTIME_EVENT_CLEANUP_BATCH_SIZE=1000
FAL_WEBHOOK_URL=https://<staging-api-host>/api/templates/provider/fal/webhook
FAL_PROVIDER_CONCURRENCY_LIMIT=10
FAL_PROVIDER_RESERVED_CONCURRENCY=2
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=10
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=5
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=0
```

API role check:

- For a sandbox or mocked FAL queue request, verify the admin cancellation route returns `200` only
  after `202 CANCELLATION_REQUESTED`, returns `202` while a transient cancellation is pending, and
  returns controlled `409` for `ALREADY_COMPLETED` and `NOT_FOUND`. Verify that only the confirmed
  cancellation creates one refund ledger row.

- `Templates:GenerationWorkerEnabled=false` for the API process.
- API and worker must have matching shared static fingerprints. Runtime capacity comes from the same
  revisioned PostgreSQL policy; worker-only lane settings are intentionally excluded from parity.
- `FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=0` is retained compatibility configuration and has no Scheduler
  V2 enforcement behavior.

## Worker Env Pack

Set these on the single GenerationWorker instance:

```env
ASPNETCORE_ENVIRONMENT=Staging
DOTNET_ENVIRONMENT=Staging
Templates__GenerationWorkerEnabled=true
Templates__GenerationSchedulerV2Enabled=false
Templates__MediaCleanupWorkerEnabled=false
Templates__TemplateOfTheDayAutoPickWorkerEnabled=false
TEMPLATES_AI_PROVIDER=Fal
TEMPLATES_WATERMARK_ENABLED=true
GENERATION_DISPATCH_CONCURRENCY=4
GENERATION_PROVIDER_RECONCILIATION_CONCURRENCY=4
GENERATION_MEDIA_IMPORT_CONCURRENCY=1
GENERATION_MAINTENANCE_CONCURRENCY=1
GENERATION_GLOBAL_MAX_CONCURRENT=8
GENERATION_IMAGE_RESERVED_CONCURRENT=3
GENERATION_IMAGE_PROTECTED_CONCURRENT=3
GENERATION_IMAGE_MAX_CONCURRENT=7
GENERATION_VIDEO_RESERVED_CONCURRENT=2
GENERATION_VIDEO_MAX_CONCURRENT=4
GENERATION_VIDEO_BORROW_MAX_CONCURRENT=2
GENERATION_ENABLE_ELASTIC_LANE_BORROWING=true
GENERATION_ALLOW_VIDEO_BORROW_WHEN_IMAGE_QUEUE_EMPTY=true
GENERATION_ALLOW_VIDEO_BORROW_IMAGE_WAIT_BELOW_SECONDS=120
GENERATION_VIDEO_BORROW_RELEASE_MODE=natural_completion
GENERATION_BORROWED_VIDEO_MAX_AGE_SECONDS=0
GENERATION_BORROWING_PRIORITY_TIERS=premium,privileged,admin,free
GENERATION_VIDEO_PREPROCESSING_MAX_CONCURRENT=1
GENERATION_QUEUE_MAX_SIZE=1000
GENERATION_ESTIMATED_IMAGE_SECONDS=90
GENERATION_ESTIMATED_VIDEO_SECONDS=420
GENERATION_ESTIMATED_VIDEO_PREPROCESSING_SECONDS=90
GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS=1800
GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS=900
GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS=3600
GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS=1800
GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS=1800
GENERATION_PRIORITY_AGING_INTERVAL_SECONDS=60
GENERATION_PRIORITY_AGING_BOOST=500
GENERATION_CANCEL_QUEUED_ENABLED=true
FAL_WEBHOOK_URL=https://<staging-api-host>/api/templates/provider/fal/webhook
FAL_PROVIDER_CONCURRENCY_LIMIT=10
FAL_PROVIDER_RESERVED_CONCURRENCY=2
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=10
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=5
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=0
GENERATION_PROVIDER_MAX_RPM=60
GENERATION_MAX_ATTEMPTS=3
GENERATION_JOB_LOCK_TIMEOUT_MS=900000
GENERATION_ORPHAN_QUEUED_TIMEOUT_MS=120000
Templates__MaxRefundAttempts=5
Templates__RefundRetryDelayMilliseconds=30000
Templates__Fal__StartTimeoutSeconds=120
Templates__Fal__ImageMaxPollingAttempts=180
Templates__Fal__ImagePreprocessingMaxPollingAttempts=180
Templates__Fal__VideoMaxPollingAttempts=300
```

Worker role check:

- `Templates:GenerationWorkerEnabled=true` for GenerationWorker.
- `Templates:MediaCleanupWorkerEnabled=false` and `Templates:TemplateOfTheDayAutoPickWorkerEnabled=false`
  in the dedicated generation worker unless those jobs are intentionally deployed elsewhere.
- Verify `numInstances: 1`, `plan: standard`, `maxShutdownDelaySeconds: 300`, no worker disk/domain,
  and Dashboard autoscaling disabled.

## Runtime capacity matrix

| Confirmed fal limit | Effective global | Image reserved/protected/max | Video guaranteed/max/borrow | Preprocessing max | Worker |
| ---: | ---: | ---: | ---: | ---: | --- |
| 10 | 8 | 3 / 3 / 7 | 2 / 4 / 2 | 1 | `1 x Standard` |
| 18 | 16 | 6 / 6 / 14 | 4 / 8 / 4 | 2 | `1 x Standard` |
| 26 | 24 | 9 / 9 / 21 | 6 / 12 / 6 | 3 | `1 x Standard` |
| 40 | 38 | 14 / 14 / 33 | 10 / 19 / 10 | 5 | `1 x Standard` |

Only effective global `8` is selected for the initial staging rollout. The other rows are runtime
policy steps, not Render replica changes.

## Runtime control checks

Use the AdminOnly endpoints, or the Capacity panel on `/generations`:

- `GET /api/admin/templates/generation-control`;
- `PUT /api/admin/templates/generation-control/policy`;
- `POST /api/admin/templates/generation-control/provider/refresh`.

For `PUT`, send the displayed `expectedRevision`, a 3-500 character `reason`, and a unique
`Idempotency-Key`. Confirm stale revision returns `409`, exact replay is idempotent, and the same key
with a different payload conflicts. Lowering capacity must stop new provider reservations until
natural drain; it must not cancel active fal attempts.

The panel must show balance freshness, confirmed/effective fal limits, image/video/stage queue depth,
native/borrowed/reserved slots, lane counts, worker heartbeat/progress/applied revision, and stable
alerts. Verify both desktop and 390 px layout. DTOs/logs must not contain the fal key or provider
secrets.

Rollout sequence: deploy the additive migration with the flag `false`, inspect migration/backfill,
and verify the bootstrap preserves `AdmissionEnabled=true` for the legacy V1 queue. Before the
maintenance window, explicitly pause admission through the Admin API with a reason, verify
`AdmissionEnabled=false`, drain, and canary the compatibility loop. Then change the shared Render
value to `true`, Manual Sync/redeploy, and require the bounded-lane start log before enabling
admission/reopening traffic. Rollback sets the flag back to `false` and Manual Sync/redeploys; the
additive schema stays in place.

## DB Pool Check

For the selected profile, plan for at least:

```text
short_lived_worker_lane_operations = 4 dispatch + 4 reconciliation + 1 import + 1 maintenance
provider_attempts_do_not_hold_db_connections_while_fal_runs = true
api_margin = current API replica count * expected concurrent request DB usage
migration_or_admin_margin = 5
```

Before running smoke, confirm:

```sql
SHOW max_connections;
SELECT count(*) FROM pg_stat_activity;
SELECT application_name, state, count(*)
FROM pg_stat_activity
GROUP BY application_name, state
ORDER BY count(*) DESC;
```

Block staging rollout if `max_connections - active_connections` is less than
the measured peak API/worker/migration demand with safety headroom after API traffic is present. The
acceptance target is fewer than `70` PostgreSQL connections under the 50-user/200-job fake-provider
run. If the DB is small, set explicit per-process `Max Pool Size` in
`ConnectionStrings__DefaultConnection` instead of relying on the Npgsql default.

## Migration Order Check

Apply migrations with the same tooling planned for production. Do not wrap the whole EF migration
bundle in an external transaction, because the scheduler/provider migrations use PostgreSQL
`CREATE INDEX CONCURRENTLY` / `DROP INDEX CONCURRENTLY`.

Current source check:

```powershell
rg -n "CONCURRENTLY|suppressTransaction" src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260630234809_AddGenerationSchedulerQueueFields.cs src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260701093000_AddAsyncGenerationProviderPipeline.cs src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260702234729_AddGenerationBillingReconciliationIndexes.cs
```

Expected result: every `CONCURRENTLY` SQL call has `suppressTransaction: true`.

Scheduler V2 additionally requires additive migration
`20260728231704_AddGenerationControlFoundation`. It creates provider attempts, webhook inbox,
runtime policy/snapshot, control receipts, media-import checkpoints, and worker heartbeat revision
fields. Inspect its bootstrap rows and active legacy-job backfill before starting the V2 worker.

Staging DB check:

```sql
SELECT "MigrationId"
FROM "__EFMigrationsHistory"
WHERE "MigrationId" IN (
  '20260630234809_AddGenerationSchedulerQueueFields',
  '20260701093000_AddAsyncGenerationProviderPipeline',
  '20260702234729_AddGenerationBillingReconciliationIndexes',
  '20260728231704_AddGenerationControlFoundation'
)
ORDER BY "MigrationId";
```

All four migration IDs must be present before Scheduler V2 smoke. Test both a clean database and an
existing database with active legacy provider jobs. Keep the additive V2 schema during application
rollback.

## Secrets To Fill Manually

Do not commit or paste these values:

- `ConnectionStrings__DefaultConnection` / `STAGING_DATABASE_URL`.
- `POSTGRES_PASSWORD` when running the Docker Compose staging profile.
- `FAL_AI_API_KEY`: backend-only fal key with Admin permission for Account Billing API; do not expose
  it to admin-web/mobile.
- `FAL_WEBHOOK_URL` after replacing the host with the real public staging API URL.
- `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_URL`.
- `BACKEND_PUBLIC_BASE_URL`.
- `BACKEND_ALLOWED_HOSTS`.
- `BACKEND_HEALTHCHECK_HOST`.
- `NEXT_PUBLIC_API_BASE_URL` and `INTERNAL_API_BASE_URL` for admin-web.
- `JWT_SIGNING_KEY`.
- `DATA_PROTECTION_CERTIFICATE_PASSWORD`.
- `ALERTMANAGER_WEBHOOK_URL` and `GRAFANA_ADMIN_PASSWORD` when the monitoring profile is enabled.
- `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` if push notifications are enabled.
- `STAGING_FREE_JWT`, `STAGING_PREMIUM_JWT`, optional `STAGING_ADMIN_AUTH_TOKEN`.

## Staging Smoke Runbook

1. Create or pick users.

```powershell
$api = "https://<staging-api-host>"
curl.exe -sS -X POST "$api/api/auth/register" `
  -H "Content-Type: application/json" `
  -d '{"email":"staging-free@example.com","password":"<secret>","displayName":"Staging Free","termsOfUseAccepted":true,"privacyPolicyAccepted":true,"termsOfUseVersion":"current","privacyPolicyVersion":"current","marketingEmailsEnabled":false}'

curl.exe -sS -X POST "$api/api/auth/login" `
  -H "Content-Type: application/json" `
  -d '{"email":"staging-free@example.com","password":"<secret>"}'
```

Copy `accessToken` into `STAGING_FREE_JWT`. Repeat for a Premium user and put its `accessToken` into
`STAGING_PREMIUM_JWT`. If email confirmation is enforced in staging, use existing verified test
accounts or complete the staging email verification flow before login.

2. Create or pick templates.

Prefer the Admin UI so uploaded preview/reference media go through the same API contracts. If using
HTTP directly, authenticate as Admin and use:

```powershell
curl.exe -sS "$api/api/admin/templates/?status=Active&type=Image&take=20" `
  -H "Authorization: Bearer $adminJwt"

curl.exe -sS "$api/api/admin/templates/?status=Active&type=Video&take=20" `
  -H "Authorization: Bearer $adminJwt"
```

Put active template IDs into `STAGING_IMAGE_TEMPLATE_ID` and `STAGING_VIDEO_TEMPLATE_ID`. For
`STAGING_FAILING_TEMPLATE_ID`, use an active staging-only failing template that is expected to reach a
terminal failed generation status. Do not use production templates.

3. Verify webhook reachability.

```powershell
curl.exe -i "$api/api/templates/provider/fal/webhook"
```

Expected result: the endpoint is publicly reachable over HTTPS and does not 404 at the gateway. A
method/signature failure is acceptable for this unauthenticated probe. Real delivery evidence is the
smoke runner check `provider.webhook_delivery_observed` plus DB rows with `WebhookReceivedAtUtc`.

4. Verify Prometheus access.

```powershell
$prom = "https://<staging-prometheus-host>"
curl.exe -sS "$prom/api/v1/query?query=fal_provider_configured_concurrency"
curl.exe -sS "$prom/api/v1/query?query=fal_provider_inflight_requests"
curl.exe -sS "$prom/api/v1/query?query=fal_provider_balance_usd"
curl.exe -sS "$prom/api/v1/query?query=histogram_quantile(0.95,sum%20by%20(le)(rate(generation_queue_depth_bucket%5B5m%5D)))"
curl.exe -sS "$prom/api/v1/query?query=increase(fal_provider_rate_limit_errors%5B10m%5D)"
```

Expected result: HTTP 200 with Prometheus `status: success` and non-empty result vectors for live
metrics.

5. Run automated smoke.

```powershell
Copy-Item .env.staging.local.example .env.staging.local
# Fill .env.staging.local from secret storage.
node scripts/qa/run-staging-generation-scheduler-smoke.mjs
```

The runner writes `artifacts/staging-generation-scheduler-smoke/<run>/evidence.json` and
`summary.md`. Keep those artifacts as staging evidence.

6. Verify the generation observability release gate.

Use `docs/observability/generation-release-gate.md` as the required dashboard, alert, smoke, and
runbook source. Staging evidence must include:

- `prometheus.required_generation_metrics_present` passing in the smoke summary;
- no missing metric names in `evidence.prometheus.metricNames.missing`;
- the Prometheus `petmagic-generation` alert group loaded;
- no critical generation alert firing outside an intentionally triggered failure probe.

## Blockers Before Production

- fal.ai dashboard does not show the concurrency stored in the current DB policy, or confirmation is
  older than seven days.
- Render generation worker is not exactly one `Standard` instance, Dashboard autoscaling remains
  enabled, or the worker lanes are not `4/4/1/1`.
- Scheduler V2 rollout flag was enabled before migration/backfill/canary validation, or remains
  disabled when claiming V2 staging evidence.
- Staging API and Worker static fingerprints differ, or worker `AppliedPolicyRevision` is behind the
  current DB policy.
- `FAL_WEBHOOK_URL` is not the public HTTPS staging API callback URL.
- Provider balance cannot be read with the Admin-capable backend key, is older than the five-minute
  last-known-good window, is at or below `$5`, or credits are not topped up for launch traffic.
- DB connection headroom is not proven for the bounded worker lanes and API traffic.
- Required migrations are missing, or any external migration wrapper forces `CONCURRENTLY` indexes
  inside a transaction.
- Scheduler V2 bootstrap/backfill has not been inspected on an existing database.
- Prometheus queries for scheduler and fal provider metrics do not return live data.
- Required generation metric names are missing from Prometheus, or generation alert rules are not
  loaded.
- Staging smoke fails, lacks webhook delivery evidence, or produces duplicate refunds / stuck charged
  jobs.
- Production env has not been filled explicitly in the production secret/env store.
