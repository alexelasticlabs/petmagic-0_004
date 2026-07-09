# PetMagic deployment brief for GPT discussion

Use this document as the initial context when discussing PetMagic hosting,
deployment, costs, and production rollout with GPT or another deployment
assistant. Do not paste real secrets into the chat.

## Copy-paste prompt

```text
Ты senior full-stack/platform engineer. Помоги мне выбрать и настроить hosting/deployment для проекта PetMagic.

Отвечай по-русски, но оставляй имена сервисов, env vars, Dockerfiles, API paths и технические термины как в проекте. Не давай generic hosting advice: веди диалог по этой архитектуре, задавай уточняющие вопросы, объясняй trade-offs и помогай деплоить пошагово. Цель - production-ready, а не быстрый хак.

Проект:
- Monorepo PetMagic.
- Backend: ASP.NET Core modular backend, Dockerfile.api.
- Worker: отдельный ASP.NET/.NET GenerationWorker, Dockerfile.generation-worker.
- Admin panel: Next.js/Node app в apps/admin-web, Dockerfile внутри apps/admin-web.
- Mobile: Flutter app, потребляет backend REST API.
- Database: PostgreSQL 16, source of truth для app data и generation queue.
- Media: production/staging должны использовать Cloudflare R2, не local filesystem.
- AI generation: fal.ai через queue/worker.
- Payments: Stripe + Google Play + App Store / In-App purchase validation.
- Push: Firebase/FCM/APNs paths есть, нужны real credentials/device verification.
- Observability: OpenTelemetry, Prometheus/Grafana/Alertmanager configs уже есть в repo.

Текущая service topology:
- backend: public HTTP API, listens on container port 5000, health endpoint /health.
- generation-worker: long-lived background worker, no public ingress.
- admin-web: Next.js admin UI, listens on port 3000.
- postgres: managed PostgreSQL preferred for staging/production.
- local-only: Mailpit, local volumes, fake/local providers.

Important runtime flags:
- API host must run with Templates__GenerationWorkerEnabled=false.
- GenerationWorker must run with Templates__GenerationWorkerEnabled=true.
- API may enable Templates__TemplateOfTheDayAutoPickWorkerEnabled=true.
- Worker should keep Templates__MediaCleanupWorkerEnabled=false and Templates__TemplateOfTheDayAutoPickWorkerEnabled=false unless we explicitly change the design.
- Staging profile expects TEMPLATES_STORAGE_PROVIDER=R2 and TEMPLATES_AI_PROVIDER=Fal.
- For fal.ai rollout, repo has a FalConcurrency10 staging profile: GENERATION_GLOBAL_MAX_CONCURRENT=8, FAL_PROVIDER_CONCURRENCY_LIMIT=10, FAL_PROVIDER_RESERVED_CONCURRENCY=2, GENERATION_WORKER_REPLICAS=4, GENERATION_WORKER_MAX_CONCURRENT_JOBS=2.

What I want:
1. Compare Render, VPS, Railway, Azure Container Apps, and any better practical alternative for this exact architecture.
2. Tell me what services I need to create and what each one maps to: Web Service, Background Worker, Postgres, R2, DNS, email, monitoring.
3. Estimate monthly cost for:
   - staging/soft launch;
   - first production without HA;
   - production with HA / safer setup;
   - VPS equivalent with realistic hidden operational work.
4. Identify what I still need to buy or provision: domain/DNS, R2, email provider, Apple Developer, Google Play Console, Stripe, fal.ai credits, monitoring/Sentry, managed Postgres, secrets storage.
5. Help me build a deployment plan with:
   - env var matrix for backend, worker, admin-web;
   - safe secret handling;
   - migration strategy;
   - health checks;
   - rollback plan;
   - staging validation;
   - provider callback tests.
6. Do not suggest putting all production services on a single VPS unless you clearly list the risks and backup/restore/monitoring responsibilities.
7. Do not suggest free/sleeping tiers for production. They are acceptable only for demos.

Known costs from the last check on 2026-07-09, verify before final purchase:
- Render service compute: Starter about $7/mo, Standard about $25/mo, Pro about $85/mo.
- Render Postgres: Basic-1gb about $19/mo, Pro-4gb about $55/mo; HA requires a matching standby and roughly doubles DB instance cost.
- Render Pro workspace: about $25/mo, optional but useful for team/production features.
- Cloudflare R2: free tier covers small start; paid roughly $0.015/GB-month, Class A writes and Class B reads billed separately, no Internet egress fee.
- Resend: free tier can be enough for early transactional email; Pro around $20/mo.
- Apple Developer Program: $99/year.
- Google Play Console: $25 one-time.
- Stripe: usually no monthly fee, but transaction fees apply.
- fal.ai: usage/prepaid credits; likely the main variable cost for image/video generation.

Ask me first:
- target region and main users;
- expected MAU and daily generation volume;
- expected image/video ratio and average media size;
- whether we need HA immediately;
- whether admin-web can be private/VPN-protected at first;
- whether we already own petmagic.app and Cloudflare account;
- whether we have Apple/Google/Firebase/Stripe/fal.ai/R2 credentials;
- whether we want Render first or VPS first.
```

## Recommended starting architecture

For staging and first production, prefer a managed platform over a single VPS:

- Render Web Service: `backend`, Dockerfile `Dockerfile.api`, public domain
  `api.staging.petmagic.app` / `api.petmagic.app`, health check `/health`.
- Render Background Worker: `generation-worker`, Dockerfile
  `Dockerfile.generation-worker`, no public ingress.
- Render Web Service: `admin-web`, Dockerfile `apps/admin-web/Dockerfile`,
  public domain `admin.staging.petmagic.app` / `admin.petmagic.app`.
- Render Postgres or another managed PostgreSQL provider for app DB.
- Cloudflare R2 for template/generated media storage.
- Cloudflare DNS/TLS/WAF in front of public domains.
- Resend/SendGrid/Postmark for real SMTP/transactional email.
- Sentry plus Render logs/metrics or hosted Prometheus/Grafana for production
  error and metrics visibility.

Do not rely on Docker Compose as the production orchestrator on Render. Compose
is useful as the local map of services. In Render, create separate services
that map to the Compose roles.

## Why not one VPS first

A VPS is cheaper on the invoice but pushes operational responsibility onto us:

- OS and Docker security updates.
- Reverse proxy and TLS renewal.
- PostgreSQL backup, restore drills, PITR or snapshot policy.
- Disk growth and database maintenance.
- Monitoring, alerting, log retention.
- Zero-downtime deploy and rollback.
- Worker supervision and queue backlog alerts.
- Incident response when API, DB, worker, and admin share one host.

For PetMagic, this risk matters because the system handles payments, token
wallets, generation billing, provider webhooks, retries, refunds, media, and
push notifications.

## Expected service selection on Render

From the Render "Create a new Service" screen:

- Choose `Web Services` for `backend`.
- Choose `Background Workers` for `generation-worker`.
- Choose `Web Services` for `admin-web`.
- Choose `Postgres` for the managed database.
- Do not choose `Static Sites` for the current admin-web unless the app is
  changed to static export. Current admin uses Next.js server runtime.
- Do not choose `Key Value` initially. The project queue is PostgreSQL-backed.
- Do not choose `Workflow` initially. It is not needed for the current design.
- `Cron Jobs` may be useful later for explicit maintenance tasks, but not as
  the first deployment surface.

## Environment groups

Create separate environments for `staging` and `production`. Keep secret values
out of chat and docs.

Common backend and worker variables:

```env
ASPNETCORE_ENVIRONMENT=Staging
DOTNET_ENVIRONMENT=Staging
ConnectionStrings__DefaultConnection=<managed-postgres-connection-string>
JWT_SIGNING_KEY=<64-byte-base64-secret>
BACKEND_PUBLIC_BASE_URL=https://api.staging.petmagic.app
TEMPLATES_STORAGE_PROVIDER=R2
TEMPLATES_AI_PROVIDER=Fal
PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION=false
FAL_AI_API_KEY=<secret>
FAL_WEBHOOK_URL=https://api.staging.petmagic.app/api/templates/generations/fal/webhook
R2_ACCOUNT_ID=<secret>
R2_ACCESS_KEY=<secret>
R2_SECRET_KEY=<secret>
R2_BUCKET_NAME=<bucket>
R2_PUBLIC_URL=<https-r2-or-cdn-url>
STRIPE_TEST_SECRET_KEY=<secret>
STRIPE_TEST_WEBHOOK_SECRET=<secret>
GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL=<secret>
GOOGLE_PLAY_PRIVATE_KEY_PEM=<secret>
APP_STORE_SHARED_SECRET=<secret>
FIREBASE_PROJECT_ID=<project>
FIREBASE_SERVICE_ACCOUNT_JSON=<secret-json>
OTEL_EXPORTER_OTLP_ENDPOINT=<otel-endpoint-or-empty>
```

API-only variables:

```env
Templates__GenerationWorkerEnabled=false
Templates__TemplateOfTheDayAutoPickWorkerEnabled=true
BACKEND_ALLOWED_HOSTS=api.staging.petmagic.app
BACKEND_HEALTHCHECK_HOST=api.staging.petmagic.app
Cors__AllowedOrigins__0=https://admin.staging.petmagic.app
```

Worker-only variables:

```env
Templates__GenerationWorkerEnabled=true
Templates__MediaCleanupWorkerEnabled=false
Templates__TemplateOfTheDayAutoPickWorkerEnabled=false
GENERATION_WORKER_MAX_CONCURRENT_JOBS=2
GENERATION_PROVIDER_MAX_RPM=60
GENERATION_MAX_ATTEMPTS=3
GENERATION_JOB_LOCK_TIMEOUT_MS=900000
GENERATION_ORPHAN_QUEUED_TIMEOUT_MS=120000
GENERATION_REFUND_RETRY_DELAY_MS=30000
FAL_PROVIDER_CONCURRENCY_LIMIT=10
FAL_PROVIDER_RESERVED_CONCURRENCY=2
FAL_PROVIDER_BALANCE_LOW_THRESHOLD_USD=100
FAL_PROVIDER_BALANCE_CRITICAL_THRESHOLD_USD=25
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD=<set-a-real-daily-cap>
```

Admin-web variables:

```env
NODE_ENV=production
NEXT_PUBLIC_API_BASE_URL=https://api.staging.petmagic.app
INTERNAL_API_BASE_URL=https://api.staging.petmagic.app
ADMIN_WEB_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=false
```

Important: `NEXT_PUBLIC_API_BASE_URL` is build-time visible to the browser.
Build staging and production admin images/config separately.

## Deployment order

1. Create DNS and domains:
   - `api.staging.petmagic.app`
   - `admin.staging.petmagic.app`
   - later `api.petmagic.app`
   - later `admin.petmagic.app`
2. Create managed PostgreSQL.
3. Create R2 bucket and public/custom media URL.
4. Create staging secrets/env group.
5. Deploy `backend` only.
6. Confirm `/health`.
7. Run or confirm startup migrations and seed under migration lock.
8. Deploy `generation-worker`.
9. Deploy `admin-web`.
10. Configure provider webhook URLs:
    - Stripe webhooks to backend economy endpoints.
    - fal.ai callback/webhook to backend templates endpoint.
    - Google Play Pub/Sub / App Store server notifications if enabled.
11. Run staging smoke:
    - backend `/health`;
    - admin login;
    - template feed;
    - image generation;
    - video generation;
    - Stripe sandbox checkout/webhook;
    - Google Play/App Store sandbox purchase restore/verify;
    - push delivery on real devices;
    - R2 upload/read/signed URL behavior.

## Questions GPT should ask before touching deployment

- Which provider are we choosing for first deploy: Render, Railway, Azure
  Container Apps, VPS, or hybrid?
- What is the target region: EU, US, or mixed?
- Do we need production HA from day one?
- What is acceptable monthly budget for staging and production?
- What generation volume should we plan for in the first 30 days?
- What percentage of generations are video?
- Do we have `petmagic.app` and Cloudflare access?
- Do we already have Apple Developer, Google Play Console, Stripe, Firebase,
  fal.ai, R2, and email provider accounts?
- Should `admin-web` be public with auth, or protected behind IP/VPN/basic auth
  during staging?
- Do we need a separate staging database seeded from production-like fixtures?
- Who owns migration approval and backup confirmation before production deploy?

## Production blockers to keep visible

- Real provider/device-backed staging proof is still required:
  - fal.ai real generation and callback.
  - R2 upload/read/public or signed media URL.
  - Stripe sandbox payment and webhook idempotency.
  - Google Play and App Store sandbox validation.
  - FCM/APNs push delivery on real devices.
- Android production signing must be configured outside git.
- Secrets must live in platform secret storage, CI/CD secrets, 1Password, Vault,
  or an equivalent secret manager.
- Free/sleeping tiers are not production safe.
- A single VPS is not production HA and should be treated as a budget trade-off,
  not a stability upgrade.

## Files GPT should inspect in the repo

- `README.md`
- `docker-compose.yml`
- `.env.example`
- `.env.staging.local.example`
- `Dockerfile.api`
- `Dockerfile.generation-worker`
- `apps/admin-web/Dockerfile`
- `docs/API_CONTRACTS.md`
- `docs/OBSERVABILITY.md`
- `docs/production-readiness-audit-2026-07-03.md`
- `docs/economy-generation-billing.md`
- `docs/payments-sandbox-checklist.md`
- `docs/notifications-contract.md`
- `docs/render-staging-deployment.md`
- `render.yaml`
- `scripts/qa/run-render-predeploy-gate.mjs`
- `scripts/qa/run-render-postdeploy-smoke.mjs`
- `src/Host/PetMagic.Host.Api/Program.cs`
- `src/Host/PetMagic.Host.GenerationWorker/Program.cs`
