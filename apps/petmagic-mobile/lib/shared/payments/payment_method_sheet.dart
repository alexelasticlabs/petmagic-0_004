import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

const _kSelectedGreen = Color(0xFF34C759);

class PaymentMethodSheetOption {
  const PaymentMethodSheetOption({
    required this.id,
    required this.title,
    required this.icon,
    this.subtitle,
    this.badge,
    this.warningTitle,
    this.warningMessage,
    this.notes,
    this.legalNotice,
    this.isEnabled = true,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? subtitle;
  final String? badge;
  final String? warningTitle;
  final String? warningMessage;
  final String? notes;
  final String? legalNotice;
  final bool isEnabled;
}

Future<PaymentMethodSheetOption?> showPaymentMethodSheet({
  required BuildContext context,
  required String title,
  required String continueLabel,
  required List<PaymentMethodSheetOption> options,
  String Function(PaymentMethodSheetOption selected)? continueLabelBuilder,
  String? subtitle,
  String? trustTitle,
  List<String>? trustLines,
}) async {
  if (options.isEmpty) {
    return null;
  }

  final selectable = options.where((option) => option.isEnabled);
  final initial = selectable.isNotEmpty ? selectable.first : options.first;

  return showPetMagicModalBottomSheet<PaymentMethodSheetOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext, bottomInset) {
      final colors = sheetContext.petMagicColors;
      var selected = initial;

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final legalNotice = selected.legalNotice?.trim();
          final hasTrust = trustLines != null && trustLines.isNotEmpty;

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                for (var index = 0; index < options.length; index++) ...[
                  _PaymentMethodOptionTile(
                    option: options[index],
                    isSelected: selected.id == options[index].id,
                    onTap: options[index].isEnabled
                        ? () => setModalState(() => selected = options[index])
                        : null,
                  ),
                  if (index != options.length - 1) const SizedBox(height: 10),
                ],
                if (hasTrust) ...[
                  const SizedBox(height: 14),
                  _TrustCard(
                    title: trustTitle,
                    lines: trustLines,
                    colors: colors,
                  ),
                ],
                if (legalNotice != null && legalNotice.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    legalNotice,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected.isEnabled
                        ? () => Navigator.of(modalContext).pop(selected)
                        : null,
                    child: Text(
                      continueLabelBuilder?.call(selected) ?? continueLabel,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.lines, required this.colors, this.title});

  final String? title;
  final List<String> lines;
  final PetMagicColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSelectedGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kSelectedGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_rounded, color: _kSelectedGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.check_rounded,
                            color: _kSelectedGreen,
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodOptionTile extends StatelessWidget {
  const _PaymentMethodOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentMethodSheetOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isEnabled = option.isEnabled;

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? _kSelectedGreen.withValues(alpha: 0.09)
                  : colors.surfaceStrong.withValues(alpha: isLight ? 0.8 : 0.3),
              border: Border.all(
                color: isSelected
                    ? _kSelectedGreen
                    : colors.border.withValues(alpha: isLight ? 0.74 : 0.45),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kSelectedGreen.withValues(alpha: 0.12)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    option.icon,
                    color: isSelected ? _kSelectedGreen : colors.textSoft,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.title,
                              style: TextStyle(
                                color: isSelected
                                    ? colors.textStrong
                                    : colors.textSoft,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (option.badge != null && option.badge!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kSelectedGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                option.badge!,
                                style: const TextStyle(
                                  color: _kSelectedGreen,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (option.subtitle != null &&
                          option.subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            option.subtitle!,
                            style: TextStyle(
                              color: isSelected
                                  ? colors.textSoft
                                  : colors.textMuted,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? _kSelectedGreen : colors.textMuted,
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
