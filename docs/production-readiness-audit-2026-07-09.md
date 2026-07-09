# PetMagic production-readiness audit — mobile + backend

**Audit date:** 2026-07-09/10, Europe/Minsk  
**Verdict:** `NO-GO`  
**Audit branch:** `audit/production-readiness-2026-07-09`  
**Immutable audit snapshot:** `6dad689af8cb9faf0ed6bcb44667db4ab132231f`  
**Snapshot base:** `c0d3b7747ec239130bf7ff3c809da3fc8ce4a25c`  

## Executive summary

Release from the audited snapshot is blocked. The snapshot does not compile in either the ASP.NET backend or the Flutter application, the Android flavor configuration prevents APK assembly, and the new Templates cancellation persistence model has no forward EF Core migration. These failures also block clean/existing database verification, an isolated Docker runtime, Android installation, Render staging, provider verification, and the iOS pass.

The audit found one `P0`, nine `P1`, and five `P2` findings. `GO` is not permissible until every `P0/P1` is closed and all release-critical external gates are executed against one replacement SHA.

No product behavior, public API, DTO, database schema, or configuration was changed by this audit. The only tracked audit artifact is this document.

## Snapshot integrity and isolation

The original dirty worktree remained on `master` at `c0d3b7747ec239130bf7ff3c809da3fc8ce4a25c`; its index was not modified. The audit worktree was created separately and contains a snapshot commit with all source, configuration, tests, and documentation that were present at audit start, excluding ignored secrets, caches, builds, and generated artifacts.

The tracked diff copied into the audit worktree matched the source worktree patch by SHA-256:

```text
F023101D63ABA0450AAB2FE72C392FBC56A8E3127AE8DCD63E4C7D670EE3E1E6
```

The snapshot commit was pushed to `origin/audit/production-readiness-2026-07-09`. All checks in this report refer to that snapshot only. Containers later rebuilt from the evolving source worktree were explicitly excluded as evidence.

## Release blockers

| ID | Severity | Area | Finding | Release impact |
|---|---|---|---|---|
| PR-001 | P0 | Templates/DB | Cancellation model changes have no forward EF Core migration; historical migrations were edited in place | Clean and existing databases cannot be proven compatible; runtime schema mismatch is expected |
| PR-002 | P1 | Backend/API | `TemplateGenerationService` does not implement the newly added `CancelAdminAsync` interface member | Entire solution and API/worker images fail to build |
| PR-003 | P1 | Flutter | Mobile source and tests do not compile under `flutter analyze` | No releasable mobile artifact or reliable test result |
| PR-004 | P1 | Android/CI | Product flavors use disabled `resValue` support; release commands are not flavor-aware | APK/AAB assembly fails before application compilation |
| PR-005 | P1 | Repository security | Firebase configuration ignore rules contain leading spaces and do not match real credential files | Firebase/OAuth configuration can be committed accidentally |
| PR-006 | P1 | iOS | `Info.plist` references undefined build settings for app name and Google OAuth | Signed iOS build and Google Sign-In configuration are not reproducible |
| PR-007 | P1 | Admin/CI | Support regression tests fail and CI invokes a missing `test:e2e` script | Admin regression gate and CI are red |
| PR-008 | P1 | Outbox/email | A crash after claiming the final retry can leave rows permanently in `Processing` | Push/email delivery can become stuck without dead-lettering or recovery |
| PR-009 | P1 | Support/audit | Ownership behavior breaks the prior unassigned-ticket contract; audit logging is not atomic with assignment | Existing admin flows can regress and security audit trail can be lost |
| PR-010 | P1 | Mobile CI | Mobile workflow listens to `main`, while the repository release branch is `master` | Mobile gates are skipped on normal `master` pushes |
| PR-011 | P2 | Localization | Required translations fall back to English in multiple supported locales | Visible release-quality regression |
| PR-012 | P2 | Google auth | Shared Google Sign-In adapter retains the first `serverClientId` for the process lifetime | Environment/account reconfiguration can require app restart |
| PR-013 | P2 | FCM | Aggregate multi-token retry resends to devices that already accepted the message | Duplicate background/OS notifications are possible |
| PR-014 | P2 | Economy/notifications | Premium push can be persisted before cross-module entitlement synchronization completes | User may be notified before profile/Identity state converges |
| PR-015 | P2 | Observability | Crashlytics dependency is present but no runtime initialization/use is wired | Expected mobile crash evidence is unavailable |

## Detailed findings

### PR-001 — Templates cancellation schema is not migratable

**Severity:** `P0`  
**Status:** `FAIL`

`TemplateGenerationJob` and `TemplatesDbContext` introduce provider cancellation URLs, cancellation actor/timestamps, previous state, attempt/retry fields, accepted timestamp, last error, a pending-cancellation index, and updated partial unique-index predicates for `TemplateGenerationStatus.CancellationRequested = 11`.

No migration contains the new model fields or index changes. The only new Templates migration, `AddTemplatesPushOutbox`, creates the push outbox and does not reconcile the cancellation model. In addition, already-published historical migrations were edited to remove idempotent SQL. Editing applied migrations does not repair existing databases and makes clean-history behavior diverge from deployed history.

**Impact:** a worker/API compiled after PR-002 is fixed would address columns and indexes that are absent on clean and upgraded databases. Existing deployments cannot receive the intended index predicate changes through EF migration history.

**Required fix:** restore historical migrations to their committed form; add one forward migration that adds every cancellation/cancel-URL column, creates `IX_tgj_PendingCancellation`, and recreates affected partial unique indexes with status `11`. Do not modify applied migration files.

**Required regression:** `has-pending-model-changes` for Identity, Economy, Gamification, SupportChat, and Templates; full apply on an empty PostgreSQL database; upgrade from a database migrated at `c0d3b7747ec239130bf7ff3c809da3fc8ce4a25c`; invalid/missing-index checks; API and worker boot against both resulting schemas.

### PR-002 — Incomplete admin cancellation API/service contract

**Severity:** `P1`  
**Status:** `FAIL`

`ITemplateGenerationService` declares both `CancelAdminQueuedAsync(...)` and a new `CancelAdminAsync(...)`. `TemplateGenerationService` implements only the queued method, while the admin endpoint still invokes that method. At the same time, response mapping exposes `canCancel` for provider-queued/processing jobs when a provider cancel URL exists, and the domain includes the new cancellation-requested state.

Release build fails with:

```text
CS0535: 'TemplateGenerationService' does not implement interface member
'ITemplateGenerationService.CancelAdminAsync(Guid, Guid, CancellationToken)'
```

**Impact:** API, generation worker, Docker images, backend tests, migration tooling, and staging deployment are blocked. The endpoint, interface, DTO behavior, docs, and state model describe three different cancellation capabilities.

**Required fix:** complete one cancellation state machine and preserve the existing HTTP route and response compatibility. The endpoint should call the new service operation; queued jobs may cancel/refund synchronously, while submitted provider jobs transition atomically to `CancellationRequested` and are processed with bounded retries. A provider `already completed` result must restore/continue the prior state; refunds must be exactly once and auditable.

**Required regression:** endpoint authorization and ProblemDetails tests; queued/provider-queued/processing/completed races; duplicate admin requests; provider timeout/retry/permanent rejection; callback-before-cancel and cancel-before-callback ordering; exactly-once wallet refund and audit event.

### PR-003 — Flutter source and tests do not compile

**Severity:** `P1`  
**Status:** `FAIL`

`flutter analyze --fatal-infos` reports:

- undefined `BillingResponse` in `wallet_repository.dart` because the public billing wrapper library is not imported;
- `Uint8List` is not a type in `external_auth_repository_test.dart` because `dart:typed_data` is missing;
- an unnecessary `flutter/services.dart` import in `main.dart` is fatal under the configured gate.

The full test command repeatedly failed to load test files through the same `BillingResponse` compiler error. It was stopped after the failure was deterministic; its partial count is not treated as a full-suite result.

**Required fix:** import `package:in_app_purchase_android/billing_client_wrappers.dart` explicitly, import `dart:typed_data` in the test, and remove the unused import. Keep the current purchase consume/acknowledgement semantics unchanged.

**Required regression:** fatal analyze, complete Flutter test suite, focused wallet/store verification tests, debug and release flavor builds.

### PR-004 — Android flavor/build pipeline is incomplete

**Severity:** `P1`  
**Status:** `FAIL`

The Gradle configuration adds `staging` and `production` flavors with custom `resValue` entries but does not enable `buildFeatures.resValues`. Gradle fails with:

```text
Product Flavor staging contains custom resource values, but the feature is disabled.
```

README, VS Code launch/tasks, and mobile CI still use generic non-flavor commands. CI invokes `assembleRelease`/`bundleRelease`, and it does not generate or securely inject the flavor-specific Firebase files.

**Required fix:** enable resource values, define explicit staging/production application IDs and signing/config inputs, and make every documented/CI build command flavor-specific. Firebase placeholders may be generated only for packaging smoke with an explicit allow flag; provider QA must use secret-store material.

**Required regression:** `assembleStagingDebug`, `assembleStagingRelease`, `bundleProductionRelease`, install/launch of staging on API 35, package/application ID verification, and proof that production signing/secrets are not used by staging.

### PR-005 — Firebase credential files are not ignored

**Severity:** `P1`  
**Status:** `FAIL`

Three `.gitignore` rules for profile/root Android `google-services.json` and iOS `GoogleService-Info.plist` begin with spaces. `git check-ignore` does not match the real file paths. The repository hygiene script passes because it checks the current tree, not whether future credential paths are protected.

**Impact:** real Firebase/OAuth project identifiers and configuration can be staged accidentally.

**Required fix:** remove leading spaces, cover every generated flavor path, retain tracked `.example` files only, and add a hygiene assertion using `git check-ignore` against canonical real paths.

**Required regression:** create non-secret sentinel files at every protected path, prove they are ignored, run sensitive-file scanning against tracked and untracked files, then remove the sentinels.

### PR-006 — iOS configuration is not reproducible

**Severity:** `P1`  
**Status:** `FAIL`

`Runner/Info.plist` references `APP_DISPLAY_NAME`, `GOOGLE_REVERSED_CLIENT_ID`, and `GOOGLE_CLIENT_ID`, but those settings are absent from the Xcode project and xcconfig files. The audit snapshot contains no real `GoogleService-Info.plist`, signing material, staging scheme, or production-like secret injection path.

**Required fix:** define staging/production xcconfig values and schemes, inject Firebase/OAuth files from the CI/provider secret store, and keep bundle IDs, reversed client ID, URL scheme, and backend client ID aligned.

**Required regression:** archive the replacement SHA on macOS with production-like signing, install on a registered iPhone, verify Apple/Google auth, APNs foreground/background/cold start, and App Store sandbox purchase/restore/renew/cancel/refund.

### PR-007 — Admin regression and E2E gates are red

**Severity:** `P1`  
**Status:** `FAIL`

Admin formatting, typecheck, and production build pass. Unit tests report 85/87 files and 658/662 tests passing. Four Support workspace source-contract assertions fail: role guard, close confirmation state, reply submit guard, and sensitive tag-input guard.

The admin workflow installs Playwright and calls `npm run test:e2e`, but `apps/admin-web/package.json` has no such script. The command fails immediately.

**Required fix:** reconcile the four guards with the intended authorization/UX contract, then add a real Playwright configuration and `test:e2e` script or remove the invalid workflow step only if an equivalent E2E release gate is deliberately replaced.

**Required regression:** all unit tests plus E2E smoke for auth redirect, security headers/CSP, role-restricted Support actions, assignment/close/reply flows, and sensitive-field rendering.

### PR-008 — Final-attempt outbox rows can become permanently stuck

**Severity:** `P1`  
**Status:** `FAIL`

Economy, Templates, and SupportChat push processors claim only rows with `AttemptCount < MaxAttempts`, increment the attempt while setting `Processing`, and apply the delivery result later. Email dispatch follows the same pattern. If a worker crashes after claiming the final attempt but before result persistence, the lease eventually expires with `AttemptCount == MaxAttempts`; the claim query excludes the row forever, so it is neither retried nor dead-lettered.

No focused push-outbox tests were found for crash-after-claim, terminalization, or concurrent claim behavior.

**Impact:** generation, wallet/premium, support notification, and account email delivery may silently stop while rows remain non-terminal.

**Required fix:** atomically terminalize expired final-attempt leases to `DeadLetter` (or allow one recovery claim that only performs terminalization), expose stuck/dead-letter counts in readiness/alerts, and ensure lease duration safely exceeds provider timeout. Keep claim/result updates concurrency-safe.

**Required regression:** worker crash after each claim phase, crash on final attempt, multi-worker race, lease expiry, retry-after handling, dead-letter alerting, and manual replay idempotency for all four outbox families.

### PR-009 — Support ownership compatibility and audit atomicity

**Severity:** `P1`  
**Status:** `FAIL`

The new ownership validation rejects mutations unless the ticket is already assigned to the current admin. The prior flow and existing integration coverage allow the first admin reply to an unassigned ticket, effectively claiming it. This is a backward-incompatible behavioral change for admin clients.

In assignment, the database transaction commits before the cross-module audit write. If audit delivery fails, the assignment is committed but the request fails; retry takes the idempotent early-return path and can permanently omit the audit record.

**Required fix:** preserve compatibility by atomically assigning an unowned ticket to the first mutating admin and returning conflict/forbidden only when another owner already exists. Write a Support audit-outbox row in the same transaction and deliver it idempotently to the audit sink.

**Required regression:** first reply/close/tag on unassigned ticket, two-admin claim race, non-owner mutation, audit sink outage and replay, duplicate request, and admin/mobile contract tests.

### PR-010 — Mobile CI does not run on `master`

**Severity:** `P1`  
**Status:** `FAIL`

`.github/workflows/mobile-ci.yml` is triggered for pushes to `main`; the active repository branch is `master`. Admin CI already targets `master`.

**Required fix:** make the mobile workflow branch policy match the release branch and add an explicit pull-request trigger if required by the repository policy.

**Required regression:** verify a no-op PR and `master` push both create the expected required check; protect the branch with that check.

### PR-011 — Localization completeness regressions

**Severity:** `P2`  
**Status:** `FAIL`

The localization gates report English fallbacks for `generationStatusWaitMinutes` in `de/es/fr/it/pl`, `gamificationXpProgress` in `ru/de/es/fr/it/pl`, and `petsStatsPhotos` plus `profileNotificationsDeviceMicrophone` in `fr`.

**Required fix:** add reviewed translations without changing keys or parameter contracts.

**Required regression:** both localization tools, widget smoke in every supported locale, narrow screen and enlarged text-scale checks.

### PR-012 — Google Sign-In adapter locks first client configuration

**Severity:** `P2`  
**Status:** `FAIL`

The shared Google Sign-In adapter initializes once with the first `serverClientId`; session reset no longer resets adapter initialization. Changing backend/mobile configuration within one process can produce a generic configuration error until restart.

**Required fix:** key the adapter instance by effective OAuth configuration or recreate it safely when that configuration changes. Do not expose raw provider errors or identifiers.

**Required regression:** staging-to-production configuration switch in one process, logout/login with another account, canceled login, invalid client ID, and process restart.

### PR-013 — FCM aggregate retry can duplicate notifications

**Severity:** `P2`  
**Status:** `FAIL`

One transient token failure makes the aggregate delivery retry the full message, including tokens that already accepted it. Foreground application deduplication does not prevent duplicate OS-rendered notifications in background/cold-start states.

**Required fix:** persist delivery state per token/device, or create child outbox deliveries so only transient targets retry. Preserve the logical notification ID for routing and observability.

**Required regression:** mixed success/permanent/transient token batch, invalid-token cleanup, background and cold-start duplicate checks, and outbox replay.

### PR-014 — Premium notification can precede entitlement convergence

**Severity:** `P2`  
**Status:** `FAIL`

The Economy transaction can persist premium push intent before cross-module entitlement synchronization completes. A later synchronization failure can therefore notify the user while Identity/profile state is still stale.

**Required fix:** emit notification from a reconciliation-confirmed state transition or include a durable entitlement-sync prerequisite in the outbox workflow.

**Required regression:** Identity outage during purchase/renew/cancel/refund, reconciliation replay, notification ordering, and duplicate provider events.

### PR-015 — Crashlytics is declared but not active

**Severity:** `P2`  
**Status:** `FAIL`

`firebase_crashlytics` is present in dependencies, but no `FirebaseCrashlytics` initialization, Flutter error forwarding, or platform evidence was found.

**Required fix:** wire release-only collection with privacy-safe filtering and environment separation, or remove the dependency and document the actual crash pipeline.

**Required regression:** non-PII test exception in staging, Flutter and platform fatal/non-fatal delivery, opt-out behavior where required, and proof that secrets/tokens are redacted.

## Gate results

### Repository and configuration

| Gate | Result | Evidence |
|---|---|---|
| Snapshot branch/worktree isolation | PASS | Separate worktree and pushed immutable snapshot SHA |
| Source tracked-patch integrity | PASS | SHA-256 matched source worktree patch |
| Repository sensitive-file script | PASS | No current tracked sensitive files detected |
| Script safety inventory | PASS | Safety inventory completed |
| Canonical Firebase paths ignored | FAIL | Three rules do not match because of leading spaces |
| Markdown local links | PASS | 50 files checked |
| Compose config: example/local smoke/staging | PASS | All three `docker compose config --quiet` checks passed |

### ASP.NET/backend/database

| Gate | Result | Evidence |
|---|---|---|
| `dotnet restore PetMagic.slnx` | PASS | Restore completed |
| Release solution build | FAIL | `CS0535` for missing `CancelAdminAsync` implementation |
| Backend unit/integration/contract/security/payment/outbox tests | BLOCKED | Valid test run requires successful solution build |
| NuGet vulnerability audit | PASS | No vulnerable direct/transitive packages reported |
| EF pending model checks (5 contexts) | BLOCKED | Design-time build cannot compile |
| Clean DB migration apply | BLOCKED | Compile failure; static audit also proves Templates drift |
| Previous-HEAD DB upgrade | BLOCKED | Compile failure and missing forward migration |
| Render predeploy gate | FAIL | All preliminary checks pass; backend API build fails |

### Flutter/mobile

| Gate | Result | Evidence |
|---|---|---|
| `flutter pub get` | PASS | Dependencies resolved |
| `flutter gen-l10n` | PASS | Generation completed |
| Generation-status localization gate | FAIL | Five locale fallbacks |
| Full localization completeness | FAIL | Additional RU/FR/DE/ES/IT/PL fallbacks |
| `flutter analyze --fatal-infos` | FAIL | Two compiler errors and one fatal info |
| Full Flutter tests | FAIL | Repeated test-load compiler failure; partial run terminated after deterministic failure |
| Android debug APK | FAIL | Gradle flavor `resValue` feature disabled |
| Android release APK/AAB | BLOCKED | Same pipeline defect plus missing real signing/provider config |

### Admin web

| Gate | Result | Evidence |
|---|---|---|
| `npm ci --engine-strict` | PASS | 406 packages, zero npm vulnerabilities |
| Format check | PASS | No formatting errors |
| ESLint | PASS | Three import-order warnings, no errors |
| Typecheck | PASS | TypeScript check completed |
| Unit tests | FAIL | 4 failed, 658 passed |
| Production build | PASS | Next.js production build completed |
| E2E | FAIL | `test:e2e` script is missing |

### Docker/runtime

| Gate | Result | Evidence |
|---|---|---|
| Isolated audit image build | FAIL | Generation-worker publish reaches backend `CS0535`; other images canceled |
| Isolated audit stack start | BLOCKED | No audit images; audit compose project has no containers |
| Runtime migrations/health/worker/API smoke | BLOCKED | Isolated stack did not start |
| Log review against audit SHA | BLOCKED | No audit runtime exists |

### Android device QA

| Gate | Result | Evidence |
|---|---|---|
| Android toolchain / `flutter doctor -v` | PASS | No toolchain issues |
| Requested Android 15 device visible | PASS | Physical API 35 device connected through ADB |
| Audit SHA install | BLOCKED | APK build failed |
| Critical flows and responsive UI matrix | BLOCKED | No audit build installed |
| Crash/layout logcat for audit build | BLOCKED | Existing installed 1.0.0 build predates the snapshot and is not valid evidence |

No screenshots were recorded because showing an older build would be misleading evidence.

### Dedicated staging and providers

| Gate | Result | Evidence |
|---|---|---|
| Staging environment readiness | FAIL | Untracked `.env.staging.local` not provided |
| Dedicated Render API/worker/admin/QA DB | BLOCKED | Backend image cannot build; no authorized staging provisioned |
| Staging DNS | BLOCKED | Expected custom names do not resolve |
| Render default service endpoints | BLOCKED | Probed endpoints return 404, not deployed audit services |
| FAL/R2 generation and callbacks | BLOCKED | No staging service/provider secrets |
| Stripe test checkout/subscription/refund/webhooks | BLOCKED | No staging service/provider access |
| Google Play internal purchase lifecycle/Pub/Sub | BLOCKED | No installable build/internal track access |
| FCM and SMTP recovery | BLOCKED | No staging service/provider access |
| macOS build/iPhone/Apple auth/App Store sandbox/APNs | BLOCKED | No Mac/Xcode/signing/device/provider access; static iOS config also fails |

No production service, database, DNS, token, payment, or provider configuration was changed.

## Contract and security review summary

- Canonical billing remains under `/api/economy/...`; the retired `/api/payments/stripe/*` surface was not reintroduced.
- The new Templates cancellation surface is internally inconsistent across interface, implementation, endpoint, DTO mapping, docs, and persistence; see PR-001/PR-002.
- Store account binding passes the application user ID and backend verification compares it with Google/Apple provider binding identifiers. Compatibility mode rejects mismatches; real-provider correctness remains `BLOCKED` without staging evidence.
- Google Play consumption after backend verification remains compatible with the intentional `autoConsume: false` flow; removal of a pre-verification acknowledgement check is not classified as a defect.
- Economy, Templates, and SupportChat now persist push intent with domain changes, improving transaction atomicity. Retry terminalization and per-device fan-out remain unsafe; see PR-008/PR-013.
- Forwarded-header boundaries are validated statically, including the Render trust mode. Runtime proxy/header spoofing tests remain `BLOCKED` without staging.
- Media/SSRF, webhook signatures, callback ordering, double-credit/refund, ProblemDetails, pagination, enums, nullability, and authorization have static coverage in source/tests, but dynamic release evidence is not valid while the backend does not compile.
- `PostgreSqlIndexIntegrityValidator` detects invalid indexes; it does not prove that every expected index exists. It cannot compensate for PR-001.

## Decision-complete fix roadmap

Fixes must be implemented on commits after the audit report; do not rewrite the snapshot commit.

### Batch 1 — Restore backend build and database compatibility

1. Complete `CancelAdminAsync` and route the existing admin endpoint through it without changing the public route or breaking the existing response body.
2. Implement the full queued/provider cancellation state machine, bounded retry, callback races, audit trail, and exactly-once refund.
3. Restore modified historical migrations and add one forward Templates migration containing every cancellation column and index change.
4. Add cancellation service/endpoint/provider/race/refund tests.
5. Run Release build, all backend tests, five-context pending-model checks, clean DB apply, previous-HEAD upgrade, API/worker boot, and schema/index assertions.

**Exit criterion:** no build/schema drift and no destructive migration behavior on either database path.

### Batch 2 — Restore mobile release pipeline

1. Fix the explicit Dart imports and fatal analyzer issue.
2. Correct `.gitignore` rules and add ignore/hygiene regression coverage.
3. Enable Android `resValues`, finalize flavor IDs/configuration, and make README, VS Code, Gradle, and CI commands explicitly flavor-aware.
4. Add secure Firebase/signing injection; define iOS schemes/xcconfig build settings and URL schemes.
5. Finish translations and either activate privacy-safe Crashlytics or remove it.
6. Align mobile CI with `master` and make it a required check.

**Exit criterion:** full analyze/tests/l10n pass; staging APK installs on API 35; production APK/AAB and signed iOS archive build from one SHA without tracked secrets.

### Batch 3 — Make delivery retry recoverable

1. Terminalize expired final-attempt leases for Economy/Templates/Support push and Identity email.
2. Add stuck/dead-letter readiness metrics and alerts plus idempotent manual replay.
3. Persist device/token-level FCM delivery so successful targets are not retried.
4. Gate premium notification on confirmed entitlement convergence.

**Exit criterion:** crash-injection and multi-worker tests prove no non-terminal orphan, duplicate logical delivery, or premature premium notification.

### Batch 4 — Restore Support/admin compatibility and audit guarantees

1. Atomically claim an unassigned ticket on the first authorized admin mutation; reject only conflicting ownership.
2. Persist Support audit intent in the same transaction and deliver it idempotently.
3. Fix the four admin Support guard regressions.
4. Add an actual Playwright E2E command/configuration and CI smoke suite.

**Exit criterion:** backend integration, admin unit, and E2E tests cover unassigned/assigned/racing admins, audit outage/replay, role restrictions, CSP, and sensitive display.

### Batch 5 — Re-run full audit on one replacement SHA

1. Re-run all local gates and isolated Compose runtime from the replacement SHA.
2. Install that exact staging build on the Android 15 device and capture redacted screenshots/logs for every critical flow, theme, locale, text scale, keyboard, offline/error, and lifecycle state.
3. Deploy dedicated Render services/QA DB with provider secret stores and budget limits.
4. Execute FAL/R2, Stripe, Google Play, FCM, SMTP, callback/retry/replay, reconciliation, and ledger invariant checks.
5. Build the same SHA on macOS and run registered-iPhone Apple auth, App Store sandbox, and APNs checks.

**GO criterion:** all local, clean/existing DB, Android, iOS, staging, payment, generation, push, email, and outbox gates are `PASS`; no open `P0/P1`; evidence contains no secrets or sensitive payloads.

## Audit changes and limitations

**Changed files:** only `docs/production-readiness-audit-2026-07-09.md` in the report commit. The preceding snapshot commit contains the pre-existing dirty source state and is not an audit-authored product change.

**Checks run:** repository/secret hygiene, Markdown links, Compose config, .NET restore/build/package audit, Render predeploy, Flutter dependency/l10n/analyze/tests/build, admin install/format/lint/typecheck/tests/build/E2E command, isolated Docker image build, ADB/toolchain/device inspection, staging readiness/DNS/endpoint probes, and static API/data/security/outbox review.

**Not verified:** successful backend tests, EF migration execution, audit Docker runtime, Android UI flows, real Render services, FAL/R2, Stripe, Google Play, FCM, SMTP, iOS build/device/App Store/APNs. Each is blocked by a recorded build/configuration defect or missing authorized external environment, not marked as pass.

**Residual risk:** contract/security code not reached dynamically may contain additional findings. The next audit must start from a replacement immutable SHA after Batches 1–4 and must not reuse old containers, screenshots, provider events, or logs as evidence.
