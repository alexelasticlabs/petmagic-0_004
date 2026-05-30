import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

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
          final warningTitle = selected.warningTitle?.trim();
          final warningMessage = selected.warningMessage?.trim();
          final notes = selected.notes?.trim();
          final legalNotice = selected.legalNotice?.trim();

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
                const SizedBox(height: 12),
                for (var index = 0; index < options.length; index++) ...[
                  _PaymentMethodOptionTile(
                    option: options[index],
                    isSelected: selected.id == options[index].id,
                    onTap: options[index].isEnabled
                        ? () => setModalState(() => selected = options[index])
                        : null,
                  ),
                  if (index != options.length - 1) const SizedBox(height: 8),
                ],
                if (warningMessage != null && warningMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (warningTitle != null && warningTitle.isNotEmpty)
                          Text(
                            warningTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (warningTitle != null && warningTitle.isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          warningMessage,
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notes,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
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
                const SizedBox(height: 14),
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
    final isEnabled = option.isEnabled;

    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.12)
                  : colors.surfaceStrong.withValues(alpha: 0.45),
              border: Border.all(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.7)
                    : colors.border.withValues(alpha: 0.8),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(option.icon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: 10),
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
                                color: colors.textStrong,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (option.badge != null && option.badge!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                option.badge!,
                                style: TextStyle(
                                  color: colors.accent,
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
                              color: colors.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
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
                  color: isSelected ? colors.accent : colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
