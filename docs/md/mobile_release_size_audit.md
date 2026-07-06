# PetMagic Mobile: Release Size Audit Runbook

## Scope

Release-only audit for Android size drivers:

- `assets` (images, videos, fonts)
- native `.so` libraries
- ABI split / App Bundle configuration
- debug/mock/test/smoke files leaking into release
- potentially unused direct dependencies

## Prerequisites

- Flutter SDK installed
- Run from the repository root.

## 1) Run automated audit script

```powershell
pwsh -File .\scripts\audit_mobile_release_size.ps1
```

## 2) Build release artifacts for baseline

Use release mode only. Production store artifacts require real release signing
through `apps/petmagic-mobile/android/key.properties`.

```powershell
cd .\apps\petmagic-mobile
flutter clean
flutter pub get
flutter build appbundle --release --target-platform android-arm64 --analyze-size
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

If release signing is not available on the audit machine, run a packaging-only
R8/resource check from `apps/petmagic-mobile/android` instead:

```powershell
.\gradlew.bat :app:bundleRelease -PallowInsecureReleaseSigning=true --warning-mode all
```

This bypass is not a production artifact. It signs with the debug key only to
prove the release packaging pipeline.

## 3) Current release state

The old 2026-05-30 R8 blocker for Stripe push provisioning missing classes is no
longer current. The 2026-07-03 release-hardening pass verified that
`:app:bundleRelease` completes successfully with the explicit local insecure
signing override. The remaining blocker for production store artifacts is real
release signing material, not R8 missing classes.

If `build/app/outputs/mapping/release/missing_rules.txt` appears in a future
run, treat it as a new regression and capture it in the release report.

## 4) Required report output

Capture and store:

- Total release artifact sizes (`.aab`, split `.apk`)
- Asset breakdown by extension + top largest files
- Native libs breakdown per ABI + top libs
- ABI/App Bundle settings found in Gradle config
- Debug/mock/smoke candidates that could impact release
- Shortlist of potentially unused direct dependencies (manual validation required)

## 5) Acceptance checklist

- Baseline is built from **release** artifacts only.
- AAB and split APK sizes are recorded.
- Top size contributors are identified (assets + native libs + deps).
- At least one concrete size reduction action item is proposed per contributor class.
- Runtime cache behavior is unchanged except centralized limits.
