# Localization And Theme Guide

This guide defines the current PetMagic localization and light/dark theme rules
for mobile, admin web, and backend/API contracts.

## Supported Locales

Mobile currently supports these locales through Flutter gen-l10n:

- `ru`
- `en`
- `de`
- `es`
- `fr`
- `it`
- `pl`

The source of truth must stay consistent across:

- `apps/petmagic-mobile/lib/l10n/app_*.arb`
- `apps/petmagic-mobile/lib/app/app.dart`
- `apps/petmagic-mobile/lib/app/localization/generated/app_localizations.dart`
- `apps/petmagic-mobile/lib/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart`

There are no supported RTL locales today. If an RTL locale is added later, the
change must include layout-direction QA and widget coverage for navigation,
forms, dialogs, bottom sheets, media grids, and overflow-prone controls.

Admin web currently supports:

- `ru`
- `en`

Backend user-facing notification/email helpers must stay aligned with the
mobile locale set when the message is sent directly to a user. Legal document
body copy is currently approved only for `ru` and `en`; do not add or machine
translate legal policy text without product/legal approval.

## Mobile Localization

Mobile localization source files live in:

- `apps/petmagic-mobile/lib/l10n/app_en.arb`
- `apps/petmagic-mobile/lib/l10n/app_ru.arb`
- `apps/petmagic-mobile/lib/l10n/app_de.arb`
- `apps/petmagic-mobile/lib/l10n/app_es.arb`
- `apps/petmagic-mobile/lib/l10n/app_fr.arb`
- `apps/petmagic-mobile/lib/l10n/app_it.arb`
- `apps/petmagic-mobile/lib/l10n/app_pl.arb`

Generation is configured by `apps/petmagic-mobile/l10n.yaml`. The template file
is `app_en.arb`. Generated files are written under
`apps/petmagic-mobile/lib/app/localization/generated/` and must not be edited by
hand. Missing translations are reported to
`apps/petmagic-mobile/lib/l10n/untranslated_messages.txt` by Flutter gen-l10n.

When adding or changing mobile copy:

1. Add the key to `app_en.arb` first.
2. Add the same key to every other supported ARB file.
3. Use Flutter placeholders and plural/select syntax instead of string
   concatenation.
4. Format dates, numbers, currencies, and percentages through `intl` with
   `Localizations.localeOf(context).toLanguageTag()` or the active generated
   locale, not with manual string formatting.
5. Run `flutter gen-l10n`.
6. Confirm `lib/l10n/untranslated_messages.txt` is absent or empty.
7. Run `flutter analyze --fatal-infos` and relevant widget/source tests.

Mobile app locale selection is stored by
`apps/petmagic-mobile/lib/app/preferences/app_preferences_storage.dart` under
`petmagic_mobile_locale` and applied by `MaterialApp` through the generated
`AppLocalizations.supportedLocales`. Theme selection is stored in the same
storage class under `petmagic_mobile_theme_mode`.

Mobile fallback behavior:

- a saved user locale wins over the system locale;
- unsupported system locales fall back to English;
- region variants match by language code when the base language is supported;
- the settings screen can clear the explicit locale only if the UI exposes a
  system/default option for that behavior.

Useful mobile localization checks:

```bash
cd apps/petmagic-mobile
flutter gen-l10n
flutter test test/localization_brand_copy_test.dart
flutter test test/template_flow_localization_test.dart
flutter test test/auth_feedback_mapper_test.dart
```

Use source tests for guardrails such as ARB key parity, removed legacy keys,
brand/payment wording, and error-code mapping. Use widget or device tests for
layout proof; source tests alone do not prove text fit or contrast.

## Admin Web Localization

Admin dictionaries live in:

- `apps/admin-web/src/lib/i18n.ts`
- `apps/admin-web/src/lib/i18n.ru.ts`
- `apps/admin-web/src/lib/i18n.en.ts`
- `apps/admin-web/src/lib/i18n.types.ts`

Routes are locale-scoped under `apps/admin-web/src/app/[locale]`. Add new admin
UI copy through the typed dictionary contract, not inline in components. Keep
RU/EN key parity intact and run the i18n tests after dictionary edits. The
current admin default locale is `ru`.

Useful admin localization checks:

```bash
cd apps/admin-web
npm test -- src/lib/i18n.test.ts src/lib/i18n-ru-copy.test.ts src/components/admin-shell-localization.test.ts
```

Admin is intentionally a two-locale surface today. Do not infer the seven
mobile locales for admin unless product requirements explicitly expand the admin
audience.

## Backend API And User-Facing Messages

API errors that can reach mobile or admin UI must expose stable machine-readable
codes, not raw service exception text. The frontend maps those codes to
localized user-facing copy.

Backend rules:

- Use stable error codes in `ProblemDetails.title` and `ProblemDetails`
  extension `code` where the endpoint helper supports it.
- Keep `ProblemDetails.detail` generic and safe.
- Do not return provider payloads, stack traces, secrets, raw validation
  internals, or raw `Error.Message` values to users.
- Validation errors should use stable codes where the client presents them.
  Current code-based validation families include profile avatar uploads,
  external-auth ticket exchange, template source images, admin template media
  uploads, admin economy incident actions, support attachments, and application
  validators in Identity, Economy, Templates, and Support Chat.
  FluentValidation default failures are serialized as generic `validation.*`
  codes instead of framework-generated English sentences.
- Push notifications and email templates that are sent directly by the backend
  must localize against the saved or requested user locale and fall back
  predictably to English.
- Legal document body text must use approved legal copy. Current approved
  catalog coverage is `ru` and `en`.

Frontend rules:

- mobile maps auth/profile/payment/generation/support error codes through
  localized mappers or generated `AppLocalizations`;
- admin maps API failure states through `Dictionary` strings;
- raw backend `detail` is for safe support context, not primary user copy;
- unknown codes must fall back to a localized generic message.

Contract changes that affect visible error behavior must update backend tests,
mobile/admin error mapping tests, and `docs/API_CONTRACTS.md` when the API shape
changes.

## Theme Sources

Mobile theme tokens live in:

- `apps/petmagic-mobile/lib/app/theme/app_theme.dart`

Admin theme tokens live in:

- `apps/admin-web/src/app/globals.css`
- `apps/admin-web/src/lib/theme.ts`

Theme selection must respect the system setting by default and preserve manual
user choice when the product surface offers a manual selector. Mobile uses
`ThemeMode.system`, `ThemeMode.light`, and `ThemeMode.dark`; admin stores
`petmagic_admin_theme` in `localStorage` and applies it through
`document.documentElement.dataset.theme`.

## Theme Rules

Do not hardcode one-off UI colors in screens or components. Use the active
theme, color scheme, PetMagic color extensions, CSS variables, or established
design tokens.

For text or icons on custom mobile token backgrounds, use
`context.petMagicColors.on(background)` or `Theme.of(context).colorScheme`
foregrounds instead of assuming white or black contrast.

Allowed direct colors are limited to cases with a stable semantic reason, such
as transparent overlays, image processing masks, test fixtures, or assets where
the color is intrinsic to the asset. New direct colors in user-facing UI need a
reviewable reason.

Required states for new or touched screens:

- loading
- empty
- error
- disabled
- selected/unselected
- success/warning/error/info where applicable

Text must remain readable in both light and dark mode, including dialogs,
bottom sheets, cards, nav surfaces, forms, skeletons, and toast/snackbar
surfaces.

When touching a screen, test the longest supported translations in compact
widths. Prefer flexible layout constraints, wrapping, scroll affordances, and
semantic typography over shrinking text until it becomes unreadable.

Useful theme checks:

```bash
cd apps/petmagic-mobile
flutter test test/app_theme_test.dart
flutter test test/shared_ui_performance_regression_test.dart
```

```bash
cd apps/admin-web
npm test -- src/lib/theme.test.ts src/components/admin/admin-primitives.test.ts
```

## Verification

Minimum local checks after localization or theme changes:

```bash
cd apps/petmagic-mobile
flutter gen-l10n
flutter analyze --fatal-infos
flutter test
```

```bash
cd apps/admin-web
npm run lint
npm run typecheck
npm test
npm run build
```

```bash
dotnet test PetMagic.slnx --disable-build-servers -m:1 /nr:false -p:UseSharedCompilation=false
```

For release proof, add device or browser evidence across:

- English light/dark
- Russian light/dark
- every supported mobile locale light/dark for mobile-only flows
- admin `ru` and `en` light/dark for admin-only flows
- small, medium, and large viewport/screen sizes
- Android
- iOS when available

Minimum screen matrix for a full release pass:

- mobile splash/onboarding/auth/profile/settings/legal/support
- mobile templates/feed/template detail/generation launch/generation status
- mobile gallery/result/history/wallet/premium/subscriptions/notifications
- admin login/dashboard/users/economy/templates/generations/feedback/support
- loading, empty, error, disabled, selected, and permission-denied states

Record skipped checks with a reason. Do not report source/test evidence as
device-backed visual proof unless the screen was actually run and inspected.

## Documentation Maintenance

Update this guide whenever any of these change:

- supported locale list;
- ARB or admin dictionary structure;
- fallback locale behavior;
- theme storage or token files;
- user-facing API error contract;
- release verification matrix.

Keep links from the root README, mobile README, and admin README pointing to
this guide so product and engineering rules stay in one place.
