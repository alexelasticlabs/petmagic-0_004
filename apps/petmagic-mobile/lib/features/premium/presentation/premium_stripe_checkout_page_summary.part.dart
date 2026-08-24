part of 'premium_stripe_checkout_page.dart';

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
