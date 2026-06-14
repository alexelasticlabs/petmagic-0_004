# PetMagic Mobile, API, and Notifications Optimization Report

Date: 2026-06-13

## What Changed

- Mobile UI performance: added shared lightweight animated/interactive widgets, reusable async/image states, unified page transitions, and reduced duplicated loading/error UI in templates/auth/startup surfaces.
- Template media lifecycle: replaced per-card skeleton controller logic with shared image state widgets, kept video/image lifecycle tests green, and avoided unnecessary local media storage reads during generation status polling.
- Notifications: added `PushTokenRegistrar` with in-flight dedupe and successful-registration cache for FCM token registration across templates, support, and economy modules.
- Notification registration traffic: startup and notification settings now share the same push token registration path; repeated permission refreshes no longer resend the same three PUT requests when token/platform/locale/app version are unchanged.
- Notification interaction stability: foreground push still routes only to allowed internal destinations, uses dedupe keys, and presents through the unified in-app notification center.
- Lifecycle stability: fixed async guards for generation history delete, generation status load cancellation, media share cancellation, and polling during share/save actions.
- Android build config: removed explicit app-level Kotlin Android plugin usage so the app follows Flutter built-in Kotlin support.

## Backend/API Checks

- Verified auth, legal acceptance, wallet, template generations, support conversation, safe problem details, rate limits, push payload contracts, and module startup through the existing .NET test suite.
- Frontend/backend push token contracts remain compatible with current endpoints:
  - `PUT /api/templates/notifications/push-token`
  - `PUT /api/support/notifications/push-token`
  - `PUT /api/economy/notifications/push-token`
- No backend DTO contract change was required for this pass; optimization was client-side dedupe and lifecycle-safe request timing.

## Test Account

- Email: `qa.mobile@petmagic.local`
- Password: `TestMagic!2026`
- User id: `e071c31b-53c6-4aee-bdf9-46df3621d1d2`
- Status: `Active`
- Email confirmed: `true`
- Legal versions accepted: `2026-05-20`
- Wallet balance: `240` PawSpark
- Referral code: `QAMOBILE26`
- Seeded data:
  - Completed generation: `11111111-2222-4333-8444-555555555555`
  - Support conversation: `22222222-3333-4444-8555-666666666666`
  - Wallet ledger entries for initial QA grant and generation spend

## Verification

- `flutter analyze`: passed.
- `flutter test`: passed, 350 tests.
- `flutter build apk --debug`: passed, built `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build ios --simulator --debug`: passed, built `build/ios/iphonesimulator/Runner.app`.
- `dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --no-restore`: passed, 399 tests.
- API smoke with test account:
  - `POST /api/auth/login`: passed.
  - `GET /api/auth/me`: returned active confirmed user.
  - `GET /api/economy/wallet`: returned balance `240`.
  - `GET /api/templates/generations?take=5`: returned seeded generation.
  - `GET /api/support/conversation`: returned seeded conversation with 2 messages.

## Remaining Risks

- Physical iOS/Android manual walkthrough was not performed in this environment. Builds and automated tests passed, but final QA should still open the app on real/simulator devices and walk auth, templates, profile, wallet, support, settings, media, empty/loading/error states.
- Push notification background/closed-app delivery was verified by contract/tests and routing logic, not by sending live FCM notifications to physical devices.
- Flutter warns that some third-party plugins still apply Kotlin Gradle Plugin and `sign_in_with_apple` does not yet support Swift Package Manager. Current builds pass, but these warnings should be tracked during dependency upgrades.
