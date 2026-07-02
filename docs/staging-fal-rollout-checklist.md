# Staging fal.ai Rollout Checklist

Use this checklist to move from local smoke evidence to staging evidence without changing production
configuration automatically. The source of truth for the selected profile is the current staging
settings plus the fal.ai dashboard check recorded on 2026-07-01.

## Selected Profile

- Profile: `FalConcurrency10`.
- fal.ai account concurrency confirmed for staging: `10`.
- API appsettings and GenerationWorker appsettings are pinned to the same scheduler values.
- Worker layout: exactly `4` GenerationWorker replicas with `2` loops each.
- Capacity formula: `4 * 2 = 8` worker loops, matching `GENERATION_GLOBAL_MAX_CONCURRENT=8`.

Do not move to `FalConcurrency30` or `FalConcurrency40` until the fal.ai dashboard explicitly shows
that account concurrency. Purchase amount alone is not evidence.

## API Env Pack

Set these in the staging API environment:

```env
ASPNETCORE_ENVIRONMENT=Staging
DOTNET_ENVIRONMENT=Staging
Templates__GenerationWorkerEnabled=false
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
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=100
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=25
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=0
```

API role check:

- `Templates:GenerationWorkerEnabled=false` for the API process.
- API must have the same scheduler, provider guardrail, webhook, and balance values as workers.

## Worker Env Pack

Set these in every GenerationWorker replica:

```env
ASPNETCORE_ENVIRONMENT=Staging
DOTNET_ENVIRONMENT=Staging
Templates__GenerationWorkerEnabled=true
Templates__MediaCleanupWorkerEnabled=false
Templates__TemplateOfTheDayAutoPickWorkerEnabled=false
TEMPLATES_AI_PROVIDER=Fal
TEMPLATES_WATERMARK_ENABLED=true
GENERATION_WORKER_REPLICAS=4
GENERATION_WORKER_MAX_CONCURRENT_JOBS=2
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
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=100
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=25
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

## Replica Matrix

| Profile | fal.ai limit | Worker replicas | Jobs per worker | Total worker loops |
| --- | ---: | ---: | ---: | ---: |
| `FalConcurrency10` | 10 | 4 | 2 | 8 |
| `FalConcurrency30` | 30 | 6 | 4 | 24 |
| `FalConcurrency40` | 40 | 8 | 4 | 32 |

Only `FalConcurrency10` is selected for this staging rollout.

## DB Pool Check

For the selected profile, plan for at least:

```text
worker_loop_connections = 4 replicas * 2 loops = 8
provider_polling_and_import_margin = 4 replicas
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
`worker_loop_connections + provider_polling_and_import_margin + migration_or_admin_margin` after API
traffic is present. If the DB is small, set explicit per-process `Max Pool Size` in
`ConnectionStrings__DefaultConnection` instead of relying on the Npgsql default.

## Migration Order Check

Apply migrations with the same tooling planned for production. Do not wrap the whole EF migration
bundle in an external transaction, because the scheduler/provider migrations use PostgreSQL
`CREATE INDEX CONCURRENTLY` / `DROP INDEX CONCURRENTLY`.

Current source check:

```powershell
rg -n "CONCURRENTLY|suppressTransaction" src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260630234809_AddGenerationSchedulerQueueFields.cs src\Modules\Templates\PetMagic.Modules.Templates.Infrastructure\Data\Migrations\20260701093000_AddAsyncGenerationProviderPipeline.cs
```

Expected result: every `CONCURRENTLY` SQL call has `suppressTransaction: true`.

Staging DB check:

```sql
SELECT "MigrationId"
FROM "__EFMigrationsHistory"
WHERE "MigrationId" IN (
  '20260630234809_AddGenerationSchedulerQueueFields',
  '20260701093000_AddAsyncGenerationProviderPipeline'
)
ORDER BY "MigrationId";
```

Both migration IDs must be present before smoke.

## Secrets To Fill Manually

Do not commit or paste these values:

- `ConnectionStrings__DefaultConnection` / `STAGING_DATABASE_URL`.
- `FAL_AI_API_KEY`.
- `FAL_WEBHOOK_URL` after replacing the host with the real public staging API URL.
- `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_URL`.
- `BACKEND_PUBLIC_BASE_URL`.
- `JWT_SIGNING_KEY`.
- `DATA_PROTECTION_CERTIFICATE_PASSWORD`.
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

- fal.ai dashboard does not show concurrency `10` or the selected profile is changed without updating
  API env, Worker env, and worker replica count together.
- Staging API and Worker use different scheduler or provider guardrail values.
- `FAL_WEBHOOK_URL` is not the public HTTPS staging API callback URL.
- Provider balance cannot be read, is at or below critical threshold, or fal.ai credits are not
  topped up for launch traffic.
- DB connection headroom is not proven for the selected worker loop count.
- Required migrations are missing, or any external migration wrapper forces `CONCURRENTLY` indexes
  inside a transaction.
- Prometheus queries for scheduler and fal provider metrics do not return live data.
- Required generation metric names are missing from Prometheus, or generation alert rules are not
  loaded.
- Staging smoke fails, lacks webhook delivery evidence, or produces duplicate refunds / stuck charged
  jobs.
- Production env has not been filled explicitly in the production secret/env store.
