# Observability

PetMagic exports OpenTelemetry metrics from:

- `PetMagic.Host.Api`
- `PetMagic.Modules.Economy`
- `PetMagic.Modules.Templates`

## Required Metrics

API SLI:

- `request_duration_seconds` histogram, labelled by `method`, `route`, and `status_code`.
- `request_errors_total` counter, labelled by `method`, `route`, `status_code`, and `error_kind`.
- `api_response_time_p95` Prometheus recording rule in `deploy/monitoring/prometheus/petmagic-alerts.yml`.

Template generation:

- `generation_jobs_queued` current queued job delta.
- `generation_jobs_processing` current processing job delta.
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
- `generation_jobs_cancelled_total` queued cancellation counter.
- `generation_jobs_refunded_total` generation refund counter.
- `generation_duplicate_refund_attempts_total` duplicate generation refund attempt counter.
- `generation_fal_timeouts_total` FAL timeout counter by media type, stage, and model.
- `generation_scheduler_claim_attempts_total` scheduler claim attempts by media type and result.
- `generation_scheduler_no_slot_skips_total` scheduler loops skipped because no slot was available.
- `generation_scheduler_borrowed_video_starts_total` video jobs started on borrowed image/global capacity.
- `generation_scheduler_video_borrow_denied_total` video borrow attempts denied by guardrail reason.
- `generation_scheduler_borrowing_cap_violations_total` detected elastic borrowing cap violations.
- `generation_scheduler_active_image_native_slots` active image jobs observed during scheduling.
- `generation_scheduler_active_video_native_slots` active video jobs within reserved video capacity.
- `generation_scheduler_active_video_borrowed_slots` active video jobs estimated to use borrowed capacity.
- `generation_scheduler_image_protected_capacity_available` protected image capacity still available.

Economy:

- `stripe_webhook_failures_total` webhook failure counter.

## Alerts

Prometheus rules live in `deploy/monitoring/prometheus/petmagic-alerts.yml` and cover:

- API p95 latency above threshold.
- API error rate above threshold.
- generation queue backlog.
- scheduler queue depth and oldest queued job age.
- pre-charge admission rejections and FAL timeouts.
- queued jobs with no processing lifecycle events.
- generation failures and retry exhaustion.
- AI provider error rate.
- Stripe webhook failures.

The backend CI validates these rules with `promtool check rules`.

## Correlation IDs

The API accepts inbound `X-Correlation-ID`, stores it on `HttpContext`, includes it in structured Serilog request logs, and propagates it on outbound `HttpClient` calls through `CorrelationIdDelegatingHandler`. Generation jobs persist the current correlation id so worker logs and lifecycle events can be tied back to the originating API request.

## External Providers

Provider calls must use named or typed `HttpClient` registrations with explicit timeouts. Stripe, App Store/Google Play verification, FCM push, FAL queue, generated media import, and localization calls are bounded so unstable networks fail predictably instead of pinning API requests or workers indefinitely.
