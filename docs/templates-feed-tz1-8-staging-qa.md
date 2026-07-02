# Templates Feed TZ1-8 Staging QA

This document is the operator protocol for the TZ1-8 follow-up items that require staging metrics or manual admin UI verification.

## Required Inputs

Use `.env.staging.local` or equivalent CI/secret storage. Do not commit real values.

```text
STAGING_PROMETHEUS_BASE_URL=
STAGING_PROMETHEUS_BEARER_TOKEN=
TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON=
TEMPLATE_FEED_ROUTE_REGEX=.*(/api/templates/feed|templates.*feed|ListFeedAsync).*
TEMPLATE_FEED_METHOD_REGEX=GET
TEMPLATE_FEED_LATENCY_RATE_WINDOW=5m
TEMPLATE_FEED_MAX_P95_REGRESSION_SECONDS=0
TEMPLATE_FEED_MAX_P99_REGRESSION_SECONDS=0
TEMPLATE_FEED_SSE_WINDOW=15m
TEMPLATE_FEED_ADMIN_ACTION_LABELS=text_update,media_update,category_rename
```

The feed route label comes from ASP.NET endpoint display names, not necessarily the raw URL path. Keep `TEMPLATE_FEED_ROUTE_REGEX` broad enough to match the deployed label. If the regex does not match, `scripts/qa/run-template-feed-staging-snapshot.mjs` writes the top `request_duration_seconds_count` route candidates into the artifact so the operator can correct the regex and rerun.

If staging Prometheus requires auth, set `STAGING_PROMETHEUS_BEARER_TOKEN` or `TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON` locally. The runner records only whether auth was configured and the custom header names; it does not write secret values to artifacts.

Before collecting real staging evidence, run the local self-test:

```powershell
node scripts/qa/test-template-feed-staging-snapshot.mjs
node scripts/qa/test-template-feed-tz1-8-evidence-validator.mjs
node scripts/qa/test-template-feed-long-scroll-promoter.mjs
node scripts/qa/test-template-feed-release-gate.mjs
powershell -ExecutionPolicy Bypass -File scripts/qa/run-template-feed-tz1-8-release-gate.ps1 -PreflightOnly
```

Expected result: the mock Prometheus latency/SSE scenarios, evidence validator fixtures, long-scroll artifact promoter fixtures, and release-gate skip-mode guard pass, while missing before/after timestamps, zero-wait SSE runs, and skip-mode without required run ids fail acceptance as intended.
The full `run-template-feed-tz1-8-release-gate.ps1 -PreflightOnly` path also runs `test-template-feed-release-gate.mjs`; the nested release-gate invocation suppresses that one self-test to avoid recursion.

After collecting staging/Admin evidence, run the release gate:

```powershell
node scripts/qa/test-template-feed-tz1-8-evidence-validator.mjs
node scripts/qa/validate-template-feed-tz1-8-evidence.mjs
```

Expected validator self-test result: positive fixture passes and missing external evidence fixture fails.
Expected pre-release result: all checks pass. Until real weak-device/mobile and staging evidence is attached, the validator should fail on missing weak-device long-scroll signoff, feed latency, SSE admin-window, and Admin manual QA report artifacts.

After a weak-device or constrained-memory emulator run, promote the raw mobile artifacts into the curated Task 2 artifact:

```powershell
node scripts/qa/promote-template-feed-long-scroll-artifact.mjs `
  --run-dir=artifacts/mobile-template-feed/tz1-8-long-scroll-500-low-memory-<date> `
  --signoff=low-memory-emulator `
  --device-label="Pixel_3a_API_35 low-memory emulator"
```

Use `--signoff=weak-device` for a physical weak device. Use `--signoff=pending` only for ordinary-device exploratory runs.

## Task 4: Feed Latency Baseline

Goal: capture p95 and p99 for `GET /api/templates/feed` before and after the PublishedAtUtc/cursor rollout.

Prometheus queries used by the runner:

```promql
histogram_quantile(
  0.95,
  sum by (le, route, method) (
    rate(request_duration_seconds_bucket{method=~"GET",route=~".*(/api/templates/feed|templates.*feed|ListFeedAsync).*"}[5m])
  )
)
```

```promql
histogram_quantile(
  0.99,
  sum by (le, route, method) (
    rate(request_duration_seconds_bucket{method=~"GET",route=~".*(/api/templates/feed|templates.*feed|ListFeedAsync).*"}[5m])
  )
)
```

Run after both timestamps are known:

```powershell
$env:TEMPLATE_FEED_BEFORE_AT_UTC = "2026-07-02T10:00:00Z"
$env:TEMPLATE_FEED_AFTER_AT_UTC = "2026-07-02T11:00:00Z"
node scripts/qa/run-template-feed-staging-snapshot.mjs --mode=latency
```

The runner intentionally fails `latency.before_after_times_configured` when either timestamp is missing. For route-label discovery only, set `TEMPLATE_FEED_ALLOW_CURRENT_LATENCY_ONLY=true`; do not use that current-only run as the Task 4 acceptance artifact.

The runner also fails `latency.no_material_regression` when the after p95 or p99 is greater than the baseline plus the configured budget. The default budgets are strict (`0` seconds). If staging has an explicit latency tolerance, set `TEMPLATE_FEED_MAX_P95_REGRESSION_SECONDS` and `TEMPLATE_FEED_MAX_P99_REGRESSION_SECONDS`; the values are written into the artifact and reviewed with the release evidence.

Acceptance record:

```text
Before PublishedAtUtc/cursor rollout:
- p95: <fill seconds>
- p99: <fill seconds>
- timestamp/window: <fill>
- artifact: artifacts/template-feed-staging-snapshots/<run>/summary.md

After PublishedAtUtc/cursor rollout:
- p95: <fill seconds>
- p99: <fill seconds>
- timestamp/window: <fill>
- artifact: artifacts/template-feed-staging-snapshots/<run>/summary.md
- route candidates if no feed sample matched: artifacts/template-feed-staging-snapshots/<run>/evidence.json

Result: PASS only if the artifact contains passing `latency.before_after_points_present` and `latency.no_material_regression` checks.
```

## Task 6: SSE Full Invalidation Snapshot

Goal: prove ordinary scoped admin operations do not increment `sse_full_invalidation_count`.

Prometheus query used by the runner:

```promql
sum(sse_full_invalidation_count)
sum(increase(sse_full_invalidation_count[15m]))
```

Run the snapshot and perform the admin actions during the wait window:

```powershell
$env:TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS = "180"
$env:TEMPLATE_FEED_ADMIN_ACTION_LABELS = "text_update,media_update,category_rename,status_update_if_available"
node scripts/qa/run-template-feed-staging-snapshot.mjs --mode=sse
```

The runner intentionally fails `sse.admin_action_window_configured` when `TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS=0`. For metric-name discovery only, set `TEMPLATE_FEED_ALLOW_ZERO_WAIT_SSE=true`; do not use that zero-wait run as the Task 6 acceptance artifact.

The final evidence gate requires the SSE artifact to include at least `text_update`, `media_update`, and `category_rename` in `actionLabels`. Keep `status_update_if_available` and `bulk_status_update_if_available` in the labels only when those controls exist in the deployed Admin surface.

During the wait window, perform on staging:

- text-only template update;
- media update;
- category rename;
- status update if the single-template status control is available;
- bulk status update only if a bulk UI/API has been introduced.

Acceptance record:

```text
sse_full_invalidation_count before total: <fill>
sse_full_invalidation_count after total: <fill>
delta: <fill>
artifact: artifacts/template-feed-staging-snapshots/<run>/summary.md

Result: PASS only if ordinary scoped operations keep delta=0 and the artifact action labels cover the required admin operations.
```

## Task 8: Admin Manual QA Guard Rails

Run on staging admin UI with an admin account.

Local source-contract coverage already guards two regressions before the manual pass:

```powershell
npm test -- --run src/components/templates/template-form-mappers.test.ts src/components/templates/templates-catalog-actions.test.ts
```

Expected local result: template editor activation still checks required media/readiness before `saveTemplateMutation.mutateAsync`, and the Admin catalog still has no bulk status UI/API path until SSE batching is implemented.

| Scenario | Steps | Expected | Result |
| --- | --- | --- | --- |
| Category rename under feed load | Start repeated `/api/templates/feed?take=20` requests while renaming a category in Admin. | Rename succeeds atomically; public feed remains usable; scoped category invalidation is emitted; no partial category/template mismatch. | Not run |
| Bulk status update | Inspect Admin templates UI/API for a bulk status action. | If absent, record N/A and keep Task 7 documentation. If present, stop release until SSE batching test exists. | Not run |
| Activate without required media | Create or edit a template, remove required thumbnail/feed preview media, then attempt to set `Status=Active` from UI. | UI/API blocks activation and surfaces a validation error; active template is not persisted without required media. | Not run |
| Archive category with public templates | Archive a category that has public templates, then check public feed/category filters. | Admin guard rails preserve documented archive semantics; public endpoints do not expose archived-category templates. | Not run |

Manual QA report template:

```text
Environment:
- Admin URL:
- API build/health:
- Operator:
- Date/time UTC:

Results:
- Category rename under feed load: PASS/FAIL, evidence:
- Bulk status update: PASS/FAIL/N/A, evidence:
- Activate without required media: PASS/FAIL, evidence:
- Archive category with public templates: PASS/FAIL, evidence:

Related metrics artifact:
- artifacts/template-feed-staging-snapshots/<run>/summary.md
```

Use `artifacts/templates-feed-tz1-8-admin-qa-report.template.md` as the report skeleton and save the completed run as `artifacts/templates-feed-tz1-8-admin-qa-report-<date>.md`.
All Environment fields in the completed report must be filled. The release validator rejects reports that only contain PASS rows without Admin URL, API build/health, operator, UTC time, an existing accepted SSE snapshot summary under `artifacts/template-feed-staging-snapshots/`, and concrete Evidence cells for every scenario.

Full release-gate run after staging metrics and Admin QA are ready:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qa/run-template-feed-tz1-8-release-gate.ps1 `
  -EnvFile .env.staging.local `
  -RunId template-feed-tz1-8-<date> `
  -AdminQaReportPath artifacts/templates-feed-tz1-8-admin-qa-report-<date>.md `
  -MobileLongScrollRunDir artifacts/mobile-template-feed/tz1-8-long-scroll-500-low-memory-<date> `
  -MobileLongScrollSignoff low-memory-emulator `
  -MobileLongScrollDeviceLabel "Pixel_3a_API_35 low-memory emulator" `
  -SseWaitSeconds 180
```

During the SSE wait window, perform the admin actions listed above. The script then runs the final evidence validator and exits non-zero unless Task 4/6/8 artifacts are present and valid.
The release gate also scopes `TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID` and `TEMPLATE_FEED_REQUIRED_SSE_RUN_ID` to the current `RunId` snapshots. When `-AdminQaReportPath` is provided, it scopes `TEMPLATE_FEED_ADMIN_QA_REPORT_PATH` to that exact report, so stale latency/SSE/Admin artifacts elsewhere under `artifacts/` cannot satisfy Task 4/6/8 by accident.
If reusing previously collected staging snapshots with `-SkipLatency` or `-SkipSse`, set `TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID` and/or `TEMPLATE_FEED_REQUIRED_SSE_RUN_ID` to the exact accepted snapshot run ids before running the gate. The script rejects skip-mode validation without those variables.
Accepted staging snapshot `evidence.json` files must include runner metadata (`runId`, `startedAtUtc`, `finishedAtUtc`, anonymized `prometheusBaseUrl`) plus measurement data (`latency.before/after`, latency deltas, `sseFullInvalidations.before/after`, and window increase) in addition to passing checks, so handcrafted check-only JSON is not accepted as release evidence.
