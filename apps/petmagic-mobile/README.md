# PetMagic Mobile

Flutter iOS/Android client for PetMagic. The app starts with a production-oriented Templates feed: anonymous catalog browsing, light/dark themes, localization, API layer, caching, skeleton/loading/empty/error states, and a floating bottom navigation shell.

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
flutter run --dart-define=API_BASE_URL=https://api.petmagic.app
```

## Release Hardening Checklist

- Always pass HTTPS API endpoint in release builds:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.petmagic.app
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
- For local packaging/R8/resource experiments only, bypass signing with direct
  Gradle from `apps/petmagic-mobile/android`:

```bash
./gradlew :app:bundleRelease -PallowInsecureReleaseSigning=true
```

Do not use the insecure override for production artifacts. It signs with the
debug key only to prove the release packaging pipeline.

## External auth and password reset

Google and Apple sign-in use native provider SDKs and send provider tokens to the backend for validation.
Tracked Firebase files in this repository are placeholders only. For local or CI mobile builds, inject environment-specific Firebase config outside git:

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

See the full setup guide in [../../docs/md/AUTH_EMAIL_SETUP.md](../../docs/md/AUTH_EMAIL_SETUP.md).

## Checks

```bash
dart format lib test
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
	app/                  App bootstrap, router, theme, generated localization
	core/                 Config, networking, errors, realtime abstractions
	features/templates/   Domain models, API/cache data sources, repository, state, UI
	shared/               Navigation shell and reusable app-level UI
```

Templates are loaded from `GET /api/templates/feed`; users can browse without authentication. Feed pagination uses the `nextCursor` value from the previous response as the next request's `cursor` query parameter. Malformed or hand-built cursors are rejected by the backend with `400` and `templates.invalid_cursor`.

Authenticated areas are implemented as separate feature modules for profile, pets, premium purchases, template generation, gallery/creations, notifications, achievements, and support. Keep new user flows inside the relevant feature folder and route backend access through the existing repository/data-source layer instead of calling HTTP directly from widgets.
