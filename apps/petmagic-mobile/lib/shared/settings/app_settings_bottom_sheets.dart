import 'dart:ui';

// Shared app preferences UI used before and after authentication.

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

part 'app_settings_bottom_sheet_widgets.part.dart';

class ProfileLanguageSheetOption {
  const ProfileLanguageSheetOption({
    required this.locale,
    required this.nativeLabel,
  });

  final Locale locale;
  final String nativeLabel;
}

const profileLanguageSheetOptions = <ProfileLanguageSheetOption>[
  ProfileLanguageSheetOption(locale: Locale('ru'), nativeLabel: 'Русский'),
  ProfileLanguageSheetOption(locale: Locale('en'), nativeLabel: 'English'),
  ProfileLanguageSheetOption(locale: Locale('de'), nativeLabel: 'Deutsch'),
  ProfileLanguageSheetOption(locale: Locale('es'), nativeLabel: 'Español'),
  ProfileLanguageSheetOption(locale: Locale('fr'), nativeLabel: 'Français'),
  ProfileLanguageSheetOption(locale: Locale('it'), nativeLabel: 'Italiano'),
  ProfileLanguageSheetOption(locale: Locale('pl'), nativeLabel: 'Polski'),
];

String profileLanguageLabel(AppLocalizations text, Locale locale) {
  return switch (locale.languageCode) {
    'ru' => text.profileSettingsLanguageRussian,
    'en' => text.profileSettingsLanguageEnglish,
    'de' => text.profileSettingsLanguageGerman,
    'es' => text.profileSettingsLanguageSpanish,
    'fr' => text.profileSettingsLanguageFrench,
    'it' => text.profileSettingsLanguageItalian,
    'pl' => text.profileSettingsLanguagePolish,
    _ => text.profileSettingsLanguageEnglish,
  };
}

Future<void> showProfileLanguageSheet({
  required BuildContext context,
  required Locale selectedLocale,
  required List<ProfileLanguageSheetOption> options,
  required Future<void> Function(Locale locale) onSelect,
}) {
  final colors = context.petMagicColors;
  final text = AppLocalizations.of(context);

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      return _ProfileSettingsSheetShell(
        bottomInset: bottomInset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              text.profileSettingsLanguageTitle,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border.withValues(alpha: 0.8)),
                color: colors.surfaceStrong.withValues(alpha: 0.48),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final option in options)
                      _LanguageTile(
                        locale: option.locale,
                        nativeLabel: option.nativeLabel,
                        isSelected: _isSameLocale(
                          option.locale,
                          selectedLocale,
                        ),
                        onTap: () async {
                          await onSelect(option.locale);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(text.walletRedeemCancelAction),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showProfileThemeSheet({
  required BuildContext context,
  required ThemeMode selectedThemeMode,
  required Future<void> Function(ThemeMode mode) onSelect,
}) {
  final colors = context.petMagicColors;
  final text = AppLocalizations.of(context);

  final options = [
    (
      mode: ThemeMode.system,
      label: text.profileSettingsThemeSystem,
      icon: Icons.brightness_auto_rounded,
    ),
    (
      mode: ThemeMode.light,
      label: text.profileSettingsThemeLight,
      icon: Icons.light_mode_rounded,
    ),
    (
      mode: ThemeMode.dark,
      label: text.profileSettingsThemeDark,
      icon: Icons.dark_mode_rounded,
    ),
  ];

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      return _ProfileSettingsSheetShell(
        bottomInset: bottomInset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              text.profileSettingsThemeTitle,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.78),
                ),
                color: colors.surfaceStrong.withValues(alpha: 0.46),
              ),
              child: Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: _ThemeChip(
                        label: option.label,
                        icon: option.icon,
                        isSelected: selectedThemeMode == option.mode,
                        onTap: () async {
                          await onSelect(option.mode);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Icon(
                Icons.brightness_6_rounded,
                size: 26,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                text.profileSettingsThemeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(text.walletRedeemCancelAction),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showProfileDeleteAccountConfirmationSheet({
  required BuildContext context,
  required Future<void> Function() onConfirm,
}) {
  final colors = context.petMagicColors;
  final text = AppLocalizations.of(context);

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      return _ProfileSettingsSheetShell(
        bottomInset: bottomInset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.danger.withValues(alpha: 0.42),
                ),
              ),
              child: Icon(
                Icons.delete_forever_outlined,
                color: colors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text.profileSettingsDeleteAccountTitle,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.profileSettingsDeleteAccountSubtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text.profileDetailsDeleteBody,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: colors.backgroundBottom,
                  shadowColor: colors.danger.withValues(alpha: 0.38),
                ),
                onPressed: () async {
                  await onConfirm();
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Text(text.profileSettingsDeleteAccountTitle),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(text.walletRedeemCancelAction),
              ),
            ),
          ],
        ),
      );
    },
  );
}
