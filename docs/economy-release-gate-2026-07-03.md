# Economy, Purchases, Notifications, Generation Billing Release Gate - 2026-07-03

## Verdict

Production release is blocked.

Code-level reconciliation checks are in a much better state after the reconciliation-first fix, but this gate cannot be closed as production-ready because:

- full backend `dotnet test` still exits with code 1 due to a test host crash after the assertion failure was fixed;
- EF migration checks and `database update` cannot run in this shell because migration connection strings are not configured;
- Stripe / Google Play / App Store sandbox purchases were not executed against external providers;
- real-device Android and iOS notification and purchase flows were not manually verified.

The current state is suitable for the next sandbox/device validation pass, not for production rollout.

## Changes Made During Gate

- Tightened Templates generation billing snapshot selection so reconciliation does not scan every historical charged generation:
  - `TemplateGenerationBillingReconciliationService.ListGenerationBillingSnapshotsAsync` now filters `ChargedAtUtc` and `RefundedAtUtc` by `changedAfterUtc`.
- Added backend tests for the remaining generation billing incident branches:
  - refund without spend;
  - refund ledger without `RefundedAtUtc`;
  - `RefundedAtUtc` without refund ledger;
  - duplicate spend ledger;
  - duplicate refund ledger;
  - stale uncharged active generation;
  - clean completed charged generation with ledger.
- Fixed one non-economy backend release-gate failure in `Program.cs`:
  - production `/templates-media` static-media blocking now uses `IsManagedStaticMediaPath(context.Request.Path, "/templates-media")` instead of raw string prefix matching.

## Architecture Review

The cross-module boundary is acceptable:

- Economy does not reference Templates infrastructure or `TemplatesDbContext` directly.
- Templates Infrastructure implements the Economy application port `IGenerationBillingReconciliationService`.
- Economy reconciliation depends on the port, not on Templates persistence.
- Admin recovery actions stay under `/api/admin/economy` and require `AdminOnly`.
- Admin UI calls the API contract; no direct database access was found in the admin-web path checked for this gate.

Risk fixed during gate:

- The initial snapshot query included every charged job with `x.ChargedAtUtc != null`. This could become a full historical scan. It was changed to `x.ChargedAtUtc >= changedAfterUtc` and `x.RefundedAtUtc >= changedAfterUtc`, while still keeping failed/cancelled unrefunded jobs visible.

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

## Legacy Payment Endpoints

Legacy Stripe endpoints still exist in backend:

- `POST /api/payments/stripe/token-purchase`;
- `POST /api/payments/stripe/subscription`;
- `POST /api/payments/stripe/customer-portal`;
- `GET /api/payments/stripe/diagnostics`.

They are still documented and smoke-tested. Scoped search did not find mobile or admin-web source usage of these legacy routes. Treat them as backend compatibility legacy, not active client dependency. A separate deprecation/removal decision is still needed before production cleanup can remove them safely.

## Automated Verification

Passed:

- `dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~EconomyServiceTests" -p:UseSharedCompilation=false`
  - 159 passed, 0 failed.
- `npm run typecheck` in `apps/admin-web`
  - passed.
- `npm test` in `apps/admin-web`
  - 81 test files passed, 600 tests passed.
- `flutter analyze` in `apps/petmagic-mobile`
  - no issues found.
- `flutter test` in `apps/petmagic-mobile`
  - 1132 tests passed.

Blocked / not green:

- `dotnet test -p:UseSharedCompilation=false`
  - first run failed `HostApiMiddlewareOrderTests.Program_ShouldClassifyStaticMediaOnlyByManagedPathSegments`;
  - fixed raw `/templates-media` prefix check in `Program.cs`;
  - second run had 0 failed assertions and 1277 passed, but still exited with code 1: `Active test run aborted. Reason: Test host process crashed`.

## EF / Database Verification

EF CLI is available:

- `dotnet ef --version` -> `10.0.8`.

Both migration checks built successfully, then failed at design-time context creation because required environment variables are absent:

- Economy:
  - command: `dotnet ef migrations has-pending-model-changes --project src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context EconomyDbContext`
  - failure: `PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING is required for design-time migrations.`
- Templates:
  - command: `dotnet ef migrations has-pending-model-changes --project src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/PetMagic.Modules.Templates.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context TemplatesDbContext`
  - failure: `PETMAGIC_TEMPLATES_MIGRATIONS_CONNECTION_STRING is required for design-time migrations.`

`dotnet ef database update` was not run because the same required migration connection strings are missing. Running it without an explicit local/staging target would not be a safe production gate check.

## Sandbox and Device Verification

Not verified in this gate:

- Stripe sandbox one-time token purchase;
- Stripe subscription purchase, renewal/cancel/refund webhook behavior;
- Google Play Billing sandbox purchase;
- App Store sandbox purchase;
- real Android notification token registration and push receipt;
- real iOS APNs/FCM token registration and push receipt;
- real Android/iOS wallet balance refresh immediately after purchase/refund;
- real generation start on device with spend, worker processing, failure refund, and reconciliation rerun.

These remain mandatory before production go.

## Go / No-Go

No-go for production.

Go only for the next controlled validation stage after:

1. rerun full backend tests and resolve the test host crash;
2. provide local/staging migration connection strings and run Economy/Templates `has-pending-model-changes` plus `database update`;
3. execute Stripe / Google Play / App Store sandbox purchase scenarios;
4. verify real-device Android and iOS notifications and wallet refresh;
5. rerun economy reconciliation on the target environment and confirm no critical open generation billing incidents.
