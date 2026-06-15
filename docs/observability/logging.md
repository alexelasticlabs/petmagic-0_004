# PetMagic Logging

## Log Levels

- `Information`: important business events only, such as login, registration, generation job claimed/started/completed, result uploaded, payment webhook processed, subscription activation/cancellation.
- `Warning`: the system continued after a recoverable condition, such as retry, rate limit, invalid login, duplicate webhook, reached limit, stale generation job recovery.
- `Error`: an operation failed. Include the exception object when there is one. Examples: generation failed, provider failed, payment failed, upload failed, database failure.
- `Critical`: the app cannot operate, such as missing required production config or database unavailable on startup.
- `Debug` and `Trace`: local development only. Production and staging keep these disabled.

## Structured Logging

Use structured message templates and named properties:

```csharp
logger.LogError(exception, "Template generation job failed. GenerationId={GenerationId}", generationId);
```

Do not use string interpolation or concatenate values into log messages. Put values into properties so logs can be queried reliably.

## Required Context

HTTP request completion logs should carry:

- `ApplicationName`
- `Environment`
- `TraceId`
- `CorrelationId`
- `RequestId`
- `UserId`
- `Role`
- `Endpoint`
- `HttpMethod`
- `Path`
- `StatusCode`
- `ElapsedMs`

Business logs written while an endpoint is executing inherit the ambient HTTP context: `ApplicationName`, `Environment`, `TraceId`, `CorrelationId`, `RequestId`, `UserId`, `Role`, `Endpoint`, `HttpMethod`, and `Path`. `StatusCode` and `ElapsedMs` belong to the completion log because they are only known after the endpoint returns.

Worker generation logs also include `JobId`, `GenerationId`, `Provider`, `Attempt`, and `MaxAttempts`.

## Correlation ID

The API reads `X-Correlation-ID` from incoming requests. If it is absent or invalid, the API creates one. The API always returns it in the response header and adds it to logs.

Mobile sends `X-Correlation-ID` on every request. Generation start and polling share one flow id so the path can be followed across:

```text
mobile -> API -> generation job -> worker -> AI provider -> result
```

For outbound HTTP calls, API and worker forwarding handlers copy the active correlation id to external provider requests.

## HTTP Request Logs

Request logs include method, path, status code, elapsed time, user id, and correlation id.

Excluded endpoints:

- `/health`
- `/metrics`
- `/swagger`
- `/favicon.ico`
- `OPTIONS`
- static files and managed media paths

`LoggingOptions:SlowRequestThresholdMs` controls slow request warnings. HTTP 5xx responses are logged as `Error`.

## Exceptions

Unhandled API exceptions are logged by the global exception middleware at `Error` with the exception object. The HTTP request logger still emits the structured 500 request event, but it does not attach the exception object, so one failure does not produce duplicate stack traces. Production responses do not expose stack traces. Every error response includes `correlationId` and `traceId`.

## Worker Logs

Generation worker `Information` events:

- job claimed
- job started
- result uploaded
- job completed

Generation worker `Warning` events:

- stale job recovered
- provider or upload retry conditions
- refund retry failure

Generation worker `Error` events:

- job failed
- provider failed
- upload failed
- failed after all retries

Never log provider payloads, signed URLs, API keys, prompts with raw user data, request bodies, or response bodies.

External provider calls must use bounded named or typed `HttpClient` registrations. Log safe provider stage/status context when a timeout occurs, but never include request bodies, response bodies, signed URLs, or credentials.

## Payments

Payment logs cover:

- webhook received
- webhook processed
- duplicate webhook ignored
- payment/subscription failure
- subscription activation or cancellation

Allowed context: `PaymentIntentId`, `StripeCustomerId`, `EventType`, `UserId`, `CorrelationId`.

Never log card data, full webhook payloads, client secrets, provider secrets, or raw payment request/response bodies.

## Admin Audit Log

Admin audit events are stored in PostgreSQL `audit_events`. These are product/security audit records, not technical logs.
Cross-module admin actions use `IAdminAuditLog`; Identity owns the PostgreSQL implementation and modules write through the shared contract.

Fields:

- `ActorUserId`
- `ActorRole`
- `Action`
- `TargetType`
- `TargetId`
- `OldValue`
- `NewValue`
- `IpAddress`
- `UserAgent`
- `CorrelationId`
- `CreatedAtUtc`

Use the audit table for admin actions such as role changes, block/unblock, generation status changes, refunds, content approval/rejection, and content deletion.

Implemented admin audit actions include user role changes, block/unblock, wallet adjustments, user deletion, template approval/rejection/status changes, template deletion, and admin subscription cancellation.

## Sensitive Data

Never log:

- passwords
- access or refresh tokens
- API keys
- Stripe/FAL/R2 secrets
- full payloads
- raw user data
- Authorization headers
- signed URLs

Mask values:

- email: `e***@gmail.com`
- Authorization: `Bearer ***`
- signed URLs: remove or replace the query string

## Searching Incidents

1. Copy the `correlationId` from the mobile error, API response, or support ticket.
2. Search API logs by `CorrelationId`.
3. Follow worker logs with the same `CorrelationId` and `GenerationId`.
4. For payments, filter by `CorrelationId`, then `EventType`, `PaymentIntentId`, or `StripeCustomerId`.
5. For admin changes, query `audit_events` by `CorrelationId`, `ActorUserId`, `TargetId`, or `CreatedAtUtc`.

## Local Debug

Environment levels:

| Environment | App logs | Microsoft/System |
| --- | --- | --- |
| Development | Debug | Warning |
| Staging | Information | Warning |
| Production | Information | Warning |

Development sets app logs to `Debug` and Microsoft/System logs to `Warning`. To enable more local logging, edit `src/Host/PetMagic.Host.Api/appsettings.Development.json`, `src/Host/PetMagic.Host.GenerationWorker/appsettings.Development.json`, or use environment variables such as:

```bash
Serilog__MinimumLevel__Default=Debug
LoggingOptions__SlowRequestThresholdMs=250
```

Do not enable `Debug` or `Trace` in production.
