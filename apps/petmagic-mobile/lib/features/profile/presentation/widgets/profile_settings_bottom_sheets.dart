import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

class ProfileLanguageSheetOption {
  const ProfileLanguageSheetOption({
    required this.locale,
    required this.nativeLabel,
  });

  final Locale locale;
  final String nativeLabel;
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

class _ProfileSettingsSheetShell extends StatelessWidget {
  const _ProfileSettingsSheetShell({
    required this.bottomInset,
    required this.child,
  });

  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: child,
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: PerformanceGuard.shouldAvoidBlur(context)
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Center(
      child: Container(
        width: 56,
        height: 6,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.locale,
    required this.nativeLabel,
    required this.isSelected,
    required this.onTap,
  });

  final Locale locale;
  final String nativeLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.6)
                : colors.border.withValues(alpha: 0.76),
          ),
          color: isSelected
              ? colors.accentSoft.withValues(alpha: 0.26)
              : colors.surfaceGlass.withValues(alpha: 0.34),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isSelected
                          ? colors.accent.withValues(alpha: 0.2)
                          : colors.surfaceStrong.withValues(alpha: 0.52),
                    ),
                    child: Text(
                      locale.languageCode.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? colors.accent : colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nativeLabel,
                      style: TextStyle(
                        color: isSelected ? colors.textStrong : colors.textSoft,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? colors.accent : colors.textMuted,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.56)
                  : colors.border.withValues(alpha: 0.62),
            ),
            color: isSelected
                ? colors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.accent : colors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors.accent : colors.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameLocale(Locale left, Locale right) {
  return left.languageCode == right.languageCode &&
      (left.countryCode ?? '') == (right.countryCode ?? '');
}
