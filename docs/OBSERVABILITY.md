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

Economy:

- `stripe_webhook_failures_total` webhook failure counter.

## Alerts

Prometheus rules live in `deploy/monitoring/prometheus/petmagic-alerts.yml` and cover:

- API p95 latency above threshold.
- API error rate above threshold.
- generation queue backlog.
- queued jobs with no processing lifecycle events.
- generation failures and retry exhaustion.
- AI provider error rate.
- Stripe webhook failures.

The backend CI validates these rules with `promtool check rules`.

## Correlation IDs

The API accepts inbound `X-Correlation-ID`, stores it on `HttpContext`, includes it in structured Serilog request logs, and propagates it on outbound `HttpClient` calls through `CorrelationIdDelegatingHandler`. Generation jobs persist the current correlation id so worker logs and lifecycle events can be tied back to the originating API request.

## External Providers

Provider calls must use named or typed `HttpClient` registrations with explicit timeouts. Stripe, App Store/Google Play verification, FCM push, FAL queue, generated media import, and localization calls are bounded so unstable networks fail predictably instead of pinning API requests or workers indefinitely.
