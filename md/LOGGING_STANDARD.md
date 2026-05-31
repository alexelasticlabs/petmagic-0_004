# Logging Standard (Backend + Mobile)

## Goals
- Logs must be readable in console and actionable for incident diagnosis.
- Every warning/error must include operation context.
- Secrets and PII must never be logged.

## Log Levels
- `Debug`: noisy technical telemetry, retries, infra handshakes, health/noise endpoints.
- `Information`: business-relevant successful operations.
- `Warning`: degraded behavior with fallback/retry, but request can still complete.
- `Error`: failed operation, unhandled exception, HTTP 5xx, broken user flow.

## Required Context Fields
- `feature`: domain/component name (`Wallet.Api`, `Network`, `Notifications`, etc.).
- `operation`: concrete operation (`create_purchase_started`, `request_failed`, etc.).
- `requestId`: request correlation id when available.
- `traceId`: distributed trace id when available.
- `context`: minimal structured payload with identifiers (`entityId`, `userId`, `provider`, `status`).

## Security Rules (Never Log)
- Access tokens, refresh tokens, passwords, API keys, secrets.
- Full payment payloads or cardholder data.
- Personal message content unless explicitly masked and approved.

## Good Examples
- `info`: `feature=Network operation=response_completed status=200 duration_ms=84`
- `warn`: `feature=Wallet.Checkout operation=stripe_verify_attempt_failed order_id=... attempt=2`
- `error`: `feature=App operation=platform_dispatcher_error requestId=... traceId=...`

## Code Review Guardrails
- New `catch` blocks must log with context (`feature`, `operation`, identifiers).
- Direct `print/debugPrint` are not allowed in app/runtime code.
- Backend request logs must preserve `RequestId/TraceId/UserId` correlation.
