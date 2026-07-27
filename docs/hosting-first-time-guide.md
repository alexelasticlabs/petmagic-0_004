# PetMagic first-time hosting guide

This guide is the practical first deploy path for PetMagic. It assumes the
first platform is Render, with GitHub as the deployment source, Cloudflare for
DNS/R2, and external provider accounts for payments, AI, push, and email.

Do not paste real secrets into GitHub, docs, issues, PRs, or assistant chats.

## What will be hosted

PetMagic is a monorepo. Do not split it into separate repositories for the first
deploy.

| Runtime | Host target | Source in repo | Public |
| --- | --- | --- | --- |
| Backend API | Render Web Service | `Dockerfile.api`, context `.` | Yes |
| Generation worker | Render Background Worker | `Dockerfile.generation-worker`, context `.` | No |
| Admin web | Render Web Service | `apps/admin-web/Dockerfile`, context `apps/admin-web` | Yes |
| PostgreSQL | Render managed Postgres | `petmagic-staging-db` in `render.yaml` | No after setup |
| Media storage | Cloudflare R2 | Runtime env vars | Public/custom R2 URL |

The Render staging topology is declared in `render.yaml`. Production uses the
separate `render.production.yaml` Blueprint and production-only secret storage;
never promote staging by copying local `.env` files.

## What you need to buy or create

### Required for staging

1. GitHub repository access
   - Already expected: `https://github.com/alexelasticlabs/petmagic-0_004.git`.
   - Render deploys from GitHub. Push to GitHub, Render pulls the repo and uses
     `render.yaml`.

2. Render account
   - Create at `https://render.com`.
   - Connect the GitHub repository.
   - Required resources for staging:
     - one Web Service for API;
     - one Background Worker for generation;
     - one Web Service for admin-web;
     - one managed PostgreSQL database;
     - one env group plus per-service secrets.

3. Domain and DNS
   - Recommended domain: `petmagic.app`.
   - DNS provider: Cloudflare.
   - Required staging DNS:
     - `api.staging.petmagic.app`;
     - `admin.staging.petmagic.app`.
   - Later production DNS:
     - `api.petmagic.app`;
     - `admin.petmagic.app`;
     - app store website/support/privacy domains as required.

4. Cloudflare R2
   - Used for generated/template media.
   - Create a staging bucket, for example `petmagic-staging-media`.
   - Create an R2 access key restricted to that bucket.
   - Configure a public/custom URL for media reads.

5. fal.ai
   - Create an account and API key.
   - Add prepaid credits.
   - Set a real daily cap through `FAL_PROVIDER_SPEND_DAILY_LIMIT_USD`.

6. Email provider
   - Recommended first option: Resend.
   - Create sender domain, verify DNS, create API/SMTP credentials.
   - Configure `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USERNAME`,
     `EMAIL_PASSWORD`, `EMAIL_FROM_ADDRESS`.

7. Stripe test mode
   - Create Stripe account.
   - Use test mode for staging.
   - Create webhook endpoint for staging API.
   - Configure test secret key, publishable key, and webhook secret.

8. Firebase
   - Create staging Firebase project.
   - Create service account JSON for backend push sending.
   - Configure Android/iOS app client configs for real devices.
   - Do not commit real `google-services.json` or
     `GoogleService-Info.plist` replacements without a separate review.

### Required before public mobile release

1. Apple Developer Program
   - Required for TestFlight/App Store distribution and Apple platform
     production capabilities.
   - Needed for iOS app distribution and App Store purchase validation.

2. Google Play Console
   - Required for Android production distribution and Play Billing.
   - Needed for Play Developer API/service account setup.

3. Production signing
   - Android release keystore and `android/key.properties`.
   - iOS signing certificates/profiles through Apple Developer.
   - Keep signing files outside Git.

### Recommended before production

1. Sentry or equivalent error monitoring.
2. Hosted logs/metrics/alerts.
3. Password manager or secret manager: 1Password, Vault, or equivalent.
4. Backup/restore runbook for Postgres.

## Cost model to expect

Prices change. Verify official pages immediately before buying.

Known official references checked on 2026-07-09:

- Render pricing: `https://render.com/pricing`.
- Cloudflare R2 pricing: `https://developers.cloudflare.com/r2/pricing/`.
- Apple Developer Program: `https://developer.apple.com/programs/`.
- Stripe pricing: `https://stripe.com/pricing`.
- Resend pricing: `https://resend.com/pricing`.
- Sentry pricing: `https://sentry.io/pricing/`.
- fal pricing: `https://fal.ai/pricing`.

### Practical staging estimate

Expected monthly baseline before usage-heavy AI/video:

| Item | Expected start |
| --- | --- |
| Render API service | paid small/standard instance |
| Render worker | paid small/standard instance |
| Render admin-web | paid starter/small instance |
| Render Postgres | paid managed Postgres |
| Cloudflare R2 | often near-free at small start, then storage/operation usage |
| Resend | free or low paid tier depending volume |
| Stripe | no fixed monthly fee for standard online payments, transaction fees apply |
| fal.ai | prepaid/usage-based, likely the main variable cost |
| Sentry | free for solo/dev, paid for team/production volume |

For PetMagic, fal.ai usage and generated media storage/reads are the main
variable costs. The base infrastructure cost is predictable; generation cost is
not unless product limits are configured.

### Render vs VPS

Render costs more on the invoice than a small VPS, but removes a lot of
operational work:

| Area | Render managed path | Single VPS path |
| --- | --- | --- |
| Deploy from GitHub | Built in | You build scripts/CI yourself |
| TLS/custom domains | Built in | Configure reverse proxy and renewal |
| Postgres | Managed database | Install, tune, backup, restore yourself |
| Worker supervision | Render worker service | systemd/Docker Compose supervision |
| Rollback | Platform deploy history | Build your own image/version rollback |
| Monitoring | Platform basics plus add-ons | Install logs/metrics/alerts yourself |
| Security updates | Platform handles host layer | You patch OS/Docker/Postgres |
| HA path | Add instances/managed DB tiers | Complex and manual |

A VPS can be cheaper for a prototype, but for PetMagic it is riskier because the
app has payments, wallet tokens, AI generation jobs, provider webhooks, refunds,
media storage, push notifications, and background workers. A single VPS is not
high availability and should not be treated as a stability upgrade.

## Step-by-step staging deploy

### 1. Clean local workspace

From repo root:

```powershell
node scripts\qa\clean-local-generated-artifacts.mjs
```

If it only lists generated/cache paths:

```powershell
node scripts\qa\clean-local-generated-artifacts.mjs --apply
```

### 2. Run local predeploy checks

Fast path without generating `bin/obj`:

```powershell
node scripts\qa\run-render-predeploy-gate.mjs --skip-dotnet-build
```

Full local path before first deploy:

```powershell
node scripts\qa\run-render-predeploy-gate.mjs
```

Heavier Docker path before the first Render deploy or after Dockerfile changes:

```powershell
node scripts\qa\run-render-predeploy-gate.mjs --with-docker-build --docker-platform linux/amd64
```

After running checks, clean generated local artifacts again:

```powershell
node scripts\qa\clean-local-generated-artifacts.mjs --apply
```

### 3. Push to GitHub

Render reads `render.yaml` from GitHub. Commit and push the repo before creating
the Blueprint.

### 4. Create Render Blueprint

In Render:

1. Go to `New > Blueprint`.
2. Connect `alexelasticlabs/petmagic-0_004`.
3. Use Blueprint path `render.yaml`.
4. Review services before applying.
5. Create only one staging Blueprint for these staging services.

Expected staging resources:

- `petmagic-staging-api`;
- `petmagic-staging-generation-worker`;
- `petmagic-staging-admin-web`;
- `petmagic-staging-db`;
- `petmagic-staging-shared`.

### 5. Configure domains

In Render service settings:

- API custom domain: `api.staging.petmagic.app`;
- Admin custom domain: `admin.staging.petmagic.app`.

In Cloudflare DNS, add the DNS records Render asks for. Wait until Render marks
domains as verified and TLS is active.

### 6. Fill Render secrets

Use `docs/render-staging-secrets-checklist.md`.

Important rules:

- Never put secret values into `render.yaml`.
- `sync: false` values must be filled in Render dashboard/secret workflow.
- Use staging/test credentials first.
- Generate `Jwt__SigningKey` as a new long random secret.
- Keep `FAL_PROVIDER_SPEND_DAILY_LIMIT_USD` low until generation is proven.

### 7. Deploy order

1. Deploy `petmagic-staging-api`.
2. Wait for `/health`.
3. Confirm startup migrations/seeds in logs.
4. Deploy `petmagic-staging-generation-worker`.
5. Deploy `petmagic-staging-admin-web`.
6. Configure provider callbacks.
7. Run post-deploy smoke.

### 8. Post-deploy smoke

On your local machine, create `.env.staging.local` from
`.env.staging.local.example` and fill only local runner values.

Then run:

```powershell
node scripts\qa\check-staging-env-readiness.mjs
node scripts\qa\run-render-postdeploy-smoke.mjs
```

The post-deploy smoke is read-only. It checks:

- `https://api.staging.petmagic.app/health`;
- `https://admin.staging.petmagic.app/ru`.

### 9. Provider validation

After base health is green, validate:

1. R2 upload/read/signed or public media URL behavior.
2. fal.ai image generation and callback.
3. fal.ai video generation and callback.
4. Stripe sandbox checkout and webhook idempotency.
5. Google Play sandbox purchase validation.
6. App Store sandbox purchase validation.
7. Firebase push delivery to real Android/iOS devices.

### 10. Staging gates

Run when `.env.staging.local` is filled:

```powershell
node scripts\qa\run-economy-staging-infra-gate.mjs
node scripts\qa\run-staging-generation-scheduler-smoke.mjs
```

Do not treat local Docker smoke as production evidence. Staging evidence must
use staging API/DB/worker/provider configuration.

## What to configure in each external service

### Cloudflare

- DNS zone for `petmagic.app`.
- DNS records for Render custom domains.
- R2 bucket.
- R2 access key/secret.
- Optional custom domain for R2 public media.

### Render

- Blueprint from `render.yaml`.
- Custom domains.
- Secret values for all `sync: false` keys.
- Public Postgres access only temporarily for operator maintenance, then lock
  it down.

### Stripe

- Test mode secret key.
- Test mode publishable key.
- Staging webhook endpoint.
- Webhook secret.
- Test products/prices if required by the current economy flow.

### fal.ai

- API key.
- Prepaid credits.
- Daily spending cap in app config.
- Callback URL:
  `https://api.staging.petmagic.app/api/templates/generations/fal/webhook`.

### Firebase

- Staging project.
- Android app config.
- iOS app config.
- Backend service account JSON in Render secret storage.
- Real-device push test.

### Google Play

- Play Console account.
- App entry.
- Service account for Play Developer API.
- Pub/Sub push auth values if server notifications are enabled.
- Sandbox purchase testers.

### Apple

- Apple Developer Program membership.
- App ID / Bundle ID.
- Services ID if used by auth.
- App Store shared secret.
- Sandbox testers.
- TestFlight setup.

### Email provider

- Verified sending domain.
- DNS records: SPF/DKIM/DMARC as provider requires.
- SMTP/API credentials in Render secrets.
- Test password reset/email verification delivery.

## Production promotion checklist

Do not promote staging to production until these are true:

- Staging deploy has green post-deploy smoke.
- Real provider callback tests passed.
- Staging generation and economy gates passed.
- Database backup/restore process is documented and tested.
- Production secrets are separate from staging secrets.
- Production domains are configured.
- Android/iOS release signing is configured outside Git.
- Error monitoring and alerting are enabled.
- Budget caps are set for fal.ai and other variable-cost services.

## Day-one operating rules

- Keep `.env*` real values local and ignored.
- Commit only `.env*.example`.
- Run `node scripts\qa\check-repository-sensitive-files.mjs` before every push.
- Run `node scripts\qa\clean-local-generated-artifacts.mjs --apply` before
  staging commits if local build artifacts were generated.
- For production, prefer managed services over one VPS unless you are ready to
  own backup, restore, updates, monitoring, TLS, rollbacks, and incidents.
