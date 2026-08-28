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
    required this.flag,
  });

  final Locale locale;
  final String nativeLabel;
  final String flag;
}

const profileLanguageSheetOptions = <ProfileLanguageSheetOption>[
  ProfileLanguageSheetOption(
    locale: Locale('de'),
    nativeLabel: 'Deutsch',
    flag: '🇩🇪',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('en'),
    nativeLabel: 'English',
    flag: '🇬🇧',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('es'),
    nativeLabel: 'Español',
    flag: '🇪🇸',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('fr'),
    nativeLabel: 'Français',
    flag: '🇫🇷',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('it'),
    nativeLabel: 'Italiano',
    flag: '🇮🇹',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('pl'),
    nativeLabel: 'Polski',
    flag: '🇵🇱',
  ),
  ProfileLanguageSheetOption(
    locale: Locale('ru'),
    nativeLabel: 'Русский',
    flag: '🇷🇺',
  ),
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
  final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.60;
  final maxListHeight = (maxSheetHeight - 76)
      .clamp(0, maxSheetHeight)
      .toDouble();

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      return _ProfileSettingsSheetShell(
        bottomInset: bottomInset,
        horizontalInset: 0,
        topInset: 0,
        borderRadius: 28,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(width: 36, height: 4),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.profileSettingsLanguageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSoft,
                      size: 24,
                    ),
                    tooltip: MaterialLocalizations.of(
                      sheetContext,
                    ).closeButtonTooltip,
                  ),
                ],
              ),
              Divider(height: 16, color: colors.border.withValues(alpha: 0.58)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.42),
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return _LanguageTile(
                      locale: option.locale,
                      nativeLabel: option.nativeLabel,
                      flag: option.flag,
                      isSelected: _isSameLocale(option.locale, selectedLocale),
                      onTap: () async {
                        final selection = onSelect(option.locale);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        await selection;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
  final screenHeight = Overlay.of(
    context,
    rootOverlay: true,
  ).context.size!.height;

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
    constraints: BoxConstraints.tightFor(height: screenHeight),
    builder: (sheetContext, bottomInset) {
      final sheetHeight = screenHeight - bottomInset;

      return _ProfileSettingsSheetShell(
        bottomInset: bottomInset,
        horizontalInset: 0,
        topInset: 0,
        borderRadius: 0,
        contentPadding: EdgeInsets.zero,
        child: SizedBox(
          height: sheetHeight,
          child: SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          text.profileSettingsThemeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSoft,
                          size: 24,
                        ),
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text.profileSettingsThemeSubtitle,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < options.length; index++) ...[
                    _ThemeModeTile(
                      label: options[index].label,
                      icon: options[index].icon,
                      isSelected: selectedThemeMode == options[index].mode,
                      onTap: () async {
                        await onSelect(options[index].mode);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                    if (index < options.length - 1)
                      Divider(
                        height: 1,
                        color: colors.border.withValues(alpha: 0.55),
                      ),
                  ],
                ],
              ),
            ),
          ),
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
