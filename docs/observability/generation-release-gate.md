# Generation Observability Release Gate

This gate is required before production generation rollout. Passing tests is not enough: staging must
prove that runtime metrics, dashboards, alerts, API/Worker fingerprints, billing invariants, provider
health, and media import signals are live.

## Dashboards

Create or verify these dashboard panels before production:

1. Provider
   - `fal_provider_balance_usd`, `fal_provider_balance_low`, `fal_provider_balance_critical`.
   - `fal_provider_configured_concurrency` and `fal_provider_inflight_requests`.
   - `fal_provider_rejected_due_to_capacity`, `fal_provider_submit_failures`,
     `fal_provider_rate_limit_errors`.
   - `histogram_quantile(0.95|0.99, rate(fal_provider_queue_wait_seconds_bucket[10m]))`.
   - `generation_webhook_delivery_failures_total` and `generation_webhook_signature_failures_total`.

2. Queue and scheduler
   - `histogram_quantile(0.95, rate(generation_queue_depth_bucket[5m]))` by `media_type`, `tier`,
     and `lane`.
   - `histogram_quantile(0.95, rate(generation_oldest_queued_job_age_seconds_bucket[5m]))`.
   - `generation_active_jobs_bucket` by `media_type`, `tier`, and `lane`.
   - `generation_scheduler_active_image_native_slots`,
     `generation_scheduler_active_video_native_slots`, and
     `generation_scheduler_active_video_borrowed_slots`.
   - `generation_scheduler_video_borrow_denied_total` and
     `generation_scheduler_borrowing_cap_violations_total`.
   - `generation_jobs_accepted_total` and `generation_jobs_rejected_total` by `media_type`, `tier`,
     and `reason`.

3. Billing
   - `generation_jobs_queued_without_charge_total`.
   - `generation_jobs_refunded_total`, `generation_cancel_refunds_total`,
     `generation_duplicate_refund_attempts_total`, and `generation_refund_failures_total`.

4. Jobs
   - `generation_stuck_stage_age_seconds_bucket` for `ProviderQueued`, `ProviderProcessing`, and
     `ImportingMedia`.
   - `generation_jobs_failed_total`, `generation_retry_attempts_total`,
     `generation_jobs_exhausted_total`, and `ai_provider_errors_total`.

5. Media
   - `generation_media_import_failures_total`.
   - `generation_preview_404_total`.
   - `generation_r2_upload_failures_total`.

## Staging Smoke Gate

Run:

```powershell
node scripts/qa/run-staging-generation-scheduler-smoke.mjs
```

Required inputs:

- `STAGING_PROMETHEUS_BASE_URL` must point to the Prometheus API used by the staging dashboards.
- `STAGING_API_PROCESS_ID` and `STAGING_WORKER_PROCESS_ID` must identify the deployed API and Worker
  processes/containers.
- API and Worker scheduler fingerprints must match in
  `templates_runtime_config_fingerprints`. The public `/health` response remains part of the gate,
  but detailed scheduler diagnostics are exposed only to authenticated admin requests.

The smoke runner blocks staging rollout when:

- Prometheus is not configured or unreachable in staging mode.
- Required generation metric names are missing from Prometheus.
- Core PromQL queries fail.
- API and Worker scheduler fingerprints do not match.
- `GENERATION_WAIT_TOO_LONG` is not observed when overload is intentionally produced.
- Cancel refund evidence is missing or duplicated.
- Webhook/SSE/provider pipeline evidence is missing.

The default metric-name gate is production-blocking. It can be overridden only for incident debugging
with `STAGING_REQUIRED_GENERATION_METRICS`. Do not use that override as production evidence.

## Production Blockers

Production rollout is blocked if any of these are true:

- Prometheus does not contain the required generation metric names after staging smoke.
- The `petmagic-generation` alert group is not loaded by Prometheus.
- Any critical generation alert is firing in staging after the smoke run, except an alert intentionally
  triggered and acknowledged as part of a failure probe.
- API and Worker scheduler fingerprints differ.
- fal.ai balance is critical or balance cannot be observed.
- Generated media import or R2 upload alerts fire.
- Billing invariant alerts fire: queued without charge, duplicate refund attempt, or refund failure.

## Alert Runbook

`PetMagicFalProviderBalanceLow`
- Top up fal.ai credits before launch traffic increases. Confirm `fal_provider_balance_usd` rises and
  low gauge returns to `0`.

`PetMagicFalProviderBalanceCritical`
- Stop rollout and keep generation admission rejecting before charge. Top up fal.ai credits, then
  confirm critical gauge returns to `0`.

`PetMagicFalProviderCapacityRejected`
- Check `fal_provider_configured_concurrency`, `fal_provider_inflight_requests`, balance gauges, and
  API admission settings. Confirm users were rejected before charge.

`PetMagicFalProviderInflightNearLimit`
- Check worker replica count, `FAL_PROVIDER_CONCURRENCY_LIMIT`, reserved concurrency, and queue wait.
  Reduce admission or raise provider capacity before scaling traffic.

`PetMagicFalProviderSubmitFailures`
- Inspect tags `stage`, `model`, and `status_code`. Check fal.ai dashboard, API key, queue endpoint,
  and model availability.

`PetMagicFalProviderQueueWaitHigh`
- Check fal.ai provider queue status, account concurrency, balance, and recent rate-limit errors.
  Tighten max-wait thresholds if user wait time is rising.

`PetMagicFalProviderRateLimitErrors`
- Compare configured concurrency with fal.ai dashboard. Lower worker concurrency or request a provider
  limit increase.

`PetMagicFalWebhookDeliveryFailures`
- Check public webhook URL routing, gateway logs, callback HTTP status, payload shape, and request-id
  mismatch.

`PetMagicFalWebhookSignatureFailures`
- Check JWKS fetch reachability, API clock skew, signed headers, and whether non-fal traffic is hitting
  the endpoint.

`PetMagicGenerationQueueBacklog` / `PetMagicGenerationSchedulerQueueDepthHigh`
- Compare queue depth by lane, active image/video slots, worker count, provider in-flight requests, and
  admission thresholds. Do not increase admission until provider capacity is proven.

`PetMagicGenerationOldestQueuedAgeHigh`
- Find oldest queued rows by lane. Check whether the worker is claiming jobs and whether max-wait
  thresholds are too permissive.

`PetMagicGenerationWaitTooLongHigh`
- Confirm `GENERATION_WAIT_TOO_LONG` is pre-charge. Check lane-specific depth, max-wait thresholds, and
  provider balance/capacity.

`PetMagicGenerationWorkerNotProcessing`
- Check generation-worker process health, DB locks, scheduler fingerprint mismatch, and worker logs.
  Roll back or restart workers only after preserving logs.

`PetMagicGenerationVideoBorrowDeniedByImageBacklog`
- Check image queue depth and protected image capacity. Tighten video admission or increase capacity
  only if image SLA remains healthy.

`PetMagicGenerationBorrowingCapViolation`
- Stop rollout. Compare API/Worker scheduler fingerprints and env values. Treat mismatch as fatal until
  corrected.

`PetMagicGenerationStuckProviderQueued`
- Check fal.ai request ids, provider queue status URLs, polling intervals, and webhook delivery.

`PetMagicGenerationStuckProviderProcessing`
- Check provider job status, polling timeout settings, and whether provider completed without webhook.

`PetMagicGenerationStuckImportingMedia`
- Check provider result URL expiry, generated media import logs, R2 upload failures, and storage policy.

`PetMagicGenerationFailuresHigh`
- Break down by `failure_code`, `media_type`, `tier`, and model. Check provider errors, media import, and
  billing/refund state before retrying traffic.

`PetMagicGenerationRetryRateHigh`
- Inspect retry reasons and recent worker logs. If retries correlate with provider failures, reduce
  admission before adding worker replicas.

`PetMagicGenerationRetriesExhausted`
- Treat as release blocker. Inspect the exact generation rows and refund status. Do not delete failed
  rows before evidence is captured.

`PetMagicGenerationQueuedWithoutCharge`
- Treat as critical billing invariant breach. Stop rollout, inspect API start-generation logs, and
  verify affected jobs were failed and not charged.

`PetMagicGenerationRefundFailures`
- Check wallet ledger writes, billing service health, and `RefundLastErrorCode`. Retry only through the
  worker path so idempotency is preserved.

`PetMagicGenerationDuplicateRefundAttempt`
- Stop rollout and inspect refund idempotency/concurrency. Verify no wallet double-credit occurred.

`PetMagicAiProviderErrorsHigh`
- Check provider status, model config, rate limits, and request payload validation.

`PetMagicGenerationMediaImportFailures`
- Check provider result URL expiry, HTTP status/content type, size limits, and R2 upload path.

`PetMagicTemplatePreview404`
- Remove the template from production-visible feed or fix preview/reference media. Confirm
  `templates_content` health returns healthy.

`PetMagicR2UploadFailures`
- Check R2 credentials, endpoint, bucket name, object key prefix, and bucket policy. Do not retry user
  traffic until uploads succeed.
