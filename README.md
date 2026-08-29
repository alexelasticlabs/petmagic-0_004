# PetMagic

PetMagic is a modular ASP.NET Core backend with a Next.js admin panel and a Flutter mobile client. PostgreSQL is the source of truth for application data and template generation jobs.

## Backend Architecture

The ASP.NET backend is a **modular monolith** organised around bounded contexts and Clean Architecture principles. It is not a set of independently deployed microservices: `PetMagic.Host.Api` and `PetMagic.Host.GenerationWorker` compose the same modules against one PostgreSQL installation.

| Module | Responsibility |
| ------ | -------------- |
| `Identity` | Accounts, authentication, sessions, legal acceptance, and user administration |
| `Templates` | Template catalogue, pets, generated media, and generation lifecycle |
| `Economy` | Wallet, Premium, purchases, subscriptions, and payment-provider webhooks |
| `SupportChat` | User support conversations, attachments, and support notifications |
| `Gamification` | Achievements, streaks, challenges, and progression |

Each module is divided into the following projects:

```text
Domain          business rules and domain types; no module dependencies
Application     use-case contracts, DTOs, validation, and abstractions
Infrastructure  EF Core, migrations, provider clients, persistence, and implementations
Api             HTTP endpoints and request/response binding
```

`PetMagic.BuildingBlocks` contains shared technical contracts and cross-cutting primitives. `PetMagic.Host.Api` is the HTTP composition root: it wires module implementations into DI and maps their endpoints. `PetMagic.Host.GenerationWorker` is a separate process that composes only the infrastructure required to process background generation work; it does not expose HTTP endpoints.

### Dependency Rules

- `Domain` must not depend on another module or infrastructure technology.
- `Application` may depend only on its own `Domain` and `PetMagic.BuildingBlocks`.
- `Infrastructure` may implement its own application abstractions and may consume another module only through that module's `Application` contracts; it must not reference another module's `Infrastructure`, `DbContext`, entities, or tables.
- `Api` must keep HTTP concerns at the edge and use application contracts rather than persistence types.
- Each module owns its `DbContext` and EF Core migrations. Cross-module operations use explicit application contracts or durable delivery/reconciliation flows, never direct access to another module's database model.
- Only the host projects compose concrete module implementations.

When adding a feature, choose the owning module first, keep the business rule in `Domain`/`Application`, put technical implementation in `Infrastructure`, and expose it through the module's `Api` project. Do not add feature logic directly to `Program.cs`.

## Services

| Service             | Port                                                  | Role                                                        |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------- |
| `postgres`          | `5432`                                                | PostgreSQL 16 data store                                    |
| `mailpit`           | `8025` web UI, `1025` SMTP                            | Local email inbox for confirmation and password reset codes |
| `backend`           | `BACKEND_HOST_PORT` on host, `5000` in Docker network | REST API, auth, economy, template queue API                 |
| `generation-worker` | none                                                  | Claims and processes queued template generation jobs        |
| `admin-web`         | `3000`                                                | Admin UI                                                    |

The backend API does not run template generation work in Docker Compose. It enqueues rows in `templates_generation_jobs` with `Templates__GenerationWorkerEnabled=false`. The `generation-worker` service runs the processing loops with `Templates__GenerationWorkerEnabled=true`.

## Local Startup

```bash
cp .env.example .env
# Fill JWT_SIGNING_KEY before starting Compose. The copied template already
# targets the local backend and local admin URLs.
docker compose up --build
```

If those host ports are already occupied (5432, 5000/5001, 1025, 3000), use:

```powershell
pwsh scripts/docker/compose-up-portfree.ps1 -Build
```

or override manually:

```powershell
$env:POSTGRES_HOST_PORT='5433'
$env:BACKEND_HOST_PORT='5601'
$env:MAILPIT_SMTP_HOST_PORT='2525'
$env:MAILPIT_WEB_HOST_PORT='9025'
$env:ADMIN_WEB_HOST_PORT='4000'
docker compose up --build --wait --wait-timeout 240
```

This starts the core local stack: PostgreSQL, Mailpit, backend API, generation worker, and admin web.
The observability stack is available separately through the `monitoring` profile:

```bash
docker compose --profile monitoring up --build
```

When enabling the monitoring profile, set `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`
in your local `.env` so the API and generation worker export telemetry to the collector. Keep it
empty for the core stack.

## Database migrations

The `backend` service applies EF Core migrations for the existing PetMagic modules during startup
under `StartupMigrationLock`, then performs the configured seed operations. No manual migration
container is needed for the current topology.

Scale generation workers locally:

```bash
docker compose up --build --scale generation-worker=3
```

Expected local endpoints:

- Backend health: `http://localhost:<BACKEND_HOST_PORT>/health`
- Admin web: `http://localhost:3000`
- Local email inbox: `http://localhost:8025`
- PostgreSQL: `localhost:5432`

`BACKEND_HOST_PORT` defaults to `5001` in Compose. If your local `.env` overrides it to `5000`, use `http://localhost:5000`.

If you change `BACKEND_HOST_PORT`, update frontend and mobile API base URLs accordingly.
The local template sets `ADMIN_WEB_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=true`
because the Dockerized Next build intentionally targets the local HTTP backend.
Keep it `false` for staging, production, and production-like validation.

For an isolated local-smoke proof without touching the default local ports, use a
separate Compose project and an ignored `.env.local-smoke` created from the
template:

```powershell
Copy-Item .env.local-smoke.example .env.local-smoke
# Fill local-only values if the following QA probes require them.
docker compose -p petmagic_goal_probe --env-file .env.local-smoke up -d --build --wait --wait-timeout 240
curl http://localhost:5601/health
curl "http://localhost:5601/api/templates/feed?limit=3"
curl http://localhost:3600/ru
```

This proves a fresh build and startup path on isolated volumes/network. It is
local development evidence only, not staging or production rollout evidence.

## Configuration

Use `.env.example` as a template only. Real credentials must stay in local `.env`, CI/CD secrets, platform environment variables, or a managed secret store. `.env` is ignored by Git.

### Configuration source of truth

| Purpose | Canonical source | Local mutable file | Do not use it for |
| --- | --- | --- | --- |
| Default local Docker Compose | `.env.example` and `docker-compose.yml` | `.env` | staging or production deployment |
| Isolated local smoke | `.env.local-smoke.example` | `.env.local-smoke` | staging evidence or production secrets |
| Isolated payment staging on the VPS | `deploy/vps/compose.staging.vps.yaml` and `/opt/petmagic-staging/env/.env.staging` | `.env.staging.local` only for local QA inputs | production data or credentials |
| Production deploy | `deploy/vps/compose.vps.yaml`, `/opt/petmagic/shared/env/.env.vps`, and `deploy/vps/scripts/deploy-release.sh` | none required | staging or local configuration |
| Standalone admin-web | `apps/admin-web/.env.<environment>.example` | `apps/admin-web/.env.local` for development | root Compose configuration |

The staging runner template intentionally contains both QA inputs and Compose
parity values. Its comments mark those sections; it never overrides the VPS
runtime configuration.
Validate template syntax with `--env-file *.example`, but run a local scenario
with the corresponding ignored file after copying and filling it.

Important variables:

```env
POSTGRES_PASSWORD=replace_with_local_or_secret_value
JWT_SIGNING_KEY=replace_with_64_byte_random_value
BACKEND_HOST_PORT=5001
BACKEND_ALLOWED_HOSTS=api.petmagic.app
BACKEND_HEALTHCHECK_HOST=api.petmagic.app
ADMIN_WEB_HOST_PORT=3000
ADMIN_WEB_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
MAILPIT_WEB_HOST_PORT=8025
EMAIL_HOST=mailpit
EMAIL_PORT=1025
EMAIL_USE_SSL=false

GENERATION_SCHEDULER_V2_ENABLED=false
GENERATION_WORKER_POLL_INTERVAL_MS=500
GENERATION_DISPATCH_CONCURRENCY=4
GENERATION_PROVIDER_RECONCILIATION_CONCURRENCY=4
GENERATION_MEDIA_IMPORT_CONCURRENCY=1
GENERATION_MAINTENANCE_CONCURRENCY=1
GENERATION_GLOBAL_MAX_CONCURRENT=3
GENERATION_PROVIDER_MAX_RPM=60
GENERATION_QUEUE_MAX_SIZE=1000

STRIPE_TEST_SECRET_KEY=
STRIPE_TEST_WEBHOOK_SECRET=
FAL_AI_API_KEY=
R2_ACCOUNT_ID=
R2_ACCESS_KEY=
R2_SECRET_KEY=
R2_BUCKET_NAME=
R2_PUBLIC_URL=
```

Generate a local JWT signing key:

```bash
openssl rand -base64 64
```

`docker compose` requires `JWT_SIGNING_KEY` to be set explicitly; there is no shared fallback signing key in the Compose file.

Production startup validates unsafe defaults. Non-development environments require a non-placeholder JWT signing key, explicit non-wildcard `AllowedHosts`, configured CORS origins, production payment/provider secrets, production-safe template providers, and no `BootstrapAdmin:Password`.

## Development

```bash
dotnet restore PetMagic.slnx
dotnet build PetMagic.slnx
dotnet test PetMagic.slnx
```

Localization and light/dark theme rules are documented in
[docs/localization-and-theme.md](docs/localization-and-theme.md). Update that guide when supported locales,
fallback behavior, user-facing API error contracts, or shared theme token
locations change.

Run the backend without Docker after PostgreSQL is available:

```bash
dotnet run --project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj
```

The non-Docker launch profile listens on `http://localhost:5001` to avoid the
macOS AirPlay Receiver service that commonly owns port `5000`.

Run the admin web:

```bash
cd apps/admin-web
npm install
npm run dev
```

Run the mobile app:

```bash
cd apps/petmagic-mobile
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://localhost:<BACKEND_HOST_PORT>
```

Format mobile Dart code:

```bash
dart format --set-exit-if-changed apps/petmagic-mobile/lib apps/petmagic-mobile/test
```

## Template Generation Queue

Template generation requests create queued jobs and return `202 Accepted`. Active duplicate protection uses `Idempotency-Key` and deterministic request hashes. The worker claims jobs with PostgreSQL locking (`FOR UPDATE SKIP LOCKED`), writes locks through `LockedBy` and `LockedAtUtc`, retries stale jobs, and records terminal results only for the claimed job.

The queue supports:

- Per-user active generation limits.
- Global queue size limit.
- DB-backed provider request-per-minute throttle before FAL submit.
- PostgreSQL advisory locks for global worker concurrency.
- Queue position and estimated wait time in queued generation responses.

## Load Testing

The k6 script is in `scripts/k6/template-generation-load-test.js`. Runtime outputs are written under ignored `artifacts/load/`.

```bash
k6 run -e BASE_URL=http://localhost:<BACKEND_HOST_PORT> \
  -e MODE=admin-test \
  -e TEMPLATE_ID=<template-id> \
  -e PROFILE=generation \
  scripts/k6/template-generation-load-test.js
```

See [docs/load-testing.md](docs/load-testing.md) for profiles, environment variables, and baseline capture notes.

## Observability

OpenTelemetry metrics and Prometheus alert rules cover API latency/error SLIs, Stripe webhook failures, template generation queue health, lifecycle stages, retry exhaustion, and AI provider errors.

See [docs/observability.md](docs/observability.md) and `deploy/monitoring/prometheus/petmagic-alerts.yml`.

## Security

- CI runs Gitleaks on repository history through `.github/workflows/backend-security.yml`.
- Real Stripe, FAL, R2, JWT, SMTP, Google, Apple, Firebase, and database credentials must not be committed.
- If a credential is committed, rotate or revoke it, remove it from history, and rerun the secret scan.
- Production problem responses hide exception details and include correlation identifiers.

See [docs/security.md](docs/security.md) for the security policy and dependency audit notes.

## Release Readiness

Current repo-wide production-readiness status is tracked in
[docs/release-readiness.md](docs/release-readiness.md). Treat local green builds and
tests as pre-release evidence only; production release still requires real
provider-backed staging proof and signed store artifacts.

## Documentation Map

### Canonical references

- [Release readiness](docs/release-readiness.md) — current production gate and remaining evidence.
- [API contracts](docs/api-contracts.md), [security](docs/security.md), [authentication](docs/authentication-and-registration.md), [payments](docs/payments-sandbox-checklist.md), and [notifications](docs/notifications-contract.md) — cross-stack contracts and security rules.
- [VPS deployment runbook](deploy/vps/README.md) — canonical production and isolated-payment-staging procedure.
- [Observability](docs/observability.md), [logging](docs/observability/logging.md), and [generation release gate](docs/observability/generation-release-gate.md) — production monitoring and gates.

### Runbooks and validation evidence

- [Economy billing](docs/economy-generation-billing.md), [generation lifecycle](docs/generation-media-lifecycle-audit.md), [content hygiene](docs/template-content-hygiene.md), and [scheduler rollout](docs/generation-scheduler-rollout.md).
- [Admin style guide](docs/admin-style-guide.md), [mobile release size audit](docs/mobile-release-size-audit.md), and [mobile background crash playbook](docs/mobile-background-crash-playbook.md).
- [Staging FAL rollout](docs/staging-fal-rollout-checklist.md), [template-feed QA](docs/templates-feed-tz1-8-staging-qa.md), [watermark QA](docs/watermark-monetization-manual-qa.md), and [template preview profile](docs/templates-preview-content-profile.md).

### Supplementary guides

- [Hosting first-time guide](docs/hosting-first-time-guide.md) — provider-neutral purchase, access, and first-server checklist; use the VPS runbook for all current operations.
- [Auth email setup](docs/auth-email-setup.md). Repository agent workflow
  rules are kept only in `AGENTS.md`.

## Useful Commands

```bash
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.local-smoke.example config --quiet
docker compose --env-file .env.staging.local.example config --quiet
docker compose ps
docker compose logs backend
docker compose logs generation-worker
dotnet test PetMagic.slnx --no-restore
node scripts/qa/check-markdown-local-links.mjs
```

## Backups

Use `scripts/backup-postgres.ps1` to export the current PostgreSQL database to `backups/`. Avoid `docker compose down -v` unless you intentionally want to delete local data volumes.
