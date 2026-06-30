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
- Run from repository root: `D:\Flutter\project\petmagic-0_004`

## 1) Run automated audit script

```powershell
pwsh -File .\scripts\audit_mobile_release_size.ps1
```

## 2) Build release artifacts for baseline

Use release mode only.

```powershell
cd .\apps\petmagic-mobile
flutter clean
flutter pub get
flutter build appbundle --release --target-platform android-arm64 --analyze-size
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## 3) Current blocker (must be fixed first)

As of 2026-05-30, release build fails in R8 due to Stripe push provisioning missing classes.
Source: `build/app/outputs/mapping/release/missing_rules.txt`.

Until this R8 issue is fixed, final install-size baseline is not reliable.

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
