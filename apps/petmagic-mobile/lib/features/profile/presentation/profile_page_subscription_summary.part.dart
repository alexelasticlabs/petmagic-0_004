part of 'profile_page.dart';

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.summary,
    required this.isOpening,
    required this.onManageTap,
  });

  final PremiumSubscriptionSummaryView summary;
  final bool isOpening;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.yMMMd(locale);
    final providerLabel = switch (summary.provider) {
      PremiumSubscriptionProviderView.appStore => text.premiumPaymentApple,
      PremiumSubscriptionProviderView.googlePlay =>
        text.premiumPaymentGooglePlay,
      PremiumSubscriptionProviderView.stripe => text.premiumPaymentStripe,
      PremiumSubscriptionProviderView.unknown => text.premiumPaymentStripe,
    };
    final subtitle = summary.planName?.trim().isNotEmpty == true
        ? summary.planName!
        : providerLabel;
    final nextBillingValue = summary.currentPeriodEndUtc == null
        ? null
        : format.format(summary.currentPeriodEndUtc!.toLocal());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.gold.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.gold.withValues(alpha: 0.12),
            colors.surfaceGlass,
            colors.surfaceStrong.withValues(alpha: 0.52),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const PremiumCrownIcon(size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.profileSubscriptionTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CompactPremiumAction(
                  label: text.premiumManageAction,
                  onTap: isOpening ? null : onManageTap,
                  isLoading: isOpening,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProfileStatusPill(
                  label: summary.status,
                  leading: Icons.verified_rounded,
                  backgroundColor: colors.gold.withValues(alpha: 0.16),
                  foregroundColor: colors.gold,
                ),
                ProfileStatusPill(
                  label: providerLabel,
                  leading: Icons.credit_card_rounded,
                  backgroundColor: colors.surfaceStrong.withValues(alpha: 0.58),
                  foregroundColor: colors.textStrong,
                ),
              ],
            ),
            if (nextBillingValue != null) ...[
              const SizedBox(height: 12),
              _SubscriptionMetaTile(
                label: text.profileSubscriptionNextBillingLabel,
                value: nextBillingValue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionMetaTile extends StatelessWidget {
  const _SubscriptionMetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPremiumAction extends StatelessWidget {
  const _CompactPremiumAction({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 126),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              color: colors.gold,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: colors.gold.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.backgroundBottom,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.open_in_new_rounded,
                      color: colors.backgroundBottom,
                      size: 14,
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.backgroundBottom,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
