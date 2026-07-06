# PetMagic Security Audit - 2026-06-17

> Historical security audit snapshot. This document preserves the June 2026
> security review and should not be used as current release evidence. For the
> current production-readiness gate, use
> `production-readiness-audit-2026-07-03.md`.

## What Was Checked

- Backend route metadata for Identity, Economy, Templates, and SupportChat: explicit auth/anonymous metadata, rate limiting, and admin role policies.
- Auth/session flows: refresh-token rotation, logout revoke, refresh reuse after logout, refresh-token ownership checks, and client-side session persistence.
- Payments/subscriptions: Stripe diagnostics exposure, Stripe checkout/payment-intent order identity, amount, and currency verification, webhook idempotency coverage already present.
- Uploads/files: avatar upload MIME spoofing, pet/template upload policy shape, filename sanitization via `Path.GetFileName`, and static-file production handling.
- Mobile security surfaces: secure storage versus SharedPreferences, logout/session cache reset behavior, and existing safe API error/log tests.
- Admin panel security surfaces: role-aware session guard, volatile token storage, safe error/sensitive display tests, critical confirmation tests already present.
- Secrets/configs: tracked current tree regex scan, repository secret hygiene tests, ignored local `.env`/key files, and git-history pattern scan.

## Vulnerabilities Found

- Stripe/payment diagnostics endpoints were available to any authenticated active user:
  - `GET /api/economy/premium/stripe-diagnostics`
  - Stripe diagnostics exposure, now limited to `GET /api/economy/premium/stripe-diagnostics`
- Avatar upload trusted declared `image/*` content type without magic-byte validation, allowing non-image payloads to reach avatar storage when labeled as an image.
- Backend route contract tests did not enforce all `/api/*` routes to declare explicit access metadata and rate-limit metadata across every module.
- Regression coverage was missing for refresh-token reuse after logout and refresh-token ownership violation on logout.
- Regression coverage was missing for admin persisted session migration that strips access/refresh tokens from `sessionStorage`.
- Regression coverage was missing for mobile `AuthSessionStorage.save` and `clear` guarantees against legacy SharedPreferences token persistence.

## Fixes Applied

- Restricted Stripe diagnostics endpoints to `AdminOnly` while preserving route names and rate-limit policies.
- Added avatar magic-byte sniffing for JPEG, PNG, WebP, GIF, and HEIC/HEIF-compatible uploads; mismatched declared MIME types now return validation errors before service/storage calls.
- Added all-module route contract checks for:
  - explicit `AllowAnonymous` or authorization metadata on every `/api/*` route;
  - rate-limit metadata on every `/api/*` route;
  - admin role policy on every `/api/admin/*` route.
- Added auth/session tests for:
  - refresh token cannot be reused after logout;
  - logout rejects a refresh token owned by another user without revoking the owner session.
- Added upload security test for declared image content with invalid magic bytes.
- Added admin-web session test proving persisted auth sessions are migrated without access/refresh tokens.
- Added mobile tests proving auth sessions persist only in secure storage and `clear` removes secure and legacy SharedPreferences sessions.
- Preserved existing user changes around Stripe checkout/payment-intent verification, which now require order identity, amount, and currency match before confirming payment.

## Secret Scan Results

- `gitleaks` was not installed in this environment.
- Fallback current-tree regex scan matched only redacted placeholder/test locations:
  - `docs/watermark-monetization-manual-qa.md`
  - `tests/PetMagic.Modules.Identity.Tests/Economy/EconomyInfrastructureConfigurationTests.cs`
- `RepositorySecretHygieneTests` passed: 8/8.
- Tracked local secret files:
  - Firebase placeholder configs are tracked and covered by hygiene tests.
  - `.env`, `.env.load.local`, `android/key.properties`, and local keystore files are ignored and were not printed.
- Git-history pattern scan returned commits that touched placeholder/key-like patterns. Values were not emitted. Recommended production action: run an installed scanner such as Gitleaks in CI/local and rotate any real credentials if the scanner reports non-placeholder findings.

## Dependency Recheck - 2026-07-03

- `dotnet list PetMagic.slnx package --vulnerable --include-transitive` reported no vulnerable packages for every solution project against NuGet.org and the local SDK feed.
- `cd apps/admin-web && npm audit --omit=dev` reported `0 vulnerabilities` for production dependencies.
- `cd apps/petmagic-mobile && flutter pub outdated` found one safe direct patch update: `image_picker` `1.2.2` -> `1.2.3`; the lockfile was updated and `flutter analyze` passed with no issues.
- Remaining newer Flutter packages are blocked by current dependency constraints or SDK/package compatibility and were not force-upgraded.

Current-tree dependency refresh:

- `dotnet list PetMagic.slnx package --vulnerable --include-transitive` still reports no vulnerable packages for every solution project.
- `dotnet list PetMagic.slnx package --outdated` reports available updates, but no security advisory in the current scan:
  - backend major/API-touching updates left for a dedicated compatibility pass: `SixLabors.ImageSharp` 4.x, `SixLabors.ImageSharp.Drawing` 3.x, `AWSSDK.S3` 4.x, `Microsoft.OpenApi` 3.x, `Stripe.net` 52.x;
  - backend minor/test-tool updates left for a low-risk maintenance pass: `Google.Apis.Auth` 1.75.0, `Microsoft.NET.Test.Sdk` 18.7.0, `coverlet.collector` 10.0.1.
- `npm audit --omit=dev --json` in `apps/admin-web` reports 0 vulnerabilities for production dependencies.
- `npm outdated --json` in `apps/admin-web` reports only major dev-tool line updates outside the current constraints: `@types/node` 26.x, `eslint` 10.x, and `typescript` 6.x.
- `flutter pub outdated --json` reports no discontinued, retracted, or advisory-affected current packages; remaining newer packages are transitive or direct patch/minor updates that require a separate Flutter SDK/constraint compatibility pass.

## Security Tests Added Or Extended

- Backend:
  - `EconomyApiStartupSmokeTests.StripeDiagnosticsEndpoints_ShouldRequireAdminOnlyPolicy`
  - `ClientApiContractRouteTests.ApiRoutes_ShouldDeclareExplicitAccessPolicy`
  - `ClientApiContractRouteTests.ApiRoutes_ShouldDeclareRateLimitPolicy`
  - `ClientApiContractRouteTests.AdminApiRoutes_ShouldRequireAdminOrModeratorPolicy`
  - `IdentityServiceEmailFlowTests.LogoutAsync_ShouldRevokeRefreshToken_AndRejectReuse`
  - `IdentityServiceEmailFlowTests.LogoutAsync_ShouldRejectRefreshTokenOwnedByAnotherUser`
  - `AuthEndpointsNativeGoogleTests.UpdateAvatar_ShouldRejectDeclaredImageWithInvalidMagicBytes`
- Admin web:
  - `ensureAdminSession` persisted-session migration test for volatile tokens.
- Mobile:
  - `AuthSessionStorage` secure-storage-only save test.
  - `AuthSessionStorage.clear` secure plus legacy SharedPreferences cleanup test.

## Verification Evidence

- `dotnet test PetMagic.slnx --no-restore`
  - Passed: 1438, Failed: 0, Skipped: 0.
- `cd apps/admin-web && npm test && npm run lint && npm run build`
  - Vitest passed: 605 tests across 82 files.
  - ESLint passed.
  - Next production build passed.
- `cd apps/petmagic-mobile && flutter test --no-pub`
  - All Flutter tests passed in the latest full run: 1142 tests.
- `cd apps/petmagic-mobile && flutter analyze`
  - No issues found.
- Focused preflight checks also passed:
  - 49 backend security/contract tests.
  - admin session Vitest file.
  - mobile auth/session tests.

## Residual Risks

- Private generated media and support/user media still need production validation against deployed storage/CDN behavior to confirm no stable direct URLs are exposed outside authorized API flows.
- Git history was scanned with fallback regex only because Gitleaks was unavailable locally. CI should run Gitleaks or an equivalent scanner on full history before production.
- Tracked Firebase config files must remain placeholders; real mobile Firebase config injection/release signing should be verified in the production build pipeline.
- Admin critical-action UX has regression coverage, but production should still verify role assignments, wallet adjustments, refunds, template publishing, and support actions against real admin accounts.
- Webhook signature/idempotency tests exist, but live provider webhook configuration, endpoint secrets, retry behavior, and event replay handling must be verified in Stripe/App Store/Google Play dashboards.

## Pre-Production Checklist

- Run Gitleaks or equivalent full-history scanner and rotate any real credentials if found.
- Verify production environment fails fast for missing/placeholder JWT, CORS, Stripe, store, AI provider, R2, SMTP, Firebase, and bootstrap admin secrets.
- Exercise payment flows against Stripe test mode and store sandboxes: checkout, payment intent, subscription activation, cancellation, failed invoice, duplicate webhook replay.
- Verify direct access to private media URLs after logout and from another account returns no private content.
- Verify mobile release builds use secure API base URLs and no dev URLs unless explicitly debug-gated.
- Verify deployed logs do not include tokens, receipts, raw webhook payloads, signed URLs, emails, or payment data.
