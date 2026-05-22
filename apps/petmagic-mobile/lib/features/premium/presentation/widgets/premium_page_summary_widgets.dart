part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumComparisonTitle),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FeatureColumnCard(
                title: text.premiumFreeColumn,
                accent: false,
                items: const [
                  '20 токенов в месяц',
                  'Водяной знак',
                  'Базовые шаблоны',
                  'Стандартное качество',
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FeatureColumnCard(
                title: text.premiumPremiumColumn,
                accent: true,
                items: [
                  selectedPlan == null
                      ? text.premiumComparisonPremiumTokensFallback
                      : text.premiumComparisonPremiumTokens(
                          selectedPlan!.tokenAllowance,
                        ),
                  text.premiumComparisonNoWatermark,
                  text.premiumComparisonPremiumTemplates,
                  text.premiumComparisonHighQuality,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureColumnCard extends StatelessWidget {
  const _FeatureColumnCard({
    required this.title,
    required this.accent,
    required this.items,
  });

  final String title;
  final bool accent;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent
              ? colors.accent.withValues(alpha: 0.8)
              : colors.border.withValues(alpha: 0.7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: accent
              ? [
                  colors.accent.withValues(alpha: 0.18),
                  colors.surfaceStrong.withValues(alpha: 0.9),
                ]
              : [
                  colors.surfaceStrong.withValues(alpha: 0.78),
                  colors.surfaceStrong.withValues(alpha: 0.55),
                ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent ? colors.accent : colors.textStrong,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    accent
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: accent ? colors.accent : colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
            ],
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedPlanText != null) ...[
              Text(
                selectedPlanText,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip(
                  icon: Icons.workspace_premium_rounded,
                  label: text.premiumPopularBadge,
                ),
                _PlanChip(
                  icon: Icons.event_available_rounded,
                  label: text.premiumCancelAnytime,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text.premiumSocialProof,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text.premiumSecurePaymentSubtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit(this.icon, this.label);

  final IconData icon;
  final String label;
}
