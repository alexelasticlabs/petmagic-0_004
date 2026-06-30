part of 'subscription_management_page.dart';

class _SubscriptionContent extends StatelessWidget {
  const _SubscriptionContent({
    required this.summary,
    required this.isProcessing,
    required this.onManage,
    required this.onRestore,
    required this.onChangePayment,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final VoidCallback onManage;
  final VoidCallback onRestore;
  final VoidCallback onChangePayment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isStripe = summary.provider == PremiumSubscriptionProviderView.stripe;
    final canCancel =
        isStripe && summary.isPremium && summary.cancelAtPeriodEnd != true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Stack(
          children: [
            const Positioned.fill(child: _SubscriptionSparkleBackground()),
            Column(
              children: [
                _PremiumHeroCard(summary: summary),
                const SizedBox(height: 12),
                _TokensCard(summary: summary),
                const SizedBox(height: 12),
                _BenefitsCard(),
                if (isStripe) ...[
                  const SizedBox(height: 12),
                  _PaymentCard(
                    summary: summary,
                    isProcessing: isProcessing,
                    onChangePayment: onChangePayment,
                  ),
                ],
                const SizedBox(height: 20),
                _ActionsSection(
                  summary: summary,
                  isProcessing: isProcessing,
                  canCancel: canCancel,
                  onManage: onManage,
                  onRestore: onRestore,
                  onCancel: onCancel,
                ),
                if (summary.isPremium && summary.cancelAtPeriodEnd == true) ...[
                  const SizedBox(height: 16),
                  _CancelledHintBanner(
                    summary: summary,
                    colors: colors,
                    text: text,
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
