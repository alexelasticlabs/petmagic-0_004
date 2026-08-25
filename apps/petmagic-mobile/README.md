# PetMagic Mobile

Flutter iOS/Android client for PetMagic. The app starts with a production-oriented Templates feed: anonymous catalog browsing, light/dark themes, localization, API layer, caching, skeleton/loading/empty/error states, and a floating bottom navigation shell.

## Vendored plugins

`third_party/flutter_plugins` intentionally contains the source roots of
`app_links`, `sign_in_with_apple`, and `photo_manager`: `pubspec.yaml` uses
them as pinned `path` dependencies for reproducible mobile builds. They are not
generated artifacts and must not be removed during cleanup. Upstream demo apps
are intentionally excluded because PetMagic does not build or test them.

## Requirements

- Flutter 3.41+
- Dart 3.11+
- Backend API running locally. The mobile debug resolver probes local port
  `5000` first and Compose default port `5001` as fallback.

## Run

```bash
flutter pub get
flutter gen-l10n
flutter run
```

For Android emulator, the app probes `http://10.0.2.2:5000` first and
`http://10.0.2.2:5001` as fallback. For iOS simulator and desktop debug runs,
it probes `http://localhost:5000` first and `http://localhost:5001` as fallback.

If you run on a physical Android device over USB, mirror the host backend port
first. Use `5000` for the VS Code USB profile or a manually started backend on
port `5000`:

```bash
adb reverse tcp:5000 tcp:5000
```

Then keep the default `http://127.0.0.1:5000` or pass it explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

If you use Docker Compose with the default `BACKEND_HOST_PORT=5001`, mirror and
pass port `5001` instead:

```bash
adb reverse tcp:5001 tcp:5001
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

Override the API URL when needed:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000
flutter run --dart-define=API_BASE_URL=http://localhost:5001
flutter run --dart-define=API_BASE_URL=https://api.petgpt.app
```

## Architecture

The mobile client uses a lean Clean Architecture that is intentionally easy to
evolve with small, reviewable changes:

- `app/` is the composition root: `GoRouter`, app lifecycle, push/deep-link
  orchestration and session-scope invalidation live here. It may depend on
  features.
- `core/` contains cross-cutting contracts and infrastructure: auth session,
  networking, logging, realtime, configuration and platform adapters. It must
  not import `features/`.
- `features/<name>/` owns a product capability. Complex capabilities use
  `domain/`, `application/`, `data/` and `presentation/`; simple ones are not
  artificially split. A feature may consume another feature only through its
  public `application/` or `domain/` API. Direct cross-feature imports from
  `data/` and `presentation/` are forbidden.
- `shared/` contains reusable UI and utilities without product-flow ownership.

For feature data access, `application/` owns the repository/gateway/storage
port and its Riverpod provider token. `data/` owns the concrete implementation.
`app/composition/mobile_provider_overrides.dart` is the only production place
that binds these tokens. Controllers and feature UI never instantiate a Dio,
Firebase, SharedPreferences, store-purchase or SignalR implementation.

The navigation contract (`AppNavigator` and typed `AppDestination` values)
lives in `core/navigation`; the GoRouter adapter and feature-aware shell live in
`app/router` and `app/shell`. Shared widgets and layout helpers never import a
feature module.

The primary task-first information architecture is `Discover / Create /
Creations / Rewards / Profile`. `/templates` remains the compatible Discover
route, while `/create` is the guided entry point that preserves a guest's
creation intent through authentication. Existing generation, notification and
deep-link routes remain stable.

The Premium Playful design system lives in `app/theme`: semantic color and
typography themes are separated from spacing, radius, breakpoint, motion and
accessibility tokens. Reusable production surfaces live in `shared/widgets`.
Feature pages consume these tokens instead of defining local visual scales.

Auth session JSON and the secure-storage key are a compatibility contract.
Repositories depend on `AuthSessionStore`, while `AuthSessionStorage` remains
the production implementation. Push and deep links navigate via typed
`AppDestination` values through `AppNavigator`; route strings remain internal
to the router boundary.

`test/mobile_architecture_test.dart` enforces every layer direction, keeps
domain code framework-independent, rejects `GoRouter` in feature/shared UI,
checks the app composition bindings, and prevents new production files over
600 lines. Target ownership limits are 400 lines for app/core/application/data/
domain code and 500 lines for presentation/shared UI. Existing files above
either target are explicit, exact frozen debt sets: entries may be removed as
responsibilities are extracted, but new entries are not accepted. The same test
also guards concrete `AuthSessionStorage` usage and app-owned push/session
orchestration. UI quality gates include a `320×568` viewport, 200% system text
scaling, button semantics, a deterministic compact welcome golden, and a
1000+ item feed stress test that runs on an Android emulator in CI.
Create reference screens additionally keep light/dark golden baselines for
compact, phone and tablet viewports. The golden harness loads the real Material
Icons font so missing glyphs cannot be accepted as a visual baseline.

## Release Hardening Checklist

- Every release build must target an explicit flavor and provide the matching
  environment contract. A production build also requires real Firebase config
  injected outside Git and protected release signing material:

```bash
flutter build appbundle --release --flavor production \
  --dart-define=APP_ENVIRONMENT=production \
  --dart-define=APP_PACKAGE_NAME=com.petmagic.app \
  --dart-define=API_BASE_URL=https://api.petgpt.app \
  --obfuscate --split-debug-info=build/symbols/production
```

- Configure release signing by copying
  `android/key.properties.example` to `android/key.properties` and replacing
  every placeholder. Do not commit `android/key.properties`, keystores, or
  password material.

```properties
storeFile=../keystore/release.keystore
storePassword=CHANGE_ME
keyAlias=CHANGE_ME
keyPassword=CHANGE_ME
```

- Release tasks fail fast if signing is missing. This is expected on machines
  without production signing material and must remain a blocker for store
  artifacts.
- CI assigns a unique store build number from `GITHUB_RUN_NUMBER` and rejects a
  staging AAB that grows by more than 5% from the recorded release baseline.
- `ios/Runner/PrivacyInfo.xcprivacy` is bundled in the Runner target. Before an
  App Store submission, generate Xcode's privacy report and reconcile it with
  App Store Connect privacy answers and the current backend/privacy policy.
- For local packaging/R8/resource experiments only, use the same explicit
  staging contract as CI. Generate placeholder Firebase configuration first;
  it is ignored by Git and must never be used for provider E2E or store rollout:

```bash
dart run tool/configure_firebase_smoke.dart --environment=staging
flutter build appbundle --release --flavor staging \
  --android-project-arg=allowInsecureReleaseSigning=true \
  --android-project-arg=allowPlaceholderFirebase=true \
  --dart-define=APP_ENVIRONMENT=staging \
  --dart-define=APP_PACKAGE_NAME=com.petmagic.app.staging \
  --dart-define=API_BASE_URL=https://api.staging.petgpt.app \
  --obfuscate --split-debug-info=build/symbols/staging
```

Do not use either insecure override for production artifacts. They sign with
the debug key and permit placeholder Firebase configuration only to prove the
release packaging pipeline.

## External auth and password reset

Google and Apple sign-in use native provider SDKs and send provider tokens to the backend for validation.
Firebase templates are tracked, but active Firebase configuration is injected
outside Git for local, CI, and release builds:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Do not commit real Firebase API keys, Google OAuth client IDs, signing keystores, or backend OAuth secrets.

For Google sign-in to work end-to-end:

- configure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` on the backend using the Google Web application client
- optionally configure `GOOGLE_AUDIENCES` as comma-separated Web/iOS/Android OAuth client IDs for the current environment
- create a separate Android OAuth client for `com.petmagic.app`
- create a separate iOS OAuth client for `com.petmagic.app`
- run the app against the same backend host via `API_BASE_URL`

For Apple sign-in to work end-to-end:

- enable Sign in with Apple on the iOS Bundle ID
- configure backend `APPLE_CLIENT_ID`, `APPLE_CLIENT_SECRET`, and optionally `APPLE_AUDIENCES`
- use separate dev/stage/prod Apple credentials and keep private keys out of git

Password reset emails are sent by the backend SMTP worker, so reset flow depends on valid backend email settings rather than any direct SMTP integration in Flutter.

See the full setup guide in [../../docs/auth-email-setup.md](../../docs/auth-email-setup.md).

## Checks

```bash
dart format lib test integration_test
flutter analyze --fatal-infos
flutter test
```

Localization and light/dark theme rules for the mobile app are part of the
repo-wide guide at [../../docs/localization-and-theme.md](../../docs/localization-and-theme.md).
Run `flutter gen-l10n` after ARB changes and keep all supported ARB files in
key parity.

## Structure

```text
lib/
  app/                  Composition root, router, shell, lifecycle orchestration
  core/                 Cross-cutting contracts and infrastructure
  features/<name>/      Domain, application API, data implementation, presentation
  shared/               Feature-independent UI and utilities
```

Templates are loaded from `GET /api/templates/feed`; users can browse without authentication. Feed pagination uses the `nextCursor` value from the previous response as the next request's `cursor` query parameter. Malformed or hand-built cursors are rejected by the backend with `400` and `templates.invalid_cursor`.

Authenticated areas are implemented as separate feature modules for profile, pets, premium purchases, template generation, gallery/creations, notifications, achievements, and support. Keep new user flows inside the relevant feature folder and route backend access through the existing repository/data-source layer instead of calling HTTP directly from widgets.
