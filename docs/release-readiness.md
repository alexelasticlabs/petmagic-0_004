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
  `f7c7da65f2b651752e80026c38c6209f03289fe6`; its runtime preflight and the
  public API health check passed. The VPS database currently has 101 applied EF
  migrations. On 2026-08-25 the fal.ai credential was
  rotated to a dedicated `ADMIN`-scope production key; the direct billing read
  returned HTTP 200 and the persisted provider check became `Healthy`/`fresh`
  with zero consecutive failures. This is deployment and provider-authorization
  evidence, not mobile, paid generation, callback, or payment acceptance.
- The economy migration
  `20260824155159_AlignPremiumAllowanceAndTestPackPrices` is applied on the VPS.
  Live rows confirm Premium allowance `40` for monthly/yearly and test pack
  prices `0.99`/`1.49`/`1.99` in USD and EUR. Provider purchase acceptance is
  still pending.
- Application R2 media access passed a temporary `PUT`/`GET`/`DELETE` smoke
  check. A dedicated least-privilege backup bucket, encrypted restic repository
  and enabled nightly timer are in place. The 2026-08-24 scheduled run succeeded;
  three encrypted snapshots are present and a fresh read-only repository check
  reports no errors.
- The first coordinated PostgreSQL/API-data backup passed `restic check` and
  the latest scheduled dump was independently checksum-verified and restored
  into an isolated temporary database with 82 public tables, 99 EF migrations
  and one user. Zero temporary verification databases remain.
- Stripe live credentials authenticated with a read-only API request. Google
  Play service-account OAuth and the purchase-verification API are authorized;
  a synthetic token reached the expected validation failure path without
  creating a purchase. Catalog-list access remains intentionally ungranted
  because backend purchase verification does not need `Manage store presence`.
- Stripe has one enabled VPS webhook endpoint with all backend-required checkout
  and subscription event types. A real signed delivery is still required.
- Isolated Stripe staging now has separate test credentials, test catalog,
  webhook signing secret and database. On 2026-08-25 a signed sandbox
  `payment_intent.succeeded` delivery received HTTP 200, and the Android
  PaymentSheet checkout path activated Premium for an isolated staging user.
  This does not prove a live delivery or public-charge lifecycle.
- App Store Connect production and Sandbox notification URLs both target the
  VPS API webhook route. A real signed Sandbox delivery is still required.
- Production transactional email uses Resend SMTP, not the local Mailpit
  service. Resend reports `petgpt.app` verified for sending, and public DNS
  confirms its DKIM plus the `send.petgpt.app` SPF/return-path MX records. The
  VPS email-confirmation job reached `Sent` in one attempt, the seven-day
  backend-log check found no SMTP/email error, and Resend records a PetMagic
  verification message as `delivered`. This is current transport evidence;
  recipient data and message contents were not inspected.
- The protected VPS backend runtime contains the Firebase project and service
  account configuration, while `/health` reports `push_outbox=Healthy` with no
  queued or dead-lettered delivery. This proves configuration presence and
  queue health only; FCM and APNs delivery on real devices remain required.
- Public DNS now publishes an initial monitored DMARC policy for `petgpt.app`
  (`p=none`, strict DKIM/SPF alignment and aggregate reports to the
  owner-controlled operations mailbox). This adds authentication observability
  without changing acceptance or delivery; review reports before enabling a
  rejecting policy.
- Native Google mobile authentication is configured against the Google/Firebase
  project embedded in the published Android bundle. The public mobile-config
  route returns HTTP 200 and a deliberately invalid native token reaches the
  expected authentication rejection path. The Play-distribution signing
  certificate matches the production Android OAuth client in that project. A
  real Google-account sign-in on the Play-installed physical Android device was
  accepted by the VPS and completed `/api/auth/me` successfully.

## Mobile release correction status

- The production mobile-release workflow was corrected to build with
  `API_BASE_URL=https://api.petgpt.app`. The prior `api.petmagic.app` host does
  not resolve in DNS and explains the earliest unreachable Android artifacts.
  Current Play-installed production builds use the corrected host; physical
  device acceptance now proves API connectivity, email/password authentication,
  native Google authentication and authenticated `/api/auth/me` restoration.
- The protected GitHub production environment now has the existing Android
  upload keystore, matching Firebase production config and Play service-account
  JSON. Run `32666052824` built and signed `1.0.0+2`, preserved its symbols
  artifact and reached the Play Internal upload, but Google Play rejected the
  track update with `The caller does not have permission`. The existing service
  account was granted `Release apps to testing tracks`; follow-up run
  `32674447149` then built, archived, and uploaded `1.0.0+2` to Play Internal
  successfully. Later Play-installed builds completed verified email/password
  and real Google-account sign-in acceptance against the VPS.
  Browser redirect-based Google OAuth is intentionally disabled until a
  matching client secret is provisioned in the same Google project; native
  Android/iOS token verification does not use that secret. The independent iOS
  signing/API-key chain remains incomplete in GitHub `production`: Firebase
  iOS configuration and App ID are present, and App Store Connect API access is
  approved. A dedicated App Manager team API key and its three required
  protected GitHub `production` secrets are now configured. A dedicated private
  `petmagic-ios-signing` repository, scoped
  deploy key and protected `MATCH_*` inputs are configured. The App Store
  Connect record named `Pet Video Magic` is confirmed to use Bundle ID
  `com.petmagic.app` and Apple ID `6796478761`; production and Sandbox server
  notifications both target the production App Store webhook. Match bootstrap
  run `32781360447` was rejected before its first step by the GitHub
  account-level billing/spending-limit gate, so no Apple signing state changed.
  Repair GitHub Billing, then run the first Match bootstrap and TestFlight.
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

  A subsequent production control pass removed the remaining two exhausted
  `email.dispatch_failed` test records addressed to `example.com`. The
  `push_outbox` health check is again `Healthy`; no customer email records
  were changed.

  SPF and DKIM are active for the Resend sending domain, but public DNS does not
  currently expose `_dmarc.petgpt.app`. Publish and monitor a DMARC policy
  before public launch; this is email-authentication hardening, not a current
  SMTP delivery outage.

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
- GitHub-hosted release run `32767419162` was rejected before its first step
  because the account has a failed payment or insufficient Actions spending
  limit. The hosted-runner Gradle memory/worker tuning is committed but is not
  execution-verified while that account-level block remains. As an independent
  fallback, Android `1.0.0+15` was built and signed locally as
  `app-production-release.aab` (SHA-256
  `098D568155BC3F3F981D446D90D463A59F5E9FAC01003A3D59F7FE8E0A34AC5D`).
  Google Play Android Publisher API then uploaded the exact artifact and a
  follow-up API read confirmed Internal release `1.0.0 (15)`, status
  `completed`, version code `15`. Physical-device install and payment acceptance
  are still pending.
- iOS Match bootstrap run `32781360447` was rejected before its first step by
  the same GitHub Billing gate. The App Store Connect App Manager key and its
  protected production secrets were present, but the runner never started;
  this is not an Apple credential, Match, archive, or TestFlight result.

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
  USD 0.99) and yearly (`com.petmagic.app.premium.yearly`, USD 1.99)
  subscriptions with active base plans. On 2026-08-25 the base prices were
  updated through Play Console for all 177 selected countries/regions and
  re-read for the United States. A tester offer was not created without an
  approved product decision. Complete sandbox purchase, renewal, restore,
  cancellation/refund and idempotent backend-crediting proof.
- App Store Connect contains the same monthly and yearly product IDs in
  `Prepare for Submission`, with one-month and one-year durations and current
  price matrices for 175 countries/regions, while sale availability is currently
  configured for only 28 of those countries/regions. On 2026-08-25 their United States
  base prices were changed and re-read as USD 0.99 and USD 1.99; Apple
  calculated the corresponding regional prices. Complete Sandbox purchase,
  renewal, restore, cancellation/refund and backend-crediting acceptance.
- The active Play Internal track contains release `1.0.0 (20)` and an attached
  tester list. The uploaded production AAB has SHA-256
  `7E99AAE3BCFA87E59331B1259FAD5ECF76B2E899E6FBD2113CCD714F9B28BEB4`.
  The prior `1.0.0 (18)` AAB from commit `3d88d997` remains documented below as
  payment-selector acceptance evidence; `1.0.0 (20)` is the current
  distribution and still requires physical-device acceptance.
  The matching VPS revision completed controlled deployment, all containers were
  healthy, runtime preflight passed, and the public paywall API returns localized
  legal notices for `locale=ru-RU`. This proves release distribution and API
  deployment, not Billing eligibility for every Play account or country.
  A physical Android device now runs the Play-installed `1.0.0+19` build. The
  preceding build `17` completed native Google Sign-In acceptance after logout:
  it opened the account chooser and returned to the authenticated app without a
  `network.unavailable`, Dio or Flutter error. Build `18` accepts the
  payment-method selector with Russian Stripe and Google Play titles/subtitles;
  selecting Google Play replaces the Stripe Checkout notice with the Russian
  store-billing notice. The selector was closed before checkout. No store or
  Stripe purchase was started. Verify the tester
  account's Play-country eligibility and license-testing status against the active
  products before a sandbox charge.
- Android `1.0.0+19` from commit `9210b101c` was built locally with the
  configured production signing identity; its AAB SHA-256 is
  `19A84CDC48E5331A437B8E788036C1F787EB03519AACECBC42BE4940AECEE5B3`.
  Android Publisher API accepted the artifact on Play Internal and an
  independent read confirmed `versionCode=19`. The physical Samsung device
  installed that Play build. Guest access opened the templates screen, native
  Google Sign-In completed into the authenticated templates screen, and a
  malformed email request showed the specific localized validation message
  rather than the generic request failure. This is acceptance for mobile API
  reachability, native OAuth and validation feedback—not a successful real
  email/password sign-in or a provider-purchase lifecycle.
  A subsequent direct recheck signed the same physical device out and back in
  with Google: the account chooser completed, the VPS returned HTTP 200 for
  `/api/auth/external/google/native` and the following `/api/auth/me` request.
  The reported password failure used an email local-part with a missing
  character; no matching production user exists. The actual account is active,
  email-confirmed, has a password credential and is not locked. This is a
  user-input diagnosis, not an auth, DNS, Cloudflare or VPS outage.
- The locally signed production AAB built after commit `0e07fe2f` was uploaded
  to Play Internal as `1.0.0+20`; its SHA-256 is
  `7E99AAE3BCFA87E59331B1259FAD5ECF76B2E899E6FBD2113CCD714F9B28BEB4`.
  It includes the native Stripe PaymentSheet response-preservation fix. Upload
  is release-distribution evidence only for the native Stripe path. The focused
  native-PaymentSheet/hosted-fallback Flutter test passes locally; this is code
  evidence only.
- **Android OAuth device acceptance (2026-08-25):** the connected physical
  Samsung was updated from Play Internal to `versionCode=20`, then signed out
  and back in through the Android system Google account chooser. PetMagic
  returned to the authenticated application state and its wallet data loaded.
  The public API and mobile Google configuration endpoint were available
  throughout the check. Google Cloud contains the production Android OAuth
  client for `com.petmagic.app` with the matching Google Play app-signing
  certificate, and the VPS native-token verifier is configured for the matching
  web-client audience. The Firebase General page's empty certificate display is
  therefore not an OAuth defect; no Firebase or GitHub secret was changed.
  Crashlytics had already shown that the reported password attempt reached the
  VPS and was rejected with `auth.email_invalid` (HTTP 400), not by DNS or
  server unavailability. Commit `c0e5adf3` additionally prevents known email
  and external-auth failures from being rendered as a generic
  server-unavailable screen; its focused Flutter regression test passes, but
  that UX correction still requires a release newer than `1.0.0+20` for device
  acceptance.
- Android `1.0.0+21` is prepared at commit `edbe2d327`. Its focused
  `app_unavailable_state_test.dart` regression suite and release-version check
  pass locally. GitHub Actions run `32844447065` was rejected before its first
  build step, artifact creation, or Play upload because recent account payments
  have failed or the GitHub Actions spending limit must be increased. This is
  an account-billing gate, not an Android build failure. Release `1.0.0+20`
  remains the current Play Internal artifact until that gate is resolved or a
  separately authorized local signed-build/upload fallback is used.
- A local signed production AAB for `1.0.0+21` was built from the same code
  revision after the GitHub rejection. Its SHA-256 is
  `E585E77DA55E2F6D7C704B455629D9FF3B9D5C6830E134BDCA317DA80791DFCE`.
  The artifact has not been uploaded to Play, so it is a verified local
  fallback artifact, not a distributed or device-accepted release.
  The corresponding local APK is signed with the upload key and intentionally
  does not match the Google Play app-signing certificate on the installed app;
  it was not sideloaded over the Play build. Physical acceptance therefore
  still requires the normal Internal-track AAB distribution path.
- A direct, owner-authorized Google Play Internal upload was attempted for that
  local AAB on 2026-08-25. The available browser surface rendered the release
  form but did not expose a usable native file-selection control; no app bundle
  was attached or uploaded. The resulting empty draft release was discarded,
  and `1.0.0+20` remains the active Internal-track artifact. Upload therefore
  still requires either resolving the GitHub Actions billing gate or selecting
  the already-built AAB in the native Play upload dialog.
- **Release blocker — Premium allowance rollout:** the owner approved
  `40 PawSpark` at purchase and every seven days while Premium remains active.
  Local plan defaults, health checks, migration and mobile copy now match the
  decision, with clean/existing DB migration proof. The VPS migration and live
  database values are confirmed aligned. Active store product copy and a real
  renewal/cancellation lifecycle still have to prove idempotent granting.
- **Release blocker — native Stripe acceptance:** eligible Android Stripe
  checkout now uses native PaymentSheet. iOS/web retain hosted Checkout or
  store billing according to policy. The optional client-secret contract,
  narrow-screen Premium UI, production-flavor debug APK and minified release
  AAB pass locally, the backend is deployed on the VPS at commit `1f08a322`,
  and Android `1.0.0+20` is active on Play Internal. Focused verification on
  2026-08-25 passes 224
  backend economy tests, 68 auth/store security tests, 108 Flutter auth/payment
  tests and `flutter analyze`; this proves code contracts, not provider or
  physical-device acceptance. Install that exact release, then prove a Stripe
  test-mode payment, cancellation/retry and signed webhook reconciliation on a
  physical device before treating this as delivered.
  A read-only live API audit found the expected enabled production webhook and
  event set. The live Stripe catalog now has separate monthly and yearly
  Premium Prices at USD 0.99 and USD 1.99. The protected VPS environment and
  both production Premium rows contain their matching Stripe Price IDs; the
  public paywall API returns those IDs, the same prices, `40` PawSpark per
  seven-day grant interval, and recommends the yearly plan. No real live
  charge, signed webhook delivery, renewal, cancellation, refund, or restore
  has been accepted. Production provider routes are all `live`. An isolated
  staging API now responds at `api.staging.petgpt.app` with separate database,
  local paths and secrets, while production remains healthy. Its
  test credentials, test catalog and signed webhook delivery are accepted;
  an automated Android-mode PaymentSheet checkout activated Premium for an
  isolated staging user. A freshly built staging debug APK was installed on
  the physical Android device on 2026-08-25; it resolved
  `api.staging.petgpt.app` to the dedicated VPS and loaded the guest start
  screen without a server-unavailable state. This confirms the staging mobile
  endpoint, DNS and VPS route are aligned. The same isolated staging APK then
  presented Stripe's native Android `PaymentSheet` (with its `TEST` marker),
  accepted a Stripe test card and returned to the app; the staging subscription
  endpoint subsequently reported `isPremium=true` and `status=Active`. This
  accepts device-level sandbox presentation and activation only. Cancellation,
  renewal and refund remain pending. The
  physical Android selector rendering is
  accepted for build `1.0.0+15`; build `17` is now installed and accepted for
  native Google authentication and provider-specific selector copy, but its
  provider purchase, cancellation/retry and
  signed webhook proof remain pending.
- **iOS payment-policy guard:** the default and existing legacy iOS Stripe
  provider routes are disabled by migration `20260824223451`. It was deployed
  to the VPS on 2026-08-25; live `*` and `EU` rows confirm both
  `IsEnabled=false` and `ExternalCheckoutAllowed=false`. Apple external
  purchases require an approved entitlement plus StoreKit token and
  transaction-reporting work that PetMagic does not yet implement. App Store
  Billing remains the only iOS in-app payment route until that separate feature
  is implemented and accepted.
- **Release blocker — fal.ai generation canary:** runtime authorization is now
  accepted with the dedicated `petmagic-production-vps-billing` `ADMIN` key.
  The VPS env retained `0600 root:root`, preflight and supervisor restart
  passed, all containers are healthy, the billing endpoint returns HTTP 200,
  and `templates_fal_provider` is `Healthy`/`fresh` with zero consecutive
  failures. The superseded Render API key was revoked. A paid image/video
  generation, callback reconciliation and R2-import canary are still required.
- Google Play token-pack product IDs are derived from the active catalog as
  `com.petmagic.app.tokens.google.<pack-code>` rather than stored per pack.
  The Play Console now contains active standard **Buy** one-time products for
  `starter` (USD 0.99), `creator` (USD 1.49), and `viral` (USD 1.99), matching
  the VPS catalog and derived production IDs. Catalog configuration is
  complete; an eligible Internal tester still has to prove that each product
  is offered, purchased, verified by the backend, credited and consumed
  exactly once.
- App Store Connect contains the matching Apple consumables in `Prepare for
  Submission`: `com.petmagic.app.tokens.apple.starter` (20 PawSpark),
  `com.petmagic.app.tokens.apple.creator` (45 PawSpark), and
  `com.petmagic.app.tokens.apple.viral` (100 PawSpark). Their United States base
  prices were re-read on 2026-08-25 as USD 0.99, USD 1.49 and USD 1.99. The first
  in-app purchase must also be submitted with an app version. The three Apple
  consumables consistently target 28 storefronts: the United States plus 27
  European countries/regions, matching the intended US/Europe audience. This
  is catalog and availability evidence, not purchase, crediting, consumption,
  restore or refund proof.
- The production and retained Render databases both currently contain zero
  template items, categories and assets; this is not a VPS migration loss.
  Populate the production catalog only with approved template content and then
  verify R2-backed mobile feed/generation flows.
- The retained Render PostgreSQL directory export and persistent-disk archive
  passed an isolated restore audit on 2026-08-24. The temporary restore matched
  the recorded source hashes, produced 82 public tables, 99 EF migrations and
  one Data Protection key, then left zero temporary databases, directories or
  scripts. Production was not overwritten and remained healthy during the
  audit; retain the source archives until final launch sign-off.
- An iOS archive and store validation from a supported macOS/Xcode environment.
- A protected-VPS inspection confirms the Sign in with Apple client ID and
  audience are `com.petmagic.app`, with a configured client-secret JWT valid
  through `2027-01-27T05:15:02Z`. This proves configuration presence and expiry,
  not an Apple authorization-code exchange; complete the real iOS login flow.
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
