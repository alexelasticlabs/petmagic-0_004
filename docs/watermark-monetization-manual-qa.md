# Watermark Monetization Manual QA

This checklist verifies the free, premium, and paid-unlock watermark flows on mobile, backend, and admin surfaces.

## Prerequisites

- Backend API is running and reachable from devices.
  Use the host port configured by `BACKEND_HOST_PORT` in the repo root `.env`.
- iOS simulator base URL: `API_BASE_URL=http://localhost:<BACKEND_HOST_PORT>`
- Android emulator base URL: `API_BASE_URL=http://10.0.2.2:<BACKEND_HOST_PORT>`
- Generation worker is running with watermark rendering enabled.
- Test accounts:
  - Free user with at least 1 credit
  - Free user with 0 credits
  - Premium user
  - Admin user
- Test results:
  - Completed image generation with original and watermarked copy
  - Completed video generation with original and watermarked copy
  - Completed free result where original exists but watermarked copy is temporarily missing
- Admin watermark settings are configured:
  - enabled
  - text `Made with PetMagic` or `PetMagic`
  - opacity between 45% and 65%
  - position `bottom-right`
  - size `small`
  - cost `1` credit
  - apply to image and video

## Optional Local Seed Helper

For local manual QA, first create or identify three existing Identity users:

- Free user with credits.
- Free user with 0 credits.
- Premium user.

To create local QA users and tokens automatically against a running backend:

```bash
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> \
DATABASE_URL="$DATABASE_URL" \
WATERMARK_QA_PASSWORD="<unique-local-qa-password>" \
scripts/qa/prepare-watermark-qa-users.mjs
```

If Docker maps Postgres to a host port that conflicts with a local Postgres, use the Docker `psql` wrapper:

```bash
WATERMARK_QA_PSQL_COMMAND=scripts/qa/psql \
DATABASE_URL=postgresql://petmagic_user:unused@docker/petmagic_db \
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> \
WATERMARK_QA_PASSWORD="<unique-local-qa-password>" \
scripts/qa/prepare-watermark-qa-users.mjs
```

From Windows PowerShell, use `WATERMARK_QA_PSQL_COMMAND=scripts\qa\psql.cmd` for the same Docker-backed `psql` wrapper.

Use a fresh local-only password for each QA run. The helper does not provide a default password because the generated env file includes that password alongside user IDs, emails, and access tokens. Load `artifacts/watermark-qa-users.env` before the seed and backend smoke commands:

```bash
set -a
source artifacts/watermark-qa-users.env
set +a
```

Then prepare local media fixtures for image and video checks. On macOS, the helper uses `sips` for images and Swift/AVFoundation for short synthetic MP4 files:

```bash
scripts/qa/prepare-watermark-manual-qa-media.sh
```

On Windows and Linux, the preflight runner records this media step as skipped instead of failing on the macOS-only helper. For full manual QA on those hosts, place equivalent files under `src/Host/PetMagic.Host.Api/wwwroot/templates-media/manual-qa/` or provide real playable MP4 files from another machine.

To use your own video files instead of generated synthetic fixtures, provide real playable MP4 files and rerun the helper:

```bash
WATERMARK_QA_VIDEO_CLEAN=/path/to/clean.mp4 \
WATERMARK_QA_VIDEO_WATERMARKED=/path/to/watermarked.mp4 \
scripts/qa/prepare-watermark-manual-qa-media.sh
```

Then seed database rows:

```bash
"${WATERMARK_QA_PSQL_COMMAND:-psql}" "$DATABASE_URL" \
  -v free_user_id="'$FREE_USER_ID'" \
  -v no_credit_user_id="'$NO_CREDIT_USER_ID'" \
  -v premium_user_id="'$PREMIUM_USER_ID'" \
  -v public_base_url="'http://localhost:<BACKEND_HOST_PORT>'" \
  -f scripts/qa/seed-watermark-manual-qa.sql
```

If you already have access tokens for the same three users, run the backend smoke check before the mobile walkthrough:

```bash
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> \
DATABASE_URL="$DATABASE_URL" \
FREE_USER_ID="$FREE_USER_ID" \
NO_CREDIT_USER_ID="$NO_CREDIT_USER_ID" \
PREMIUM_USER_ID="$PREMIUM_USER_ID" \
FREE_TOKEN="$FREE_TOKEN" \
NO_CREDIT_TOKEN="$NO_CREDIT_TOKEN" \
PREMIUM_TOKEN="$PREMIUM_TOKEN" \
scripts/qa/run-watermark-backend-qa.mjs
```

Use a premium user's token issued after premium status is enabled. If premium was granted after login, log in again before running the smoke check.

Optional admin coverage:

```bash
ADMIN_TOKEN="<admin-access-token>" scripts/qa/run-watermark-backend-qa.mjs
```

The smoke runner writes redacted evidence to `artifacts/watermark-backend-qa-evidence.json` by default. Override with `WATERMARK_QA_EVIDENCE_PATH=/path/to/evidence.json`.
Run `scripts/qa/run-watermark-backend-qa.mjs --help` to print required environment variables without writing evidence or touching the database.

To run the local fixture prep, backend smoke, and Flutter integration smoke as one preflight:

```bash
set -a
source artifacts/watermark-qa-users.env
set +a

WATERMARK_QA_ANDROID_DEVICE=emulator-5554 \
WATERMARK_QA_IOS_DEVICE="<ios-simulator-or-device-id>" \
WATERMARK_QA_SKIP_FIREBASE=1 \
scripts/qa/run-watermark-preflight-qa.mjs
```

The preflight runner writes `artifacts/watermark-preflight-qa-evidence.json`. Missing backend env or device IDs are recorded as skipped checks, so use `WATERMARK_QA_STRICT=1` when the run must fail on any skipped step. The preflight does not replace the manual iOS and Android walkthrough below; attach its evidence file to the final manual QA table.
Run `scripts/qa/run-watermark-preflight-qa.mjs --help` to inspect all options without creating an evidence file.

If Android is not already booted, the runner can launch an AVD and wait for `adb` readiness:

```bash
WATERMARK_QA_ANDROID_EMULATOR=petmagic_api35 \
WATERMARK_QA_AUTO_DEVICES=1 \
WATERMARK_QA_SKIP_FIREBASE=1 \
scripts/qa/run-watermark-preflight-qa.mjs
```

The AVD launch uses headless-safe defaults: `-no-window -no-audio -gpu swiftshader_indirect -no-boot-anim`. Add extra emulator flags with `WATERMARK_QA_ANDROID_EMULATOR_ARGS`; the emulator log defaults to `/tmp/petmagic_watermark_android_emulator.log`.

`WATERMARK_QA_SKIP_FIREBASE=1` passes `--dart-define=PETMAGIC_SKIP_FIREBASE=true` so local QA can run with placeholder Firebase files. Use real Firebase config and omit this flag for production-like push-notification checks.

Keep placeholder Firebase API keys syntactically valid locally, using the `AIza` prefix plus a non-secret filler of the expected length, so native Firebase validation does not abort simulator startup before Dart runs. Do not commit literal Firebase API-key-shaped values to docs.

If Flutter device discovery or a device run hangs, use explicit device IDs and adjust `WATERMARK_QA_DEVICE_DISCOVERY_TIMEOUT_MS` or `WATERMARK_QA_COMMAND_TIMEOUT_MS`. For iOS Swift Package Manager state issues, use `WATERMARK_QA_IOS_RESOLVE_PACKAGES=1`; if a local Flutter setup needs the CocoaPods path, set `flutter config --no-enable-swift-package-manager` before the run and record that in the evidence notes.

Use a `public_base_url` that the tested device can open:

- iOS simulator: `http://localhost:<BACKEND_HOST_PORT>`
- Android emulator: `http://10.0.2.2:<BACKEND_HOST_PORT>`
- Both platforms in one seed: a LAN host/IP URL reachable from both devices

The script seeds wallet balances, watermark settings, and deterministic generation rows:

- `50000000-0000-4000-8000-000000000001`: free image with watermark.
- `50000000-0000-4000-8000-000000000002`: free video with watermark.
- `50000000-0000-4000-8000-000000000003`: no-credit image with watermark.
- `50000000-0000-4000-8000-000000000004`: premium image with watermark source data for clean-access checks.
- `50000000-0000-4000-8000-000000000005`: free preparing state with original but no watermarked copy.

The seeded media URLs point to `/templates-media/manual-qa/...` under the chosen `public_base_url`. For local storage, the helper writes matching files under `src/Host/PetMagic.Host.Api/wwwroot/templates-media/manual-qa/`. For R2, upload the generated or custom files under the same `templates-media/manual-qa/` key prefix.

## Mobile: Free User With Credits

Run on both iOS and Android.

1. Sign in as the free user with credits.
2. Open a completed image result.
3. Verify the result media is watermarked.
4. Verify the message says the watermark was added on the free plan.
5. Open the result action menu.
6. Verify actions:
   - Save/share with watermark.
   - Remove watermark.
   - Upgrade to Premium.
7. Tap Remove watermark.
8. Verify the bottom sheet offers:
   - Use 1 credit.
   - Upgrade to Premium.
9. Choose Use 1 credit.
10. Verify success state:
    - Watermark removed message.
    - Clean media is shown.
    - Download without watermark is available.

11. Repeat the remove/unlock request if reachable through refresh or retry.
12. Verify credits are not charged a second time.
13. Open the same result after app restart.
14. Verify clean access persists for that result.

## Mobile: Free User Without Credits

Run on both iOS and Android.

1. Sign in as the free user with 0 credits.
2. Open a completed watermarked result.
3. Tap Remove watermark.
4. Choose Use 1 credit.
5. Verify the no-credits sheet offers:
   - Buy credits.
   - Upgrade to Premium.
6. Verify the error path does not expose a clean URL.

## Mobile: Premium User

Run on both iOS and Android.

1. Sign in as the premium user.
2. Open completed image and video results.
3. Verify clean media is shown.
4. Verify watermark controls are absent.
5. Verify actions:
   - Save.
   - Share.
   - Download or save clean result, according to media type.
   - Generate similar/again where supported.
6. Remove premium status or sign in as the same user after expiry.
7. Verify new downloads without a paid unlock return the watermarked copy.
8. Verify previously credit-unlocked results remain clean.

## Mobile: Watermark Preparing State

Run on both iOS and Android.

1. Open a completed free result where the original exists but the watermarked copy is not ready.
2. Verify the app shows a preparing-result message.
3. Verify clean download/share/save actions are not available.
4. When the watermarked copy becomes available, refresh.
5. Verify the watermarked result is shown.

## Visual Watermark Checks

Run for image and video on at least one iOS and one Android viewport.

1. Verify the watermark is in the bottom-right corner by default.
2. Verify opacity is visibly semi-transparent, about 45% to 65%.
3. Verify the badge is small and does not dominate the image.
4. Verify it does not critically cover the pet face.
5. For video, verify the watermark is visible for the full duration.
6. For video, verify badge width is no more than 8% of frame width.
7. Verify 9:16, 1:1, and 16:9 video frames keep the badge in a sensible corner position.

## Backend API Checks

Use authenticated requests for each test user.

1. `GET /api/generations/{id}`
   - Free without unlock returns watermarked `mediaUrl`, `hasWatermark=true`, `canRemoveWatermark=true`, `userPlan=free`.
   - Premium returns clean `mediaUrl`, `hasWatermark=false`, `userPlan=premium`.
   - Credit-unlocked free result returns clean `mediaUrl`, `isWatermarkRemoved=true`.
2. `POST /api/generations/{id}/remove-watermark`
   - First credit unlock spends 1 credit and returns clean signed URL.
   - Repeated request returns existing unlock and does not spend credits again.
3. `GET /api/generations/{id}/download`
   - Free without unlock returns watermarked media.
   - Premium returns clean media.
   - Credit/admin/promo unlock returns clean media.
4. Cross-user access:
   - A user cannot fetch, download, share, or unlock another user's result.
5. Clean URL security:
   - Free users without unlock never receive the original media path or clean signed URL.
   - Signed URLs are short-lived.

## Admin Checks

1. Open Monetization -> Watermark.
2. Verify settings are editable:
   - enabled
   - text
   - logo
   - opacity
   - position
   - size
   - cost in credits
   - apply to image/video
3. Verify image and video-frame previews update after settings changes.
4. Open the generation list/card.
5. Verify watermark status, unlock actor, unlock time, method, and credits are visible.
6. Use Grant clean download as Admin.
7. Verify the result receives clean access without charging credits.
8. Verify non-admin users cannot access watermark settings or grant-clean endpoints.

## Analytics Checks

Verify events are recorded with `generationId`, `templateId`, `mediaType`, `userPlan`, `unlockMethod`, and `creditsSpent` when applicable.

- `result_viewed`
- `remove_clicked`
- `paywall_viewed`
- `removed_credit`
- `removed_premium`
- `download_watermarked`
- `download_clean`
- `share_watermarked`
- `share_clean`

## Evidence Template

| Area                           | iOS result | Android result | Evidence |
| ------------------------------ | ---------- | -------------- | -------- |
| Free watermarked result        |            |                |          |
| Remove watermark bottom sheet  |            |                |          |
| Credit unlock, no double spend |            |                |          |
| No-credit path                 |            |                |          |
| Premium clean result           |            |                |          |
| Preparing state                |            |                |          |
| Image watermark visual         |            |                |          |
| Video watermark visual         |            |                |          |
| Download/share version routing |            |                |          |
| Admin settings and preview     |            |                |          |
| Admin grant clean              |            |                |          |
| Analytics events               |            |                |          |
