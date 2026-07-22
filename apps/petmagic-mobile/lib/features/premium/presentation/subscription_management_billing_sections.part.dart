part of 'subscription_management_page.dart';

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.summary,
    required this.isProcessing,
    required this.onChangePayment,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final VoidCallback onChangePayment;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final maskedCard = summary.cardLast4 != null
        ? '**** ${summary.cardLast4}'
        : null;
    final paymentLabel = maskedCard != null
        ? '${text.subscriptionPaymentProviderStripe}  ·  $maskedCard'
        : text.subscriptionPaymentProviderStripe;

    return _SubscriptionPanel(
      accentColor: colors.border,
      borderOpacity: 0.14,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.subscriptionPaymentSectionTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: colors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  paymentLabel,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(
                alpha: isLight ? 0.94 : 0.78,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border.withValues(alpha: isLight ? 0.92 : 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: colors.textMuted,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.subscriptionPaymentTrustText,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isProcessing || !summary.canManageSubscription
                  ? null
                  : onChangePayment,
              style: OutlinedButton.styleFrom(
                backgroundColor: isLight ? colors.surface : null,
                side: BorderSide(
                  color: isLight
                      ? colors.border
                      : colors.border.withValues(alpha: 0.9),
                ),
                foregroundColor: isLight ? colors.textStrong : null,
              ),
              child: Text(text.subscriptionChangePaymentAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.summary,
    required this.isProcessing,
    required this.canCancel,
    required this.onManage,
    required this.onRestore,
    required this.onCancel,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isProcessing;
  final bool canCancel;
  final VoidCallback onManage;
  final VoidCallback onRestore;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final manageColor = colors.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed:
              isProcessing ||
                  !summary.canManageSubscription ||
                  !summary.isPremium
              ? null
              : onManage,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(36),
            backgroundColor: manageColor,
            foregroundColor: colors.on(manageColor),
            disabledBackgroundColor: colors.surfaceStrong,
            disabledForegroundColor: colors.textMuted,
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            shadowColor: Colors.transparent,
          ),
          child: Text(text.premiumManageAction),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: isProcessing ? null : onRestore,
          style: OutlinedButton.styleFrom(
            backgroundColor: isLight ? colors.surface : null,
            side: BorderSide(
              color: isLight
                  ? colors.border
                  : colors.border.withValues(alpha: 0.9),
            ),
            foregroundColor: isLight ? colors.textStrong : null,
          ),
          child: Text(text.premiumRestoreAction),
        ),
        if (canCancel) ...[
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: Divider(color: colors.danger.withValues(alpha: 0.25)),
              ),
              const SizedBox(width: 12),
              Text(
                text.subscriptionDangerZoneTitle,
                style: TextStyle(
                  color: colors.danger.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: colors.danger.withValues(alpha: 0.25)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: isProcessing ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger.withValues(
                alpha: isLight ? 0.95 : 1,
              ),
              backgroundColor: isLight ? const Color(0xFFFFF8F8) : null,
              side: BorderSide(
                color: colors.danger.withValues(alpha: isLight ? 0.62 : 0.5),
              ),
            ),
            child: Text(text.subscriptionCancelAction),
          ),
        ],
      ],
    );
  }
}

String _resolveStatusLabel(
  PremiumSubscriptionSummaryView summary,
  AppLocalizations text,
) {
  final kind = classifyPremiumSubscriptionStatus(
    isPremium: summary.isPremium,
    cancelAtPeriodEnd: summary.cancelAtPeriodEnd == true,
    status: summary.status,
  );
  return _premiumSubscriptionStatusLabel(text, kind);
}

String _premiumSubscriptionStatusLabel(
  AppLocalizations text,
  PremiumSubscriptionStatusKind kind,
) => switch (kind) {
  PremiumSubscriptionStatusKind.inactive => text.subscriptionStatusInactive,
  PremiumSubscriptionStatusKind.cancelled => text.subscriptionStatusCancelled,
  PremiumSubscriptionStatusKind.active => text.subscriptionStatusActive,
  PremiumSubscriptionStatusKind.paymentFailed =>
    text.subscriptionStatusPaymentFailed,
  PremiumSubscriptionStatusKind.expired => text.subscriptionStatusExpired,
  PremiumSubscriptionStatusKind.pending => text.subscriptionStatusPending,
};

Color _resolveStatusColor(
  PremiumSubscriptionSummaryView summary,
  PetMagicColors colors,
) {
  if (!summary.isPremium) {
    return colors.textMuted;
  }
  if (summary.cancelAtPeriodEnd == true) {
    return colors.gold;
  }
  return switch (summary.status.toLowerCase()) {
    'active' || 'trialing' => colors.accent,
    'past_due' || 'unpaid' => colors.danger,
    'canceled' => colors.textMuted,
    'incomplete' || 'incomplete_expired' => colors.gold,
    _ => colors.accent,
  };
}
