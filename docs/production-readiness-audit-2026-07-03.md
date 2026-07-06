# Production Readiness Audit - 2026-07-03

Status: partially ready

This report is the current working audit artifact for the repo-wide production
readiness pass. It records only evidence that was verified in the current
workspace, and it keeps local technical green separate from provider/device-backed
production readiness.

## Scope

- Backend, API contracts, background workers, logging, security guards, Docker,
  migrations, and runtime smoke paths.
- Flutter mobile build, analysis, tests, release packaging, and real Android
  device smoke.
- Admin web API boundary, env alignment, lint/typecheck/test/build gates.
- QA scripts, markdown docs, dependency/security checks, and repository hygiene.

## Current Verdict

The project is not blocked for continued hardening and release preparation, but
it is not yet ready for production release.

Production release remains partially ready because:

- Android production signing material is not present in the repo-local
  environment.
- Provider/device-backed staging smoke has not been proven with real FAL, R2,
  Stripe, Google Play, App Store, FCM, and APNs credentials/callbacks.
- Android Gradle still needs a future AGP built-in Kotlin/new DSL migration
  after the Flutter toolchain and Android plugin dependencies support it.
- The worktree is intentionally large and mixed; release commits should be split
  by subsystem before PR/release packaging.

## Objective Coverage Matrix

This matrix tracks the pasted production-readiness objective against current
evidence in this report. "Proved locally" means the current workspace has direct
source, build, test, config, or runtime evidence. It does not mean production
release is approved when external provider, signing, or staging evidence is
still missing.

| Objective area | Current status | Evidence / remaining gap |
| --- | --- | --- |
| 1. Repository hygiene and stale artifact cleanup | Proved locally, with broad dirty-tree caveat | Stale/scratch removals are listed, tracked build/cache/temp artifacts were scanned, suspicious names were classified, and current dirty scope is inventoried. Release still needs commit splitting because the worktree is intentionally broad. |
| 2. Backend build, contracts, services, security, logging, payments, generation, storage | Proved locally for code/test gates; external payment/provider callbacks still missing | Restore/build/test, route hardening, validation, logging privacy, media path safety, Google Play idempotency unit coverage, and API smokes passed. Real Stripe/store/provider callback evidence remains external. |
| 3. EF migrations and database state | Proved locally against clean/existing/Docker local-smoke evidence | Pending-model checks passed for active contexts, Docker DB has 73 applied migrations matching repo migration files, key wallet/payment/generation schema invariants were inspected, and destructive forward migration hits were reviewed. |
| 4. Mobile Flutter app stability, configs, assets, lifecycle, networking | Proved locally for Flutter gates and Android smoke; store/iOS proof still missing | `flutter pub get`, analyze, full tests, targeted production-networking tests, debug APK, release bundle, real Android gallery smoke, Android manifest scans, and asset inventory passed. iOS store artifact and store sandbox flows are not proven in this Windows workspace. |
| 5. Admin/tools/scripts | Proved locally | `npm ci`, lint, typecheck, tests, production build, API-boundary tests, script syntax checks, script safety inventory, and staging-runner local-target rejection checks passed. |
| 6. Docker and infrastructure | Proved locally for config/local-smoke/default-stack evidence | Compose config gates passed for example/local-smoke/staging envs, isolated Docker stack rebuilt healthy, default backend/generation-worker containers were recreated from current `.env`, API/feed/admin/Postgres smokes passed, and source appsettings parsed. |
| 7. Documentation | Proved locally | Markdown local-link checks passed, stale status docs and obsolete guidance were removed or marked historical, and current release status is centralized in this report. |
| 8. Dependencies | Proved locally for audits; upgrades deferred by risk | .NET vulnerable audit is clean, admin `npm audit` is clean, admin outdated items are dev tooling, Flutter outdated items remain constraint-bound, and .NET package upgrades are recorded as separate risk-managed tasks. |
| 9. Code quality and architecture boundaries | Partially proved; large-file refactor remains follow-up | Admin API boundary and mobile presentation/data boundary tests passed, direct runtime debug/logging scans are clean except allowlisted wrappers, and large files are inventoried. Broad file splitting remains a separate subsystem refactor. |
| 10. Production-readiness security and loss-prevention scenarios | Partially proved locally; external end-to-end scenarios still blocked | Local guards cover hardcoded dev URLs, secret scans, local/private URL rejection, webhook/idempotency unit tests, wallet/generation refund paths, push-token handling, and media safety. Real Stripe/FAL/R2/store/push callback and replay evidence remains missing. |
| 11. Minimum command gates | Proved locally where credentials/toolchain allow | Backend restore/build/test/migrations/API smoke, mobile pub/analyze/test/debug/release-bundle/Android smoke, admin install/lint/typecheck/test/build, Docker config/up/smoke, scripts/docs checks all have recorded evidence. Signed Android AAB and iOS artifact require external signing/toolchain context. |
| 12. Change constraints | Proved locally in this audit artifact | Public-contract changes are paired with mobile/admin/backend tests where changed, risky provider/signing work is not faked locally, and external gaps are reported instead of hidden. |
| 13. Final report deliverables | Current working report is present; final release claim remains blocked | This report lists changed areas, removed files, command evidence, migration/database evidence, retained compatibility holds, risks, blockers, and status. Final status remains `partially ready`. |

## Verified Gates

Backend:

- `dotnet restore PetMagic.slnx --disable-build-servers` passed in the latest
  `2026-07-04` backend rerun; all projects were up to date for restore.
- `dotnet build PetMagic.slnx --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false`
  passed in the latest `2026-07-04` backend rerun after the bounded provider
  JSON reader fix: 0 warnings, 0 errors, elapsed `00:00:08.72`.
- The current single-command backend solution no-build gate is green:
  `dotnet test PetMagic.slnx --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false`
  passed 1736/1736 tests with TRX evidence at
  `tests/PetMagic.Modules.Identity.Tests/TestResults/backend-full-after-raw-reader.trx`,
  elapsed `4 m 21 s`.
- The latest backend rerun first exposed 7 real provider-client regressions in
  `StoreSubscriptionVerifierCorrelationTests` and
  `FalQueueClientRateLimiterTests`: the bounded HTTP body reader sanitized
  provider JSON before parsing, replacing Google `access_token` values and fal.ai
  callback URLs with masked placeholders. The fix split raw bounded reads from
  sanitized log reads, switched provider JSON parsers to the raw reader, and
  added regression coverage. A focused build-backed rerun passed 82/82 tests
  before the final full 1736/1736 no-build pass.
- The previous backend gate had passed 1723/1723 after the image generation
  integration contract was updated to assert that provider cost remains
  persisted internally while user-facing generation responses suppress provider
  diagnostics.
- The earlier backend domain-batched rerun also passed: Economy 315/315,
  Gamification 35/35, Host 227/227, Identity 191/191, Infrastructure 14/14,
  SupportChat 204/204, Templates 686/686, and Validation 39/39, for 1711/1711
  tests. That earlier solution-level `1692/1692` pass was superseded by the
  current 1736/1736 full no-build gate after later backend guard additions and
  contract coverage.
- Targeted backend guard tests passed for route contracts, repository hygiene,
  environment contracts, correlation id privacy, DataProtection certificate
  loading, logging privacy, and scheduler/runtime hardening.
- Targeted backend validation-localization guard passed after a build-backed
  rerun:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~BackendValidationLocalizationTests"`
  passed 1/1 tests. This pins validators to stable validation codes instead of
  user-facing sentence literals.
- Targeted Google Play token-pack idempotency tests passed for both billing
  validation and direct store-purchase verification: purchase tokens are stored
  as `gpt_{sha256}` references, raw purchase tokens are not copied into new
  purchase/ledger records, repeat verification credits once, and legacy raw-token
  orders are recognized without a duplicate grant.
- Targeted payment/store loss-prevention reruns passed in the latest
  `2026-07-04` slice: backend Economy webhook, store, idempotency, billing,
  endpoint, and sanitization tests passed 243/243; mobile wallet/premium/Stripe
  submit guard/store availability/error mapping tests passed 71/71; admin
  economy and user-wallet tests passed 60/60.
- Latest focused mobile premium/payment rerun passed 35/35 tests:
  `flutter test test\premium_repository_test.dart test\premium_controller_test.dart test\wallet_repository_test.dart test\store_product_availability_cache_test.dart --reporter compact`.
  This includes the new repository-level store-purchase verification coverage
  proving the mobile client forwards the cancellation token and bearer-auth
  header to `/api/economy/premium/store/verify`.
- API route contract and endpoint-hardening rerun passed 82/82 targeted tests
  against the current backend build after a fresh test-project build and a
  no-build rerun.
- Targeted signed-media URL tests passed for avatar, support attachment, and
  template media read-url signers plus avatar/support response suppression after
  hardening encoded path separator and malformed percent-encoding handling.
- Targeted local media storage tests passed after applying the same conservative
  managed-path rejection to avatar, support attachment, and template local-file
  cleanup paths.
- Targeted R2/template storage path tests passed after applying the same
  conservative managed-path rejection to production object-key resolution,
  template media lifecycle persistence, and generation storage path normalization.
- Shared media path segment validation was extracted into BuildingBlocks so
  avatar, support attachment, local template, R2, lifecycle, generation, and
  read-url surfaces use one audited unsafe-segment implementation.
- Public generation share-token decoding was rechecked for malformed percent
  escapes, encoded separators, and encoded null input; the public service path
  and public JSON/HTML route layer return the same not-found contract instead of
  surfacing decode errors.
- EF migrations were checked for clean apply, existing database apply, Docker
  local-smoke apply, and pending model changes across the relevant module
  contexts.
- API runtime smoke passed for `/health` and `/api/templates/feed`.

Mobile:

- `flutter pub get` passed in the latest `2026-07-04` rerun. The solver still
  reports 16 packages with newer versions outside current constraints; this is
  dependency drift, not a restore failure.
- `flutter analyze --fatal-infos` passed with no issues in the latest
  `2026-07-04` rerun against the current mobile worktree.
- `flutter test --reporter compact` initially exposed a real mobile logging
  policy regression: 1288 tests passed and 1 failed because
  `wallet_store_purchase_recovery_store.dart` cleared malformed pending store
  purchase payloads through `catch (_)`. The recovery path now logs a sanitized
  `AppLogger.warn` event and clears the invalid payload without logging raw JSON.
  The focused rerun
  `flutter test test\templates_presentation_logging_contract_test.dart test\store_product_availability_cache_test.dart test\wallet_controller_lifecycle_test.dart --reporter compact`
  passed 49/49 tests, and the final full rerun
  `flutter test --reporter compact` passed 1289/1289 tests.
- `flutter test test\mobile_asset_inventory_test.dart --reporter expanded`
  passed: 3/3 tests.
- Latest focused mobile asset/config guard rerun:
  `flutter test test\mobile_asset_inventory_test.dart test\production_networking_config_test.dart --reporter compact`
  passed 16/16 tests, and
  `flutter test test\app_config_debug_tools_test.dart --reporter compact`
  passed 5/5 tests. The run also repeated dependency resolution and still
  reported the known 16 constraint-bound outdated package notices.
- Latest focused mobile premium/payment rerun:
  `flutter test test\premium_repository_test.dart test\premium_controller_test.dart test\wallet_repository_test.dart test\store_product_availability_cache_test.dart --reporter compact`
  passed 35/35 tests. Dependency resolution again reported the same 16
  constraint-bound outdated package notices.
- `flutter build bundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  passed for the Flutter asset bundle after tightening runtime asset
  declarations, and passed again in the `2026-07-04` rerun against the current
  worktree.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:5000`
  passed the Android Gradle `assembleDebug` path and produced
  `build\app\outputs\flutter-apk\app-debug.apk`.
- Real Android device smoke passed on device `R5CR126590A` using
  `adb reverse tcp:5000 tcp:5000` and
  `flutter test integration_test\gallery_cross_flow_test.dart -d R5CR126590A --dart-define=API_BASE_URL=http://127.0.0.1:5000 --reporter expanded`.
- Current Android device availability was rechecked again on `2026-07-04`:
  `adb devices` listed no attached devices, `adb reverse --list` returned
  `error: no devices/emulators found`, and `flutter devices` saw only Windows,
  Chrome, and Edge. Host `http://localhost:5000/health` with `Host: localhost`
  returned `200`/`Healthy`, and `/api/templates/feed?limit=3` returned `200`
  with two items. The repo-local VS Code USB profile still points at
  `API_BASE_URL=http://127.0.0.1:5000` with prelaunch
  `adb reverse tcp:5000 tcp:5000`, but a fresh device launch cannot be claimed
  from this environment state.
- Mobile debug API resolution now documents and tests both the host `5000`
  path and the Docker compose `5001` fallback path. Targeted resolver/security
  tests passed for the added fallback coverage.
- Mobile external URL policy now uses a conservative local/private IPv4
  classifier for release-style HTTP rejection, including wildcard, loopback,
  CGNAT, link-local metadata, RFC1918, and multicast/reserved ranges.
- Targeted mobile production-networking rerun passed on `2026-07-04`: external
  URL policy, app-config security, and production-networking guards passed
  22/22 tests; API base-url lifecycle and Android loopback hint coverage passed
  8/8 tests. Native config scans confirmed Android main keeps
  `usesCleartextTraffic="false"`, debug/profile source sets intentionally keep
  local cleartext overrides, iOS transport/debug URL markers were clean, and no
  Android/iOS Impeller opt-out marker was found.
- Production signing guard correctly blocks `flutter build appbundle --release`
  when `android/key.properties` is absent.
- The signing guard was rechecked against the current `2026-07-04` worktree:
  `apps/petmagic-mobile/android/key.properties` is absent, no `*.jks`,
  `*.keystore`, or `key.properties` file exists under `apps/petmagic-mobile`,
  and `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  failed at `android/app/build.gradle.kts` line 76 with
  `Release signing is not configured. Add android/key.properties with release keystore or set -PallowInsecureReleaseSigning=true only for local temporary builds.`
- Local release packaging check passed with explicit insecure local signing:
  `.\gradlew.bat :app:bundleRelease -PallowInsecureReleaseSigning=true --warning-mode all`
  completed successfully in the current worktree with 724 actionable tasks.
- Mobile CI now preserves that packaging/R8 smoke with the same explicit
  `allowInsecureReleaseSigning` override; it remains separate from the real
  production-signing gate.

Admin web:

- `npm ci` passed in the latest `2026-07-04` admin install rerun: 410 packages
  installed, 411 packages audited, and 0 vulnerabilities found.
- Admin lint and typecheck passed again after that `npm ci` in the latest
  `2026-07-04` rerun: `eslint .` exited 0 and route type generation completed
  before typecheck success.
- Admin tests and production build passed again in the latest `2026-07-04` rerun:
  `npm test` passed 85/85 files and 656/656 tests, and `npm run build` completed
  the Next.js 16.2.10 optimized production build, TypeScript, static page
  generation, route listing, and route trace collection.
- The latest full admin test rerun initially caught stale source-contract
  assertions after dashboard/economy/moderation source formatting and component
  extraction changed. The assertions now use whitespace-tolerant contract checks
  while preserving the same guarantees for localized copy, chart currency
  formatting, and React Query `AbortSignal` propagation.
- Admin lint initially caught a `react-hooks/set-state-in-effect` violation in
  `src/lib/support-realtime.ts`; the realtime status subscription now uses
  `useSyncExternalStore`, and the support realtime source-contract test was
  updated to pin that external-store pattern.
- Admin tests caught a stale `.env.local-smoke.example` assertion for the old
  local API port; `src/lib/next-config-env.test.ts` now pins the current
  isolated local-smoke `NEXT_PUBLIC_API_BASE_URL=http://localhost:5601`
  contract.
- Added API-boundary coverage so admin web cannot drift into direct DB/backend
  layer usage. The latest strict scan found only two localized/metadata
  `PetMagic` copy strings and no DB or backend-layer import matches.
- Fresh `2026-07-04` Admin-to-API boundary refresh passed
  `npm test -- src\lib\admin-api-boundary.test.ts
  src\lib\dependency-inventory.test.ts
  src\lib\api-client-admin-users-query.test.ts
  src\lib\api-client-economy-query.test.ts
  src\lib\api-client-support-query.test.ts
  src\lib\api-client-templates-query.test.ts`: 6/6 files and 65/65 tests.
  Direct source scans over `apps/admin-web/src` found 0 matches for forbidden
  DbContext/EntityFramework/backend-module imports, database connection strings,
  SQL/ORM client usage, or repository patterns. `apps/admin-web/package.json`
  still contains 0 direct DB client package dependencies.
- Latest admin package-script refresh parsed `apps/admin-web/package.json` and
  confirmed only conventional Next/Vitest/ESLint/Prettier scripts are exposed:
  `dev`, `dev:turbo`, `build`, `start`, `lint`, `lint:fix`, `typecheck`,
  `format`, `format:check`, `test`, `test:watch`, and `test:coverage`. The scan
  found 0 DB client dependencies and no destructive DB/reset package scripts.
- Staging API host alignment is covered by `next-config-env` tests.
- Admin production API URL guards reject localhost, private-network, wildcard,
  Docker host, and compose-service origins by default, while preserving explicit
  local-smoke opt-in for localhost/backend compose targets.
- Admin secure-media helpers for template previews, support attachments, and
  user avatars now share one unsafe-host policy and block localhost,
  `.localhost`, Docker host, compose-service, wildcard, private IPv4, private
  IPv6, and placeholder media origins before direct rendering or browser fetch.

Docker and infrastructure:

- `docker compose --env-file .env.example config --quiet` passed again in the
  latest `2026-07-04` rerun.
- `docker compose --env-file .env.local-smoke.example config --quiet` passed
  again in the latest `2026-07-04` rerun.
- `docker compose --env-file .env.staging.local.example config --quiet` passed
  again in the latest `2026-07-04` rerun.
- The three compose/env config gates were rerun against the current dirty
  worktree after the mobile/admin hardening slices and local-smoke API URL test
  alignment, and still passed without interpolation or profile conflicts.
- All eight source `appsettings*.json` files under `src/Host/PetMagic.Host.Api`
  and `src/Host/PetMagic.Host.GenerationWorker` were parsed individually with
  `ConvertFrom-Json`, excluding `bin`/`obj` copies; every source file parsed
  successfully.
- The current `docker-compose.yml` has 12 required interpolation variables
  (`${VAR:?...}` / `${VAR?...}`), and `.env.example`,
  `.env.local-smoke.example`, and `.env.staging.local.example` each define all
  12 required keys.
- Local `.env` compose management drift was fixed: the file had local backend
  URLs but was missing the now-required `BACKEND_ALLOWED_HOSTS` and
  `BACKEND_HEALTHCHECK_HOST` variables, causing
  `docker compose --env-file .env ps` to fail before Docker inspection. After
  adding localhost/backend allowed-host values, `docker compose --env-file .env
  config --quiet` and `docker compose --env-file .env ps` both passed.
- A fresh `2026-07-04` default-stack runtime recheck first found the running
  `petmagic-0_004-backend-1` container was still on an older container
  environment with a production-only `AllowedHosts` value. Recreating the default
  backend/generation-worker containers exposed and then fixed a real scheduler
  parity issue: the backend compose environment was missing several
  fingerprinted generation scheduler keys that the worker received. After
  adding the same fingerprint keys to the backend service, `docker compose
  --env-file .env up -d --build --force-recreate --wait --wait-timeout 240
  backend generation-worker` completed with backend and generation-worker
  healthy.
- The post-fix default-stack proof now shows backend, generation-worker,
  Postgres, and Mailpit healthy. Backend effective `AllowedHosts` is
  `localhost;127.0.0.1;[::1];backend`; backend and worker both receive
  `Templates__MaxConcurrentJobsPerWorker=1`,
  `Templates__MaxAiProviderRequestsPerMinute=60`,
  `Templates__MaxGenerationAttempts=3`,
  `Templates__JobLockTimeoutMilliseconds=900000`, and
  `Templates__OrphanQueuedJobTimeoutMilliseconds=120000`.
- Default-stack host `/health` with `Host: localhost` returned `Healthy` with
  `schedulerConfig.initialized=true` and `isMismatchDetected=false`;
  `/api/templates/feed?limit=3` returned `200`. The latest database
  `templates_runtime_config_fingerprints` rows for API and generation-worker
  have matching checksum
  `5fc8bcdb3810687feb050bf11f79e0b7d4f1d5bcb89e8c6f01b18408ea345233` and
  `MismatchDetected=false`. Logs since the recreate contain no scheduler
  mismatch, fatal startup, or unhandled exception lines.
- `.env.local-smoke.example` was corrected to be self-contained for isolated
  compose probes. A fresh `petmagic_goal_probe` rebuild first exposed that
  Mailpit still mapped default host ports `1025/8025`, colliding with the
  default stack. The local-smoke env now owns isolated host ports for postgres,
  backend, admin, and Mailpit (`56543`, `5601`, `3600`, `1625`, `8625`), and the
  README local-smoke command no longer relies on ad-hoc shell overrides.
- Monitoring profile config passed.
- Running Docker backend/generation-worker/postgres health was verified. Current
  runtime smoke is strongest for the isolated `petmagic_goal_probe` stack:
  `docker compose --env-file
  .env.local-smoke.example -p petmagic_goal_probe up -d --build --wait
  --wait-timeout 240` completed again after the backend bounded provider JSON
  reader fix, rebuilding backend, generation-worker, and admin-web images from
  the current worktree. All isolated services became healthy.
- The fresh isolated smoke after that rebuild showed backend `5601`, admin
  `3600`, postgres `56543`, and Mailpit `1625/8625` up; backend and
  generation-worker healthy; host `/health` and backend-container `/health`
  returned `Healthy`; host `/api/templates/feed?limit=3` returned valid JSON
  with `items: []`, `hasMore: false`, and
  `generatedAtUtc=2026-07-04T10:27:28.032803Z`; Postgres `pg_isready` accepted
  connections; admin host `/ru` returned HTML; Docker Postgres still contains 73
  applied EF migrations and 66 public base tables.
- The running isolated `petmagic_goal_probe` stack was rechecked after the admin
  local-smoke URL contract fix: backend `5601`, admin `3600`, postgres `56543`,
  and Mailpit `1625/8625` were up; backend and generation-worker were healthy;
  host `/health`, host `/api/templates/feed?limit=3`, backend-container
  `/health`, Postgres `pg_isready`, and admin host `/ru` all returned successful
  responses.
- The isolated `petmagic_goal_probe` runtime was rechecked again on
  `2026-07-04`: `docker compose ... ps` showed admin, backend,
  generation-worker, mailpit, and postgres up for roughly 4 hours, with backend,
  generation-worker, mailpit, and postgres marked healthy. Host `/health` and
  backend-container `/health` both returned `Healthy` with
  `processStartedAtUtc=2026-07-04T00:20:44.2195404+00:00`;
  host `/api/templates/feed?limit=3` returned valid JSON with `items: []`,
  `hasMore: false`, and `generatedAtUtc=2026-07-04T03:53:18.2106716Z`;
  admin host `/ru` returned `HTTP/1.1 200 OK`; and Postgres `pg_isready`
  accepted connections.
- The latest runtime recheck on `2026-07-04T10:53Z` found the isolated
  `petmagic_goal_probe` stack still up: admin-web, backend, generation-worker,
  Mailpit, and Postgres were running, with backend, generation-worker, Mailpit,
  and Postgres healthy. Host `http://localhost:5601/health` returned `Healthy`
  with `processStartedAtUtc=2026-07-04T10:26:59.3255591+00:00`; host
  `/api/templates/feed?limit=3` returned valid empty JSON with
  `generatedAtUtc=2026-07-04T10:53:21.3962695Z`; admin
  `http://localhost:3600/ru` returned `HTTP/1.1 200 OK`; isolated Postgres
  accepted `pg_isready` and still had 73 applied migrations.
- The default compose stack was also rechecked on `2026-07-04T10:54Z`: backend
  and generation-worker were healthy, host `http://localhost:5000/health`
  returned `Healthy` with `processStartedAtUtc=2026-07-04T04:43:06.4511186+00:00`,
  host `/api/templates/feed?limit=3` returned valid JSON with two active template
  items, admin `http://localhost:3000/ru` returned `HTTP/1.1 200 OK`, default
  Postgres accepted `pg_isready`, and the default database had 73 applied
  migrations.
- The default compose stack was refreshed again on `2026-07-04T12:28Z`:
  `docker compose ps` showed backend and generation-worker still `healthy`, with
  admin-web on `3000`, backend on `5000`, Postgres on `5432`, and monitoring
  services still running. Host `http://localhost:5000/health` returned `200`
  and `Healthy` with
  `processStartedAtUtc=2026-07-04T04:43:06.4511186+00:00`; host
  `/api/templates/feed?limit=3` returned `200` with two template items,
  `hasMore=false`, and `generatedAtUtc=2026-07-04T12:28:53.2685043Z`; admin
  `http://localhost:3000/ru` returned `200`; default Postgres accepted
  `pg_isready`, reported 73 rows in `__EFMigrationsHistory`, 66 public base
  tables, and latest migration
  `20260702234729_AddGenerationBillingReconciliationIndexes`.
- The isolated Docker Postgres database was inspected after startup. The single
  EF history table contains 73 applied migrations, matching the 73 current
  non-designer migration files in the repo, and the app schema contains 66
  application tables. Key token/payment/generation tables exist with expected
  non-null columns, primary keys, non-negative wallet constraints, generation
  billing FKs, webhook/payment idempotency indexes, and generation job active
  idempotency/request-hash indexes.

Scripts and docs:

- `node --check` passed for all 22 `scripts/**/*.js` and `scripts/**/*.mjs`
  files in the latest `2026-07-04` rerun.
- PowerShell AST parser validation passed for all 7 repo `.ps1` scripts in the
  latest rerun, excluding generated/build/cache directories; no script was
  executed during this syntax check.
- Shell syntax validation passed for all 7 repo `.sh` scripts after rerunning
  `bash -n` with repo-relative forward-slash paths. The first Windows
  absolute-drive path attempt failed before script parsing, so it is not treated
  as a script failure.
- Python compile validation passed for all 4 repo `scripts/**/*.py` files.
- QA self-tests passed in the latest rerun: script safety inventory, markdown
  local-link checker, watermark QA help behavior, template-feed load probe,
  staging snapshot, release gate, admin QA report draft, long-scroll promoter,
  and TZ1-8 evidence validator.
- The tooling/docs refresh was rerun again after the latest runtime/report
  updates: `node --check` passed for all 22 JS/MJS files under `scripts`,
  PowerShell AST parsing passed for all 7 repo `.ps1` files, and the QA
  self-tests passed for script safety inventory, markdown local-link checker,
  watermark QA help, template-feed load probe, staging snapshot, release gate,
  admin QA report draft, long-scroll promoter, and TZ1-8 evidence validator.
  `node scripts\qa\check-markdown-local-links.mjs` also still reports
  `Markdown local links ok (46 files checked)`.
- Current scripts/tooling inventory now covers 47 files: 5 GitHub workflow YAML
  files plus repo scripts across JS/MJS, PowerShell, shell, Python, CMD, K6, and
  QA helpers. The refreshed syntax/safety rerun passed for 22 JS/MJS files,
  7 PS1 files, 7 shell scripts, 4 Python scripts, 2 CMD wrappers inventoried,
  and 8 QA/tooling self-tests with 0 failures.
- Production-source debug/console scans were rechecked across backend `src`,
  admin web `src`, and mobile `lib`; backend has no direct console/debug output,
  mobile has no direct `print`/`debugPrint` and only allowlisted
  `developer.log` wrappers, and admin has no direct `console.log`/`debugger`
  use outside tests. The latest read-only commands were:
  `rg -n "Console\.Write(Line)?|Debug\.Write(Line)?|Trace\.Write(Line)?|Debugger\.|System\.Diagnostics\.Debug|System\.Diagnostics\.Trace" src -g "*.cs" -g "!**/bin/**" -g "!**/obj/**"`,
  `rg -n "console\.(log|debug|trace)|debugger\b" apps/admin-web/src -g "*.ts" -g "*.tsx" -g "!**/*.test.ts" -g "!**/*.test.tsx"`,
  and `rg -n "\bprint\(|debugPrint\(" apps/petmagic-mobile/lib -g "*.dart" -g "!**/*.g.dart"`.
- A latest `2026-07-04` runtime-source marker scan excluded tests, generated
  code, migrations, build/cache output, and CLI scripts, then checked backend,
  admin, and mobile runtime source for `TODO`, `FIXME`, `HACK`, `XXX`,
  `NotImplementedException`, `debugger`, direct console output, `print(`,
  `debugPrint(`, and user-facing stub phrases such as `not configured yet`.
  It found no actionable runtime leftovers; the only direct admin console matches
  were the intentionally centralized sanitized `clientLogger.warn/error` sinks.
- The runtime-source marker scan was rerun again against the current worktree on
  `2026-07-04`. Backend `src` had no matches for direct console/debug output or
  leftover markers after excluding migrations/tests/build output. Admin runtime
  matches remain limited to `apps/admin-web/src/lib/client-logger.ts`
  `console.error/warn`, and mobile runtime matches remain limited to
  `AppLogger` plus `RequestIdentity` `developer.log` wrappers.
- The follow-up `2026-07-04` production-sensitive code/config marker sweep also
  checked backend `src`, mobile `lib`/native folders, admin `src`/`next.config`,
  env examples, Docker, deploy, workflow, and QA script files for local URLs,
  secret-looking markers, bypass/debug markers, and direct logging calls.
  Reviewed hits were expected and guarded: backend `AllowAnyOrigin` is limited to
  Development and non-development CORS requires configured origins, mobile
  `developer.log` calls are centralized/sanitized with debug-only stack traces,
  admin localhost paths are behind production rejection tests or local-smoke
  opt-ins, test secret strings are sanitizer fixtures, and local URLs in
  `.env.local-smoke.example`/Development config are explicitly local-only.
- A refined tracked/untracked filename scan for real scratch/backup/temp
  patterns found no untracked scratch files. The six tracked matches were
  reviewed and classified as intentional: debug Android manifests in debug/example
  source sets, mobile `TempMediaCleanup` source/tests, the mobile debug-tools
  test, and `scripts/backup-postgres.ps1` as an active maintenance script.
- The current-state repo hygiene refresh on `2026-07-04` scanned
  `git ls-files -co --exclude-standard` across 2366 tracked/untracked
  non-ignored paths. The suspicious filename pattern produced only 3 false
  positives caused by intentional `copy` source/test names:
  `apps/admin-web/src/lib/i18n-ru-copy.test.ts`,
  `apps/admin-web/src/components/templates/template-analytics-copy.ts`, and
  `apps/petmagic-mobile/lib/core/notifications/notification_foreground_copy.dart`.
  It found 0 tracked build/cache leaks.
- Ignored test-output cleanup removed
  `tests/PetMagic.Modules.Identity.Tests/TestResults` after verifying the
  resolved path stayed inside the workspace. The removed directory contained 45
  temporary runner/TRX files totaling 44,933,212 bytes. A follow-up ignored-status
  scan no longer reported `TestResults`, `.trx`, coverage, log, or tmp outputs
  under `tests`.
- Full ignored/generated dry-run inventory found 102 remaining ignored entries
  after cleanup. They are expected local/dependency/build/evidence state:
  `.env`, IDE folders, admin `.next`/`node_modules`, Flutter `.dart_tool`/build
  outputs, Android/iOS generated Flutter files, .NET `bin`/`obj`, and local
  audit evidence under `artifacts`/`backend/artifacts`. These were not deleted
  because they are either local configuration/dependencies, reproducible build
  caches, or evidence artifacts referenced by this audit.
- Ignored Python bytecode cleanup removed `scripts/qa/__pycache__` after
  verifying the resolved path stayed inside the workspace. The removed cache
  contained 4 `.pyc` files totaling 41,158 bytes; follow-up ignored status and
  `git clean -ndX` scans no longer reported `__pycache__`.
- Manual API scratch/export scan found only the already-deleted tracked cleanup
  path `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http`; no live Postman,
  Insomnia, HAR, or exported OpenAPI artifact remained in tracked/untracked
  non-ignored files.
- Production-code TODO/FIXME/HACK marker scan found no runtime source markers.
  Matches were limited to template-feed QA tooling that intentionally creates
  draft Admin QA rows as `TODO` and rejects them as final release evidence.
  `node scripts\qa\test-template-feed-admin-qa-report-draft.mjs` passed in the
  same refresh.
- Fresh logging wrapper guards passed after the direct logging scan classified
  admin `client-logger.ts`, mobile `AppLogger`, and mobile `RequestIdentity` as
  centralized sanitized wrappers: admin logging tests passed 3/3 files and
  19/19 tests; mobile logging/correlation tests passed with `All tests passed!`
  and 42/42 tests.
- README, mobile README, agent rules, and release-size audit docs were updated
  to remove stale `/dev/null` compose guidance, stale `docker-compose`
  references, and the obsolete R8 failure claim.
- Markdown local-link checks passed for the updated release/audit docs.
- `git diff --check` reported only CRLF normalization warnings, not whitespace
  errors.

Dependencies/security:

- .NET vulnerable package check found no vulnerable packages.
- `dotnet list PetMagic.slnx package --deprecated` found no deprecated packages
  in production projects. The only deprecated package signal is `xunit 2.9.3` in
  `PetMagic.Modules.Identity.Tests`, reported as `Legacy` with `xunit.v3` as the
  alternative; this is tracked as a test-framework migration follow-up, not a
  runtime release blocker.
- Admin `npm audit` reported 0 vulnerabilities.
- Admin web CI now runs `npm audit --audit-level=moderate` after `npm ci`.
- `flutter pub outdated` completed successfully. No dependency was upgraded
  during this audit; the actionable follow-up is limited to routine package
  drift review, with direct `intl` `0.20.2 -> 0.20.3` still constraint-bound
  and locked transitive packages `cross_file` and `in_app_purchase_storekit`
  showing newer resolvable patch versions.
- Outdated package/deprecation warnings remain tracked as follow-up work rather
  than bulk-updated during this audit.

## Files Removed As Stale Or Scratch

- `.mimocode/plans/1782243995518-gentle-squid.md`
  - Removed as a stale generated plan.
  - Usage was checked before deletion.
- `docs/md/STATUS.md`
  - Removed as an obsolete status snapshot.
  - Current release state is now tracked in focused release/audit docs.
- `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http`
  - Removed as a manual scratch/demo HTTP file.
  - It contained development/demo requests and no active runtime contract.
- `apps/admin-web/public/.gitkeep`
  - Removed as an empty Next.js public placeholder.
  - `public` is not required when empty, and `.gitkeep` would otherwise be a
    served static file.
- `GoogleService-Info.plist`
  - Removed as an unused root-level Firebase placeholder.
  - The active mobile config placeholders remain under
    `apps/petmagic-mobile/android/app/google-services.json` and
    `apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist`.

## Notable Updated Areas

- Env examples and Docker compose:
  `.env.example`, `.env.local-smoke.example`, `.env.staging.local.example`,
  `docker-compose.yml`, monitoring Dockerfiles, and healthcheck host settings.
- Backend production guards:
  `HostApiProductionConfigurationValidator`, repository hygiene tests,
  environment contract tests, route contract tests, correlation/log privacy, and
  scheduler/runtime health checks.
- Backend signed media guards:
  avatar, support attachment, and template media read-url signers now reject
  encoded path separators and malformed percent-encoding instead of signing or
  authorizing ambiguous managed media paths. Avatar/support response helpers use
  the same managed-path rejection before exposing stored media URLs.
- Backend local media storage cleanup:
  avatar, support attachment, and template local storage now reject encoded path
  separators and malformed percent-encoding before resolving managed delete paths.
- Backend R2/template object-key handling:
  R2 media storage, template media lifecycle persistence, and generation storage
  path resolution now reject encoded path separators and malformed
  percent-encoding before treating a URL/object key as managed storage.
- Backend shared helper cleanup:
  duplicate invalid-percent/decoded-separator helper implementations were removed
  from module infrastructure classes and replaced with
  `PetMagic.BuildingBlocks.Storage.ManagedPathSegments`.
- Backend public share-token guard:
  generation share-token decoding now has explicit regression coverage for
  malformed percent escapes, encoded slash/backslash, and encoded null bytes.
  A decoding surface scan found the remaining production `Uri.UnescapeDataString`
  uses in the shared managed-path helper and the generation share-token decoder;
  the other hit is a test-only localization assertion. The public share JSON API
  and public HTML page routes also have integration coverage for those
  double-encoded malformed token inputs.
- Mobile hardening:
  logging privacy, direct debug-log guardrails, lifecycle cleanup,
  notification/token registration, templates/generation/gallery flows,
  wallet/premium recovery paths, localization, debug API fallback coverage for
  `5000`/`5001`, release networking/local-host rejection, and Android release
  signing guard.
- Mobile assets:
  runtime asset declarations now include only the two premium hero files from
  `assets/branding`, while `petmagic-app-icon-1024.png` remains in the repo as a
  source asset for icon generation scripts but no longer enters
  `build/flutter_assets`.
- Admin web hardening:
  typed API clients, secure media handling, support/users/templates/economy page
  tests, query-key isolation, client logger privacy, centralized console-output
  policy, local/private production API URL rejection, and API boundary tests.
- QA/docs:
  staging rollout docs, scheduler rollout docs, observability docs, load testing
  docs, mobile release-size audit, markdown local-link checker, psql helpers,
  and watermark QA scripts.

## Current Change Inventory

Current branch and `git status --short` scope at the time of this report update:

- Branch: `codex/release-blockers-hardening`.
- Total dirty entries: 863 in the latest `2026-07-04` rerun.
- Tracked dirty entries: 804.
- Deleted tracked files: 6.
- Untracked files: 59.
- Renamed entries: 0.

Current dirty scope by top-level area:

- `apps`: 472 entries.
- `src`: 211 entries.
- `tests`: 115 entries.
- `docs`: 25 entries.
- `scripts`: 17 entries.
- `deploy`: 6 entries.
- `.github`: 5 entries.
- `.config`: 1 entry.
- `.mimocode`: 1 deleted stale-plan entry.
- Root/config files: `.dockerignore`, `.env.example`,
  `.env.local-smoke.example`, `.env.staging.local.example`, `.gitignore`,
  `Directory.Build.props`, `Directory.Packages.props`, `README.md`,
  `docker-compose.yml`, `GoogleService-Info.plist`.
- Removed stale tracked paths:
  `.mimocode/plans/1782243995518-gentle-squid.md`, `docs/md/STATUS.md`,
  `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http`,
  `apps/admin-web/public/.gitkeep`, `GoogleService-Info.plist`.
- Current additional tracked deletion:
  `apps/petmagic-mobile/lib/shared/payments/stripe_paymentsheet_coordinator.dart`.
  Reference scan found only
  `apps/petmagic-mobile/test/monetization_external_launch_guard_test.dart`
  guarding that removed internal coordinator, so it is tracked under the mobile
  monetization refactor lane rather than the stale scratch-removal lane.
- Latest temporary/backup artifact refresh scanned 2376 tracked and untracked
  paths outside ignored build/vendor/evidence directories for suspicious names
  such as `.bak`, `.backup`, `.old`, `.orig`, `.rej`, `.tmp`, `.temp`, `.log`,
  `.dump`, `.cache`, `Thumbs.db`, backup/tmp/temp directories, and copy suffixes.
  It found 0 matches outside ignored evidence artifacts. The broader unignored
  filesystem scan found `.log` files only under ignored `artifacts/**` release
  evidence directories; `.gitignore` and `.dockerignore` both exclude
  `artifacts/`, logs, temporary files, and backup file extensions.

Review buckets from the audited split-planning snapshot remain the working
classification for commit planning. Deleted stale paths are included in their
owning area; the repo cleanup/removals lane covers the two root-level stale
entries that do not belong to a subsystem. Refresh exact file-level membership
from `git status --short` before staging.

- Admin web UI/API-boundary hardening: 208 entries.
- Mobile app hardening, tests, localization: 245 entries.
- Backend test coverage: 108 entries.
- Backend templates/generation/storage hardening: 81 entries.
- Backend host, identity, and shared building-blocks hardening: 48 entries.
- Backend economy/payments hardening: 44 entries.
- Docs and audit reports: 25 entries, including root `README.md`.
- Backend support-chat hardening: 27 entries.
- QA scripts: 17 entries.
- Docker/env/monitoring infrastructure: 10 entries.
- CI/repo tooling: 8 entries.
- Backend gamification hardening: 2 entries.
- Repo cleanup/removals and root-level contracts: 4 entries.

Release split plan before PR packaging:

1. Backend safety primitives and host/identity/gamification hardening.
2. Backend economy/payments hardening with its focused tests.
3. Backend templates/generation/storage hardening with migration and media tests.
4. Backend support-chat hardening with attachment/realtime tests.
5. Admin web API-boundary, secure media, localization, and realtime-store fixes.
6. Mobile networking, lifecycle, payments/templates/support, localization, and
   asset/release-signing guard fixes.
7. Docker/env/monitoring and CI/repo hygiene tooling.
8. QA scripts and documentation/audit report updates.
9. Stale-path removals after each owning subsystem commit proves no remaining
   references.

Important untracked audit-owned additions currently visible:

- Repo tooling:
  `.config/dotnet-tools.json`,
  `.github/workflows/repo-hygiene-ci.yml`.
- Admin web tests/helpers:
  `apps/admin-web/src/components/admin-shell-localization.test.ts`,
  `apps/admin-web/src/lib/admin-api-boundary.test.ts`,
  `apps/admin-web/src/lib/admin-unsafe-remote-host.ts`,
  `apps/admin-web/src/lib/dependency-inventory.test.ts`,
  `apps/admin-web/src/lib/i18n-ru-copy.test.ts`.
- Mobile shared payment/test additions:
  `apps/petmagic-mobile/lib/shared/payments/external_checkout_result.dart`,
  `apps/petmagic-mobile/test/app_lifecycle_signal_test.dart`,
  `apps/petmagic-mobile/test/app_preferences_storage_test.dart`,
  `apps/petmagic-mobile/test/generation_gallery_store_lifecycle_test.dart`,
  `apps/petmagic-mobile/test/mobile_architecture_boundary_test.dart`,
  `apps/petmagic-mobile/test/mobile_asset_inventory_test.dart`, and
  `apps/petmagic-mobile/test/premium_repository_test.dart`.
- Monitoring Dockerfiles:
  `deploy/monitoring/alertmanager/Dockerfile`,
  `deploy/monitoring/grafana/Dockerfile`,
  `deploy/monitoring/otel-collector/Dockerfile`,
  `deploy/monitoring/prometheus/Dockerfile`,
  `deploy/monitoring/tempo/Dockerfile`.
- Docs:
  `docs/economy-technical-validation-final.md`,
  `docs/gallery-release-branch-prep-2026-07-03.md`,
  `docs/localization-and-theme.md`,
  `docs/production-readiness-audit-2026-07-03.md`.
- QA scripts:
  `scripts/qa/check-markdown-local-links.mjs`,
  `scripts/qa/psql.cmd`, `scripts/qa/psql.ps1`,
  `scripts/qa/test-markdown-local-links.mjs`,
  `scripts/qa/test-script-safety-inventory.mjs`,
  `scripts/qa/test-watermark-qa-help.mjs`.
- Shared safety helpers:
  `src/BuildingBlocks/PetMagic.BuildingBlocks/Observability/SafeHttpContentReader.cs`,
  `src/BuildingBlocks/PetMagic.BuildingBlocks/Observability/SafeLogValues.cs`,
  `src/BuildingBlocks/PetMagic.BuildingBlocks/Storage/ManagedPathSegments.cs`.
- Backend bounded provider JSON parsing:
  `src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/Payments/StoreSubscriptionVerifier.GooglePlay.cs`,
  `src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/Payments/StripePaymentGateway.Helpers.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Api/FalWebhookSignatureVerifier.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FalProviderHealthService.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FalQueueClient.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateLocalizationTranslator.cs`.
- Backend validation response helpers:
  `src/Modules/Economy/PetMagic.Modules.Economy.Api/Endpoints/ValidationProblemCodeExtensions.cs`,
  `src/Modules/Identity/PetMagic.Modules.Identity.Api/Authentication/ExternalAuthTicketPayloadProtection.cs`,
  `src/Modules/Identity/PetMagic.Modules.Identity.Api/Endpoints/ValidationProblemCodeExtensions.cs`,
  `src/Modules/SupportChat/PetMagic.Modules.SupportChat.Api/Endpoints/ValidationProblemCodeExtensions.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Api/Endpoints/ValidationProblemCodeExtensions.cs`.
- Template infrastructure additions:
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/AdminFailureMessageSanitizer.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/Data/Migrations/20260702234729_AddGenerationBillingReconciliationIndexes*.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/ProcessOutputDrainer.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateLogSanitizer.cs`,
  `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateMediaReadUrlSigner.cs`.
- Backend tests:
  `tests/PetMagic.Modules.Identity.Tests/BackendValidationLocalizationTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Economy/EconomyWorkerLoggingPrivacyTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/BackendEnvironmentContractTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/ManagedPathSegmentsTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/RequestDrainingMiddlewareTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/RequestTimeoutMiddlewareTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/SafeHttpContentReaderTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Host/SafeLogValuesTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Identity/EmailDispatchProcessorTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Identity/IdentityAdminAuditLogTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Identity/IdentityServiceLoggingPrivacyTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Identity/LegalDocumentsCatalogLocalizationTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Infrastructure/BackgroundWorkerLoggingPrivacyTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/SupportChat/SupportChatRealtimePrivacyTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Templates/FalTransientProviderPipelineSourceTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Templates/FalQueueClientRateLimiterTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Templates/TemplatesInfrastructureConfigurationTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/Templates/TemplateMediaReadUrlSignerTests.cs`,
  `tests/PetMagic.Modules.Identity.Tests/TestAssemblyConfiguration.cs`.

Exact current file-level scope must be re-read from `git status --short` before
commit splitting, because the worktree is still active and broad.

## Command Evidence Snapshot

Commands verified during this audit include:

- `2026-07-04` dirty-worktree inventory rerun: `git status --short`
  shows 863 dirty entries on branch `codex/release-blockers-hardening`: 804
  tracked dirty entries, 6 tracked deletions, 59 untracked files, and 0
  renames. The audited lane grouping remains the split-planning baseline, but
  exact file membership must be refreshed before staging.
- `git diff --stat --compact-summary` reported 802 tracked changed files with
  29,701 insertions and 7,518 deletions. The only command warnings were Git
  line-ending normalization notices (`CRLF will be replaced by LF`) for selected
  files; no diff-stat failure occurred.
- `dotnet restore PetMagic.slnx --disable-build-servers` passed; all projects
  were up to date for restore.
- `dotnet build PetMagic.slnx --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false`
  passed in the latest backend rerun after the bounded provider JSON reader
  fix: 0 warnings, 0 errors, elapsed `00:00:08.72`.
- Current full backend single-run test status:
  `dotnet test PetMagic.slnx --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false`
  passed 1736/1736 tests with TRX output at
  `tests/PetMagic.Modules.Identity.Tests/TestResults/backend-full-after-raw-reader.trx`,
  elapsed `4 m 21 s`.
- The same backend rerun first failed 7 provider-client tests because
  `SafeHttpContentReader.ReadStringPrefixAsync` sanitized provider JSON before
  parsing. `SafeHttpContentReader.ReadRawStringPrefixAsync` now preserves
  bounded provider payloads for JSON parsing while `ReadStringPrefixAsync`
  remains the sanitized log-safe reader. Focused build-backed regression tests
  then passed 82/82:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~SafeHttpContentReaderTests|FullyQualifiedName~AdminUserTemplateAnalyticsReaderHardeningTests|FullyQualifiedName~StoreSubscriptionVerifierCorrelationTests|FullyQualifiedName~FalQueueClientRateLimiterTests|FullyQualifiedName~FalTransientProviderPipelineSourceTests|FullyQualifiedName~TemplatesInfrastructureConfigurationTests|FullyQualifiedName~EconomyLoggingPrivacyTests"`.
- The previous full backend gate passed 1723/1723 after the image generation
  flow contract was corrected; it superseded an intermediate 1722/1723 run where
  the test still expected provider cost in the user response.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~BackendValidationLocalizationTests"`
  passed 1/1 tests after rebuilding the current test project.
- Earlier backend domain-batched test rerun passed 1711/1711 tests:
  Economy 315/315, Gamification 35/35, Host 227/227, Identity 191/191,
  Infrastructure 14/14, SupportChat 204/204, Templates 686/686, and
  Validation 39/39. The earlier final solution-level test count was 1692/1692
  after collapsing one startup smoke-test theory into a single equivalent fact.
  The current final solution-level test count is 1736/1736 after later backend
  guard additions and contract coverage.
- Targeted backend tests for production configuration, route contracts,
  repository secret hygiene, environment contracts, DataProtection loading,
  request/correlation logging, and scheduler/runtime health.
- Fresh backend startup/DI smoke rerun:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~IdentityApiStartupSmokeTests|FullyQualifiedName~EconomyApiStartupSmokeTests|FullyQualifiedName~TemplatesApiStartupSmokeTests|FullyQualifiedName~SupportChatApiStartupSmokeTests|FullyQualifiedName~GamificationApiStartupSmokeTests"`
  passed 249/249 tests. This covers module startup smoke for Identity, Economy,
  Templates, SupportChat, and Gamification against the current test project
  outputs.
- EF migration clean-apply, existing-apply, and pending-model checks for the
  relevant module contexts.
- `2026-07-04` EF pending-model rerun passed for Identity, Economy,
  Gamification, SupportChat, and Templates: each
  `dotnet ef migrations has-pending-model-changes` command returned
  `No changes have been made to the model since the last migration`. The latest
  rerun set process-local placeholder
  `PETMAGIC_*_MIGRATIONS_CONNECTION_STRING` values only for the design-time
  factories; it did not apply migrations or modify schema state.
- The EF gate was rerun again after the latest report/tooling updates: a serial
  `dotnet build PetMagic.slnx --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false`
  completed with 0 warnings and 0 errors, then all five
  `dotnet ef migrations has-pending-model-changes --no-build` checks returned
  `No changes have been made to the model since the last migration`.
- `flutter pub get` passed in `apps/petmagic-mobile`; it still reports 16
  packages with newer versions incompatible with current dependency constraints.
- `flutter analyze --fatal-infos` passed in `apps/petmagic-mobile` with no
  issues against the current mobile worktree.
- `flutter test --reporter compact` initially exited 1 after reaching 1288
  passed and 1 failed test. The failure was a real silent-catch violation in
  `apps/petmagic-mobile/lib/features/wallet/data/wallet_store_purchase_recovery_store.dart`.
  After replacing it with sanitized `AppLogger.warn` logging, the focused policy
  and wallet recovery rerun passed 49/49 tests, and the final full
  `flutter test --reporter compact` rerun passed 1289/1289 tests.
- `flutter test integration_test\gallery_cross_flow_test.dart -d R5CR126590A --dart-define=API_BASE_URL=http://127.0.0.1:5000 --reporter expanded`.
- `flutter test test\app_config_security_test.dart test\api_base_url_resolver_lifecycle_test.dart test\android_loopback_backend_hint_config_test.dart`.
- `flutter test test\mobile_asset_inventory_test.dart --reporter expanded`.
- `flutter test test\production_networking_config_test.dart --reporter expanded`.
- `flutter test test\external_url_policy_test.dart test\app_config_security_test.dart test\production_networking_config_test.dart --reporter compact`
  passed 22/22 tests in the targeted `2026-07-04` rerun.
- `flutter test test\api_base_url_resolver_lifecycle_test.dart test\android_loopback_backend_hint_config_test.dart --reporter compact`
  passed 8/8 tests in the targeted `2026-07-04` rerun.
- Mobile lifecycle/storage direct-use scan over `apps/petmagic-mobile/lib` and
  `apps/petmagic-mobile/test` found no `SharedPreferences.getInstance()` calls
  and no blanket `ignore_for_file: cancel_subscriptions` suppressions.
- `flutter test test\notification_coordinator_lifecycle_test.dart test\wallet_controller_lifecycle_test.dart test\network_status_controller_lifecycle_test.dart test\app_launch_controller_lifecycle_test.dart --reporter compact`
  passed 54/54 tests in the latest mobile lifecycle rerun.
- `flutter test test\template_generation_controller_test.dart test\template_card_test.dart test\generation_history_controller_lifecycle_test.dart test\templates_page_lifecycle_test.dart --reporter compact`
  passed 65/65 tests in the latest template lifecycle/feed rerun.
- `flutter test test\premium_repository_test.dart test\premium_controller_test.dart test\wallet_repository_test.dart test\store_product_availability_cache_test.dart --reporter compact`
  passed 35/35 tests in the latest mobile premium/payment rerun.
- Android manifest scan confirmed release `usesCleartextTraffic="false"`,
  debug/profile local cleartext overrides, and no `EnableImpeller` opt-out.
  The matching iOS `Info.plist`/`.xcconfig` scan found no ATS, local URL,
  `API_BASE_URL`, or Impeller override markers.
- `flutter build bundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`.
- `2026-07-04` rerun of
  `flutter build bundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  passed for the current mobile worktree.
- `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:5000`
  passed and produced `build\app\outputs\flutter-apk\app-debug.apk`, proving the
  local Android `assembleDebug` build path after the Gradle/plugin changes.
- Latest mobile gate rerun result: `flutter pub get` passed,
  `flutter analyze --fatal-infos` passed with no issues,
  `flutter test --reporter compact` passed 1289/1289 tests after the wallet
  recovery logging fix, and
  `flutter build bundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  plus `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:5000`
  exited 0 against the current mobile worktree.
- `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  as a signing-guard check.
- Latest Android signing blocker refresh:
  `Test-Path apps\petmagic-mobile\android\key.properties` returned `False`;
  recursive mobile scan for `*.jks`, `*.keystore`, and `key.properties` returned
  no files; `flutter test test\app_config_debug_tools_test.dart --reporter compact`
  passed 5/5 tests; and
  `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  failed with the expected release-signing guard message instead of producing a
  debug-signed release bundle.
- Latest mobile source-scope refresh found 1023 tracked mobile files and 6
  untracked mobile files:
  `lib/shared/payments/external_checkout_result.dart`,
  `test/app_lifecycle_signal_test.dart`,
  `test/app_preferences_storage_test.dart`,
  `test/generation_gallery_store_lifecycle_test.dart`,
  `test/mobile_architecture_boundary_test.dart`, and
  `test/mobile_asset_inventory_test.dart`. These remain part of the current
  large dirty-tree scope and are not counted as release-clean until split and
  revalidated.
- `.\gradlew.bat :app:bundleRelease -PallowInsecureReleaseSigning=true --warning-mode all`
  as a local packaging/R8 check.
- `npm run lint` passed in `apps/admin-web` after fixing the support realtime
  status subscription, and passed again after the latest `npm ci`.
- `npm run typecheck` passed in `apps/admin-web`; the latest rerun generated
  route types successfully before completing typecheck.
- `npm test` passed in `apps/admin-web`: 85/85 files and 656/656 tests in the
  latest rerun after refreshing stale source-contract assertions.
- `npm run build` passed in `apps/admin-web`, including Next.js 16.2.10
  optimized production build, TypeScript, static page generation, route listing,
  and route trace collection.
- `npm ci` passed in `apps/admin-web`: 410 packages installed, 411 packages
  audited, and 0 vulnerabilities found.
- `npm audit --audit-level=moderate` in `apps/admin-web`.
- .NET vulnerable package audit.
- `dotnet list PetMagic.slnx package --vulnerable --include-transitive`.
- `dotnet list PetMagic.slnx package --deprecated`.
- `dotnet list PetMagic.slnx package --outdated`.
- `npm outdated --long` in `apps/admin-web`.
- `flutter pub outdated` in `apps/petmagic-mobile`.
- Latest dependency rerun result after the backend/Docker refresh: .NET
  vulnerable package audit clean across all solution projects, .NET production
  deprecated-package audit clean, admin `npm audit` clean, admin outdated
  packages limited to dev tooling, and mobile outdated packages left as separate
  focused upgrade follow-ups.
- `node --check` for all 22 JavaScript/MJS files under `scripts`.
- PowerShell AST parser check for all 7 repo `.ps1` scripts, excluding
  generated/build/cache directories.
- `node scripts\qa\test-script-safety-inventory.mjs`.
- `node scripts\qa\test-markdown-local-links.mjs`.
- `node scripts\qa\test-watermark-qa-help.mjs`.
- Latest tooling/docs refresh repeated the current script syntax and QA
  validator set: `node --check` for all 22 JS/MJS scripts, PowerShell AST parse
  for all 7 `.ps1` scripts, `test-script-safety-inventory.mjs`,
  `test-markdown-local-links.mjs`, `test-watermark-qa-help.mjs`,
  `test-template-feed-release-gate.mjs`,
  `test-template-feed-admin-qa-report-draft.mjs`,
  `test-template-feed-staging-snapshot.mjs`,
  `test-template-feed-long-scroll-promoter.mjs`,
  `test-template-feed-load-probe.mjs`,
  `test-template-feed-tz1-8-evidence-validator.mjs`,
  `node --check scripts\qa\validate-template-feed-tz1-8-evidence.mjs`,
  `node --check scripts\qa\promote-template-feed-long-scroll-artifact.mjs`, and
  `node scripts\qa\check-markdown-local-links.mjs`; all passed.
- Refined tracked/untracked filename scan for real scratch/backup/temp patterns;
  it returned 6 reviewed tracked matches and 0 untracked matches.
- `docker compose --env-file .env.example config --quiet`.
- `docker compose --env-file .env.local-smoke.example config --quiet`.
- `docker compose --env-file .env.staging.local.example config --quiet`.
- `docker compose --env-file .env.example --profile monitoring config --quiet`.
- Source appsettings JSON parse:
  `Get-ChildItem -Path src -Recurse -Filter 'appsettings*.json' -File | Where-Object { $_.FullName -notmatch '\\bin\\|\\obj\\' }`
  with each file parsed individually through `ConvertFrom-Json`; all 8 source
  files passed.
- `docker compose --env-file .env config --quiet`.
- `docker compose --env-file .env ps`.
- `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe ps`.
- `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe up -d --build --wait --wait-timeout 240`.
- `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe exec -T postgres pg_isready -U petmagic_user -d petmagic_db`.
- `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe exec -T postgres psql -U petmagic_user -d petmagic_db -c 'select "MigrationId" from "__EFMigrationsHistory" order by "MigrationId";'`.
- Docker Postgres schema inventory queries for application tables, applied
  migration count, key token/payment/generation columns, constraints, and
  indexes.
- Monitoring profile config/build/up/health/metrics checks.
- Runtime smoke for `/health` and `/api/templates/feed` against the running API
  in the isolated `petmagic_goal_probe` stack; admin `/ru` was also smoke-tested
  on the isolated host port.
- Latest `2026-07-04` isolated runtime recheck:
  `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe ps`,
  host `curl http://localhost:5601/health`, host
  `curl http://localhost:5601/api/templates/feed?limit=3`, backend-container
  `curl http://localhost:5000/health`, Postgres `pg_isready`, and host
  `curl http://localhost:3600/ru` all passed.
- Latest `2026-07-04T10:53Z` runtime refresh:
  `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe ps`,
  host `curl http://localhost:5601/health`, host
  `curl http://localhost:5601/api/templates/feed?limit=3`, host
  `curl http://localhost:3600/ru`, local-smoke Postgres `pg_isready`, local-smoke
  EF migration count, `docker compose ps`, host
  `curl http://localhost:5000/health`, host
  `curl http://localhost:5000/api/templates/feed?limit=3`, host
  `curl http://localhost:3000/ru`, default Postgres `pg_isready`, and default EF
  migration count all passed.
- Latest `2026-07-04T12:28Z` default-compose runtime refresh:
  `docker compose ps`, host
  `Invoke-WebRequest http://localhost:5000/health`, host
  `Invoke-WebRequest http://localhost:5000/api/templates/feed?limit=3`, host
  `Invoke-WebRequest http://localhost:3000/ru`, default Postgres
  `pg_isready`, default EF migration count, public table count, and latest
  migration id query all passed. The current Postgres role/database are
  `petmagic_user` / `petmagic_db`; probing the stale `petmagic` role correctly
  failed and was not counted as runtime evidence.
- Latest Android availability refresh:
  `adb devices` returned no attached Android devices, `adb reverse --list`
  returned `error: no devices/emulators found`, and `flutter devices` returned
  Windows/Chrome/Edge only. The host API path is still alive:
  `Invoke-WebRequest http://localhost:5000/health` with `Host: localhost`
  returned `200` and `Healthy`, while
  `http://localhost:5000/api/templates/feed?limit=3` returned `200` with two
  feed items and `hasMore=false`. `.vscode/launch.json` / `.vscode/tasks.json`
  still pin the recommended USB profile to
  `API_BASE_URL=http://127.0.0.1:5000` plus `adb reverse tcp:5000 tcp:5000`.
- Fresh post-backend-fix isolated rebuild:
  `docker compose --env-file .env.local-smoke.example -p petmagic_goal_probe up -d --build --wait --wait-timeout 240`
  rebuilt backend, generation-worker, and admin-web images and returned with all
  services healthy. The follow-up `ps`, host `/health`, host
  `/api/templates/feed?limit=3`, backend-container `/health`, Postgres
  `pg_isready`, admin `/ru`, EF migration-count query, and public table-count
  query all passed against the recreated stack.
- Latest `2026-07-04` default-stack runtime repair and recheck:
  `docker compose --env-file .env up -d --build --force-recreate --wait
  --wait-timeout 240 backend generation-worker` initially exposed a fatal
  generation-worker scheduler fingerprint mismatch, then passed after
  `docker-compose.yml` was fixed to forward the same fingerprinted scheduler
  keys to backend and worker. `docker compose --env-file .env ps` now shows
  backend, generation-worker, Postgres, and Mailpit healthy; `docker inspect`
  confirms backend `AllowedHosts=localhost;127.0.0.1;[::1];backend`; host
  `/health` with `Host: localhost` returned `Healthy` with
  `schedulerConfig.isMismatchDetected=false`; host
  `/api/templates/feed?limit=3` returned `200`.
- The default-stack fingerprint database proof queried
  `templates_runtime_config_fingerprints`: the latest API and generation-worker
  rows share checksum
  `5fc8bcdb3810687feb050bf11f79e0b7d4f1d5bcb89e8c6f01b18408ea345233` and both
  have `MismatchDetected=false`. Logs since the successful recreate contain no
  scheduler mismatch, fatal startup, or unhandled exception lines.
- The same latest isolated runtime recheck also queried Docker Postgres directly:
  `select count(*) from "__EFMigrationsHistory"` returned 73 and
  `select count(*) from information_schema.tables where table_schema = 'public'`
  returned 66.
- `2026-07-04` EF migration inventory/destructive-operation scan: current repo
  has 73 real migration files after excluding designers and all
  `*ModelSnapshot*` files across Economy 17, Gamification 2, Identity 9,
  SupportChat 11, and Templates 34. The corrected snapshot exclusion also
  classifies the split Templates partial snapshot as a snapshot file, not a real
  migration. The refined destructive scan found 7 forward `Up` hits and 267
  rollback `Down` hits. Forward hits are reviewed as index replacement or the
  intentional `IconAssetPath` column removal from gamification achievement
  definitions.
- `2026-07-04` EF pending-model rerun passed again for Identity, Economy,
  Gamification, SupportChat, and Templates with process-local placeholder
  `PETMAGIC_*_MIGRATIONS_CONNECTION_STRING` values; each
  `dotnet ef migrations has-pending-model-changes --no-build` returned
  `No changes have been made to the model since the last migration`.
- Latest EF inventory refresh still reports 73 real migration files after
  excluding designers/snapshots: Economy 17, Gamification 2, Identity 9,
  SupportChat 11, and Templates 34. Both the default Docker database and the
  isolated `petmagic_goal_probe` database report 73 rows in
  `__EFMigrationsHistory`.
- Latest current Docker DB refresh confirmed both default Postgres and isolated
  `petmagic_goal_probe` Postgres are healthy. Each database reports 73 rows in
  `__EFMigrationsHistory` and 66 public tables, matching the current real
  migration inventory and prior local-smoke evidence.
- `gitleaks version` was attempted locally and returned command-not-found;
  `.github/workflows/backend-security.yml` remains the Gitleaks CI gate.
- Masked PowerShell secret-marker scan over tracked non-test runtime/config
  files returned 0 findings after replacing a docs-only Firebase API-key-shaped
  placeholder.
- The latest value-only secret scan over 14 env/appsettings/mobile config files
  found no secret-looking values. Broad matches in `.env.example` and
  `.env.staging.local.example` were only empty secret variable names, not values.
- Fresh `2026-07-04` repo-local signing/Firebase material refresh found no
  `*.jks`, `*.keystore`, or `key.properties` paths in tracked plus untracked
  non-ignored files. `Test-Path GoogleService-Info.plist` returned `False`; the
  root Firebase placeholder still appears only as a tracked deletion until the
  cleanup commit is staged. The only active Firebase config files are the mobile
  Android/iOS placeholders in their platform project locations.
- The same refresh found no deployable high-confidence secret-shape hits after
  excluding docs, tests, and build/cache output.
- A latest sanitized high-confidence secret-material scan over non-ignored repo
  files (`rg -l --hidden` for private-key blocks, Stripe live/restricted keys,
  webhook secrets, AWS keys, Firebase API-key shapes, GitHub/GitLab/Slack tokens,
  and SendGrid key shapes) returned only four test/redaction fixture files:
  `EconomyInfrastructureConfigurationTests.cs`,
  `EconomyServiceTests.Reconciliation.cs`,
  `admin-notifications.test.ts`, and `app_logger_test.dart`. A follow-up
  category-only scan classified every hit as a test or redaction fixture without
  printing token values.
- `RepositorySecretHygieneTests` now also runs a high-confidence deployable
  source/config scan, excluding docs/tests/build output, for private-key blocks,
  Stripe secret/webhook keys, Firebase API-key shapes, Google OAuth client IDs,
  and the real Firebase project id.
- Current `2026-07-04` no-build rerun of
  `RepositorySecretHygieneTests` passed 16/16 tests.
- A latest masked env/appsettings scan covered `.env.example`,
  `.env.local-smoke.example`, `.env.staging.local.example`,
  `apps/admin-web/.env.staging.example`, and source API/worker
  `appsettings*.json`. Production/staging secret fields remained blank;
  the only non-blank development signing value was classified as dev-only, and
  broad false positives were numeric rate-limit/password-reset settings,
  Apple token endpoint names, and R2 object-key prefix labels rather than secret
  values.
- `node scripts\qa\test-script-safety-inventory.mjs` passed again after the
  provider/staging preflight review: `script safety inventory ok`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false -p:OutputPath=..\..\backend\artifacts\identity-tests-secret-hygiene --filter "FullyQualifiedName~RepositorySecretHygieneTests"`
  passed 16/16 tests in the latest secret-hygiene rerun. The same command
  without isolated `OutputPath` first hit a stale `testhost` DLL lock, so the
  isolated output path is the authoritative run.
- The current no-build rerun of the same deployable source/config secret guard
  also passed 16/16:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~RepositorySecretHygieneTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false -p:OutputPath=..\..\backend\artifacts\identity-tests-secret-hygiene --filter "FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests"`
  passed 29/29 tests after fixing the current `SupportAttachmentStorage`
  `DeleteAsync`/`ResolveMaxFileSizeBytes` method-boundary compile blocker.
- `npm test -- src/components/admin/admin-notifications.test.ts` passed 1/1 file
  and 15/15 tests, confirming admin notification secret-looking fixture values
  remain redacted.
- `flutter test test\app_logger_test.dart --reporter compact` passed 31/31
  tests, confirming mobile log redaction still masks embedded Stripe keys,
  provider headers, JWT-like tokens, checkout/session URLs, and user/media
  identifiers.
- `flutter test test\logging_policy_test.dart test\app_logger_test.dart test\global_error_handling_test.dart --reporter compact`
  passed 35/35 tests in the current mobile logging-policy rerun. This pins the
  absence of direct `print`/`debugPrint`, centralized sanitized logging, and
  first-frame-safe global error handling.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~ValidateGooglePlayBillingAsync|FullyQualifiedName~VerifyPackStorePurchaseAsync_Should"`
  passed 6/6 Google Play token-pack idempotency tests.
- `node scripts\qa\check-markdown-local-links.mjs` passed after the latest
  audit-report update: `Markdown local links ok (46 files checked)`.
- `git diff --check` passed after the latest audit-report update; it emitted only
  CRLF normalization warnings and no whitespace errors.
- Stale audit-count scan for prior dirty-tree totals and the old 21/21 mobile
  networking count returned no matches after the report update.
- `node scripts\qa\run-staging-generation-scheduler-smoke.mjs --help` listed the
  required staging runner inputs without requiring or printing secret values.
- `STAGING_ENV_FILE=.env.staging.local.example node scripts\qa\run-staging-generation-scheduler-smoke.mjs`
  exited 1 before runtime calls and printed only missing input names:
  `STAGING_API_BASE_URL`, `STAGING_DATABASE_URL`,
  `STAGING_IMAGE_TEMPLATE_ID`, `STAGING_VIDEO_TEMPLATE_ID`,
  `STAGING_FAILING_TEMPLATE_ID`, `STAGING_FREE_AUTH_TOKENS` or
  `STAGING_FREE_JWT`, `STAGING_PREMIUM_AUTH_TOKENS` or
  `STAGING_PREMIUM_JWT`, `STAGING_PROMETHEUS_BASE_URL`,
  `STAGING_API_PROCESS_ID`, `STAGING_WORKER_PROCESS_ID`, and
  `STAGING_MIGRATION_TOOLING_LABEL`.
- `node scripts\qa\run-economy-staging-infra-gate.mjs --help` listed the
  Economy staging DB/API/admin/migration inputs.
- `STAGING_ENV_FILE=.env.staging.local.example ECONOMY_GATE_ARTIFACT_DIR=<temp> node scripts\qa\run-economy-staging-infra-gate.mjs`
  exited 1 with sanitized evidence because `STAGING_DATABASE_URL` is missing.
  The generated temp summary did not contain database or API values.
- Latest tracked artifact scan:
  `git ls-files` filtered to existing files, then checked for build/cache,
  release artifact, temp/backup, and local IDE path/name patterns. Result:
  2310 existing tracked files, 0 artifact matches.
- Latest manual API/export scan:
  `git ls-files` filtered to existing files, then checked for `.http`, `.rest`,
  Postman, and Insomnia path/name patterns. Result: 2310 existing tracked files,
  0 matches.
- Latest deleted/untracked hygiene scan:
  `git ls-files --deleted` returned six tracked deletions, and
  `git ls-files --others --exclude-standard` returned 59 untracked files. The
  latest strict segment/suffix suspicious-name scan found 0 backup/temp/scratch
  matches outside ignored build/vendor/evidence directories.
- Current tracked build/cache leak scan returned 0 matches under `bin`, `obj`,
  `build`, `.dart_tool`, `.next`, `node_modules`, `coverage`, `dist`, `out`,
  `artifacts`, `TestResults`, `.vs`, and `.idea`.
- Local equivalents for `.github/workflows/repo-hygiene-ci.yml`:
  full `scripts/**/*.js` and `scripts/**/*.mjs` syntax checks, shell syntax
  checks for every `scripts/**/*.sh`, Python `py_compile` checks for every
  `scripts/**/*.py`, PowerShell parser checks, script/workflow safety inventory,
  markdown local-link self-test, and full markdown local-link check.
- `flutter test test\app_config_security_test.dart`.
- `npm test -- src/lib/next-config-env.test.ts`.
- `npm test -- src/lib/admin-api-base-url.test.ts src/lib/next-config.test.ts src/lib/next-config-env.test.ts`.
- `npm test -- src/lib/admin-api-base-url.test.ts src/lib/next-config-env.test.ts`
  passed 25/25 tests in the latest hardcoded-local-URL guard rerun.
- `flutter test test\production_networking_config_test.dart --reporter compact`
  passed 7/7 tests in the latest mobile production-networking guard rerun.
- `flutter test test\mobile_architecture_boundary_test.dart --reporter compact`
  passed 1/1 tests in the latest mobile presentation/data boundary rerun.
- `npm test -- src/components/templates/template-preview-url-exposure.test.ts src/components/support/support-sensitive-display.test.ts src/components/users/user-avatar-url-exposure.test.ts`.
- `node_modules\.bin\eslint.cmd src\lib\admin-unsafe-remote-host.ts src\components\templates\template-secure-media.tsx src\components\support\support-secure-media.tsx src\components\users\user-secure-media.ts src\components\templates\template-preview-url-exposure.test.ts src\components\support\support-sensitive-display.test.ts src\components\users\user-avatar-url-exposure.test.ts`.
- `rg -n -e DbContext -e EntityFramework -e Npgsql -e SqlClient -e MySql -e Prisma -e DATABASE_URL -e ConnectionString -e connectionString -e '@/server' -e 'backend\\src' -e 'src/Modules' -e 'PetMagic\\.' apps\admin-web ...`
  returned only two localized/metadata `PetMagic` copy strings and no direct DB,
  backend-layer, or server-only imports in non-test admin source/scripts.
- `Select-String -Path apps\admin-web\package.json,apps\admin-web\package-lock.json -Pattern '"pg"|"mysql|mssql|prisma|typeorm|sequelize|knex|mongodb|npgsql|entityframework|sqlite'`
  returned no direct database client packages.
- Direct non-test admin source scans for common database clients and backend
  persistence types (`DbContext`, Prisma, TypeORM, Sequelize, Knex, MongoDB,
  Npgsql, SQL connection types, and package imports such as `pg`/`mysql`/`mssql`
  /`sqlite`) returned no matches.
- Admin API call scan found HTTP usage centralized in the typed admin API client
  layer and fetch timeout helper, with UI-level matches limited to refetch calls;
  no direct persistence path was found.
- `npm test -- src/lib/admin-api-boundary.test.ts src/lib/admin-api-base-url.test.ts src/lib/next-config-env.test.ts`
  passed 3/3 files and 27/27 tests in the latest admin API-boundary/env rerun.
- `npm test -- src/lib/dependency-inventory.test.ts` passed 1/1 file and
  2/2 tests in the latest admin dependency-inventory rerun.
- `npm run lint -- src/lib/dependency-inventory.test.ts` completed successfully;
  the project script linted the app and the dependency-inventory target without
  errors.
- Latest admin source-contract repair checks:
  `npm test -- src/components/dashboard-view.test.ts src/components/moderation-page-sensitive-display.test.ts src/lib/api-client-economy-query.test.ts`
  passed 39/39 tests, and targeted ESLint passed for the same three files.
- `npm run lint` in `apps/admin-web` passed in the latest rerun.
- `npm run typecheck` in `apps/admin-web` passed in the latest rerun after route
  type generation completed successfully.
- `npm test` in `apps/admin-web` passed 85/85 files and 656/656 tests in the
  latest rerun.
- `npm run build` in `apps/admin-web` passed in the latest rerun, completing the
  Next.js 16.2.10 production build, TypeScript step, static page generation, and
  route trace collection.
- `dotnet list PetMagic.slnx package --vulnerable --include-transitive` passed
  in the latest rerun: no vulnerable packages were reported for current NuGet
  sources.
- `npm audit --audit-level=moderate` in `apps/admin-web` passed: 0
  vulnerabilities.
- `flutter pub outdated` in `apps/petmagic-mobile` passed and recorded routine
  upgrade drift without applying dependency changes.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~HostApiProductionConfigurationValidatorTests|FullyQualifiedName~BackendEnvironmentContractTests"`.
- `dotnet build tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-restore --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false -v:minimal`
  passed with 0 warnings and 0 errors after `dotnet clean` refreshed the test
  project outputs.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~ClientApiContractRouteTests|FullyQualifiedName~AdminTemplateEndpointHardeningTests|FullyQualifiedName~AdminEconomyEndpointHardeningTests|FullyQualifiedName~AdminUserEndpointHardeningTests|FullyQualifiedName~GamificationEndpointHardeningTests|FullyQualifiedName~SupportChatEndpointHardeningTests|FullyQualifiedName~TemplateGenerationEndpointsSecurityTests|FullyQualifiedName~EconomyClientBillingEndpointHardeningTests|FullyQualifiedName~EconomyPublicBillingEndpointHardeningTests|FullyQualifiedName~FeedbackEndpointsSecurityTests|FullyQualifiedName~PublicTemplateEndpointsSecurityTests"`
  passed 94/94 targeted backend API route and endpoint-hardening tests in the
  latest `2026-07-04` rerun.
- `npm test -- src/lib/api-client-admin-users-query.test.ts src/lib/api-client-economy-query.test.ts src/lib/api-client-feedback-query.test.ts src/lib/api-client-support-query.test.ts src/lib/api-client-templates-query.test.ts`
  passed 5/5 admin API client test files and 65/65 tests.
- `npm test -- src/lib/admin-api-boundary.test.ts src/lib/api-client-admin-users-query.test.ts src/lib/api-client-economy-query.test.ts src/lib/api-client-feedback-query.test.ts src/lib/api-client-support-query.test.ts src/lib/api-client-templates-query.test.ts src/lib/dependency-inventory.test.ts`
  passed 7/7 files and 69/69 tests in the latest Admin -> API boundary rerun.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter FullyQualifiedName~TemplateMediaReadUrlSignerTests`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests|FullyQualifiedName~IdentityServiceProfileTests.GetCurrentUserAsync_ShouldSuppressUnsafeManagedAvatarUrl|FullyQualifiedName~SupportChatServiceTests.SendMessageWithAttachmentsAsync_WithUnsafeManagedAttachmentUrl_ShouldSuppressReturnedFileUrl"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~ManagedPathSegmentsTests|FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests|FullyQualifiedName~IdentityServiceProfileTests.GetCurrentUserAsync_ShouldSuppressUnsafeManagedAvatarUrl|FullyQualifiedName~SupportChatServiceTests.SendMessageWithAttachmentsAsync_WithUnsafeManagedAttachmentUrl_ShouldSuppressReturnedFileUrl|FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~R2MediaStorageLoggingTests"`.
- `rg -n "UnescapeDataString|UrlDecode|WebUtility\.UrlDecode|HttpUtility\.UrlDecode" src tests\PetMagic.Modules.Identity.Tests`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj -m:1 --disable-build-servers -p:UseSharedCompilation=false -p:OutputPath=D:\Flutter\project\petmagic-0_004\backend\artifacts\identity-tests-share-decode-2\ --filter "FullyQualifiedName~TemplatesServiceTests.Watermark|FullyQualifiedName~TemplateMediaReadUrlSignerTests|FullyQualifiedName~ManagedPathSegmentsTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests"`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj -m:1 --disable-build-servers -p:UseSharedCompilation=false -p:OutputPath=D:\Flutter\project\petmagic-0_004\backend\artifacts\identity-tests-share-api-decode\ --filter "FullyQualifiedName~TemplatesApiIntegrationTests.PublicShareEndpoints_ShouldRejectMalformedEncodedTokens|FullyQualifiedName~TemplatesServiceTests.GetPublicShareAsync_ShouldRejectMalformedShareToken|FullyQualifiedName~TemplatesServiceTests.GetPublicShareAsync_ShouldRejectOversizedShareToken"`.
- `rg -n "Console\.Write(Line)?|Debug\.Write(Line)?|Trace\.Write(Line)?|Debugger\.|System\.Diagnostics\.Debug|System\.Diagnostics\.Trace" src -g "*.cs" -g "!**/bin/**" -g "!**/obj/**"`.
- `rg -n "\bconsole\.(log|debug|info|warn|error)|\bdebugger\b" apps\admin-web\src -g "*.ts" -g "*.tsx" -g "!**/*.test.ts" -g "!**/*.test.tsx"`.
- `rg -n "\bprint\(|debugPrint\(|developer\.log\(|log\(" apps\petmagic-mobile\lib -g "*.dart" -g "!**/generated/**"`.
- `npm test -- src/lib/logging-policy.test.ts`.
- `npm test -- src/lib/logging-policy.test.ts src/lib/client-logger.test.ts src/lib/client-logger.privacy.test.ts`
  passed 3/3 admin logging files and 19/19 tests in the latest hygiene refresh.
- `flutter test test\logging_policy_test.dart`.
- `flutter test test\logging_policy_test.dart test\app_logger_test.dart`.
- `flutter test test\logging_policy_test.dart test\app_logger_test.dart test\api_logging_interceptor_security_test.dart test\realtime_correlation_headers_test.dart --reporter compact`
  passed with `All tests passed!` and 42/42 mobile logging/correlation tests in
  the latest hygiene refresh.
- `flutter test test\external_url_policy_test.dart test\app_config_security_test.dart test\production_networking_config_test.dart`.
- `flutter test test\app_config_security_test.dart test\api_base_url_resolver_lifecycle_test.dart test\production_networking_config_test.dart test\templates_controller_test.dart test\template_generation_controller_test.dart test\template_generation_repository_test.dart test\templates_repository_test.dart test\support_chat_repository_test.dart test\wallet_repository_test.dart test\premium_controller_test.dart --reporter compact`
  passed with `All tests passed!` and 154/154 targeted mobile API/networking,
  template, generation, support, wallet, and premium tests.
- `dart format lib\core\network\network_utils.dart test\external_url_policy_test.dart`.
- `flutter analyze`.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj -m:1 --disable-build-servers -p:UseSharedCompilation=false -p:OutputPath=D:\Flutter\project\petmagic-0_004\backend\artifacts\identity-tests-logging-policy-2\ --filter "FullyQualifiedName~LoggingPolicyTests.SourceLoggingPolicy_ShouldNotUseConsoleWriteLineOrInterpolatedLoggerTemplates"`.
- `node --check` for every `scripts/**/*.js` and `scripts/**/*.mjs`.
- `node --check scripts\qa\run-economy-staging-infra-gate.mjs`.
- `node --check scripts\qa\test-script-safety-inventory.mjs`.
- `node scripts\qa\test-script-safety-inventory.mjs`.
- Latest runtime hygiene marker scans:
  `rg` over `src`, `apps/admin-web/src`, and `apps/petmagic-mobile/lib`,
  excluding tests/generated/migrations/build/cache output, for `TODO`, `FIXME`,
  `HACK`, `XXX`, `NotImplementedException`, `debugger`, direct console output,
  `print(`, `debugPrint(`, and stub phrases. No actionable runtime leftovers
  were found beyond allowlisted `clientLogger.warn/error`.
- Fresh repo hygiene rerun after the backend/Docker refresh scanned tracked and
  untracked filenames for backup/temp/scratch/manual API/export patterns. It
  found no untracked scratch files. Tracked findings were reviewed as expected:
  mobile debug Android manifests, a vendored Flutter plugin debug manifest, and
  the already-deleted `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http`
  scratch HTTP file.
- Latest repository scratch/build-cache refresh:
  `git ls-files -co --exclude-standard` scanned 2366 tracked/untracked
  non-ignored paths for scratch/backup/temp filenames, manual API exports,
  Postman/Insomnia/HAR artifacts, and markdown status/draft naming. The same
  refresh checked `git ls-files` for tracked `bin`, `obj`, `dist`, `coverage`,
  `node_modules`, `.dart_tool`, and `.next` leaks; tracked build/cache leaks
  were 0.
- `node scripts\qa\test-template-feed-admin-qa-report-draft.mjs` passed,
  confirming template-feed Admin QA TODO rows are intentional draft output and
  not accepted as final release evidence.
- `node scripts\qa\test-template-feed-release-gate.mjs` passed, confirming draft
  Admin QA reports, missing evidence, and skip-mode misuse are rejected by the
  release-gate fixtures before they can be counted as production evidence.
- `node --check` over every current `scripts/**/*.js` and `scripts/**/*.mjs`
  passed after the hygiene refresh.
- Latest runtime-source policy rerun:
  admin `npm test -- src/lib/logging-policy.test.ts src/lib/client-logger.test.ts src/lib/client-logger.privacy.test.ts`
  passed 19/19 tests; mobile
  `flutter test test\logging_policy_test.dart test\app_logger_test.dart test\api_logging_interceptor_security_test.dart test\realtime_correlation_headers_test.dart --reporter compact`
  passed 42/42 tests; backend
  `dotnet test ... --filter "FullyQualifiedName~LoggingPolicyTests.SourceLoggingPolicy_ShouldNotUseConsoleWriteLineOrInterpolatedLoggerTemplates"`
  passed 1/1 tests.
- Fresh disabled-test/debug-marker refresh:
  refined `rg --pcre2` scans for real disabled or focused test markers
  (`[Fact(Skip...)`, `[Theory(Skip...)`, `Skip =`, `describe.skip`,
  `it.skip`, `test.skip`, `.only`, `fit`, `fdescribe`, `xit`, `xdescribe`,
  `@Disabled`, and `@Ignore`) across backend tests, admin source/tests, and
  mobile tests found 0 matches. A production runtime-source scan over backend
  `src`, admin `src`, and mobile `lib`, excluding tests/generated/migrations
  and build/cache output, found 0 matches for `TODO`, `FIXME`, `HACK`, `XXX`,
  `NotImplementedException`, `debugger`, direct console output, `print(`,
  `debugPrint(`, and direct .NET debug/trace writers. Guard reruns passed:
  `RepositorySecretHygieneTests` 16/16, admin logging/env URL tests 46/46, and
  mobile debug-tools/production-networking tests 13/13.
- Latest production-sensitive code/config marker sweep:
  `rg` over backend `src`, mobile `lib`/Android/iOS, admin `src`/`next.config`,
  env examples, Docker/deploy/workflow/script files for local URLs,
  `TODO`/`FIXME`/`HACK`, `NotImplementedException`, direct logging, bypass
  wording, and secret-shaped markers. Reviewed matches were development-only
  config, explicit local-smoke config, tests/sanitizer fixtures, guarded
  production rejection paths, or centralized sanitized logging; no additional
  production blocker was found.
- Latest active env URL refresh found one local monitoring default in the root
  example: `.env.example` used
  `ALERTMANAGER_WEBHOOK_URL=http://host.docker.internal:9099/petmagic-alerts`.
  It now uses `https://alerts.petmagic.app/petmagic-alerts`, while
  `.env.local-smoke.example` retains the localhost placeholder for local-only
  monitoring smoke.
- Latest source-size composition audit:
  PowerShell `Get-ChildItem` plus `Measure-Object -Line` over admin web
  `.ts`/`.tsx`/`.css`, backend `.cs`, and mobile `.dart` runtime source,
  excluding generated files, migrations, build output, localization output, and
  source-test files where applicable. The refreshed scan covered 1126 production
  source/style files: 270 over 300 lines, 78 over 600 lines, and 5 over 1000
  lines. Code-only inventory excluding CSS covered 1090 files: 4 over 1000
  lines, 18 between 751 and 1000 lines, and 95 between 501 and 750 lines.
- Latest markdown release-claim hygiene scan:
  `rg --files -g "*.md"` plus targeted `rg` checks for `TODO`/`FIXME`,
  `PASS`/`FAIL`, `ready for production`, `production-ready`, `release-ready`,
  `blocked`, local URL guidance, obsolete compose guidance, and historical status
  wording. Reviewed matches were either current blockers, local-development
  instructions, staging/manual QA protocols whose validators reject draft rows,
  or explicitly labeled historical reports.
- `node scripts\qa\test-markdown-local-links.mjs` passed, and the full markdown
  local-link checker still reports `Markdown local links ok (46 files checked)`.
- `2026-07-04` package command surface inventory found one non-generated
  package manifest: `apps/admin-web/package.json`. The root `package.json`
  probe produced an expected no-match warning because the repo has no root
  Node package manifest.
- `2026-07-04` scripts/tooling danger-pattern scan covered `scripts`,
  `.github`, and the admin package manifest for destructive delete/reset,
  force, shell-pipe install, eval/iex, and Docker volume-drop patterns.
  Reviewed matches were limited to allowlisted temp cleanup, QA artifact
  creation/copy, and maintenance-script compatibility paths.
- `2026-07-04` dependency/security rerun repeated NuGet vulnerable/deprecated/
  outdated checks, admin `npm audit`/`npm outdated --long`, Flutter
  `pub outdated`, and the admin dependency-inventory test/lint. No dependency
  manifest or lockfile upgrade was applied in this pass.
- Latest `node scripts\qa\test-script-safety-inventory.mjs` passed:
  `script safety inventory ok`.
- Negative local-target smokes for
  `scripts\qa\run-economy-staging-infra-gate.mjs`:
  `postgres://...@localhost`, `Host=localhost;...`, and
  `STAGING_API_BASE_URL=http://127.0.0.1:5000`.
- Negative repo-local psql wrapper smoke for
  `scripts\qa\run-economy-staging-infra-gate.mjs` with
  `STAGING_PSQL_COMMAND=scripts\qa\psql.cmd`.
- Fresh staging-collector rerun on `2026-07-04`:
  `node --check scripts\qa\run-staging-generation-scheduler-smoke.mjs`,
  `node scripts\qa\run-staging-generation-scheduler-smoke.mjs --help`, and
  the `.env.staging.local.example` missing-input run passed the intended local
  contract. The runner exited `1` before artifact or runtime work and printed
  only missing input names.
- Fresh economy staging-gate rerun on `2026-07-04`:
  `node --check scripts\qa\run-economy-staging-infra-gate.mjs`, `--help`,
  `.env.staging.local.example` missing-input validation, localhost DB-target
  rejection, and repo-local `scripts\qa\psql.cmd` wrapper rejection all behaved
  as intended. Negative evidence summaries were written under `%TEMP%`, not the
  repo.
- Fresh template-feed release-gate input validation on `2026-07-04`:
  `.\scripts\qa\run-template-feed-tz1-8-release-gate.ps1 -EnvFile
  .env.staging.local.example -ValidateStagingInputsOnly -ReleaseGateArtifactDir
  <temp>` exited `1` with
  `Missing required environment variable(s): STAGING_PROMETHEUS_BASE_URL` and a
  failed temp summary for the `staging input readiness` step.
- `node --check scripts\qa\validate-template-feed-tz1-8-evidence.mjs`.
- `node --check scripts\qa\test-template-feed-tz1-8-evidence-validator.mjs`.
- `node scripts\qa\test-template-feed-tz1-8-evidence-validator.mjs`.
- `node --check scripts\qa\promote-template-feed-long-scroll-artifact.mjs`.
- `node --check scripts\qa\test-template-feed-long-scroll-promoter.mjs`.
- `node scripts\qa\test-template-feed-long-scroll-promoter.mjs`.
- QA script self-tests:
  `test-markdown-local-links.mjs`, `test-script-safety-inventory.mjs`,
  `test-watermark-qa-help.mjs`,
  `test-template-feed-admin-qa-report-draft.mjs`,
  `test-template-feed-load-probe.mjs`,
  `test-template-feed-long-scroll-promoter.mjs`,
  `test-template-feed-release-gate.mjs`,
  `test-template-feed-staging-snapshot.mjs`, and
  `test-template-feed-tz1-8-evidence-validator.mjs` all passed in the latest
  rerun.
- PowerShell parser check for every `scripts/**/*.ps1`.
- `bash -n` for every `scripts/**/*.sh`.
- `python -m py_compile` for every `scripts/**/*.py`.
- Full markdown local-link check with `node scripts\qa\check-markdown-local-links.mjs`.

## Checks Not Claimed As Done

- No provider/device-backed staging smoke has been proven with real
  FAL/R2/Stripe, Google Play, App Store, FCM, or APNs credentials/device
  evidence.
- No production-signed Android AAB has been built because
  `apps/petmagic-mobile/android/key.properties` and the production keystore are
  intentionally absent from git.
- No final clean release PR/commit scope exists yet; the current dirty tree must
  be split and revalidated after staging.
- No iOS store artifact was built in this Windows workspace.

## Provider And Staging Evidence Matrix

The latest `2026-07-04` preflight review confirmed the repo has runnable staging
evidence collection scripts, but the required external inputs are intentionally
blank in `.env.staging.local.example` and were not available in this workspace.
This keeps provider evidence as a release blocker rather than converting local
checks into production proof.

- Generation/FAL/R2/Prometheus staging smoke:
  `scripts/qa/run-staging-generation-scheduler-smoke.mjs` requires
  `STAGING_API_BASE_URL`, `STAGING_DATABASE_URL`, active image/video/failing
  template IDs, free and premium auth tokens, `STAGING_PROMETHEUS_BASE_URL`,
  distinct API/worker process labels, and a production-equivalent migration
  tooling label. With `.env.staging.local.example`, the runner exited before
  runtime calls and printed only missing variable names. The latest syntax/help
  preflight was rerun on `2026-07-04`, and the missing-input run reported:
  `STAGING_API_BASE_URL`, `STAGING_DATABASE_URL`,
  `STAGING_IMAGE_TEMPLATE_ID`, `STAGING_VIDEO_TEMPLATE_ID`,
  `STAGING_FAILING_TEMPLATE_ID`, `STAGING_FREE_AUTH_TOKENS` or
  `STAGING_FREE_JWT`, `STAGING_PREMIUM_AUTH_TOKENS` or `STAGING_PREMIUM_JWT`,
  `STAGING_PROMETHEUS_BASE_URL`, `STAGING_API_PROCESS_ID`,
  `STAGING_WORKER_PROCESS_ID`, and `STAGING_MIGRATION_TOOLING_LABEL`.
- Economy staging infrastructure gate:
  `scripts/qa/run-economy-staging-infra-gate.mjs` requires
  `STAGING_DATABASE_URL` for read-only database invariants and can use
  `STAGING_API_BASE_URL` plus `STAGING_ADMIN_AUTH_TOKEN` for runtime/admin
  probes. Migration apply remains gated behind both
  `ECONOMY_GATE_RUN_MIGRATIONS=true` and
  `ECONOMY_GATE_BACKUP_CONFIRMED=true`. The latest syntax/help preflight was
  rerun on `2026-07-04`, and the `.env.staging.local.example` negative run
  failed fast with `Missing required env: STAGING_DATABASE_URL` while writing
  sanitized evidence to a temp directory outside the repo. Additional negative
  reruns confirmed the gate rejects
  `STAGING_DATABASE_URL=postgres://...@localhost:5432/...` and
  `STAGING_PSQL_COMMAND=scripts\qa\psql.cmd` before EF, SQL, or runtime probes.
- Template-feed staging/release evidence:
  `scripts/qa/run-template-feed-tz1-8-release-gate.ps1` has a
  `-ValidateStagingInputsOnly` mode that checks staging inputs without running
  collection. The latest direct run against `.env.staging.local.example` was
  rerun on `2026-07-04` and failed fast on
  `STAGING_PROMETHEUS_BASE_URL`, with a failed temp summary for the
  `staging input readiness` step. The related self-tests passed for the
  release gate, evidence validator, staging snapshot runner, feed load probe,
  and long-scroll artifact promoter, so the validators are runnable locally but
  still have no real staging Prometheus/feed evidence.
- Payment/store/push sandbox evidence:
  `docs/payments-sandbox-checklist.md` remains the authoritative manual evidence
  list for Stripe token packs/subscriptions, Google Play and App Store store
  purchases, FCM delivery, wallet refresh, replay/idempotency, and admin
  visibility. All listed external flows remain `needs verification` until run
  with sandbox credentials, devices/accounts, and provider callbacks.
- Local-target rejection:
  `node scripts/qa/test-script-safety-inventory.mjs` passed and pins the
  generation smoke local-vs-staging policy, Economy local target rejection,
  Economy repo-local Docker compose `psql` wrapper rejection, and the
  `requireEnv` helper spelling guard.

## Backend Startup And DI Snapshot

The latest backend startup/DI slice rechecked module startup smoke tests and
source-level registration wiring without changing source files:

- Startup smoke tests passed 249/249:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~IdentityApiStartupSmokeTests|FullyQualifiedName~EconomyApiStartupSmokeTests|FullyQualifiedName~TemplatesApiStartupSmokeTests|FullyQualifiedName~SupportChatApiStartupSmokeTests|FullyQualifiedName~GamificationApiStartupSmokeTests"`.
- Host module wiring scan found `PetMagic.Host.Api` registering all five API
  modules: Economy, Identity, SupportChat, Templates, and Gamification.
- API module/endpoint scan found 24 module or endpoint-map matches across the
  host and module API projects, including admin and public endpoint maps for
  identity, economy, templates, support chat, and gamification.
- Hosted-service scan found 16 worker/registration matches. Current background
  services are explicit in infrastructure registration: Identity email dispatch
  and account cleanup, Economy reconciliation, SupportChat attachment cleanup,
  and Templates scheduler config startup, generation worker, media cleanup, and
  template-of-the-day auto-pick workers.

## Payment And Store Local Readiness Snapshot

The latest `2026-07-04` payment/store slice rechecked local code-level
loss-prevention coverage without claiming real provider success:

- Backend:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~EconomyServiceTests|FullyQualifiedName~StoreWebhookSecurityValidatorTests|FullyQualifiedName~EconomyWebhookEndpointValidationTests|FullyQualifiedName~EconomyWebhookProblemSanitizationTests|FullyQualifiedName~EconomyPublicBillingEndpointHardeningTests|FullyQualifiedName~EconomyApiStartupSmokeTests"`
  passed 243/243 tests. This covers Stripe webhook idempotency, payment-status
  gates, subscription ownership conflicts, saved-payment-method rebinding,
  Google Play/App Store pack and premium validation paths, hashed Google Play
  purchase-token storage, replay/legacy-token no-double-credit behavior, store
  webhook security validation, webhook body limits, webhook problem sanitization,
  legacy Stripe route removal, and Economy endpoint policy/body-limit guards.
- Mobile:
  `flutter test test\wallet_repository_test.dart test\wallet_page_test.dart
  test\premium_controller_test.dart test\stripe_checkout_submit_guard_test.dart
  test\store_product_availability_cache_test.dart test\payment_error_key_mapper_test.dart --reporter compact`
  passed 71/71 tests. This covers purchase order path encoding, wallet pricing
  and recovery states, Stripe checkout duplicate-submit guards, offline checkout
  blocking, safe payment error-key mapping, premium checkout safety, and store
  product availability caching behavior.
- Admin:
  `npm test -- src/components/economy-page.content.test.ts
  src/components/economy-page.helpers.test.ts
  src/lib/api-client-economy-query.test.ts
  src/components/users/user-wallet-panel-hardening.test.ts`
  passed 4 files / 60 tests. This covers purchase/subscription filter
  normalization, admin refund and subscription-cancel guards, payment provider
  route payload validation, sanitized economy display/error strings, cache
  invalidation after financial mutations, and guarded user-wallet adjustments.

This is local readiness evidence only. Stripe sandbox payment/webhook replay,
Google Play tester purchase callbacks, App Store sandbox purchase callbacks, and
real FCM/device delivery remain external release blockers until
`docs/payments-sandbox-checklist.md` is executed with real credentials and
provider/device evidence attached.

## Repository Hygiene Scan Snapshot

Additional read-only repository hygiene scans were run after the current change
inventory was recorded:

- Strict backup/temp/scratch filename scan:
  no matches for tracked or untracked files with `.bak`, `.backup`, `.tmp`,
  `.temp`, `.orig`, `.old`, `.rej`, trailing `~`, scratch path segments, or
  `tmp_`/`tmp-` path segments after excluding build/cache directories.
- `2026-07-04` filename-level rerun over `git ls-files` plus
  `git ls-files --others --exclude-standard` also found no tracked or untracked
  backup/temp/scratch artifacts matching `.bak`, `.backup`, `.old`, `.orig`,
  `.rej`, `.tmp`, `.temp`, `.swp`, `.swo`, `.pid`, `.cache`, `.tsbuildinfo`,
  `.log`, editor backup suffixes, `.DS_Store`, `Thumbs.db`, or `desktop.ini`.
- The broader filename pattern that also includes `debug` and manual API export
  suffixes produced only reviewed non-release matches: app debug Android
  manifests, a vendored plugin debug manifest, and the deleted
  `PetMagic.Host.Api.http` scratch file. No untracked manual API/Postman/Insomnia
  export file was found.
- Production source marker scan over `apps/admin-web/src`,
  `apps/petmagic-mobile/lib`, and `src`:
  no actionable `TODO`, `FIXME`, `HACK`, `XXX`, `debugger`, `console.log`,
  `debugPrint(`, `print(`, or `Console.WriteLine` leftovers were found.
  The remaining matches were reviewed as false positives from identifiers such
  as `Fingerprint`, not debug output calls.
- A stricter current-worktree rerun excluding tests, generated files,
  migrations, build/cache output, and CLI scripts also found no actionable
  runtime leftovers: 0 matches for `TODO`/`FIXME`/`HACK`/`XXX`, 0 for
  `NotImplementedException`, 0 for user-facing stub phrases, 0 for `debugger`,
  0 for disallowed `console.log`/`console.debug`/`console.info`/`console.trace`,
  0 for backend `Console.Write*`/`Debug.Write*`/`Trace.Write*`, and 0 for mobile
  `print(`/`debugPrint(`. The only direct runtime console matches were
  `apps/admin-web/src/lib/client-logger.ts` `console.warn/error` (1 file,
  2 matches), which are the allowlisted sanitized admin client logging sink.
  Mobile `developer.log` remains limited to the allowlisted `AppLogger` and
  `RequestIdentity` wrappers (2 files, 2 matches).
- Latest commented-out-code scan over production `src`, admin `src`, and mobile
  `lib`, excluding tests/generated/migrations/build/cache output, found no
  actionable commented-out implementation blocks. The only `//` code-shaped hit
  was prose in `template_feed_playback_manager.dart` describing a playback scope
  switch, not disabled implementation.
- Latest narrowed legacy/temporary/deprecated marker scan found no actionable
  stale implementation. Exact lowercase `legacy` hits were 19 matches across
  7 files and remain compatibility/read-migration paths for wallet token
  defaults/projection, template category fallback metrics, admin economy
  fallback labeling, and mobile cache/key migration. Exact lowercase
  `temporary` hits were 7 matches across 5 files and are the upload optimizer's
  temporary-file API, template media lifecycle state/cleanup, and a fal.ai
  outage resilience comment. The single `deprecated` hit is the Economy guard
  error that rejects deprecated Stripe checkout/native PaymentSheet disclosure
  copy. `obsolete` and exact `compatibility` had 0 matches. The broad
  `fallback` bucket was 176 matches across 66 files and was reviewed as normal
  error-message defaults, parser defaults, media filename defaults, localization
  defaults, category fallback metrics, and guarded payment/store fallback paths.
- `RepositorySecretHygieneTests` now pins the runtime source marker/debug-output
  scan and passed 16/16 targeted tests after adding guards for `XXX`,
  `debugger`, `console.log`, `console.debug`, `console.trace`, `debugPrint(`,
  `print(`, `Console.WriteLine`, and high-confidence secret values in deployable
  source/config files.
- Latest `2026-07-04` split-readiness rerun of
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter FullyQualifiedName~RepositorySecretHygieneTests`
  passed 16/16 tests. The build emitted transient copy-retry warnings because an
  old `testhost` process briefly held the test assembly, then rebuilt and ran
  successfully.
- Secret-like scan:
  no live repository secret was found. A fresh non-test runtime/config marker
  scan for private-key blocks, Stripe secret/webhook keys, Firebase API-key
  shapes, AWS access keys, GitHub tokens, and Slack tokens returned 0 findings.
  A current tracked-plus-untracked signing-material scan found 0 `*.jks`, 0
  `*.keystore`, and 0 `key.properties` files. The root
  `GoogleService-Info.plist` is absent from the working tree and remains only as
  a tracked deletion until commit packaging.
  A latest value-only scan over `.env.example`, `.env.local-smoke.example`,
  `.env.staging.local.example`, admin staging env, API/worker source
  `appsettings*.json`, and the active mobile Firebase placeholder configs found
  no secret-looking values.
  A latest sanitized high-confidence scan over non-ignored files returned only
  test/redaction fixtures for private-key and Stripe live-key patterns; no
  runtime/config/doc file matched those live secret shapes. The new deployable
  source/config guard excludes docs/tests and passed as part of the 16/16
  `RepositorySecretHygieneTests` rerun.
  One docs-only Firebase API-key-shaped placeholder in
  `docs/watermark-monetization-manual-qa.md` was replaced with non-tokenized
  guidance so docs do not trip secret scanners. Remaining broad matches are
  sanitizer tests, fake test fixtures, and production validator prefix checks
  such as `sk_live_`, `rk_live_`, and `pk_live_`.
- Broad non-production scan still contains intentional CLI/test/docs output:
  QA scripts use `console.log` for command-line reporting, draft QA generators
  intentionally create `TODO` rows that release validators reject, and vendored
  `third_party` plugin examples contain upstream debug/demo output.
- Fresh QA self-tests for this classification passed:
  `test-script-safety-inventory.mjs`, `test-markdown-local-links.mjs`,
  `test-template-feed-admin-qa-report-draft.mjs`, and
  `test-template-feed-release-gate.mjs`.

These scans improve the repo-hygiene evidence but do not replace the remaining
provider/device-backed staging and production signing gates.

## Debug And Bypass Surface Snapshot

Runtime debug/bypass surfaces were rechecked after the general marker scan:

- `2026-07-04` hardcoded local/dev URL scan across backend `src`, admin `src`,
  mobile `lib`, root/admin env examples, README files, and `docker-compose.yml`
  found only documented local setup values, Development appsettings/launch
  settings, local-smoke examples, Docker healthchecks, and guarded runtime
  classifiers. No new production-facing hardcoded localhost API/media URL was
  found.
- Targeted guard rerun passed after that scan:
  `npm test -- src/lib/admin-api-base-url.test.ts src/lib/next-config-env.test.ts`
  passed 25/25 admin URL/env tests, and
  `flutter test test\production_networking_config_test.dart --reporter compact`
  passed 7/7 mobile production-networking tests.
- `2026-07-04` bypass-marker scan found only the mobile local packaging
  `allowInsecureReleaseSigning` guard and one Gradle comment about stripping a
  generated `integration_test` plugin registration from local release builds.
  The release-signing guard still throws for release tasks when real signing is
  missing unless the explicit `-PallowInsecureReleaseSigning=true` local
  override is supplied.
- The current signing refresh confirms that no local production signing material
  is available: `android/key.properties` is absent and no mobile `*.jks`,
  `*.keystore`, or `key.properties` file was found. The failed
  `flutter build appbundle --release` run did not change the tracked/untracked
  worktree counts.
- The active Firebase placeholders were rechecked on `2026-07-04`:
  `apps/petmagic-mobile/android/app/google-services.json` reports
  `project_id=petmagic-placeholder` and `project_number=000000000000`, while
  `apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist` reports
  `PROJECT_ID=petmagic-placeholder`; neither contains `private_key` or
  `client_email`.
- Latest Firebase/signing refresh confirms the only active Firebase config
  files are still the Android app JSON and iOS Runner plist. Root-level
  `GoogleService-Info.plist`, root-level `google-services.json`, and
  `apps/petmagic-mobile/android/key.properties` are absent. The Android
  placeholder reports `project_id=petmagic-placeholder` and
  `project_number=000000000000`; the iOS plist reports
  `BUNDLE_ID=com.petmagic.app` and `PROJECT_ID=petmagic-placeholder`. Neither
  file contains `private_key` or `client_email`.
- Mobile tunnel headers (`ngrok-skip-browser-warning` and
  `Bypass-Tunnel-Reminder`) are only sent from Dio and health probes inside
  `kDebugMode`. A production-networking contract test now pins this behavior.
- Mobile local API candidate discovery remains debug-only; release resolution
  normalizes to the production HTTPS API host and rejects local HTTP/private
  network candidates.
- Mobile debug/profile switches for performance overlays, frame telemetry, and
  Firebase smoke skipping are test-covered as non-release behavior.
- Latest native flag scan found Android release/main manifest
  `usesCleartextTraffic="false"`. The only cleartext overrides are in
  debug/profile Android manifests. The Gradle signing guard still exposes
  `allowInsecureReleaseSigning` only as an explicit local packaging override,
  with `app_config_debug_tools_test.dart` pinning that release tasks cannot
  silently fall back to the debug keystore.
- Admin rejects localhost, non-HTTPS, placeholder hosts, query strings,
  fragments, and credentials for production API URLs by default. The only
  localhost production-build escape hatch is
  `ADMIN_WEB_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=true`, and it appears in
  `.env.local-smoke.example` only. Root `.env.example`, staging examples, and
  Docker compose default it to `false`.
- Root `.env.example` no longer defaults the Alertmanager webhook to
  `host.docker.internal` or local HTTP. The guard is pinned by
  `BackendEnvironmentContractTests.EnvExampleMonitoringWebhook_ShouldNotDefaultToLocalOrInsecureUrl`;
  `dotnet test ... --filter "FullyQualifiedName~BackendEnvironmentContractTests"`
  passed 18/18 tests, `docker compose --env-file .env.example config --quiet`
  passed, and the admin env URL guard rerun passed 25/25 tests.
- Admin secure-media rendering now blocks local/private/wildcard/Docker/compose
  and placeholder media hosts before direct rendering or browser fetch for
  template preview media, support attachments, and user avatar/pet media.
  User-media local URL rewriting remains limited to explicit local development
  hostnames when the configured admin API origin is also local.
- Backend OpenAPI mapping is Development-only. `BootstrapAdmin:Password` is
  rejected outside Development, and the templates `Fake` AI provider is rejected
  in Production by the templates infrastructure validator.
- Admin production source has no `console.log`, `console.debug`, or
  `console.info` calls. Mobile production source has no `print(` or
  `debugPrint(` calls; remaining `developer.log` calls are centralized logging
  paths that redact stack traces or detail outside debug where applicable.
- The latest refined disabled/focused-test scan found 0 actionable markers. A
  broad first pass that matched the word `skip` was intentionally discarded as
  too noisy because the hits were pagination parameters, test names, and QA
  script wording. The production scan was rerun with marker-specific patterns
  and found no skipped, focused, or disabled tests in the checked backend,
  admin, or mobile test surfaces.
- The latest guard reruns for this surface passed:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~RepositorySecretHygieneTests"`
  passed 16/16, admin
  `npm test -- src\lib\logging-policy.test.ts src\lib\client-logger.test.ts src\lib\client-logger.privacy.test.ts src\lib\admin-api-base-url.test.ts src\lib\next-config-env.test.ts`
  passed 5/5 files and 46/46 tests, and mobile
  `flutter test test\app_config_debug_tools_test.dart test\production_networking_config_test.dart --reporter compact`
  passed 13/13 tests.

Result: no new release blocker was found in the debug/bypass sweep. The admin
localhost escape hatch remains a local-smoke compatibility hold and must not be
enabled in staging or production deployments.

## Signed Media URL Snapshot

Signed and response-level local media URL handling was rechecked across the
active backend media surfaces:

- Avatar read URLs under `/user-avatars`.
- Support attachment read URLs under `/support-attachments`.
- Template media read URLs under `/templates-media`.
- Avatar, support attachment, and template local-file cleanup paths.
- R2 template media object keys.
- Template media lifecycle storage path persistence.
- Generation storage path normalization.

Findings:

- Production local template media is intentionally blocked at startup by the
  templates infrastructure validator (`Local templates media storage cannot be
  used in Production`), so the non-development `/templates-media` static-file
  404 guard is defense-in-depth rather than a broken signed URL path.
- The three read-url signers and the avatar/support response helpers shared a
  weaker path segment check: encoded path separators such as `%2f`/`%5c` and
  malformed percent-encoding such as `%zz` could leave managed media paths
  ambiguous instead of being rejected.
- Local storage cleanup paths had the same inconsistency: literal `.`/`..`
  segments were rejected, but decoded separators and malformed percent-encoding
  were not rejected before resolving managed delete paths.
- R2 managed key resolution and template lifecycle/generation storage path
  normalization had the same inconsistency for production object-key URLs.

Cleanup performed:

- Avatar, support attachment, and template media signers now treat invalid
  percent-encoding as unsafe.
- Decoded `/` and `\` inside a managed media path segment are rejected before
  signing or authorizing a read request.
- Avatar and support response helpers apply the same rejection before returning
  stored managed media URLs.
- Avatar, support attachment, and template local-file storage cleanup now apply
  the same rejection before deleting a managed local file.
- R2 media storage, template media lifecycle storage path persistence, and
  generation storage path resolution now apply the same rejection before
  normalizing a managed object key.
- The duplicated unsafe-segment implementations were consolidated into
  `ManagedPathSegments` under BuildingBlocks. Module-specific normalizers now keep
  only their prefix/base URL logic and delegate segment safety to the shared
  helper.
- Managed media signing tests now cover encoded slash, encoded backslash,
  malformed percent-encoding, and legacy query/fragment stripping.
- Avatar privacy and support attachment response tests now cover encoded slash,
  encoded backslash, and malformed percent-encoding suppression.
- Local storage deletion tests now create literal encoded/malformed filenames
  and prove cleanup leaves them untouched when addressed through ambiguous
  managed media URLs.
- R2 key-resolution tests now reject encoded slash, encoded backslash, and
  malformed percent-encoding in direct keys and CDN URLs.
- Template media lifecycle tests now prove unsafe encoded/malformed managed URLs
  are persisted as original external-looking strings instead of canonical managed
  storage paths.
- Generation storage path source-contract tests now pin the same unsafe-segment
  logic in the job response storage resolver.

Verification:

- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`
  passed: 47/47 tests.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests|FullyQualifiedName~IdentityServiceProfileTests.GetCurrentUserAsync_ShouldSuppressUnsafeManagedAvatarUrl|FullyQualifiedName~SupportChatServiceTests.SendMessageWithAttachmentsAsync_WithUnsafeManagedAttachmentUrl_ShouldSuppressReturnedFileUrl"`
  passed: 59/59 tests.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests"`
  passed: 34/34 tests.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`
  passed: 81/81 tests.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests"`
  passed: 38/38 tests.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests"`
  passed: 66/66 tests.
- Literal source scan confirmed avatar, support, local template, R2, lifecycle,
  and generation storage helpers now route segment checks through unsafe-segment
  helpers with invalid-percent and decoded-separator rejection.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~ManagedPathSegmentsTests|FullyQualifiedName~LocalAvatarStorageTests|FullyQualifiedName~LocalSupportAttachmentStorageTests|FullyQualifiedName~LocalFileMediaStorageTests|FullyQualifiedName~AvatarReadUrlSignerTests|FullyQualifiedName~SupportAttachmentReadUrlSignerTests|FullyQualifiedName~TemplateMediaReadUrlSignerTests|FullyQualifiedName~IdentityServiceProfileTests.GetCurrentUserAsync_ShouldSuppressUnsafeManagedAvatarUrl|FullyQualifiedName~SupportChatServiceTests.SendMessageWithAttachmentsAsync_WithUnsafeManagedAttachmentUrl_ShouldSuppressReturnedFileUrl|FullyQualifiedName~R2MediaStorageKeyResolutionTests|FullyQualifiedName~TemplateMediaLifecycleStoragePathTests|FullyQualifiedName~TemplateStoragePathResolutionSourceTests"`
  passed: 143/143 tests.
- The same 143-test filter passed with `--no-build` after the build-backed run.
- Duplicate-helper source scan now shows `ContainsInvalidPercentEncoding`,
  `IsHexDigit`, and `Uri.UnescapeDataString(segment)` only in
  `ManagedPathSegments.cs`, not in the module infrastructure classes.
- An earlier `--no-build` rerun used the stale pre-change test assembly and
  failed the new malformed-percent cases. The same filtered suite was rerun with
  build enabled and passed.
- One rebuild-backed run hit a transient stale `testhost` file lock on
  `PetMagic.Modules.Identity.Tests.dll`. The blocking process had exited by the
  time it was checked, and the same command was rerun successfully.

## Static Asset Snapshot

Mobile/admin static assets were inventoried across `apps/petmagic-mobile/assets`
and `apps/admin-web/public`:

- Mobile has 19 tracked source asset files, currently totaling 23,242,998 bytes
  under `apps/petmagic-mobile/assets`.
- Admin `public` is currently empty. The previous `.gitkeep` had no references
  and was removed because an empty Next.js `public` directory is not required.
- Every mobile image asset has either a runtime Dart reference or a tooling
  reference:
  - Auth, premium, wallet, rewards, profile, and template-flow images are
    referenced from mobile UI source.
  - `assets/icons/app_icon.png` is referenced by `flutter_launcher_icons` and
    `scripts/generate-brand-icons.ps1`.
  - `assets/branding/petmagic-app-icon-1024.png` is retained as a source input
    for icon generation scripts, but it is not a runtime UI asset.
- `assets/fonts/Comfortaa-*.ttf` are retained intentionally. The app disables
  Google Fonts runtime fetching at startup, and the local `google_fonts` package
  resolves Comfortaa weights from bundled `.ttf` assets through the
  `AssetManifest`.

Cleanup performed:

- `apps/petmagic-mobile/pubspec.yaml` now lists only
  `assets/branding/premium-hero-dark.png` and
  `assets/branding/premium-hero-light.png` instead of the whole branding
  directory.
- This keeps `assets/branding/petmagic-app-icon-1024.png` available for tooling
  while removing it from the Flutter runtime asset bundle.

Verification:

- `flutter test test\mobile_asset_inventory_test.dart --reporter expanded`
  passed: 3/3 tests.
- Latest compact rerun of `flutter test test\mobile_asset_inventory_test.dart test\production_networking_config_test.dart --reporter compact`
  passed 16/16 tests. The current asset scan found 19 files and `pubspec.yaml`
  still bundles only `assets/auth/`, the two premium hero files, `assets/fonts/`,
  and `assets/rewards/`; `assets/icons/app_icon.png` remains tooling-only via
  `flutter_launcher_icons` and `scripts/generate-brand-icons.ps1`.
- Latest focused asset rerun passed:
  `flutter test test\mobile_asset_inventory_test.dart --reporter compact`.
  Result: 3/3 tests. The same run repeated dependency resolution and still
  reported the known 16 constraint-bound outdated package notices.
- Latest manual asset reference scan covered the 19 files under
  `apps/petmagic-mobile/assets` against mobile `lib`, mobile tests,
  integration tests, `pubspec.yaml`, `scripts`, and `docs`. It found 0 assets
  without a runtime, test, or tooling reference in the scanned roots.
- Latest admin static scan found 0 files under `apps/admin-web/public`.
- `flutter analyze` passed with no issues after the asset/test changes.
- `flutter build bundle --release --dart-define=API_BASE_URL=https://api.petmagic.app`
  passed.
- `build/flutter_assets/assets/branding` contains only
  `premium-hero-dark.png` and `premium-hero-light.png`.
- `Test-Path build\flutter_assets\assets\branding\petmagic-app-icon-1024.png`
  returned `False`; the two premium hero asset checks returned `True`.

## Tracked Artifact And Local Config Snapshot

Tracked repository files were scanned for build/cache output, temporary files,
binary release artifacts, local IDE state, and misplaced local-only configs.

Findings:

- Latest `2026-07-04` artifact-hygiene rerun checked 2310 existing tracked
  files. It found 0 tracked build/cache/release/temp artifact matches and 0
  tracked manual API/export matches.
- The same rerun checked 59 untracked files. The latest strict suspicious-name
  scan found 0 backup/temp/scratch matches outside ignored
  build/vendor/evidence directories.
- `git ls-files --deleted` reports six tracked deletions. Five are reviewed
  stale removals: `.mimocode/plans/1782243995518-gentle-squid.md`,
  `GoogleService-Info.plist`, `apps/admin-web/public/.gitkeep`,
  `docs/md/STATUS.md`, and `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http`.
  The sixth is the mobile monetization refactor deletion
  `apps/petmagic-mobile/lib/shared/payments/stripe_paymentsheet_coordinator.dart`.
- No tracked paths were found under build/cache output directories such as
  `bin`, `obj`, `build`, `.dart_tool`, `.next`, `node_modules`, `coverage`,
  `dist`, `out`, `artifacts`, `TestResults`, `.vs`, or `.idea`.
- No tracked temporary/rejected/backup/release-output files were found with
  extensions or names such as `.bak`, `.backup`, `.tmp`, `.temp`, `.orig`,
  `.old`, `.rej`, trailing `~`, `.log`, `.nupkg`, `.apk`, `.aab`, `.ipa`,
  `.keystore`, `.jks`, or `key.properties`.
- No manual API scratch/export files were found for `.http`, `.rest`, Postman,
  or Insomnia patterns outside ignored build/cache directories. The previously
  tracked `src/Host/PetMagic.Host.Api/PetMagic.Host.Api.http` remains deleted.
- Tracked env/appsettings files are limited to examples or explicit production/
  staging appsettings files covered by existing configuration validators.
- The current untracked `.config/dotnet-tools.json` was inspected and retained
  as an audit-owned tooling artifact, not local IDE state. It is a root
  `dotnet-ef` `10.0.9` manifest used to make EF migration checks reproducible.
  `dotnet tool restore` and `dotnet tool list` both resolved it successfully.
- A fresh suspicious-name scan over non-build, non-cache paths found only
  legitimate files: mobile temp-media cleanup source/tests, debug manifests,
  `scripts/backup-postgres.ps1`, logging context source, and vendored Flutter
  plugin example debug configs. No additional `.bak`, `.tmp`, scratch, manual
  HTTP, or export artifact was proven safe to remove in this pass.
- The root-level `GoogleService-Info.plist` had no active build/project
  reference. It was referenced only by mobile README guidance and repository
  secret-hygiene tests, so it was removed as a stale placeholder.
- The active mobile Firebase placeholder paths remain:
  - `apps/petmagic-mobile/android/app/google-services.json`.
  - `apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist`.
- The Android Firebase config still reports placeholder metadata
  (`petmagic-placeholder`) and no `private_key`/`client_email`/service-account
  payload. The iOS Runner plist contains placeholder Firebase client fields and
  no private-key/service-account payload.

Verification:

- `rg`/`git ls-files` reference checks now show `GoogleService-Info.plist`
  references only for the active iOS Runner file, README, iOS project, and
  tests.
- `RepositorySecretHygieneTests` now has a regression guard that forbids
  root-level `GoogleService-Info.plist` and `google-services.json` while
  requiring the platform-specific mobile placeholder files to remain in their
  Android/iOS project locations.
- `RepositorySecretHygieneTests` also checks the whole repository for manual
  API scratch files and exported Postman/Insomnia collections, excluding only
  ignored build/cache paths.
- `dotnet tool restore` restored `dotnet-ef` `10.0.9` from
  `.config/dotnet-tools.json`; `dotnet tool list` reported the same manifest.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false -p:OutputPath=..\..\backend\artifacts\identity-tests-secret-hygiene --filter "FullyQualifiedName~RepositorySecretHygieneTests"`
  passed: 16/16 tests in the latest rerun.
- Earlier `--no-build` or default-output runs failed because they used stale
  assemblies or hit a stale `testhost` DLL lock. The same filtered suite was
  rerun with build enabled and an isolated output path and passed.

## Runtime Dev/Production Config Scan Snapshot

Production-readiness config scans were run over the active runtime surfaces:

- Backend base and production appsettings:
  `src/Host/PetMagic.Host.Api/appsettings.json`,
  `src/Host/PetMagic.Host.Api/appsettings.Production.json`,
  `src/Host/PetMagic.Host.GenerationWorker/appsettings.json`, and
  `src/Host/PetMagic.Host.GenerationWorker/appsettings.Production.json`.
- Docker/env examples:
  `.env.example`, `.env.local-smoke.example`, `.env.staging.local.example`,
  `apps/admin-web/.env.staging.example`, and `docker-compose.yml`.
- Admin/mobile runtime config:
  `apps/admin-web/next.config.ts` and
  `apps/petmagic-mobile/lib/core/config/app_config.dart`.

Findings:

- Production appsettings do not contain localhost API/media URLs or enabled seed
  data. Base appsettings keep secrets empty and local media paths non-public.
- `.env.example` and `.env.local-smoke.example` intentionally remain
  development/local-smoke profiles with `Local`/`Fake` providers and localhost
  examples. They are not staging or production evidence.
- `.env.local-smoke.example` now includes its own isolated host port set for
  postgres, backend, admin-web, and Mailpit. This keeps the documented
  `petmagic_goal_probe` command independent from default compose ports and from
  shell-specific environment overrides.
- `.env.staging.local.example` uses staging-safe provider selections
  (`R2`/`Fal`) and keeps secrets blank or placeholder-only for injection through
  the deployment secret store.
- Required compose interpolation coverage was rechecked against the tracked env
  templates after the latest config pass: `ALERTMANAGER_WEBHOOK_URL`,
  `BACKEND_ALLOWED_HOSTS`, `BACKEND_HEALTHCHECK_HOST`,
  `BACKEND_PUBLIC_BASE_URL`, `GRAFANA_ADMIN_PASSWORD`,
  `INTERNAL_API_BASE_URL`, `JWT_SIGNING_KEY`, `NEXT_PUBLIC_API_BASE_URL`,
  `PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION`, `POSTGRES_PASSWORD`,
  `TEMPLATES_AI_PROVIDER`, and `TEMPLATES_STORAGE_PROVIDER` are present in all
  three root env templates.
- Local ignored `.env` was also checked as part of the current runtime state.
  It intentionally remains a local-development profile, but it now includes the
  required `BACKEND_ALLOWED_HOSTS` and `BACKEND_HEALTHCHECK_HOST` compose
  variables so local Docker management commands do not fail interpolation.
- The default backend and generation-worker containers were recreated from the
  current `.env` after the local host change. Docker inspection now shows
  backend effective `AllowedHosts=localhost;127.0.0.1;[::1];backend`, and
  default-stack `/health` plus `/api/templates/feed?limit=3` pass with
  `Host: localhost`.
- Admin production builds reject localhost, non-HTTPS, placeholder hosts, query
  strings, fragments, and credentials unless the explicit local-only escape
  hatch is enabled. Targeted Vitest coverage passed: 13/13 tests.
- Mobile release API resolution normalizes only `https://api.petmagic.app` and
  rejects local/debug candidates. Targeted production-networking Flutter
  coverage passed: 6/6 tests.
- Backend production validators and environment-contract tests passed: 108/108
  targeted tests in the `2026-07-04` rerun:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~HostApiProductionConfigurationValidatorTests|FullyQualifiedName~BackendEnvironmentContractTests"`.

One attempted Admin test command used a Jest-only option
`--runTestsByPath`; Vitest rejected it. The same test file was rerun with the
current runner syntax, `npm test -- src/lib/next-config-env.test.ts`, and passed.

## API Contract Drift Snapshot

The latest `2026-07-04` cross-client contract slice checked backend route
contracts and endpoint hardening, admin typed API-client query construction, and
mobile API/networking controller and repository behavior:

- Backend:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~ClientApiContractRouteTests|FullyQualifiedName~AdminTemplateEndpointHardeningTests|FullyQualifiedName~AdminEconomyEndpointHardeningTests|FullyQualifiedName~AdminUserEndpointHardeningTests|FullyQualifiedName~GamificationEndpointHardeningTests|FullyQualifiedName~SupportChatEndpointHardeningTests|FullyQualifiedName~TemplateGenerationEndpointsSecurityTests|FullyQualifiedName~EconomyClientBillingEndpointHardeningTests|FullyQualifiedName~EconomyPublicBillingEndpointHardeningTests|FullyQualifiedName~FeedbackEndpointsSecurityTests|FullyQualifiedName~PublicTemplateEndpointsSecurityTests"`
  passed 94/94 tests in the latest no-build rerun against the current test
  project outputs.
- Admin:
  `npm test -- src/lib/api-client-admin-users-query.test.ts src/lib/api-client-economy-query.test.ts src/lib/api-client-feedback-query.test.ts src/lib/api-client-support-query.test.ts src/lib/api-client-templates-query.test.ts`
  passed 5/5 files and 65/65 tests.
- Mobile:
  `flutter test test\app_config_security_test.dart test\api_base_url_resolver_lifecycle_test.dart test\production_networking_config_test.dart test\templates_controller_test.dart test\template_generation_controller_test.dart test\template_generation_repository_test.dart test\templates_repository_test.dart test\support_chat_repository_test.dart test\wallet_repository_test.dart test\premium_controller_test.dart --reporter compact`
  passed with `All tests passed!` and 154/154 targeted tests.
- Mobile premium/payment follow-up:
  `flutter test test\premium_repository_test.dart test\premium_controller_test.dart test\wallet_repository_test.dart test\store_product_availability_cache_test.dart --reporter compact`
  passed 35/35 targeted tests, including store-purchase verification cancel-token
  propagation from `PremiumRepository`.

The first backend run surfaced a stale test assembly symptom: the runner reported
an old `SupportChatEndpointHardeningTests` assertion even though the current
source already pins `BuildProblemExtensions`. `dotnet clean` plus a fresh
test-project build and a no-build rerun cleared the artifact and passed the same
SupportChat source-contract tests 4/4, then the full backend contract set 82/82.
This is recorded as a local build-artifact diagnostic, not a remaining API
contract blocker. The later backend route/auth refresh expanded the same
contract slice with public billing, feedback, and public-template hardening
coverage and passed 94/94.

## Dependency And Security Snapshot

Dependency checks were rerun from the current worktree without applying package
upgrades. The latest `2026-07-04` freshness rerun covered
`dotnet list ... --vulnerable`, `dotnet list ... --deprecated`,
`dotnet list ... --outdated`, `npm audit`, `npm outdated --long`, admin
dependency-inventory tests, and `flutter pub outdated`:

- `.NET`: `dotnet list PetMagic.slnx package --vulnerable --include-transitive`
  reported no vulnerable packages across all solution projects for the
  configured NuGet sources. This vulnerability audit was rerun against the
  current `Directory.Packages.props` state after the backend/Docker refresh and
  remained clean.
- `.NET`: `dotnet list PetMagic.slnx package --deprecated` reported no
  deprecated packages in production projects. The only deprecated package signal
  is test-only `xunit 2.9.3` in `PetMagic.Modules.Identity.Tests`, marked
  `Legacy` by NuGet with `xunit.v3` as the alternative.
- `apps/admin-web`: `npm audit --audit-level=moderate` reported
  `found 0 vulnerabilities` against the current `package-lock.json` in the
  latest rerun.
- `.github/workflows/admin-web-ci.yml` now preserves that dependency security
  gate in CI, running the same audit command immediately after `npm ci`.
- `apps/admin-web`: runtime and dev dependency inventory now has targeted
  source/script/config evidence coverage. The current rerun of
  `npm test -- src\lib\dependency-inventory.test.ts` passed 1/1 file and 2/2
  tests, and targeted lint completed successfully.
- `apps/admin-web`: `npm outdated --long` still reports only dev-tooling
  follow-ups (`@types/node`, `eslint`, `typescript`); the command exits with
  code `1` because outdated packages exist, not because the audit failed.
- `apps/petmagic-mobile`: `flutter pub outdated` completed and reported
  outdated packages, with two upgradable dependencies currently locked in
  `pubspec.lock`, but no security advisory signal.

Current dependency/security refresh after the latest EF/runtime/tooling,
staging-collector, and secret/signing report updates:

- `.NET`: `dotnet list PetMagic.slnx package --vulnerable --include-transitive`
  still reports no vulnerable packages for every solution project.
- `.NET`: `dotnet list PetMagic.slnx package --deprecated` still reports no
  deprecated packages in production projects. The only deprecated signal remains
  test-only `xunit 2.9.3` in `PetMagic.Modules.Identity.Tests` (`Legacy`,
  alternative `xunit.v3`).
- `.NET`: `dotnet list PetMagic.slnx package --outdated` still reports upgrade
  drift for `SixLabors.ImageSharp`, `SixLabors.ImageSharp.Drawing`,
  `AWSSDK.S3`, `Microsoft.OpenApi`, `Google.Apis.Auth`, `Stripe.net`, and
  test-only `coverlet.collector`.
- `apps/admin-web`: `npm audit --audit-level=moderate` still reports
  `found 0 vulnerabilities`.
- `apps/admin-web`: `npm outdated --long` still reports only dev-tooling drift:
  `@types/node`, `eslint`, and `typescript`. The command exits `1` because
  outdated packages exist.
- `apps/admin-web`: `npm test -- src\lib\dependency-inventory.test.ts` passed
  1/1 file and 2/2 tests in the latest rerun. The targeted lint evidence remains
  from the earlier dependency-inventory slice.
- `apps/petmagic-mobile`: `flutter pub outdated` still completes successfully.
  Direct `intl` remains constraint-bound at `0.20.2` with latest `0.20.3`;
  locked transitive upgradable packages remain `cross_file` `0.3.5+2 ->
  0.3.5+4` and `in_app_purchase_storekit` `0.4.10 -> 0.4.10+1`.

Outdated follow-ups currently visible:

- `.NET`:
  - `SixLabors.ImageSharp` `3.1.12 -> 4.0.0`.
  - `SixLabors.ImageSharp.Drawing` `2.1.7 -> 3.0.0`.
  - `AWSSDK.S3` `3.7.511.8 -> 4.0.100.2`.
  - `Microsoft.OpenApi` `2.7.5 -> 3.7.0`.
  - `Google.Apis.Auth` `1.70.0 -> 1.75.0`.
  - `Stripe.net` `51.1.0 -> 52.1.0`.
  - `coverlet.collector` `10.0.0 -> 10.0.1`.
  - `xunit` `2.9.3` in tests is deprecated as `Legacy`; migrate to `xunit.v3`
    in a separate test-framework upgrade pass.
- Admin web dev tooling:
  - `@types/node` `20.19.43 -> 26.1.0`.
  - `eslint` `9.39.4 -> 10.6.0`.
  - `typescript` `5.9.3 -> 6.0.3`.
- Mobile Flutter:
  - Direct dependency `intl` remains at `0.20.2`; latest is `0.20.3`, but the
    current constraint set does not make it upgradable/resolvable in this pass.
  - Locked transitive updates visible in the latest run include `cross_file`
    `0.3.5+2 -> 0.3.5+4` and `in_app_purchase_storekit`
    `0.4.10 -> 0.4.10+1`.
  - Other current drift includes analyzer/test/storage transitive packages such
    as `_fe_analyzer_shared`, `analyzer`, `flutter_secure_storage_darwin`,
    `matcher`, `meta`, `package_config`, `sse_channel`, `test`, `test_api`,
    `test_core`, `vector_math`, and `cli_util`.
  - Several analyzer/test/storage/payment transitive packages have newer latest
    versions, but many are not currently resolvable under the active dependency
    constraints.

These updates were not applied in this pass because they include major SDK/API
surface changes and payment/storage/image-processing packages. They should be
handled as separate upgrade tasks with focused build, test, runtime, and
provider-backed verification.

## EF Migration And Database Snapshot

The latest `2026-07-04` migration pass covered the five active module contexts:
Identity, Economy, Gamification, SupportChat, and Templates.

- Migration inventory: 73 real migration files after excluding designer files
  and all `*ModelSnapshot*` files. Counts by module are Economy 17,
  Gamification 2, Identity 9, SupportChat 11, and Templates 34.
- Pending-model checks: all five
  `dotnet ef migrations has-pending-model-changes --no-build` commands returned
  `No changes have been made to the model since the last migration`. The
  commands used process-local placeholder
  `PETMAGIC_*_MIGRATIONS_CONNECTION_STRING` values only for design-time factory
  construction and did not apply schema changes.
- Latest current-worktree refresh rebuilt the solution first, then reran the
  same five no-build pending-model checks for Identity, Economy, Gamification,
  SupportChat, and Templates. Build result: 0 warnings, 0 errors. Pending-model
  result: all five contexts reported no model changes since the last migration.
  Repo migration file count and both Docker database EF history counts remained
  73.
- Destructive-operation review: the latest refined scan found 7 forward `Up`
  hits and 267 rollback `Down` hits after excluding designer and
  `*ModelSnapshot*` files. Forward hits were reviewed as:
  - index replacement in Economy, SupportChat, and Templates paths;
  - intentional removal of `gamification_achievement_definitions.IconAssetPath`.
- No unreviewed forward `DROP TABLE`, `TRUNCATE`, or broad data-delete migration
  was found in this pass. Rollback remains potentially destructive by design and
  should not be used in production without a backup/restore plan.
- Isolated Docker database evidence: `petmagic_goal_probe` Postgres has 73 rows
  in `__EFMigrationsHistory`, matching the 73 current real migration files, and
  66 public application tables.
- Latest Docker DB refresh: the default Postgres service and isolated
  `petmagic_goal_probe` Postgres service are both healthy; both report 73 rows
  in `__EFMigrationsHistory` and 66 public tables.
- Key wallet/payment/generation structures were rechecked in the isolated Docker
  database: wallet non-negative balance constraint, primary keys, generation
  billing FK, payment/webhook idempotency indexes, and active generation
  idempotency/request-hash indexes are present.
- Focused DB/model guard tests passed 11/11:
  `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --disable-build-servers -m:1 -nr:false -p:UseSharedCompilation=false --filter "FullyQualifiedName~DatabaseIndexModelTests|FullyQualifiedName~SupportChatDbContextIndexTests|FullyQualifiedName~RepairMigrationDocumentationTests|FullyQualifiedName~ModelSnapshotHardeningTests"`.

## Architecture Boundary Snapshot

Read-only boundary scans and targeted tests were run against the current
workspace:

- Admin web DB boundary:
  scanned non-test `apps/admin-web` source and admin package manifests for direct
  DB clients/packages and backend-layer imports such as Prisma, EF/DbContext,
  Npgsql, pg, MySQL, SQLite, TypeORM, Drizzle, Knex, Mongoose, `@/server`,
  `backend\src`, and `src/Modules`. The latest `2026-07-04` strict direct DB
  scan across `apps/admin-web/src` and `apps/admin-web/scripts` returned no
  matches for `DbContext`, EF, Prisma, `pg`, MySQL, SQLite, `DATABASE_URL`,
  connection pools, or raw DML. The boundary is pinned by
  `src/lib/admin-api-boundary.test.ts`, which rejects direct DB packages in
  `package.json` and scans non-test admin source for backend-layer or DB access
  patterns. `npm test -- src/lib/admin-api-boundary.test.ts src/lib/api-client-admin-users-query.test.ts src/lib/api-client-economy-query.test.ts src/lib/api-client-feedback-query.test.ts src/lib/api-client-support-query.test.ts src/lib/api-client-templates-query.test.ts src/lib/dependency-inventory.test.ts`
  passed 7/7 files and 69/69 tests.
- Fresh `2026-07-04` boundary rerun passed 6/6 admin API-client and boundary test
  files with 65/65 tests. The accompanying direct source scan found 0 matches
  for `DbContext`, `EntityFramework`, `Microsoft.EntityFrameworkCore`,
  `DATABASE_URL`, connection-string literals, backend module imports, SQL/ORM
  client imports, or repository access patterns in non-test admin source. A
  package scan over `apps/admin-web/package.json` found 0 dependencies or
  devDependencies matching DB client packages such as `pg`, `postgres`, `mysql`,
  `mssql`, `sqlite`, `prisma`, `typeorm`, `sequelize`, `knex`, `drizzle-orm`,
  `mongodb`, `mongoose`, Redis clients, or Supabase clients.
- Mobile presentation/data boundary:
  scanned `apps/petmagic-mobile/lib/features` for direct `dioProvider`,
  `Dio()`, and `_dio.*` use from `presentation` paths. No direct HTTP call from
  presentation files was found in the latest `2026-07-04` rerun. Existing
  presentation `dio` imports are used for error types such as `DioException`,
  while HTTP calls remain in data repositories/data sources. This boundary is now
  pinned by `flutter test test\mobile_architecture_boundary_test.dart --reporter
  compact`, which passed 1/1 tests.
- Fresh `2026-07-04` mobile boundary refresh scanned 213 presentation Dart files.
  It found 0 `dioProvider` reads, 0 direct `Dio()` constructions, 0 `_dio.*`
  calls, 0 typed Dio HTTP verb calls, and 0 `package:http` calls. `Dio` imports
  remain present only for error-type handling in presentation controllers/pages.
  The current rerun of `flutter test test\mobile_architecture_boundary_test.dart
  --reporter compact` passed with `All tests passed!`.
- Backend anonymous/admin route surface:
  scanned backend route mappings for `AllowAnonymous` and admin route markers.
  Anonymous routes are limited to public template feed/catalog/events, legal,
  auth/bootstrap flows, store/public economy surfaces, webhooks, and health-like
  endpoints. The latest route-source scan found 44 explicit `AllowAnonymous`
  calls, 128 `RequireAuthorization` calls, 75 admin-surface markers, and 21
  endpoint/security test files. Admin and route-hardening coverage passed:
  94/94 targeted tests in the latest `2026-07-04` rerun.

This snapshot supports the Admin -> API -> Application -> Infrastructure ->
Database boundary and the mobile presentation/data separation, but it does not
replace full manual authorization review before production rollout.

## Scripts And Tooling Snapshot

Scripts, workflow files, and package command surfaces were scanned for obsolete
Compose calls, destructive local-data commands, direct secret logging, and unsafe
force flags:

- Current script/tooling file inventory found 47 files: 5 `.github/workflows`
  YAML files, 22 `scripts/**/*.js`/`scripts/**/*.mjs` files, 7 PowerShell
  scripts, 7 shell scripts, 4 Python scripts, and 2 CMD wrappers
  (`scripts/docker/run-dotnet-app.cmd` and `scripts/qa/psql.cmd`).
- The latest package-script inventory found only `apps/admin-web/package.json`
  outside generated/build/cache directories; there is no root `package.json`.
- Admin package scripts are conventional Next/Vitest/ESLint/Prettier commands:
  `dev`, `dev:turbo`, `build`, `start`, `lint`, `lint:fix`, `typecheck`,
  `format`, `format:check`, `test`, `test:watch`, and coverage helpers. No DB
  or destructive scripts are exposed through `package.json`.
- The latest package-script rerun confirmed the same command set plus
  `test:coverage`, with 0 direct DB client dependency matches and no destructive
  DB/reset script patterns.
- `docker-compose` occurrences are limited to:
  - `scripts/backup-postgres.ps1`, where `docker compose` is preferred and
    legacy `docker-compose` is only a compatibility fallback when the Docker CLI
    plugin is unavailable.
  - `docker-compose-psql`, a sentinel command name used by local-only smoke
    scripts. `run-staging-generation-scheduler-smoke.mjs` explicitly rejects it
    outside local smoke mode.
- The README mention of `docker compose down -v` is a warning not to use it
  unless intentionally deleting local data volumes.
- The latest destructive-pattern rerun matched no unreviewed repo-wide reset,
  volume-drop, shell-pipe installer, or arbitrary eval path. The root
  `package.json` argument in that scan produced an expected warning because the
  manifest is absent, not because a script failed.
- The only `rm -rf` match is a quoted `mktemp` cleanup trap in
  `scripts/qa/prepare-watermark-manual-qa-media.sh`; it deletes only the script's
  generated temporary directory.
- `Remove-Item` matches are limited to generated temporary icon cleanup and QA
  job/output cleanup paths, not repository-wide deletion.
- `-Force` matches are limited to directory creation, QA job cleanup, and
  artifact copy/write operations that do not erase arbitrary repo paths.
- SQL `DELETE FROM` matches are limited to
  `scripts/qa/seed-watermark-manual-qa.sql`, which is explicitly labeled as a
  local-only manual QA seed helper and deletes only deterministic QA rows.
- `scripts/qa/run-economy-staging-infra-gate.mjs` now rejects
  `STAGING_DATABASE_URL` and `STAGING_API_BASE_URL` targets that resolve to
  localhost/local infrastructure before EF, SQL, or runtime checks begin. The
  guard handles both URL-style PostgreSQL strings and Npgsql
  `Host=...;Database=...` connection strings without printing the raw secret.
- The same economy staging gate now rejects repo-local Docker compose psql
  wrappers through `STAGING_PSQL_COMMAND`; those wrappers intentionally ignore
  the passed database URL and target the local compose database.
- A runtime typo in the economy staging gate was fixed: EF/SQL paths now call
  the defined `requireEnv` helper instead of the nonexistent `requiredEnv`.
- `scripts/qa/validate-template-feed-tz1-8-evidence.mjs` now rejects accepted
  template-feed staging snapshot artifacts whose `prometheusBaseUrl` resolves
  to localhost/local infrastructure.
- The same evidence validator rejects accepted feed-load probe artifacts whose
  `apiBase` resolves to localhost/local infrastructure, so local probe
  self-tests cannot be reused as release evidence.
- `scripts/qa/promote-template-feed-long-scroll-artifact.mjs` now rejects
  release PASS signoff with placeholder or ordinary device labels. Low-memory
  emulator signoff must identify a low-memory or constrained-memory target.
- `scripts/qa/validate-template-feed-tz1-8-evidence.mjs` now requires the
  curated long-scroll artifact's Device line to support the weak-device or
  low-memory PASS signoff, so ordinary-device artifacts cannot satisfy Task 2.
  The parser accepts both promoter-style `Device:` metadata and list-style
  `- Device:` metadata so generated long-scroll artifacts remain valid.
- `TemplateMediaReadUrlSigner` now rejects encoded path separators inside
  managed media path segments. This prevents signed local media read URLs from
  being minted or authorized for paths such as `%2f..%2fprivate.png` or
  `%5c..%5cprivate.png`.
- No script/workflow scan match showed direct secret/password echoing to logs.
- All GitHub Actions workflows now declare top-level `permissions:
  contents: read`, with narrower job-level `pull-requests: read` retained only
  where review/secret scanning needs it.
- Workflow secret usage is pinned to the single current `secrets.GITHUB_TOKEN`
  reference needed by `gitleaks/gitleaks-action`.
- Local `gitleaks` CLI is not installed in this workspace, so a local Gitleaks
  run was not claimed. The CI workflow keeps `gitleaks/gitleaks-action@v2` as
  the full secret-scan gate.
- Workflow `uses:` references are pinned to stable major-version tags such as
  `@v4`; floating refs like `@main`, `@master`, or `@latest` are rejected by the
  safety inventory.
- Workflow safety inventory also rejects `pull_request_target`, `write-all`, and
  explicit `*: write` permission scopes unless the guard is intentionally
  reviewed and changed.
- `scripts/qa/test-script-safety-inventory.mjs` now pins the current script
  inventory, current `.github/workflows/*.yml` inventory, current workflow
  `uses:` action references and stable-tag policy, workflow `secrets.*`
  references, top-level workflow `contents: read` permissions, dangerous
  workflow trigger/write-scope bans, and executable safety allowlist for
  recursive deletes, PowerShell deletes, SQL deletes, `docker compose down -v`,
  `dropdb`, `DROP DATABASE`,
  `Invoke-Expression`, `Set-ExecutionPolicy`, `chmod 777`, and shell-piped
  curl/wget installers.
  It also asserts that the economy staging infra gate keeps the local-target
  rejection policy, rejects repo-local Docker compose psql wrappers, and does
  not regress to the undefined `requiredEnv` helper name. It also pins the
  template-feed evidence validator's local Prometheus/API target rejection and
  the mobile long-scroll release-signoff device-label guard, including metadata
  parsing compatibility for promoter-generated `Device:` lines.
- `.github/workflows/repo-hygiene-ci.yml` now runs the lightweight repo-hygiene
  checks on `README.md`, `docs/**`, `scripts/**`, and any `.github/workflows/**`
  changes. It covers every current `scripts/**/*.js` and `scripts/**/*.mjs`
  syntax, every current `scripts/**/*.sh` syntax, every current
  `scripts/**/*.py` syntax through `py_compile`, all current PowerShell script
  syntax, script/workflow safety inventory, markdown checker self-test, and full
  markdown local-link checking.

Verification:

- `2026-07-04` scripts/tooling rerun passed:
  `node scripts\qa\test-script-safety-inventory.mjs`,
  `node --check` for every current `scripts/**/*.js` and `scripts/**/*.mjs`,
  `node scripts\qa\test-markdown-local-links.mjs`, and PowerShell parser checks
  for every current `scripts/**/*.ps1`.
- The latest full scripts/tooling refresh passed `node --check` for 22
  JavaScript/MJS files, PowerShell parser checks for 7 PS1 files, `bash -n` for
  7 shell scripts, and `python -m py_compile` for 4 Python scripts.
- The current refresh also inventoried 2 CMD wrappers and reran 8 lightweight
  QA/tooling self-tests: markdown local-link checker, watermark QA help,
  template-feed load probe, staging snapshot, release gate, admin QA report
  draft, long-scroll promoter, and TZ1-8 evidence validator. Result: 8/8
  passed, 0 failed.
- `node scripts\qa\test-script-safety-inventory.mjs` passed with scripts and
  workflows included in the safety scan.
- Targeted `node --check` commands passed for
  `run-economy-staging-infra-gate.mjs` and `test-script-safety-inventory.mjs`.
- Targeted `node --check` and `--help` commands passed for
  `run-staging-generation-scheduler-smoke.mjs` and
  `run-economy-staging-infra-gate.mjs`.
- `STAGING_ENV_FILE=.env.staging.local.example`
  `run-staging-generation-scheduler-smoke.mjs` exited 1 before runtime calls and
  printed only required input names, proving the runner fails closed when real
  staging API/DB/template/JWT/Prometheus/process-label inputs are absent.
- `STAGING_ENV_FILE=.env.staging.local.example`
  `run-economy-staging-infra-gate.mjs` exited 1 with
  `Missing required env: STAGING_DATABASE_URL` and wrote sanitized evidence to
  `%TEMP%\petmagic-economy-gate-codex\summary.json`.
- Economy staging infra gate negative smokes passed for URL-style localhost DB,
  Npgsql-style localhost DB, localhost API target rejection, and repo-local
  psql wrapper rejection; the smoke output did not include the test database
  password.
- `powershell -ExecutionPolicy Bypass -File
  scripts\qa\run-template-feed-tz1-8-release-gate.ps1 -EnvFile
  .env.staging.local.example -ValidateStagingInputsOnly` exited 1 with
  `Missing required environment variable(s): STAGING_PROMETHEUS_BASE_URL`.
- Template-feed release gate, staging snapshot, evidence validator, feed-load
  probe, and long-scroll promoter self-tests all passed in the latest
  provider-readiness rerun.
- Template-feed TZ1-8 evidence validator self-test passed with added negative
  coverage for local Prometheus snapshot artifacts and local feed-load probe
  artifacts, plus ordinary-device long-scroll evidence and promoter-style
  `Device:` metadata.
- Template-feed long-scroll promoter self-test passed with added negative
  coverage for release PASS signoff using an ordinary device label.
- Build-backed `TemplateMediaReadUrlSignerTests` passed 10/10, including encoded
  slash/backslash traversal rejection for signed URL creation and authorization.
- Adjacent local/R2 media storage tests passed 36/36 after the read-URL signer
  hardening.
- Build-backed share/media decoding regression suite passed 25/25 from isolated
  output path `backend\artifacts\identity-tests-share-decode-2`, including
  malformed percent escape and encoded separator/null share-token inputs.
- Build-backed public share API/service malformed-token suite passed 13/13 from
  isolated output path `backend\artifacts\identity-tests-share-api-decode`,
  proving both `/api/templates/generations/share/{token}` and
  `/share/generation/{token}` return NotFound for double-encoded malformed
  percent/separator/null inputs.
- Admin logging policy passed 3/3 tests and now asserts that source files route
  `console.warn/error` through `clientLogger` rather than direct component/lib
  console calls.
- Admin production API URL config suite passed 31/31 tests. The resolver and
  Next image/CSP config now reject local/private/wildcard/Docker/compose
  production API origins by default and allow compose local-smoke targets only
  with the explicit local-production opt-in flag.
- Admin secure-media URL exposure suite passed 19/19 tests. Template, support,
  and user media helpers now share the same unsafe-host policy and reject
  localhost, `.localhost`, Docker host, compose-service, wildcard, private IPv4,
  private IPv6, and placeholder media origins before direct rendering or browser
  fetch. Targeted ESLint also passed for the new shared policy, the three
  helpers, and the updated media exposure tests.
- Full admin-web gate was rerun after the secure-media host-policy hardening and
  again after the latest admin source-contract refresh:
  `npm test` passed 85/85 test files and 656/656 tests, `npm run lint` passed,
  `npm run typecheck` passed, and `npm run build` completed a production Next.js
  16.2.10 build with all admin routes generated.
- Mobile logging policy, AppLogger sanitizer, and global error handling suite
  passed 35/35 tests in the latest targeted rerun,
  confirming app/tool Dart sources do not use noisy `print`/`debugPrint` logging
  and cannot use direct `dart:developer` logging outside the allowlisted
  `AppLogger` and `RequestIdentity` wrappers.
- Mobile external URL, API config, and production networking guards passed 22/22
  tests in the latest targeted rerun. API base-url lifecycle and Android
  loopback hint coverage also passed 8/8 tests. The external URL policy now
  explicitly proves every local debug HTTP
  host used by the app (`localhost`, `127.0.0.1`, Android emulator aliases,
  Docker host alias, wildcard IPv4, CGNAT, link-local metadata, RFC1918,
  multicast/reserved, and private IPv4 hosts) is rejected when local HTTP is
  disabled for release-style flows. `flutter analyze` passed after the shared
  IPv4 classifier update.
- Full Flutter test suite was rerun after the mobile network classifier and
  architecture-boundary hardening and passed 1216/1216 tests.
- Backend source logging policy passed 1/1 from isolated output path
  `backend\artifacts\identity-tests-logging-policy-2`, confirming backend `src`
  has no direct `Console.WriteLine`, interpolated logger templates, or sensitive
  URL/body placeholders.
- All QA script self-tests listed in the command evidence snapshot passed.
- PowerShell parser check passed for every `scripts/**/*.ps1`.
- `bash -n` passed for every `scripts/**/*.sh`.
- `python -m py_compile` passed for every `scripts/**/*.py`.
- Local equivalents of the new repo-hygiene workflow checks passed with the
  available Windows toolchain.

One first `bash -n` attempt used Windows backslash paths through PowerShell and
failed before reaching the scripts. It was rerun with forward-slash paths and
passed. A later attempt to run the GitHub Actions `find ... node --check` loop
inside local WSL/bash reached the loop but failed because `node` is not installed
in that WSL PATH. The same file set was checked successfully with the Windows
Node toolchain at `C:\Program Files\nodejs\node.exe`; GitHub Actions supplies
Node through `actions/setup-node`.

A first build-backed share/media decoding test run without custom `OutputPath`
failed before executing the full current source because an old `testhost (2780)`
process held DLLs under `tests\PetMagic.Modules.Identity.Tests\bin`. The same
filtered run was repeated with an isolated artifact output path and passed 25/25.

A first backend logging-policy rerun with custom `OutputPath` exposed another
source-test resolver that assumed a fixed build output depth and resolved the
repo as `D:\Flutter`. The resolver now walks to the repository root marker, and
the same logging-policy filter passed from a fresh isolated output path.

Specialized GitHub Actions workflow linting was not available locally:
`actionlint`, Ruby, `ConvertFrom-Yaml`, and PyYAML were not installed in this
workspace. The workflow files were reviewed directly. The newly introduced
Admin dependency audit and mobile release-packaging smoke commands were run
locally, and the repo-hygiene workflow checks were run locally through equivalent
Windows commands where the WSL toolchain lacked Node.

## Documentation Snapshot

Markdown docs were scanned for stale status files, broken local links, obsolete
Compose guidance, TODO/FAIL release markers, and old reports that could be
mistaken for current release status:

- Current markdown inventory scan found 40 project-owned `.md` files after
  excluding generated/build/vendor output. Full local-link check passed:
  `Markdown local links ok (46 files checked)`.
- `docs/md/STATUS.md` remains deleted as an obsolete status snapshot.
- No active markdown file still contains the stale
  `docker compose --env-file /dev/null config` guidance; the only current match
  is this audit report documenting that the stale guidance was removed.
- `docker-compose` markdown matches are limited to the `docker-compose.yml`
  filename, historical wording, or the local-smoke `docker-compose-psql`
  sentinel documented in scripts.
- `localhost:5000`/`localhost:5001` matches are local development or historical
  evidence references, not production configuration instructions.
- Draft/manual QA TODO or PASS/FAIL rows remain only in this audit report and
  `docs/templates-feed-tz1-8-staging-qa.md`, where validators explicitly reject
  TODO/FAIL before release evidence is accepted.
- Historical reports are now explicitly labeled so they do not override the
  current production-readiness gate:
  - `docs/template-feed-stability-qa-2026-06-14.md`.
  - `docs/md/mobile_release_size_report_2026-05-30.md`.
  - `apps/petmagic-mobile/ux-audit-2026-06-13/report.md`.
  - `docs/mobile-backend-notifications-optimization-report-2026-06-13.md`.
  - `docs/mobile-gallery-current-behavior-2026-06-14.md`.
  - `docs/security-audit-2026-06-17.md`.
- Fresh release-claim scan found no active markdown document claiming final
  production readiness. Current positive local evidence remains paired with
  explicit provider-backed/signing/staging blockers where release readiness is
  discussed.

Current release status is centralized in this report and the focused 2026-07-03
release/audit docs.

## Large File And Composition Snapshot

Current source-size scan covered `apps/admin-web/src`, `apps/petmagic-mobile/lib`,
and `src` for `.ts`, `.tsx`, `.css`, `.dart`, and `.cs` files, excluding tests,
generated files, build output, migrations, and localization output. No `.razor`
files were found in the repository, so the Razor page-size rule is currently not
applicable.

Production-source size summary:

| Area | Files scanned | Files over 300 lines | Files over 600 lines |
| --- | ---: | ---: | ---: |
| Admin web | 279 | 86 | 29 |
| Backend src | 516 | 61 | 19 |
| Mobile lib | 331 | 123 | 30 |
| Total | 1126 | 270 | 78 |

Current over-1000-line count: 5 production source/style files. Code-only
inventory excluding CSS counted 1090 production files: 4 over 1000 lines,
18 between 751 and 1000 lines, and 95 between 501 and 750 lines.

Largest production files found:

- `apps/petmagic-mobile/lib/features/templates/presentation/templates_controller.dart`
  at 1350 lines.
- `src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/EconomyService.Reconciliation.cs`
  at 1168 lines.
- `apps/petmagic-mobile/lib/features/templates/data/template_generation_repository_cache.part.dart`
  at 1083 lines.
- `apps/admin-web/src/components/support/support-conversation-chat-content.module.css`
  at 1081 lines.
- `apps/petmagic-mobile/lib/features/profile/presentation/profile_controller.dart`
  at 1030 lines.
- `apps/petmagic-mobile/lib/features/templates/data/generation_gallery_store_storage.part.dart`
  at 990 lines.
- `src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/EconomyService.IncidentTooling.cs`
  at 979 lines.
- `apps/petmagic-mobile/lib/features/wallet/presentation/wallet_controller_checkout.part.dart`
  at 960 lines.
- `apps/admin-web/src/components/templates/templates-catalog.module.css`
  at 957 lines.
- `apps/admin-web/src/components/promo-codes-view.module.css` at 940 lines.
- `apps/admin-web/src/components/templates/template-editor.module.css` at 932
  lines.
- `apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page_states_and_actions.part.dart`
  at 923 lines.
- `apps/admin-web/src/components/admin/admin-shell.module.css` at 921 lines.
- `apps/admin-web/src/components/promo-codes-view.tsx` at 920 lines.
- `apps/petmagic-mobile/lib/features/templates/data/template_generation_repository.dart`
  at 912 lines.

Classification:

- This is real maintainability debt, especially in mobile template/gallery
  controllers, backend economy/template infrastructure, and admin CSS/page
  modules.
- The current over-500-line code-only distribution is 56 mobile files, 31 admin
  files, 15 backend Templates files, 11 backend Economy files, and one each in
  backend Gamification, host/building-blocks, Identity, and SupportChat.
- Some large files are already split along local conventions, such as mobile
  `.part.dart` sections, backend partial services, and admin section/helper/test
  files. That reduces blast radius but does not remove the need for a dedicated
  file-size refactor pass.
- Highest-value follow-up lanes are:
  mobile templates/profile/support controllers and pages; backend economy
  reconciliation, incident tooling, wallet/purchase verification, and template
  generation processor files; admin promo/economy/users/support/template pages,
  API clients, and the largest CSS modules.
- It is not treated as a release blocker in this pass because the relevant
  backend, mobile, admin, runtime, route-contract, and boundary checks passed.
- Broad file-splitting in this already mixed release-hardening worktree would
  create unnecessary review and regression risk. The correct follow-up is a
  separate refactor pass per subsystem, preserving existing contracts and test
  coverage.

## Intentional Legacy Or Compatibility Holds

- `apps/petmagic-mobile/android/gradle.properties`
  keeps `android.newDsl=false` and `android.builtInKotlin=false`.
  - This was revalidated on 2026-07-03.
  - Removing the opt-outs makes `dev.flutter.flutter-gradle-plugin` fail with a
    `NullPointerException` before app module configuration.
  - The release packaging gate passes with the opt-outs restored.
  - This must be revisited when Flutter and Android plugin dependencies build
    cleanly with AGP built-in Kotlin/new DSL.
- The prior mobile release-size audit R8 failure is no longer a current blocker:
  direct Gradle packaging with the explicit local insecure signing override now
  completes. Any future `missing_rules.txt` output should be treated as a new
  regression, not as the preserved status from the old audit note.
- Local Development DataProtection key warnings are classified as local profile
  state, not a repo production blocker.
  - The runtime stores keys under `%USERPROFILE%\.aspnet\DataProtection-Keys`.
  - Existing old XML keys plus a regenerated dev PFX explain local decrypt
    warnings without changing production readiness.
- `ADMIN_WEB_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION=true` is retained only
  for Docker/local-smoke production-build validation against localhost.
  Staging and production examples keep it absent or `false`, and Docker compose
  defaults it to `false`.

## Remaining Release Blockers

- Configure real Android release signing:
  `apps/petmagic-mobile/android/key.properties` and the production keystore must
  be provided outside git. The current local signing-guard check fails closed
  instead of producing a debug-signed release AAB.
- Execute provider/device-backed staging smoke:
  - FAL generation with real webhook callback evidence.
  - R2 upload/read/public or signed media URL evidence.
  - Stripe sandbox payment/webhook/idempotency evidence.
  - Google Play and App Store sandbox purchase/subscription evidence. Local
    service tests now prove credited-once Google Play token-pack idempotency, but
    real store credentials/callbacks are still not verified.
  - Real FCM/APNs push delivery evidence for generation, wallet/purchase, and
    support-chat notifications on device-capable environments.
- Split the mixed worktree into reviewable subsystem commits before release PR;
  the current `2026-07-04` inventory shows 863 dirty entries across review
  lanes, so the split must happen before release packaging.
- Track Android Gradle/AGP deprecation migration separately from the release
  hardening patch set.

## Not Ready To Claim

The following claims are not proven yet:

- Final production readiness.
- Store release readiness with real signing.
- Payment and subscription production readiness with provider-backed callbacks.
- Push notification production readiness with FCM/APNs credentials and real
  device delivery evidence.
- FAL/R2 production path readiness with real staging credentials.
- Clean PR scope, because the current worktree contains a broad mixed audit set.

## Next Validation Steps

1. Provide real staging/provider credentials through the intended secret source.
2. Run the staging generation scheduler smoke with FAL/R2/Prometheus evidence.
3. Run Stripe, Google Play, and App Store sandbox purchase flows and verify
   credited-once/idempotency behavior.
4. Run FCM/APNs device push delivery checks for generation, wallet/purchase, and
   support-chat notification flows.
5. Build a signed Android AAB with production signing material.
6. Re-run backend, mobile, admin, Docker, markdown, and diff gates after commit
   splitting.
