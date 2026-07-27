# Observability

PetMagic exports OpenTelemetry metrics from:

- `PetMagic.Host.Api`
- `PetMagic.Modules.Economy`
- `PetMagic.Modules.Templates`

## Local Monitoring Stack

The default Docker Compose startup runs the core application services only. Prometheus, Alertmanager,
Grafana, Tempo, and the OpenTelemetry collector are opt-in so local API/admin startup is not coupled to
observability bind mounts or webhook credentials.

Start the monitoring stack with the `monitoring` profile. The profile builds small local images with
the checked-in monitoring config baked in, so runtime containers do not need host-file bind mounts.

```bash
docker compose --profile monitoring up -d --build
```

Required local variables for that profile include `GRAFANA_ADMIN_PASSWORD`,
`ALERTMANAGER_WEBHOOK_URL`, and `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`.
Keep `OTEL_EXPORTER_OTLP_ENDPOINT` empty when running only the core compose stack so the API and
generation worker do not try to export telemetry to a collector that is not running.

## Required Metrics

API SLI:

- `request_duration_seconds` histogram, labelled by `method`, `route`, and `status_code`.
- `request_errors_total` counter, labelled by `method`, `route`, `status_code`, and `error_kind`.
- `api_response_time_p95` Prometheus recording rule in `deploy/monitoring/prometheus/petmagic-alerts.yml`.
- `/api/templates/feed` release checks use `request_duration_seconds_bucket` filtered by the deployed
  feed route label to compare p95/p99 before and after public sort/cursor changes.

Template generation:

- `generation_jobs_queued` current queued job delta.
- `generation_jobs_processing` current processing job delta.
- `generation_jobs_accepted_total` post-charge accepted generation counter.
- `generation_jobs_failed_total` terminal failure counter.
- `generation_jobs_exhausted_total` retry-exhaustion counter.
- `generation_lifecycle_events_total` start/stage/end/fail counter.
- `generation_duration_seconds` terminal duration histogram.
- `ai_provider_errors_total` provider failure counter.
- `generation_queue_depth` scheduler-observed queue depth histogram.
- `generation_active_jobs` scheduler-observed active jobs by media/tier lane.
- `generation_oldest_queued_job_age_seconds` oldest queued job age histogram.
- `generation_oldest_processing_job_age_seconds` oldest processing job age histogram.
- `generation_queue_wait_seconds` queue wait duration histogram.
- `generation_eta_accuracy_error_seconds` queued ETA accuracy histogram.
- `generation_jobs_rejected_total` pre-charge admission rejection counter.
- `generation_jobs_cancelled_total` confirmed local or provider cancellation counter.
- `generation_jobs_queued_without_charge_total` billing invariant counter for queued jobs found
  without charge.
- `generation_jobs_refunded_total` generation refund counter.
- `generation_duplicate_refund_attempts_total` duplicate generation refund attempt counter.
- `generation_refund_failures_total` generation refund failure counter.
- `generation_cancel_refunds_total` generation refunds caused by confirmed cancellation.
- `generation_fal_timeouts_total` FAL timeout counter by media type, stage, and model.
- `generation_sse_delivery_failures_total` realtime delivery, persistence, or polling failure counter.
- `generation_webhook_delivery_failures_total` provider webhook delivery or payload failures.
- `generation_webhook_signature_failures_total` provider webhook signature failures.
- `generation_scheduler_claim_attempts_total` scheduler claim attempts by media type and result.
- `generation_scheduler_no_slot_skips_total` scheduler loops skipped because no slot was available.
- `generation_scheduler_borrowed_video_starts_total` video jobs started on borrowed image/global capacity.
- `generation_scheduler_video_borrow_denied_total` video borrow attempts denied by guardrail reason.
- `generation_scheduler_borrowing_cap_violations_total` detected elastic borrowing cap violations.
- `generation_scheduler_active_image_native_slots` active image jobs observed during scheduling.
- `generation_scheduler_active_video_native_slots` active video jobs within reserved video capacity.
- `generation_scheduler_active_video_borrowed_slots` active video jobs estimated to use borrowed capacity.
- `generation_scheduler_image_protected_capacity_available` protected image capacity still available.
- `generation_stuck_stage_age_seconds` provider/import stage age histogram tagged by `stage`.
- Prometheus release gates use histogram bucket families:
  `generation_queue_depth_bucket`, `generation_active_jobs_bucket`,
  `generation_oldest_queued_job_age_seconds_bucket`, `generation_stuck_stage_age_seconds_bucket`,
  and `fal_provider_queue_wait_seconds_bucket`.
- `generation_retry_attempts_total` retry attempt counter by reason.
- `generation_media_import_failures_total` generated media import failure counter.
- `generation_preview_404_total` template preview/reference 404 counter from content health probes.
- `generation_r2_upload_failures_total` R2 upload failure counter.
- `sse_full_invalidation_count` full feed invalidation counter used to prove ordinary admin template
  operations stay scoped.
- `fal_provider_configured_concurrency`, `fal_provider_inflight_requests`, `fal_provider_balance_low`,
  `fal_provider_balance_critical`, and `fal_provider_balance_usd` provider capacity/balance gauges.
- `fal_provider_rejected_due_to_capacity`, `fal_provider_submit_failures`,
  `fal_provider_rate_limit_errors`, and `fal_provider_queue_wait_seconds_bucket` provider guardrail
  and wait metrics.

Economy:

- `stripe_webhook_failures_total` webhook failure counter.

## Alerts

Prometheus rules live in `deploy/monitoring/prometheus/petmagic-alerts.yml` and cover:

- API p95 latency above threshold.
- API error rate above threshold.
- generation queue backlog.
- scheduler queue depth and oldest queued job age.
- pre-charge admission rejections, wait-too-long rejections, and FAL timeouts.
- fal.ai balance, configured concurrency, in-flight saturation, capacity rejections, submit failures,
  rate limits, and provider queue wait.
- fal.ai webhook delivery failures and signature failures.
- queued-without-charge, refund failures, duplicate refund attempts, and cancel refunds.
- active image/video lane capacity, borrowed video, denied borrowing due to image backlog, and
  borrowing cap violations.
- stuck `ProviderQueued`, `ProviderProcessing`, and `ImportingMedia` stages.
- queued jobs with no processing lifecycle events.
- generation failures, retry count, and retry exhaustion.
- AI provider error rate.
- generated media import failures, template preview 404s, and R2 upload failures.
- Stripe webhook failures.

The backend CI validates these rules with `promtool check rules`.

Generation release-gate dashboards, staging smoke checks, and alert response steps are documented in
`docs/observability/generation-release-gate.md`.

Template feed staging checks for TZ1-8 are documented in `docs/templates-feed-tz1-8-staging-qa.md`.
Use `scripts/qa/run-template-feed-staging-snapshot.mjs` to capture Prometheus p95/p99 feed latency and
`sse_full_invalidation_count` before/after admin operations. The runner supports local Prometheus auth
through `STAGING_PROMETHEUS_BEARER_TOKEN` or `TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON` and treats
latency runs without both `TEMPLATE_FEED_BEFORE_AT_UTC` and `TEMPLATE_FEED_AFTER_AT_UTC` as route
discovery only, not Task 4 acceptance evidence. SSE runs likewise require a positive
`TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS` admin action window unless explicitly marked as metric discovery
with `TEMPLATE_FEED_ALLOW_ZERO_WAIT_SSE=true`. Run
`node scripts/qa/test-template-feed-staging-snapshot.mjs` locally before staging collection to verify
the runner's strict acceptance checks against a mock Prometheus server. After staging collection and
Admin QA, run `node scripts/qa/test-template-feed-tz1-8-evidence-validator.mjs` and then
`node scripts/qa/validate-template-feed-tz1-8-evidence.mjs`; the validator is expected to fail until
weak-device long-scroll, feed latency, SSE admin-window, and manual Admin QA artifacts are present. On Windows, use
`powershell -ExecutionPolicy Bypass -File scripts/qa/run-template-feed-tz1-8-release-gate.ps1` to run
the preflight, staging snapshots, and final validator in one operator flow.

## Correlation IDs

The API accepts inbound `X-Correlation-ID`, stores it on `HttpContext`, includes it in structured Serilog request logs, and propagates it on outbound `HttpClient` calls through `CorrelationIdDelegatingHandler`. Generation jobs persist the current correlation id so worker logs and lifecycle events can be tied back to the originating API request.

## External Providers

Provider calls must use named or typed `HttpClient` registrations with explicit timeouts. Stripe, App Store/Google Play verification, FCM push, FAL queue, generated media import, and localization calls are bounded so unstable networks fail predictably instead of pinning API requests or workers indefinitely.
