part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final premiumTokens = selectedPlan == null
        ? text.premiumComparisonPremiumTokensFallback
        : text.premiumComparisonPremiumTokens(selectedPlan!.tokenAllowance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumComparisonTitle),
        const SizedBox(height: 2),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            color: colors.surfaceStrong.withValues(alpha: 0.62),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  color: colors.surfaceStrong.withValues(alpha: 0.7),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        text.premiumComparisonTitle,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        text.premiumFreeColumn,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        text.premiumPremiumColumn,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ComparisonRow(
                label: text.premiumComparisonTokens,
                freeValue: text.premiumFreeSummaryTokens,
                premiumValue: premiumTokens,
              ),
              _ComparisonRow(
                label: text.premiumComparisonNoWatermark,
                freeValue: text.premiumFreeSummaryWatermark,
                premiumValue: text.premiumComparisonNoWatermark,
              ),
              _ComparisonRow(
                label: text.premiumComparisonPremiumTemplates,
                freeValue: text.premiumFreeSummaryTemplates,
                premiumValue: text.premiumComparisonPremiumTemplates,
              ),
              _ComparisonRow(
                label: text.premiumComparisonHighQuality,
                freeValue: text.premiumFreeSummaryQuality,
                premiumValue: text.premiumComparisonHighQuality,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.freeValue,
    required this.premiumValue,
    this.isLast = false,
  });

  final String label;
  final String freeValue;
  final String premiumValue;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.4)),
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: colors.border.withValues(alpha: 0.15)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                freeValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                premiumValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalCheckoutWarningSheet extends StatelessWidget {
  const _ExternalCheckoutWarningSheet({required this.state});

  final PremiumState state;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final paymentMethod = state.selectedPaymentMethod;
    final warningTitle = paymentMethod?.warningTitle?.trim();
    final warningMessage = paymentMethod?.warningMessage?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warningTitle == null || warningTitle.isEmpty
                    ? text.externalCheckoutStripeTitle
                    : warningTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                warningMessage == null || warningMessage.isEmpty
                    ? text.externalCheckoutStripeMessage
                    : warningMessage,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                state.legalNotice,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(text.externalCheckoutContinueAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustSummary extends StatelessWidget {
  const _TrustSummary({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final selectedPlanText = selectedPlan == null
        ? null
        : '${_planTitle(text, selectedPlan!)} · ${_formatPrice(selectedPlan!, selectedPlan!.priceAmount)} ${_periodLabel(text, selectedPlan!)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surfaceStrong.withValues(alpha: 0.55),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TrustPill(
                  icon: Icons.lock_outline_rounded,
                  label: text.premiumSecurePaymentTitle,
                  tone: colors.gold,
                ),
                _TrustPill(
                  icon: Icons.autorenew_rounded,
                  label: text.premiumCancelAnytime,
                  tone: colors.accent,
                ),
                _TrustPill(
                  icon: Icons.verified_user_outlined,
                  label: text.premiumPaymentTitle,
                  tone: colors.blue,
                ),
              ],
            ),
            if (selectedPlanText != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 16, color: colors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedPlanText,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
