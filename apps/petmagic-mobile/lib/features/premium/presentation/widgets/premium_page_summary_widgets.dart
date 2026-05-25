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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colors.surfaceStrong.withValues(alpha: 0.65),
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.gold.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_rounded, size: 16, color: colors.gold),
                const SizedBox(width: 8),
                Text(
                  text.premiumSecurePaymentTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(Icons.lock_outline_rounded, size: 16, color: colors.gold),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedPlanText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceStrong.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, size: 16, color: colors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedPlanText,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) =>
                        Icon(Icons.star_rounded, color: colors.gold, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '4.9/5',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text.premiumSocialProof,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text.premiumSecurePaymentSubtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.icon, required this.label, this.accentColor});

  final IconData icon;
  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isAccent = accentColor != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isAccent
            ? accentColor!.withValues(alpha: 0.12)
            : colors.surfaceStrong.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isAccent
              ? accentColor!.withValues(alpha: 0.5)
              : colors.border.withValues(alpha: 0.6),
          width: isAccent ? 1.2 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isAccent ? accentColor : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isAccent ? colors.textStrong : colors.textStrong,
                fontSize: 11,
                fontWeight: isAccent ? FontWeight.w900 : FontWeight.w800,
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
