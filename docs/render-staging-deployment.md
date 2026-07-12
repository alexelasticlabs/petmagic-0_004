# Render staging deployment

This guide prepares the PetMagic staging deployment on Render from the monorepo.
It does not contain secret values.

If this is your first deploy, start with
[hosting-first-time-guide.md](hosting-first-time-guide.md), then return here for
the Render-specific runbook.

## Source model

Render deploys from the existing Git repository:

```text
https://github.com/alexelasticlabs/petmagic-0_004.git
```

Do not split the repository. `render.yaml` maps the monorepo into three Render
services:

| Render service | Repo source | Runtime role |
| --- | --- | --- |
| `petmagic-staging-api` | `Dockerfile.api`, context `.` | Public backend API |
| `petmagic-staging-generation-worker` | `Dockerfile.generation-worker`, context `.` | Background generation worker |
| `petmagic-staging-admin-web` | `apps/admin-web/Dockerfile`, context `apps/admin-web` | Admin UI |

`render.yaml` also creates `petmagic-staging-db` as managed PostgreSQL and a
shared env group for non-secret staging defaults.

The services reference the database through:

```yaml
fromDatabase:
  name: petmagic-staging-db
  property: connectionString
```

Render injects the internal Postgres connection string for services in the same
private network. After staging is reachable and migrations are verified, remove
public database access in the Render Postgres access control list unless a
temporary operator IP is explicitly needed for a maintenance window.

## Before deploying

Required external accounts/resources:

- Render account connected to the GitHub repository.
- Cloudflare DNS for `petmagic.app`.
- Cloudflare R2 bucket for staging media.
- fal.ai account and API key.
- Stripe test mode credentials and webhook secret.
- Firebase project/service account for staging push checks.
- Google Play/App Store sandbox credentials if store billing is enabled in the
  staging test pass.
- SMTP provider credentials.

Required DNS names:

```text
api.staging.petmagic.app
admin.staging.petmagic.app
```

Create the custom domains in Render first, then add the DNS records Render asks
for in Cloudflare.

Local preflight before pushing Blueprint changes:

```powershell
node scripts\qa\clean-local-generated-artifacts.mjs
node scripts\qa\run-render-predeploy-gate.mjs
```

If the cleanup dry-run only lists generated/cache paths, remove them with
`node scripts\qa\clean-local-generated-artifacts.mjs --apply` and rerun the
predeploy gate.

The gate runs repository sensitive-file checks, Blueprint validation, staging
env example validation, markdown link checks, script safety inventory, Compose
config validation, and the backend API build. It writes evidence under
`artifacts/render-predeploy-gate/`.

Run the heavier Docker build smoke before the first Render deploy or after
Dockerfile changes:

```powershell
node scripts\qa\run-render-predeploy-gate.mjs --with-docker-build --docker-platform linux/amd64
```

This builds the same API, worker, and admin Dockerfiles/contexts declared in
`render.yaml`. It passes only non-secret admin build arguments such as
`NEXT_PUBLIC_API_BASE_URL`; provider credentials remain runtime secrets.

## Blueprint creation

1. Push `render.yaml` to the branch Render will deploy from.
2. In Render, choose `New > Blueprint`.
3. Connect `alexelasticlabs/petmagic-0_004`.
4. Use the default Blueprint path `render.yaml`.
5. Review the planned resources before applying.
6. Do not create a second Blueprint for the same services.

The staging Blueprint uses `autoDeployTrigger: checksPass`. Render will deploy
after GitHub Actions pass for the linked branch. If CI is not available or is
temporarily red, switch the service to manual deploy in Render rather than
lowering production-like safety in the repo.

## Secrets to fill in Render

The following keys are intentionally `sync: false` in `render.yaml`. Fill them
in the Render dashboard or a managed secret workflow:

```text
Jwt__SigningKey
FAL_PROVIDER_SPEND_DAILY_LIMIT_USD
FAL_AI_API_KEY
R2_ACCOUNT_ID
R2_ACCESS_KEY
R2_SECRET_KEY
R2_BUCKET_NAME
R2_PUBLIC_URL
ADMIN_MEDIA_ORIGINS
STRIPE_TEST_SECRET_KEY
STRIPE_TEST_PUBLISHABLE_KEY
STRIPE_TEST_WEBHOOK_SECRET
GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL
GOOGLE_PLAY_PRIVATE_KEY_PEM
GOOGLE_PLAY_PUBSUB_AUDIENCE
GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL
GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID
GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID
APP_STORE_SHARED_SECRET
APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID
APP_STORE_PREMIUM_YEARLY_PRODUCT_ID
FIREBASE_PROJECT_ID
FIREBASE_SERVICE_ACCOUNT_JSON
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_AUDIENCES
APPLE_CLIENT_ID
APPLE_CLIENT_SECRET
APPLE_AUDIENCES
EMAIL_HOST
EMAIL_PORT
EMAIL_USERNAME
EMAIL_PASSWORD
EMAIL_FROM_ADDRESS
OTEL_EXPORTER_OTLP_ENDPOINT
```

Use a generated 64+ character `Jwt__SigningKey`. Keep live production Stripe and
store credentials out of staging until staging test mode is proven.
Use [render-staging-secrets-checklist.md](render-staging-secrets-checklist.md)
as the source-by-source fill checklist.

After the first deploy, copy `.env.staging.local.example` to `.env.staging.local`
on the machine that will run smoke checks and fill only that local file. Verify
the operator inputs before running expensive staging probes:

```powershell
node scripts\qa\check-staging-env-readiness.mjs
```

The checker validates presence and shape of the staging API URL, database URL,
JWTs, Prometheus URL, process labels, and `psql` command without printing secret
values.

## Runtime paths

The API service attaches a persistent disk at:

```text
/var/petmagic
```

The API stores:

- ASP.NET DataProtection keys in `/var/petmagic/DataProtection-Keys`;
- local avatar/support/template fallback files under `/var/petmagic/wwwroot`.

`StaticFiles__ExtraWebRootPath=/var/petmagic/wwwroot` makes those managed media
paths visible through the existing backend static-file policy while keeping
DataProtection keys outside public webroot.

Template generation media should still use R2 in staging:

```text
TEMPLATES_STORAGE_PROVIDER=R2
TEMPLATES_AI_PROVIDER=Fal
```

## Deploy order

1. Provision the Blueprint.
2. Fill all required secrets before starting the services.
3. Deploy `petmagic-staging-api`.
4. Wait for `/health` to return healthy.
5. Confirm migrations/seeds completed in API logs.
6. Deploy `petmagic-staging-generation-worker`.
7. Deploy `petmagic-staging-admin-web`.
8. Configure provider callbacks to the staging API.
9. Run the read-only post-deploy smoke.
10. Run staging smoke checks.
11. Lock down public Postgres access after operator DB access is no longer
    needed.

Do not enable real production provider callbacks before staging callbacks are
verified with test/sandbox credentials.

## First smoke checks

From a local terminal:

```powershell
curl.exe https://api.staging.petmagic.app/health
curl.exe https://admin.staging.petmagic.app/ru
node scripts\qa\run-render-postdeploy-smoke.mjs
```

Then run the project staging gates when the required env file exists locally:

```powershell
node scripts\qa\run-economy-staging-infra-gate.mjs
node scripts\qa\run-staging-generation-scheduler-smoke.mjs
```

Use `.env.staging.local` only on the runner machine. Never commit it.

## Known staging limitations

- `petmagic-staging-api` uses a persistent disk. This is acceptable for first
  staging, but services with attached disks are not the right long-term shape
  for horizontal API scaling.
- Production should either keep a deliberate single API instance with this disk
  trade-off or move avatar/support storage and DataProtection keys to external
  durable storage before scaling API replicas.
- The worker is scaled to 4 instances for the FalConcurrency10 profile. Lower
  this in Render if fal.ai limits or budget are not ready.
- `admin-web` has `NEXT_PUBLIC_API_BASE_URL` baked into the build, so staging
  and production admin services must be built with separate environment values.
