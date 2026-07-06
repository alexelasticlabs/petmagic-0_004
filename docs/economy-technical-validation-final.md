# Economy/Templates/Notifications Final Technical Validation - 2026-07-03

## Status

- Final status: **technical no-go for production release**.
- Local automated gates: **green after fixes**.
- Reason for no-go: Stripe hosted checkout completion, Google Play/App Store sandbox purchases, real FCM/APNs delivery, webhook delivery from providers, iOS build/device evidence, and real-device wallet refresh after external purchase/refund remain external `needs verification` items. Android real-device gallery/generation smoke passed on `R5CR126590A`.

## Baseline

- Date: 2026-07-03
- Branch: `codex/release-blockers-hardening`
- Commit: `c1ad9ff49`
- Head: `c1ad9ff4928fca4946ccd16e361a7c60d0d70f6a 2026-07-03T02:33:01+03:00 chore(repo): add release-gate docs, monitoring artifacts, and ops runbooks`
- Worktree: dirty before validation and still dirty after validation.
- Diff size at refreshed inventory: 367 tracked dirty entries, 26 untracked release-gate/test/monitoring files, and `git diff --shortstat` reported 366 changed files with 11559 insertions and 2407 deletions.

## Worktree Classification

Intentional release-gate work:

- Economy billing, reconciliation, premium, webhook, push-token, privacy/logging, and admin hardening changes under `src/Modules/Economy`, `tests/PetMagic.Modules.Identity.Tests/Economy`, docs, and mobile/admin clients.
- Templates generation, billing reconciliation, gallery/history, push-token, media/logging, and admin hardening changes under `src/Modules/Templates`, mobile, admin-web, and tests.
- Notification contract and sender/client changes across economy, templates, support, mobile, and docs.

Required test/migration/doc artifacts:

- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/Data/Migrations/20260702234729_AddGenerationBillingReconciliationIndexes.cs`
- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/Data/Migrations/20260702234729_AddGenerationBillingReconciliationIndexes.Designer.cs`
- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/ProcessOutputDrainer.cs`
- `src/BuildingBlocks/PetMagic.BuildingBlocks/Observability/SafeHttpContentReader.cs`
- `src/BuildingBlocks/PetMagic.BuildingBlocks/Observability/SafeLogValues.cs`
- `apps/admin-web/src/lib/admin-api-boundary.test.ts`
- Backend logging/privacy/environment tests and docs updates.

Unrelated or pre-existing dirty changes:

- Existing broad admin-web, mobile, infra, docs, and test changes were not reverted.
- Deleted `docs/md/STATUS.md` is intentional documentation cleanup: the removed status snapshot was dated 2026-05-16 and no active Markdown links point to it.

Removable scratch:

- Local `artifacts/codex-*` build/test logs and isolated SDK outputs were generated for validation. They are not tracked by Git.

## Fixes Made In This Pass

- Fixed stale notification docs: wallet push route is `/profile/wallet`, and fallback state fetches use `/api/economy/wallet` and `/api/economy/premium/status`.
- Fixed backend build failure by ensuring `ProcessOutputDrainer` is present in Templates Infrastructure. This resolves `CS0103 ProcessOutputDrainer does not exist` in:
  - `VideoThumbnailGenerator.cs`
  - `TemplateWatermarkRenderer.cs`
  - `PetsService.Thumbnails.cs`

## Contracts Checked

Economy user API under `/api/economy`:

- Wallet, ledger, packs, checkout config, purchases, Stripe/store verification, premium status/checkout/manage, billing validation aliases, Stripe/App Store/Google Play webhooks, and economy push token registration were statically checked against backend routes, mobile repositories, admin clients, and docs.
- Removed legacy `/api/payments/stripe/*` routes were not found in current mobile/admin consumers.

Admin Economy under `/api/admin/economy`:

- Ledger, purchases/refunds, metrics, incidents/detail/actions, reconciliation run, subscription summaries, and provider configs were checked against admin-web API types and tests.
- Admin API boundary test exists to prevent direct DB access from admin-web.

Templates under `/api/templates`:

- Generation start/from-result/similar, history/list, unread count, mark-read, cancel/delete, events, downloads/share, and Templates push token registration were checked against backend routes and mobile/admin DTOs.

Notifications:

- Payload types checked against `docs/notifications-contract.md`: `template_generation`, `wallet`, `premium`, `support_chat`.
- Required `dedupe_key` and route allowlist are documented.
- Mobile routes and backend sender routes align for `/profile/wallet`, `/profile`, `/profile/support`, and `/generations/{generationId}`.
- Invalid-token disable path exists in backend senders.

Reconciliation:

- Incident branches checked in code/tests: `GenerationChargeMarkerMissing`, `GenerationLedgerSpendMissing`, `GenerationRefundMissing`, `GenerationRefundMarkerMissing`, `GenerationRefundLedgerMissing`, `GenerationRefundWithoutSpend`, `GenerationDuplicateLedgerMutation`, `GenerationBillingPendingStale`, `GenerationBillingJobMissing`.
- Recovery actions checked: `restore_generation_charge_marker`, `refund_generation_spend`.
- Incident detail query limits checked: ledger 25, webhooks 10, audit 50.

## Commands And Results

Backend:

- `dotnet build PetMagic.slnx --artifacts-path artifacts\codex-dotnet-build-final --disable-build-servers -m:1 /nr:false -p:UseSharedCompilation=false`
  - Passed: 0 warnings, 0 errors.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build`
  - Passed: 1573 passed, 0 failed, 0 skipped.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build --filter "FullyQualifiedName~HostApiProductionConfigurationValidatorTests|FullyQualifiedName~BackendEnvironmentContractTests|FullyQualifiedName~ClientApiContractRouteTests"`
  - Passed: 106 passed, 0 failed, 0 skipped.

EF:

- Pending model changes:
  - `dotnet ef migrations has-pending-model-changes --context IdentityDbContext`
  - `dotnet ef migrations has-pending-model-changes --context EconomyDbContext`
  - `dotnet ef migrations has-pending-model-changes --context GamificationDbContext`
  - `dotnet ef migrations has-pending-model-changes --context SupportChatDbContext`
  - `dotnet ef migrations has-pending-model-changes --context TemplatesDbContext`
  - Passed for all contexts: no changes since last migration.
- Existing isolated DB apply:
  - `dotnet ef database update` for Identity, Economy, Gamification, SupportChat, and Templates against `petmagic_goal_probe` `petmagic_db`.
  - Passed: every context reported the database already up to date.
- Clean DB apply:
  - `dotnet ef database update` for Identity, Economy, Gamification, SupportChat, and Templates against temporary `petmagic_clean_goal_202607031826`.
  - Passed: 73 migration history entries were present after the full apply, then the temporary database was dropped.
  - Note: Templates provider logged non-transactional concurrent-index migration warnings for existing `CREATE/DROP INDEX CONCURRENTLY` operations. Operations completed, but if rollout is interrupted during those operations, repair/rollback must be manual and coordinated.

Admin:

- `npm run typecheck`
  - Passed.
- `npm test`
  - Passed: 82 test files, 616 tests.
- `npm run lint`
  - Passed.
- `npm run build`
  - Passed.

Mobile:

- `flutter analyze`
  - Passed: no issues found.
- `flutter test`
  - Passed: 1176 tests.
- `flutter build apk --profile --dart-define=API_BASE_URL=https://api.petmagic.app`
  - Passed: `build\app\outputs\flutter-apk\app-profile.apk`.
- `flutter test integration_test\gallery_cross_flow_test.dart -d R5CR126590A --reporter expanded --dart-define=API_BASE_URL=http://127.0.0.1:5000`
  - Passed on real Android device `R5CR126590A`: 1 test passed.
- `adb logcat -d -b crash -t 200`
  - Passed: no crash-buffer output after the real-device smoke.
- `flutter build ios --debug --no-codesign`
  - Not run: Windows host has no iOS/Xcode toolchain. `flutter doctor` reported Windows, Android, Chrome, Visual Studio, connected devices, and network resources healthy.

Runtime smoke:

- Active runtime stacks:
  - `petmagic-0_004-backend-1`: healthy on `localhost:5000`.
  - `petmagic_goal_probe-backend-1`: healthy on `localhost:5601`.
  - `petmagic_goal_probe-admin-web-1`: HTTP 200 on `localhost:3600`.
  - `petmagic_goal_probe-postgres-1`: healthy on `localhost:56543`.
  - `petmagic_goal_probe-generation-worker-1`: healthy.
- `GET http://localhost:5000/health`
  - Passed: healthy.
- `GET http://localhost:5000/api/templates/feed?limit=3`
  - Passed: HTTP 200 with feed items.
- `GET http://localhost:5601/health`
  - Passed: healthy.
- `GET http://localhost:5601/api/templates/feed?limit=3`
  - Passed: HTTP 200.
- `GET http://localhost:3600`
  - Passed: HTTP 200 from admin-web.

## Needs Verification

- Stripe hosted Checkout completion with real sandbox credentials.
- Stripe webhook delivery and signature validation from Stripe CLI or dashboard.
- Google Play sandbox purchase/renewal/cancel/refund flows.
- App Store sandbox purchase/renewal/cancel/refund flows.
- FCM delivery to a real Android device and APNs delivery to a real iOS device.
- Real-device wallet refresh after purchase, refund, and premium entitlement change.
- Real-device push notification foreground/background/cold-start routing for generation, wallet, premium, and support notifications.
- iOS debug build/no-codesign on macOS/Xcode.

## Final Notes

- Local backend/admin/mobile/EF/runtime gates are green after the targeted fixes and refreshed validation.
- Production release remains blocked until external provider/device evidence is captured.
- Historical open incidents in any local database must be treated as local data only, not production evidence.
