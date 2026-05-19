# PetMagic Mobile

Flutter iOS/Android client for PetMagic. The app starts with a production-oriented Templates feed: anonymous catalog browsing, light/dark themes, localization, API layer, caching, skeleton/loading/empty/error states, and a floating bottom navigation shell.

## Requirements

- Flutter 3.41+
- Dart 3.11+
- Backend API running locally at `http://localhost:5000`

## Run

```bash
flutter pub get
flutter gen-l10n
flutter run
```

For Android emulator, the app defaults to `http://10.0.2.2:5000` and also tries `http://host.docker.internal:5000` for Windows/Docker setups. For iOS simulator, it defaults to `http://localhost:5000`.

If you run on a physical Android device over USB, mirror your host port first:

```bash
adb reverse tcp:5000 tcp:5000
```

Then keep the default `http://127.0.0.1:5000` or pass it explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

Override the API URL when needed:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000
flutter run --dart-define=API_BASE_URL=https://api.petmagic.app
```

## External auth and password reset

Google sign-in uses the backend OAuth flow and returns to the app through the deep link `petmagic://auth/external`, which is already configured on Android and iOS.

For Google sign-in to work end-to-end:

- configure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` on the backend
- register the backend redirect URI `https://<your-api-host>/signin-google` in Google Cloud Console
- run the app against the same backend host via `API_BASE_URL`

Password reset emails are sent by the backend SMTP worker, so reset flow depends on valid backend email settings rather than any direct SMTP integration in Flutter.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
```

## Structure

```text
lib/
	app/                  App bootstrap, router, theme, generated localization
	core/                 Config, networking, errors, realtime abstractions
	features/templates/   Domain models, API/cache data sources, repository, state, UI
	shared/               Navigation shell and reusable app-level UI
```

Templates are loaded from `GET /api/templates/feed`; users can browse without authentication. Purchase, generation, creations, and profile flows are intentionally left as next-stage feature modules.
