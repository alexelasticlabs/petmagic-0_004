part of 'premium_stripe_checkout_page.dart';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.planLabel,
    required this.periodLabel,
    required this.price,
  });

  final String planLabel;
  final String periodLabel;
  final String price;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.premiumCheckoutSummaryTitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: text.premiumCheckoutSummaryPlanLabel,
            value: planLabel,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: text.premiumCheckoutSummaryPeriodLabel,
            value: periodLabel,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: text.walletCheckoutTaxLabel,
            value: text.walletCheckoutTaxIncludedValue,
          ),
          Divider(height: 16, color: colors.border),
          _SummaryRow(
            label: text.premiumCheckoutTotalLabel,
            value: price,
            isStrong: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

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
        Text(
          value,
          style: TextStyle(
            color: isStrong ? colors.textStrong : colors.textSoft,
            fontSize: isStrong ? 15 : 13,
            fontWeight: isStrong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.status, required this.message});

  final PremiumStripeCheckoutActionStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    final resolved = message?.trim().isNotEmpty == true
        ? message!.trim()
        : (status == PremiumStripeCheckoutActionStatus.cancelled
              ? text.premiumPurchaseCancelled
              : text.premiumCheckoutFailed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.gold.withValues(alpha: 0.12),
        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: colors.gold,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resolved,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
