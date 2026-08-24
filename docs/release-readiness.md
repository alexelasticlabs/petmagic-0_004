# Release Readiness

Status: **not approved for production release**

This file is the single current release-readiness summary. Keep detailed
contracts and operating procedures in their canonical documents instead of
adding dated audit snapshots to the repository.

## Current Infrastructure Direction

- The production target is the owner-managed private VPS. Do not treat Render
  Blueprints, environment variables, or deploy status as current production
  acceptance evidence.
- Keep Render only as a controlled migration source and potential rollback
  reference until VPS backup/restore, health, DNS/TLS, and provider-flow
  acceptance have all been evidenced. Do not discard its export or persistent
  media archive before that point.
- Required production secrets belong in the protected VPS environment file,
  `/opt/petmagic/shared/env/.env.vps`, never in Git or release documentation.
- The provider-configuration inventory and remaining VPS cutover work are
  maintained in [`deploy/vps/README.md`](../deploy/vps/README.md). Items listed
  there as configured are not a substitute for live provider acceptance.

## Verified private-VPS acceptance

- The protected VPS environment passed preflight. Caddy, the Compose
  supervisor, PostgreSQL, API, admin web and one generation worker are healthy;
  public API and admin routes return HTTP 200 over HTTPS.
- Application R2 media access passed a temporary `PUT`/`GET`/`DELETE` smoke
  check. A dedicated least-privilege backup bucket, encrypted restic repository
  and enabled nightly timer are in place.
- The first coordinated PostgreSQL/API-data backup passed `restic check` and
  was restored into an isolated temporary database with 82 public tables and
  99 EF migrations. The temporary restore database and dump were removed.
- Stripe live credentials authenticated with a read-only API request. Google
  Play service-account OAuth and the purchase-verification API are authorized;
  a synthetic token reached the expected validation failure path without
  creating a purchase. Catalog-list access remains intentionally ungranted
  because backend purchase verification does not need `Manage store presence`.
- Stripe has one enabled VPS webhook endpoint with all backend-required checkout
  and subscription event types. A real signed delivery is still required.
- App Store Connect production and Sandbox notification URLs both target the
  VPS API webhook route. A real signed Sandbox delivery is still required.
- Native Google mobile authentication is configured against the Google/Firebase
  project embedded in the published Android bundle. The public mobile-config
  route returns HTTP 200 and a deliberately invalid native token reaches the
  expected authentication rejection path. Real Google-account sign-in on a
  physical device remains required.

## Mobile release correction pending

- The production mobile-release workflow was corrected to build with
  `API_BASE_URL=https://api.petgpt.app`. The prior `api.petmagic.app` host does
  not resolve in DNS, so an already-published Android build using it cannot
  reach the VPS. Publish and install a new Play release before treating mobile
  connectivity as accepted.
- The protected GitHub production environment now has the existing Android
  upload keystore, matching Firebase production config and Play service-account
  JSON. Run `32666052824` built and signed `1.0.0+2`, preserved its symbols
  artifact and reached the Play Internal upload, but Google Play rejected the
  track update with `The caller does not have permission`. The existing service
  account was granted `Release apps to testing tracks`; follow-up run
  `32674447149` then built, archived, and uploaded `1.0.0+2` to Play Internal
  successfully. A Play-installed device has reached the VPS API, but verified
  email/password and real Google-account sign-in acceptance remain pending.
  Browser redirect-based Google OAuth is intentionally disabled until a
  matching client secret is provisioned in the same Google project; native
  Android/iOS token verification does not use that secret. The independent iOS
  signing/API-key chain remains unavailable or malformed.

## Automated Gates

Run these gates against the exact release commit:

```powershell
dotnet restore PetMagic.slnx
dotnet build PetMagic.slnx --no-restore
dotnet test PetMagic.slnx --no-build
dotnet list PetMagic.slnx package --vulnerable --include-transitive

npm ci --prefix apps/admin-web
npm audit --prefix apps/admin-web --audit-level=moderate
npm run lint --prefix apps/admin-web
npm run typecheck --prefix apps/admin-web
npm test --prefix apps/admin-web
npm run build --prefix apps/admin-web

npm ci --prefix apps/public-web
npm audit --prefix apps/public-web --audit-level=moderate
npm run validate:legal --prefix apps/public-web
npm run lint --prefix apps/public-web
npm test --prefix apps/public-web

Push-Location apps/petmagic-mobile
flutter pub get
flutter analyze --fatal-infos
flutter test
Pop-Location

docker compose --env-file .env.example config --quiet
node scripts/qa/test-markdown-local-links.mjs
node scripts/qa/check-markdown-local-links.mjs
node scripts/qa/run-render-predeploy-gate.mjs
```

Local passes are pre-release evidence only. Record failures in the release PR;
do not append command transcripts to this file.

## Production Evidence Still Required

- Formal legal approval for the current English and Russian Terms of Use and
  Privacy Policy. The public site intentionally exposes only `en` and `ru` until
  additional locale translations are approved and added to both the catalog and
  its required-locale gate.
- Privacy/legal approval for release Crashlytics collection, including the
  intended Firebase processor disclosure and retention basis.
- Real-device authentication acceptance for the uploaded Android `1.0.0+2`
  Internal build: verified email/password login and native Google login with a
  real account.
- An iOS archive and store validation from a supported macOS/Xcode environment.
- FAL generation and callback proof with production-like R2 upload/read paths.
- Stripe, Google Play, and App Store sandbox purchase, replay, refund, restore,
  and subscription lifecycle proof.
- FCM and APNs delivery proof on real devices for generation, economy, and
  support notifications.
- Real signed Stripe and App Store Sandbox webhook delivery, plus Google Play
  store sandbox acceptance. Endpoint and API authorization configuration is
  already verified, but it is not delivery proof.
- Clean and existing-database migration proof against the release commit,
  including backup and rollback evidence.
- Staging smoke for API, generation worker, admin web, public legal routes,
  observability, rate limits, and provider callbacks.

## Release Rules

- Release from a reviewed commit with a clean worktree.
- Keep secrets in platform secret storage; never package local `.env`, Firebase
  active configs, signing keys, database dumps, or test artifacts.
- Keep `Templates__GenerationWorkerEnabled=false` on the API and `true` on the
  generation worker.
- Keep exactly one `generation-worker` instance with `4/4/1/1` bounded lanes
  for the first production rollout. Enforce that limit on the VPS; if Render is
  retained during rollback readiness, keep its worker workload stopped and
  autoscaling disabled. Provider capacity is controlled by the revisioned
  PostgreSQL policy, not service replicas.
- Keep `Templates__GenerationSchedulerV2Enabled=false` through additive migration/backfill and the
  compatibility canary; enable it with Manual Sync/redeploy only for V2 acceptance. Rollback returns
  the flag to `false` without removing the additive schema.
- Require fresh fal balance from the backend-only Admin-capable `FAL_AI_API_KEY`, a current manually
  confirmed fal concurrency limit, fresh worker heartbeat/progress, and matching applied policy
  revision before enabling generation admission.
- Preserve `/api/economy/...` as the billing contract; do not reintroduce the
  removed `/api/payments/stripe/*` surface.
- A green local build does not waive provider, device, migration, backup, or
  rollback evidence.

## Canonical References

- `docs/api-contracts.md`
- `docs/security.md`
- `docs/payments-sandbox-checklist.md`
- `docs/notifications-contract.md`
- `docs/economy-generation-billing.md`
- `docs/observability.md`
- `deploy/vps/README.md` (private-VPS deployment, migration status, and cutover acceptance)
- `deploy/vps/.env.vps.example` (non-secret VPS environment inventory)
- `docs/render-staging-deployment.md`
- `docs/render-staging-secrets-checklist.md`
- `render.yaml` (staging Blueprint)
- `render.production.yaml` (production Blueprint)
