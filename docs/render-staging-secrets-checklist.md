# Render staging secrets checklist

Use this checklist when filling `sync: false` values from `render.yaml` in the
Render dashboard. Do not paste real values into this file, issues, PRs, or
assistant chats.

## Fill order

1. Fill platform boot secrets: `Jwt__SigningKey`, database binding, DNS domains.
2. Fill media and generation secrets: R2, Fal, Firebase.
3. Fill payments and store validation secrets: Stripe, Google Play, App Store.
4. Fill auth and email secrets: Google OAuth, Apple OAuth, SMTP.
5. Fill optional observability secrets: OTLP endpoint.
6. Deploy API first, then worker, then admin-web.

## Secret matrix

| Key | Render services | Source | Validation after fill |
| --- | --- | --- | --- |
| `Jwt__SigningKey` | API, worker | Generate a new 64+ character secret in a password manager or secret generator. | API and worker start outside Development; signed media URLs and JWT validation work. |
| `FAL_AI_API_KEY` | API, worker | Backend-only fal.ai staging key with the Admin permission required by Account Billing API. Keep using this existing server secret; do not create an admin-web/mobile key. | Image/video submission works, signed callbacks reach API, and the generation Capacity panel shows a fresh balance after provider refresh. |
| `R2_ACCOUNT_ID` | API, worker | Cloudflare account dashboard. | R2 storage initialization succeeds. |
| `R2_ACCESS_KEY` | API, worker | Cloudflare R2 API token/access key with bucket-scoped permissions. | Upload/read smoke passes for generated media. |
| `R2_SECRET_KEY` | API, worker | Cloudflare R2 secret access key paired with `R2_ACCESS_KEY`. | Upload/read smoke passes for generated media. |
| `R2_BUCKET_NAME` | API, worker | Cloudflare R2 staging bucket name. | Generated media records point to the staging bucket. |
| `R2_PUBLIC_URL` | API, worker | Cloudflare R2 public/custom domain URL for staging media. | Public/signed media URLs resolve over HTTPS. |
| `ADMIN_MEDIA_ORIGINS` | admin-web | Comma-separated, exact HTTPS origins that host admin-viewable media (for example the configured R2 custom domain); do not include paths, credentials, private hosts, or placeholders. | Admin CSP permits required images/video while continuing to block unconfigured origins. |
| `STRIPE_TEST_SECRET_KEY` | API | Stripe dashboard test mode secret key. | Stripe sandbox checkout/session creation works. |
| `STRIPE_TEST_PUBLISHABLE_KEY` | API | Stripe dashboard test mode publishable key. | Client-visible payment config returns test publishable key only. |
| `STRIPE_TEST_WEBHOOK_SECRET` | API | Stripe CLI/dashboard webhook endpoint signing secret for staging API. | Stripe test webhook signature verifies and idempotent processing succeeds. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` | API | Google Cloud service account used for Play Developer API and Pub/Sub. | Google Play sandbox purchase verification can authenticate. |
| `GOOGLE_PLAY_PRIVATE_KEY_PEM` | API | Private key PEM for the Google service account. | Key parses with escaped newlines preserved; purchase verification does not fail auth. |
| `GOOGLE_PLAY_PUBSUB_AUDIENCE` | API | Expected audience for Google Play Pub/Sub push authentication. | Pub/Sub push token audience is accepted. |
| `GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL` | API | Expected Google service account email for Pub/Sub push authentication. | Pub/Sub push token email is accepted. |
| `GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID` | API | Exact staging Google Play monthly subscription product ID. | `/health` reports provider catalog parity. |
| `GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID` | API | Exact staging Google Play yearly subscription product ID. | `/health` reports provider catalog parity. |
| `APP_STORE_SHARED_SECRET` | API | App Store Connect shared secret for in-app purchase validation. | App Store sandbox purchase validation succeeds. |
| `APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID` | API | Exact staging App Store monthly subscription product ID. | `/health` reports provider catalog parity. |
| `APP_STORE_PREMIUM_YEARLY_PRODUCT_ID` | API | Exact staging App Store yearly subscription product ID. | `/health` reports provider catalog parity. |
| `FIREBASE_PROJECT_ID` | API | Firebase project id for staging. The Blueprint enables template generation push delivery on the API host. | FCM initializes without exposing credentials to the generation worker. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | API | Firebase service account JSON for staging. The generation worker only enqueues durable terminal notifications. | JSON parses in Render env and push delivery can be tested on a real device. |
| `GOOGLE_CLIENT_ID` | API | Google OAuth Web application client id for backend flows. | Google external auth config returns the expected staging client id. |
| `GOOGLE_CLIENT_SECRET` | API | Google OAuth Web application client secret. | Browser fallback/token exchange works where applicable. |
| `GOOGLE_AUDIENCES` | API | Comma-separated Google OAuth client IDs accepted for staging ID tokens. | Native/mobile Google sign-in ID tokens validate for staging clients. |
| `APPLE_CLIENT_ID` | API | Apple Services ID or Bundle ID used by staging Apple auth flow. | Apple auth request uses the expected client id. |
| `APPLE_CLIENT_SECRET` | API | Generated Apple client secret JWT from Apple Developer key/team/client data. | Apple token exchange works in staging. |
| `APPLE_AUDIENCES` | API | Comma-separated Apple Bundle ID/Services ID audiences accepted for staging. | Apple identity tokens validate for staging clients. |
| `EMAIL_HOST` | API | SMTP provider host for staging email. | Email sender connects to staging SMTP. |
| `EMAIL_PORT` | API | SMTP provider port. | Email sender connects with the expected TLS/SSL mode. |
| `EMAIL_USERNAME` | API | SMTP provider username/login. | Password reset/email verification delivery works. |
| `EMAIL_PASSWORD` | API | SMTP provider password/API key. | Password reset/email verification delivery works. |
| `EMAIL_FROM_ADDRESS` | API | Verified sender address in the SMTP provider. | Provider accepts sender; user receives staging email. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | API, worker | Observability backend OTLP endpoint, if enabled for staging. | API and worker export traces/metrics or leave this empty until observability is provisioned. |

## Render entry points

Fill only the provider/storage/runtime values on both services when the matrix
explicitly lists API and worker:

- `petmagic-staging-api`
- `petmagic-staging-generation-worker`

The `petmagic-staging-admin-web` service must not receive server-only provider
secrets. Its safe public/runtime values are already explicit in `render.yaml`.

Stripe, Google Play and App Store values are API-only. Do not copy billing/store
credentials to the generation worker; the Blueprint and predeploy gate reject them.

`Templates__FirebasePush__Enabled=true` is API-only. The generation worker writes
terminal notification records to PostgreSQL in the generation transaction, while
the API-owned outbox dispatcher delivers them with Firebase credentials. Do not
copy `FIREBASE_*` values or the dispatcher flag to the generation worker.

`Templates__FalProviderSpendDailyLimitUsd=0` in the shared Blueprint is an intentionally unused
compatibility setting, not a secret to fill and not a daily budget control. Scheduler V2 uses the
`$10` low and `$5` critical balance thresholds plus operator/provider billing controls.

`Templates__GenerationSchedulerV2Enabled=false` is also intentional for the first additive-schema
deploy. After migration/backfill inspection and the compatibility-loop canary, change it to `true`
and use Blueprint Manual Sync/redeploy. It is a rollout flag, not a secret.

## Post-fill checks

Run local preflight before triggering deploy:

```powershell
node scripts\qa\run-render-predeploy-gate.mjs
```

After deploy, fill local `.env.staging.local` with runner-only values and run:

```powershell
node scripts\qa\check-staging-env-readiness.mjs
node scripts\qa\run-render-postdeploy-smoke.mjs --expected-source-revision <deployed-git-sha>
```

Do not stop at a green public `/health`. The postdeploy evidence must also show one fresh
generation-worker heartbeat, recent progress when work exists, matching API/worker static
fingerprints, the current `AppliedPolicyRevision`, and no fingerprint-mismatch marker. In Render
Dashboard, manually confirm worker autoscaling is disabled; Blueprint `numInstances: 1` does not
remove an existing scaling override.
