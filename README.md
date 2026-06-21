# PetMagic

PetMagic is a modular ASP.NET Core backend with a Next.js admin panel and a Flutter mobile client. PostgreSQL is the source of truth for application data and template generation jobs.

## Services

| Service | Port | Role |
| --- | --- | --- |
| `postgres` | `5432` | PostgreSQL 16 data store |
| `mailpit` | `8025` web UI, `1025` SMTP | Local email inbox for confirmation and password reset codes |
| `backend` | `5001` on host, `5000` in Docker network | REST API, auth, economy, template queue API |
| `generation-worker` | none | Claims and processes queued template generation jobs |
| `admin-web` | `3000` | Admin UI |

The backend API does not run template generation work in Docker Compose. It enqueues rows in `templates_generation_jobs` with `Templates__GenerationWorkerEnabled=false`. The `generation-worker` service runs the processing loops with `Templates__GenerationWorkerEnabled=true`.

## Local Startup

```bash
cp .env.example .env
# Fill JWT_SIGNING_KEY before starting Compose.
docker compose up --build
```

Scale generation workers locally:

```bash
docker compose up --build --scale generation-worker=3
```

Expected local endpoints:

- Backend health: `http://localhost:5001/health`
- Admin web: `http://localhost:3000`
- Local email inbox: `http://localhost:8025`
- PostgreSQL: `localhost:5432`

If you change `BACKEND_HOST_PORT`, update frontend and mobile API base URLs accordingly.

## Configuration

Use `.env.example` as a template only. Real credentials must stay in local `.env`, CI/CD secrets, platform environment variables, or a managed secret store. `.env` is ignored by Git.

Important variables:

```env
POSTGRES_PASSWORD=replace_with_local_or_secret_value
JWT_SIGNING_KEY=replace_with_64_byte_random_value
BACKEND_HOST_PORT=5001
ADMIN_WEB_HOST_PORT=3000
MAILPIT_WEB_HOST_PORT=8025
EMAIL_HOST=mailpit
EMAIL_PORT=1025
EMAIL_USE_SSL=false

GENERATION_WORKER_MAX_CONCURRENT_JOBS=1
GENERATION_GLOBAL_MAX_CONCURRENT=3
GENERATION_PROVIDER_MAX_RPM=60
GENERATION_QUEUE_MAX_SIZE=1000

STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
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

Production startup validates unsafe defaults. Non-development environments require a non-placeholder JWT signing key, configured CORS origins, production payment/provider secrets, production-safe template providers, and no `BootstrapAdmin:Password`.

## Development

```bash
dotnet restore PetMagic.slnx
dotnet build PetMagic.slnx
dotnet test PetMagic.slnx
```

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
flutter run --dart-define=API_BASE_URL=http://localhost:5001
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
k6 run -e BASE_URL=http://localhost:5001 \
  -e MODE=admin-test \
  -e TEMPLATE_ID=<template-id> \
  -e PROFILE=generation \
  scripts/k6/template-generation-load-test.js
```

See `docs/LOAD_TESTING.md` for profiles, environment variables, and baseline capture notes.

## Observability

OpenTelemetry metrics and Prometheus alert rules cover API latency/error SLIs, Stripe webhook failures, template generation queue health, lifecycle stages, retry exhaustion, and AI provider errors.

See `docs/OBSERVABILITY.md` and `deploy/monitoring/prometheus/petmagic-alerts.yml`.

## Security

- CI runs Gitleaks on repository history through `.github/workflows/backend-security.yml`.
- Real Stripe, FAL, R2, JWT, SMTP, Google, Apple, Firebase, and database credentials must not be committed.
- If a credential is committed, rotate or revoke it, remove it from history, and rerun the secret scan.
- Production problem responses hide exception details and include correlation identifiers.

See `docs/SECURITY.md` for the security policy and dependency audit notes.

## Useful Commands

```bash
docker compose --env-file /dev/null config
docker compose ps
docker compose logs backend
docker compose logs generation-worker
dotnet test PetMagic.slnx --no-restore
```

## Backups

Use `scripts/backup-postgres.ps1` to export the current PostgreSQL database to `backups/`. Avoid `docker compose down -v` unless you intentionally want to delete local data volumes.
