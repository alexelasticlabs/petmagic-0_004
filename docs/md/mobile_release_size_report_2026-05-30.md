# Mobile Release Size Audit Report (2026-05-30)

> Historical size-audit snapshot. This file preserves the May 2026 artifact
> measurements and dependency cleanup notes. For the current release-size status,
> use `docs/md/mobile_release_size_audit.md` and
> `docs/production-readiness-audit-2026-07-03.md`.

Project: `apps/petmagic-mobile`

## Build Artifacts (release)

- AAB: `build/app/outputs/bundle/release/app-release.aab` = **45.84 MB**
- APK (arm64 split): `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` = **43.93 MB**

## Size Breakdown

- Flutter assets total: **~17.25 MB**
- Declared project assets (`assets/*.png`): **13.78 MB**
- Native libs (arm64, stripped): **20.55 MB**
  - `libflutter.so`: 10.79 MB
  - `libapp.so`: 9.63 MB
  - `libdartjni.so`: 0.12 MB

## Major Contributors

- PNG assets in `assets/auth`, `assets/branding`, `assets/rewards`.
- Native binaries (`libflutter.so`, `libapp.so`).

## Release Configuration Status

- Release build is now passing with R8/proguard integration.
- Added `android/app/proguard-rules.pro` and wired it in `android/app/build.gradle.kts`.
- `missing_rules.txt` is not generated anymore in current release build.

## Dependency Cleanup Completed

Removed unused direct dependencies:

- `flutter_animate`
- `skeletonizer`
- `lucide_icons_flutter`

Kept:

- `cupertino_icons` (retained for compatibility with icon font expectations during tree-shake stage).

## Notes

- A `flutter analyze` info-level warning remains outside this scope:
  - `lib/features/premium/presentation/subscription_management_page.dart:664`
  - `curly_braces_in_flow_control_structures`

## Next Size-Reduction Actions

1. Re-encode the heaviest PNG assets (lossless/lossy tuned) and cap long edge dimensions per screen usage.
2. Move large non-critical visuals to network-delivered CDN assets where product-acceptable.
3. Keep publishing through AAB; use split APKs only for local/device distribution and QA.
