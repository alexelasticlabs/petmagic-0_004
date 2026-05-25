import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

class ProfileLanguageSheetOption {
  const ProfileLanguageSheetOption({required this.locale, required this.label});

  final Locale locale;
  final String label;
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
              child: Column(
                children: [
                  for (var index = 0; index < options.length; index++)
                    _LanguageTile(
                      label: options[index].label,
                      isSelected: _isSameLocale(
                        options[index].locale,
                        selectedLocale,
                      ),
                      showDivider: index != options.length - 1,
                      onTap: () async {
                        await onSelect(options[index].locale);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                ],
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
    (mode: ThemeMode.system, label: text.profileSettingsThemeSystem),
    (mode: ThemeMode.light, label: text.profileSettingsThemeLight),
    (mode: ThemeMode.dark, label: text.profileSettingsThemeDark),
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
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
            ),
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
    required this.label,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.76),
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? colors.accent : colors.textMuted,
                  size: 22,
                ),
              ],
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
    required this.isSelected,
    required this.onTap,
  });

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? colors.accent : colors.textSoft,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
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
