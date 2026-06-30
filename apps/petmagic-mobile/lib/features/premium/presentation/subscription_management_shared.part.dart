part of 'subscription_management_page.dart';

class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog({
    required this.text,
    required this.periodEndDateStr,
  });

  final AppLocalizations text;
  final String periodEndDateStr;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return AlertDialog(
      title: Text(text.subscriptionCancelConfirmTitle),
      content: Text(
        text.subscriptionCancelConfirmBody(periodEndDateStr),
        style: TextStyle(color: colors.textSoft, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(text.subscriptionCancelConfirmKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          child: Text(text.subscriptionCancelConfirmAction),
        ),
      ],
    );
  }
}

class _CancelledHintBanner extends StatelessWidget {
  const _CancelledHintBanner({
    required this.summary,
    required this.colors,
    required this.text,
  });

  final PremiumSubscriptionSummaryView summary;
  final PetMagicColors colors;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = summary.currentPeriodEndUtc != null
        ? DateFormat.yMMMd(
            locale,
          ).format(summary.currentPeriodEndUtc!.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.danger.withValues(alpha: 0.32)),
      ),
      child: Text(
        text.subscriptionCancelledHint(dateStr),
        style: TextStyle(color: colors.danger, fontSize: 13, height: 1.5),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.textStrong,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GlowStatusBadge extends StatelessWidget {
  const _GlowStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OutlineMetaBadge extends StatelessWidget {
  const _OutlineMetaBadge({required this.label, required this.foregroundColor});

  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
