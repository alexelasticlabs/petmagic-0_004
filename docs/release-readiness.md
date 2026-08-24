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
- A 2026-08-24 edge control pass confirmed valid TLS for `petgpt.app`,
  `admin.petgpt.app`, and `api.petgpt.app`, with HSTS, CSP, `nosniff`, and
  frame protection on each public surface. The earliest observed certificate
  expiry is 2026-10-28; this is current evidence, not a substitute for renewal
  monitoring.
- A root-only GitHub read-only deploy key backs the VPS `origin`. The controlled
  release script deployed source revision
  `92c202369b7a8dde54c9ac441da41433e1d04668`; its runtime preflight and the
  public API health check passed. This is deployment evidence, not mobile or
  payment acceptance.
- The economy migration
  `20260824155159_AlignPremiumAllowanceAndTestPackPrices` is applied on the VPS.
  Live rows confirm Premium allowance `40` for monthly/yearly and test pack
  prices `0.99`/`1.49`/`1.99` in USD and EUR. Provider purchase acceptance is
  still pending.
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
  expected authentication rejection path. The Play-distribution signing
  certificate matches the production Android OAuth client in that project. A
  real Google-account sign-in on the Play-installed physical Android device was
  accepted by the VPS and completed `/api/auth/me` successfully.

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
  signing/API-key chain remains incomplete in GitHub `production`: Firebase
  iOS configuration and App ID are present, and App Store Connect API access is
  approved. A dedicated private `petmagic-ios-signing` repository, scoped
  deploy key and protected `MATCH_*` inputs are configured. The team API key
  and first Match bootstrap remain pending before TestFlight.
- Android `1.0.0+3`, containing corrected mobile auth-feedback mapping and
  production API routing, was built, signed, archived and uploaded to Play
  Internal by run `32698746633`. Its Play-installed device reached the VPS API,
  but the email login was rejected as `invalid_credentials` and the native
  Google SDK did not reach the token-exchange endpoint. This is diagnostic
  evidence, not authentication acceptance.
- Android `1.0.0+4` replaced the device-wide connectivity probe from an
  unrelated public DNS lookup with the configured PetMagic API `/health`
  endpoint. Run `32701367339` built, signed, archived and uploaded it to Play
  Internal; a physical device installed build `4`, but authentication still
  trusted a stale global offline status before opening the Google selector.
- Android `1.0.0+5` removed the best-effort network banner as a hard
  precondition and was installed on a physical device. The VPS accepted a
  verified email/password request (`HTTP 200`), but the client did not make
  the subsequent `/api/auth/me` request; the native Google SDK also did not
  reach the token exchange. Android `1.0.0+6` is prepared with in-memory
  session continuity if Android secure-storage persistence stalls, bounded
  Google SDK cleanup, and less aggressive API reachability probes. Run
  `32706661084` built, signed, archived and uploaded it to Play Internal.
  Physical-device build `1.0.0+6` reached both the public Google mobile-config
  route and the API `/health` route with HTTP 200, while the UI still replaced
  the auth flow with an offline error. The remaining race was isolated to a
  transient Android connectivity callback cancelling an in-flight auth request
  after the successful API response. Current source confirms every reported
  route state with the PetMagic API probe and ignores stale concurrent probe
  completions; the focused network/profile/external-auth test shard passes 31
  tests. Android production release `1.0.0+7` was built and uploaded to Play
  Internal by successful run `32711648441` from commit `4e9d9d42`. Installing
  that exact Play artifact on a physical Samsung device reproduced the same
  offline message immediately after starting Google authentication even though
  the public mobile-config and health routes returned HTTP 200. A second race
  was then isolated in `ProfileController`: the advisory network listener
  cancelled an already-running email or external-auth request and replaced its
  real outcome with `templates.network_unavailable`. Android `1.0.0+8` kept an
  active auth request authoritative. Run `32713508079` built and uploaded that
  release successfully from commit `04d6cf54`; the installed Play artifact was
  confirmed as `versionCode=8` on a physical Samsung device. The same offline
  message still appeared immediately after the Google action even though the
  mobile-config and health routes returned HTTP 200 and no native-token exchange
  reached the backend. A live artifact/configuration audit confirmed that the
  bundle's Firebase project, Android package, Play app-signing SHA-1, Android
  OAuth client and backend web-client audience all match. The remaining false
  feedback source was the idle `ProfileController` connectivity listener: it
  could publish `templates.network_unavailable` without any profile mutation in
  progress and overwrite the actual native-auth outcome. Android `1.0.0+9`
  made that advisory non-authoritative while idle and retained cancellation only
  for a real avatar/profile mutation. Run `32715870923` built and uploaded that
  release successfully from commit `6029dd4f` in 9m11s. The installed Play
  artifact was confirmed as `versionCode=9` on the same physical Samsung device,
  but the exact offline message was reproduced again. At the Google action the
  public mobile-config and `/health` routes returned HTTP 200, no native-token
  exchange reached the backend, Google Play Services was current, Google
  accounts were present and Android Credential Manager had enabled providers.
  Android `1.0.0+10` therefore preserves the real Google SDK failure category:
  configuration and unavailable-UI failures map to distinct user feedback, and
  sanitized Crashlytics non-fatals record only the SDK enum code and whether
  opaque description/details existed. It also records when an active auth
  request is mapped to a network failure. Run `32717652959` built and uploaded
  `1.0.0+10` successfully from commit `c3249a5a` in 9m26s. The installed Play
  artifact was confirmed as `versionCode=10`; the exact offline message still
  reproduced. At that tap the physical phone received HTTP 200 for
  `/api/auth/external/google/mobile-config`, but no native-token exchange
  reached the backend. Crashlytics then confirmed that the client mapped the
  active auth outcome to `network.unavailable`. The root cause was the
  response-rewrite path in `ApiBaseUrlFailoverInterceptor`: it converted typed
  JSON maps to runtime-untyped maps after a successful response, while
  `NetworkErrorMapper` classified the resulting response-less internal
  `DioException` as connectivity loss. Android `1.0.0+11` preserves typed JSON
  maps during URL rewriting and limits unknown connectivity failures to an
  actual `SocketException`. The focused network/profile/external-auth shard
  passes 49 tests and `flutter analyze` is clean. Run `32719391026` built,
  archived and uploaded `1.0.0+11` to Play Internal successfully from commit
  `4c2ea4f4` in 9m58s; the signed-AAB step took 7m23s. The installed artifact
  was confirmed as `versionCode=11` on the same physical Samsung device. Guest
  entry and the previously failing server-backed screens now work without the
  false server-unavailable result. A post-install device log check found no new
  `DioException`, `network.unavailable`, Flutter exception or fatal crash. Live
  control checks returned HTTP 200 for `/health`, `/api/legal/current` and the
  Google mobile-config route; all VPS application containers were healthy,
  Caddy was active and `api.petgpt.app` resolved directly to `40.160.84.15` with
  a valid TLS certificate. General Android-to-VPS connectivity is therefore
  accepted for `1.0.0+11`. Native Google sign-in was then accepted on the same
  device: the system account chooser returned an ID token, the VPS handled
  `POST /api/auth/external/google/native` and `/api/auth/me` with HTTP 200, and
  the authenticated application loaded its wallet, subscription and templates.
  The prior email/password attempt reached the correct VPS route but sent the
  empty JSON state even though Android autofill visibly populated both fields.
  Android `1.0.0+12` snapshots the visible `TextEditingController` values before
  updating Riverpod state and submitting; its autofill regression widget test
  and the 55-test auth/network shard pass, and `flutter analyze` is clean. Run
  `32722408718` built, archived and uploaded that exact release from commit
  `01d92a177858fcf130f9e692d916146c4f4ffa77` to Play Internal successfully;
  `versionCode=12` is installed on the physical Samsung device. A cold-start
  check restored the authenticated session, loaded wallet-backed UI and showed
  the empty-template state without a server-unavailable result. Fresh device
  `logcat` contained no Flutter, Dio, socket or crash-buffer error.

  Crashlytics nevertheless received two build-12 events from an earlier
  authenticated session. The matching Build ID and archived Dart symbols
  resolve one stack to a deferred `TemplatesPage` callback reading Riverpod
  after its element was unmounted. Android `1.0.0+13` guards deferred provider
  work with the owning `BuildContext.mounted` state and adds an unmount
  lifecycle regression. Run `32728145852` built, archived and uploaded that
  exact release from commit `dfa47dffde8a28e66400203622f50d0e625edf8a`
  to Play Internal successfully in 10m58s; signed-AAB build took 7m37s,
  Crashlytics symbol upload 42s and Play upload 52s. The Play artifact was
  installed and confirmed as `versionCode=13` on the physical Samsung device.

  Explicit logout-to-guest and guest-to-Google transitions then exposed a
  separate first-frame failure even though the VPS completed Google native
  authentication and `/api/auth/me` with HTTP 200. Symbolized build-13
  Crashlytics evidence traces the failure to `TemplatesController`
  reconstruction after `sessionScopeResetProvider` invalidates its provider:
  Riverpod can re-run `Notifier.build()` on the same instance, but six
  lifecycle collaborators were declared `late final` and could not be assigned
  again. Android `1.0.0+14` makes those collaborators replaceable and adds an
  explicit provider-invalidation regression test. Run `32730528049` built,
  archived and uploaded that exact release from commit
  `30626279b24c2a5f4c8733fc55c10390f00b70a6` to Play Internal successfully
  in 10m20s; signed-AAB build took 7m34s, Crashlytics symbol upload 39s and
  Play upload 43s. The Play artifact was installed and confirmed as
  `versionCode=14` on the physical Samsung device. Without restarting the app,
  logout-to-guest opened the template empty state directly and guest-to-Google
  returned to the authenticated template empty state directly; the VPS handled
  Google native authentication and `/api/auth/me` with HTTP 200. Three
  profile/template navigation cycles, background/foreground and a subsequent
  cold restart also passed. Android crash-buffer and targeted Flutter/Dio logs
  remained empty. After the restart, a short Crashlytics observation still
  showed the existing five build-13 lifecycle events and no build-14 event;
  continued monitoring is still required because ingestion can be delayed.

  The same dated control pass confirmed all production containers healthy,
  Caddy active, 99 EF migrations, no recent backend error/fatal/exception log,
  and HTTP 200 with valid TLS for API health, legal, Google mobile config,
  admin and public web routes. The latest nightly PostgreSQL/API-data backup
  completed successfully and its encrypted off-site repository integrity check
  reported no errors.

  A later control pass identified one exhausted `identity_email` outbox record
  addressed to the reserved `example.com` test domain. Its SMTP failure was
  isolated from customer traffic and the stale test record was removed. A
  fresh `/health` check then reported all notification queues healthy; the
  only remaining overall `Degraded` check is the intentional
  `store_account_binding=compatibility` gate, which must stay in place until
  real Google Play and App Store purchase evidence exists.

  The current auth/network/router/templates verification shard passes 163
  tests. Three initially failing pet-generation cases were traced to stale
  test fixtures using the intentionally disallowed placeholder host
  `cdn.petmagic.app`; deterministic cached-image fixtures now use the approved
  `cdn.petgpt.app` host and the isolated pet-flow file passes all 10 cases. This
  is test-contract evidence, not a production generation-provider acceptance.
- The Android release job is configured to reuse Gradle dependency, transform
  and local build-cache state between runs. Run `32706661084` was the first
  seed: it restored no entry, saved 2.1 GB in a 56-second post-job step, and
  completed in 15m 51s; its signed-AAB step took 12m 48s. Run `32711648441`
  restored the Flutter, pub, Gradle and Ruby caches, completed successfully in
  9m 08s, built the signed AAB in 7m 09s and uploaded it to Play Internal in
  40s. This is the first measured cache-hit acceptance for the optimized
  workflow.
- Run `32713508079` also restored the workflow caches, completed successfully in
  9m 19s, built the signed AAB in 7m 12s and uploaded it to Play Internal in 41s.
  This confirms the optimized duration is repeatable; it does not prove device
  authentication.

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
- Continue post-release Crashlytics monitoring beyond the short build-14
  device-observation window. Physical-device guest, Google, authenticated
  navigation and cold-restart acceptance are complete; email/password remains
  accepted from the preceding production device pass because build 14 changes
  only template-provider reconstruction.
- Google Play contains active monthly (`com.petmagic.app.premium.monthly`,
  USD 14.99) and yearly (`com.petmagic.app.premium.yearly`, USD 99.99)
  subscriptions with active base plans in 174 countries. A tester offer was
  not created without an approved product decision. Complete sandbox purchase,
  renewal, restore, cancellation/refund and idempotent backend-crediting proof.
- The active Play Internal track contains release `1.0.0` and an attached
  tester list. This proves release distribution, not Billing eligibility for
  every Play account or country. On the physical Android device, the native
  store selector did not expose a purchasable Google Play option; Stripe stayed
  available. Before a sandbox charge, verify the tester account's Play-country
  eligibility and license-testing status against the active products.
- **Release blocker — Premium allowance rollout:** the owner approved
  `40 PawSpark` at purchase and every seven days while Premium remains active.
  Local plan defaults, health checks, migration and mobile copy now match the
  decision, with clean/existing DB migration proof. The VPS migration and live
  database values are confirmed aligned. Active store/Stripe product copy and
  a real renewal/cancellation lifecycle still have to prove idempotent granting.
- **Release blocker — native Stripe acceptance:** eligible Android Stripe
  checkout now uses native PaymentSheet. iOS/web retain hosted Checkout or
  store billing according to policy. The optional client-secret contract,
  narrow-screen Premium UI, production-flavor debug APK and minified release
  AAB pass locally, and the backend is deployed on the VPS. Upload and install
  Android `1.0.0+15`, then prove a Stripe test-mode payment,
  cancellation/retry and signed webhook reconciliation on a physical device
  before treating this as delivered.
- Google Play token-pack product IDs are derived from the active catalog as
  `com.petmagic.app.tokens.google.<pack-code>` rather than stored per pack.
  The Play Console's **One-time products** catalog is currently empty, while
  the VPS catalog has active `starter`, `creator`, and `viral` packs. Therefore
  the Android wallet correctly disables Google Play for packs and exposes
  Stripe instead. Create and activate intentionally priced matching Play
  products before a sandbox purchase is verified and consumed exactly once.
- The production and retained Render databases both currently contain zero
  template items, categories and assets; this is not a VPS migration loss.
  Populate the production catalog only with approved template content and then
  verify R2-backed mobile feed/generation flows.
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
