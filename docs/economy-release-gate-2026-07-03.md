# Economy, Purchases, Notifications, Generation Billing Release Gate - 2026-07-03

## Verdict

Production release is still blocked.

The backend crash, EF migration, and reconciliation-query blockers from this gate are closed on the local release-gate environment. The remaining no-go items are external sandbox/device validations that cannot be completed from this workspace without missing provider credentials, iOS hardware/tooling, or manual hosted checkout interaction.

Closed during this gate:

- full backend test-host crash was not reproduced after diagnostics and the latest local changes;
- Economy and Templates EF migrations were validated from clean databases and from a copied existing database;
- Templates generation billing reconciliation was indexed and revalidated;
- admin incident detail query shape was reviewed as bounded and not N+1.

Still blocking production go:

- the current local `petmagic_db` reconciliation inventory is not clean and cannot be used as production-readiness evidence until the open incidents are resolved or the gate is rerun on a clean staging snapshot;
- Stripe hosted checkout payment completion and webhook delivery were not completed end to end;
- Google Play Billing sandbox is blocked by missing Google Play service account/package/test setup;
- App Store sandbox is blocked by missing App Store API credentials and iOS device/tooling;
- real push delivery is blocked by missing FCM/APNs credentials and iOS device;
- real Android/iOS wallet refresh and generation spend/refund device flows remain unverified end to end.

## Changes Made During Gate

- Tightened Templates generation billing snapshot selection so reconciliation does not scan every historical charged/refunded generation:
  - `TemplateGenerationBillingReconciliationService.ListGenerationBillingSnapshotsAsync` filters `ChargedAtUtc` and `RefundedAtUtc` by `changedAfterUtc`.
- Added backend tests for generation billing incident branches:
  - refund without spend;
  - refund ledger without `RefundedAtUtc`;
  - `RefundedAtUtc` without refund ledger;
  - duplicate spend ledger;
  - duplicate refund ledger;
  - stale uncharged active generation;
  - clean completed charged generation with ledger.
- Added Templates database indexes for reconciliation:
  - migration `20260702234729_AddGenerationBillingReconciliationIndexes`;
  - `IX_tgj_CreatedAtUtc_Id`;
  - `IX_tgj_UpdatedAtUtc_Id`;
  - `IX_tgj_ChargedAtUtc`;
  - `IX_tgj_RefundedAtUtc`.
- Fixed one non-economy backend release-gate failure in `Program.cs`:
  - production `/templates-media` static-media blocking now uses managed path segment classification instead of raw string prefix matching.

## Architecture Review

The cross-module boundary is acceptable:

- Economy does not reference Templates infrastructure or `TemplatesDbContext` directly.
- Templates Infrastructure implements the Economy application port `IGenerationBillingReconciliationService`.
- Economy reconciliation depends on the port, not on Templates persistence.
- Admin recovery actions stay under `/api/admin/economy` and require `AdminOnly`.
- Admin UI calls the API contract; no direct database access was found in the admin-web path checked for this gate.

Risk fixed during gate:

- The initial snapshot query included every charged job with `x.ChargedAtUtc != null`. It was changed to `x.ChargedAtUtc >= changedAfterUtc` and `x.RefundedAtUtc >= changedAfterUtc`, while still keeping failed/cancelled unrefunded jobs visible.

## Generation Billing Flow Coverage

Checked start paths:

- user upload generation;
- generation from result;
- pet/admin template generation;
- similar generation;
- QA fixture generation.

Observed contract:

- normal start flows call `billing.ChargeAsync(userId, generationId, tokenCost, ...)`;
- ledger reason is `template_generation:{generationId:N}`;
- refund reason/idempotency uses `generation_refund:{generationId:N}`;
- jobs set `ChargedAtUtc` after successful charge;
- processor queue/claiming filters prevent ordinary user jobs without `ChargedAtUtc` from being processed, with the existing admin test user exception.

## Reconciliation and Admin Recovery

Covered incident types now include:

- `GenerationChargeMarkerMissing`;
- `GenerationLedgerSpendMissing`;
- `GenerationRefundMissing`;
- `GenerationRefundMarkerMissing`;
- `GenerationRefundLedgerMissing`;
- `GenerationRefundWithoutSpend`;
- `GenerationDuplicateLedgerMutation`;
- `GenerationBillingPendingStale`;
- `GenerationBillingJobMissing` is present in code; not directly added in this gate because it requires the Templates snapshot lookup to fail for a ledger-backed generation.

Admin recovery actions checked:

- `restore_generation_charge_marker`;
- `refund_generation_spend`.

Both are behind Admin economy endpoints, write incident audit entries in tests, and are idempotent where the ledger mutation must not duplicate.

Admin incident detail query shape:

- ledger rows are limited by `IncidentDetailLedgerLimit = 25`;
- webhook rows are limited by `IncidentDetailWebhookLimit = 10`;
- audit rows are limited by `IncidentDetailAuditLimit = 50`;
- generation billing details call `GetGenerationBillingSnapshotAsync` once for generation incidents;
- no per-row detail loop or N+1 query pattern was found in `BuildIncidentDetailAsync`.

## Removed Legacy Payment Endpoints

The old `/api/payments/stripe/*` compatibility route group was removed after source search found no mobile or admin-web consumers.

Removed routes:

- `POST /api/payments/stripe/token-purchase`;
- `POST /api/payments/stripe/subscription`;
- `POST /api/payments/stripe/customer-portal`;
- `GET /api/payments/stripe/diagnostics`.

Canonical replacements:

- token packs: `POST /api/economy/purchases/create`;
- Stripe purchase verification: `POST /api/economy/purchases/{orderId}/verify-stripe`;
- premium checkout: `POST /api/economy/premium/checkout`;
- premium billing portal: `POST /api/economy/premium/manage`;
- Stripe diagnostics: `GET /api/economy/premium/stripe-diagnostics`.

Startup route tests were updated to assert the canonical endpoints instead of preserving the legacy surface.

## Automated Verification

Passed:

- `dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~EconomyServiceTests" -p:UseSharedCompilation=false`
  - 159 passed, 0 failed.
- `dotnet test -p:UseSharedCompilation=false --logger "trx;LogFileName=full-backend.trx" --blame-crash --blame-hang-timeout 5m`
  - 1400 passed, 0 failed, exit code 0;
  - TRX: `tests/PetMagic.Modules.Identity.Tests/TestResults/full-backend.trx`;
  - no blame sequence file was produced because the test run completed.
- `dotnet test -p:UseSharedCompilation=false`
  - final run after the Templates index migration: 1425 passed, 0 failed, exit code 0.
- `npm run typecheck` in `apps/admin-web`
  - passed.
- `npm test` in `apps/admin-web`
  - 81 test files passed, 600 tests passed.
- `flutter analyze` in `apps/petmagic-mobile`
  - no issues found.
- `flutter test` in `apps/petmagic-mobile`
  - 1132 tests passed.

Current-tree refresh after the wider repository hardening pass:

- `dotnet test PetMagic.slnx --no-restore`
  - 1438 passed, 0 failed, 0 skipped.
- `npm test` in `apps/admin-web`
  - 82 test files passed, 605 tests passed.
- `npm run lint` in `apps/admin-web`
  - passed.
- `npm run build` in `apps/admin-web`
  - passed on Next.js 16.2.10.
- `flutter analyze` in `apps/petmagic-mobile`
  - no issues found.
- `flutter test` in `apps/petmagic-mobile`
  - 1142 tests passed.
- `flutter build apk --debug` in `apps/petmagic-mobile`
  - built `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build apk --profile` in `apps/petmagic-mobile`
  - built `build/app/outputs/flutter-apk/app-profile.apk`.
- current Docker runtime smoke:
  - `docker compose ps` showed backend and generation-worker healthy;
  - `GET http://localhost:5000/health` returned `Healthy`;
  - `GET http://localhost:5000/api/templates/feed?limit=3` returned HTTP 200 with public feed items;
  - `GET http://localhost:3000/` returned HTTP 200 from admin-web;
  - `GET http://localhost:9090/-/healthy` returned HTTP 200 from Prometheus;
  - recent backend and generation-worker logs had no matches for critical error patterns in the last 400 lines.

Backend crash blocker status: closed locally.

## EF / Database Verification

EF CLI is available:

- `dotnet tool list` -> `dotnet-ef 10.0.9` from `.config/dotnet-tools.json`.

Note: EF CLI is pinned to the same `10.0.9` major/minor patch as the EF runtime packages, so a tools/runtime version warning is no longer expected.

Local Docker PostgreSQL was used through temporary release-gate databases:

- clean Economy DB: `petmagic_ef_economy_clean_20260703`;
- clean Templates DB: `petmagic_ef_templates_clean_20260703`;
- existing-state copy DB: `petmagic_ef_existing_20260703`, restored from local `petmagic_db`.

Economy checks passed:

- clean `database update` applied through `20260702200211_AddWalletTokenAccounting`;
- existing-copy `database update` applied the pending local-copy migrations:
  - `20260702121600_AddWalletBalanceNonNegativeConstraint`;
  - `20260702192404_AddEconomyIncidents`;
  - `20260702194646_AddEconomyIncidentAuditEntries`;
  - `20260702200211_AddWalletTokenAccounting`;
- clean and existing-copy `has-pending-model-changes` both returned no model changes;
- rollback to `20260702194646_AddEconomyIncidentAuditEntries` and reapply to latest succeeded.

Templates checks passed:

- clean `database update` applied through `20260702234729_AddGenerationBillingReconciliationIndexes`;
- existing-copy `database update` applied `20260702234729_AddGenerationBillingReconciliationIndexes`;
- clean and existing-copy `has-pending-model-changes` both returned no model changes;
- rollback to `20260702232501_AddTemplateGenerationBillingCommands` and reapply to latest succeeded.

Whole-project EF refresh after the wider repository hardening pass:

- an isolated temporary PostgreSQL 16 container was used and removed after verification;
- shared clean app database `petmagic_full_clean_20260703055542` applied all five EF contexts sequentially:
  - `IdentityDbContext` through `20260702213414_AddExternalAuthTickets`;
  - `EconomyDbContext` through `20260702200211_AddWalletTokenAccounting`;
  - `GamificationDbContext` through `20260630213815_RemoveAchievementIconAssetPath`;
  - `SupportChatDbContext` through `20260629133404_RepairSupportChatSchemaDrift`;
  - `TemplatesDbContext` through `20260702234729_AddGenerationBillingReconciliationIndexes`;
- shared clean `has-pending-model-changes` returned no model changes for all five contexts;
- per-context existing-state simulations applied each context to its previous migration and then to latest:
  - Identity: `20260609071042_AddIdentityModelCompatibility` -> `20260702213414_AddExternalAuthTickets`;
  - Economy: `20260702194646_AddEconomyIncidentAuditEntries` -> `20260702200211_AddWalletTokenAccounting`;
  - Gamification: `20260624133602_BaselineGamification` -> `20260630213815_RemoveAchievementIconAssetPath`;
  - SupportChat: `20260629132451_NormalizeLegacyConversationEnums` -> `20260629133404_RepairSupportChatSchemaDrift`;
  - Templates: `20260702232501_AddTemplateGenerationBillingCommands` -> `20260702234729_AddGenerationBillingReconciliationIndexes`;
- existing-state simulation `has-pending-model-changes` returned no model changes for all five contexts.

Known migration warning:

- older Templates migrations that create indexes concurrently emit EF warnings about non-transactional operations. The update still completed successfully in the local gate DBs.

EF migration blocker status: closed locally.

## Reconciliation Query Safety

Economy ledger indexes verified on `economy_wallet_ledger`:

- `IX_economy_wallet_ledger_CreatedAtUtc`;
- `IX_economy_wallet_ledger_Source_CreatedAtUtc`;
- `IX_economy_wallet_ledger_UserId_CreatedAtUtc`;
- `UX_ewl_UserId_Reason_GenerationRefund`.

Templates indexes verified after migration:

- `IX_tgj_ChargedAtUtc`;
- `IX_tgj_CreatedAtUtc_Id`;
- `IX_tgj_RefundedAtUtc`;
- `IX_tgj_Status_RefundedAtUtc_RefundLastAttemptedAtUtc`;
- `IX_tgj_UpdatedAtUtc_Id`.

`EXPLAIN` on the reconciliation snapshot query in the clean Templates gate DB used:

- `Limit`;
- `Index Scan Backward using "IX_tgj_UpdatedAtUtc_Id" on templates_generation_jobs`.

The query remains data-distribution dependent because of OR filters, but the release-gate risk of an unindexed historical scan was reduced by timestamp filtering plus direct indexes on the relevant columns.

Reconciliation performance blocker status: closed locally.

## Current Local Reconciliation Inventory

The local Docker database is useful for exercising the reconciliation worker, but it is not a clean release fixture.
The current `petmagic_db` contains historical local smoke and queue-QA data that intentionally or accidentally violates billing invariants.

The latest inventory check against `economy_incidents` showed 295 open incidents:

| Type | Open count | Notes |
| --- | ---: | --- |
| `GenerationBillingJobMissing` | 133 | Mostly local smoke users and fixed fixture UUID users where ledger rows reference missing Templates jobs. |
| `GenerationLedgerSpendMissing` | 43 | Mostly queue-QA generations marked charged without a matching spend ledger entry. |
| `GenerationRefundWithoutSpend` | 40 | Mostly queue-QA refund ledger rows without matching spend rows. |
| `PurchaseSettlementFailed` | 36 | Local/sandbox purchase rows that still need provider-side completion or manual resolution. |
| `LedgerWalletMismatch` | 33 | Wallet projection mismatches from historical local data. |
| `PremiumEntitlementMismatch` | 9 | Sandbox subscription or premium sync rows; several include `sub_*` references or local QA identifiers. |
| `SubscriptionStateMismatch` | 1 | A canceled premium-like subscription state that remains open for review. |

Supporting evidence:

- open incident rows were first detected during the 2026-07-03 local release-gate run and then updated by each reconciliation run;
- grouped user samples were dominated by `local-smoke-*`, `queue-qa-*`, `example.test`, and fixed `10000000-...` fixture IDs;
- the backend startup worker correctly surfaced the condition as `ManualReviewRequired`, so this is visible to operators rather than silent.

Do not mark this local DB as production-ready by simply deleting the incidents.
The pre-production gate must be rerun on either:

1. a clean staging database with no historical local QA fixtures; or
2. a copied staging database where every open incident has been reviewed, repaired through the admin incident actions where applicable, or explicitly accepted with an audit note.

The production-release acceptance criterion is:

- `SELECT "Type", "Status", COUNT(*) FROM "economy_incidents" GROUP BY "Type", "Status";` has no unexpected open critical incidents;
- a manual or scheduled reconciliation run completes without creating or updating unexpected critical incidents;
- the admin incidents page can open the remaining accepted incidents and show the audit trail/recovery context.

## Sandbox and Device Verification

Available local prerequisites:

- backend `/health` was healthy on `http://localhost:5000/health`;
- Android device was connected: `SM G991B`, Android 15 API 35;
- `adb reverse --list` included `tcp:5000 tcp:5000`;
- Stripe CLI was installed and authenticated in test mode;
- Stripe API checkout creation succeeded through `/api/economy/purchases/create`:
  - pack: `starter`;
  - provider: `stripe`;
  - status: `pending`;
  - checkout URL returned;
  - amount: `6.29 EUR`;
  - spark tokens: `20`.

Blocked / incomplete external validations:

- Stripe hosted checkout payment completion and webhook replay were not completed automatically because this workspace had no usable browser automation/runtime for the hosted checkout flow.
- Google Play Billing sandbox is blocked:
  - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` missing;
  - `GOOGLE_PLAY_PACKAGE_NAME` missing;
  - no Play test product/test account setup was available to the gate.
- App Store sandbox is blocked:
  - `APP_STORE_ISSUER_ID` missing;
  - `APP_STORE_KEY_ID` missing;
  - `APP_STORE_PRIVATE_KEY` missing;
  - no iOS device/Xcode execution path was available in this Windows workspace.
- Push notification delivery is blocked:
  - Firebase/FCM service credentials missing;
  - APNs credentials missing;
  - no iOS device was available.
- Real-device Android wallet refresh/generation spend/refund was not completed end to end because purchase completion and external provider-side events were not available.

## Go / No-Go

No-go for production.

The release gate can move to the next validation stage after the remaining external checks are executed with real sandbox/provider prerequisites:

1. complete Stripe hosted checkout payment and verify webhook-driven wallet update;
2. complete Stripe subscription renewal/cancel/refund webhook behavior;
3. complete Google Play Billing sandbox purchase and wallet refresh;
4. complete App Store sandbox purchase and wallet refresh;
5. verify Android FCM token registration and push receipt on a real device;
6. verify iOS APNs/FCM token registration and push receipt on a real device;
7. run real generation spend, worker processing, failure refund, wallet refresh, and reconciliation rerun on device/staging.
