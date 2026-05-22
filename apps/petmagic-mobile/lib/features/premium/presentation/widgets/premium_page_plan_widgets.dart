part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final tokenAllowance = selectedPlan?.tokenAllowance;
    final benefits = [
      _Benefit(
        Icons.workspace_premium_rounded,
        text.premiumComparisonPremiumTemplates,
      ),
      _Benefit(Icons.visibility_off_rounded, text.premiumComparisonNoWatermark),
      _Benefit(Icons.flash_on_rounded, text.premiumComparisonFast),
      _Benefit(
        Icons.auto_awesome_rounded,
        tokenAllowance == null
            ? text.premiumComparisonPremiumTokensFallback
            : text.premiumComparisonPremiumTokens(tokenAllowance),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumIncludesTitle),
        const SizedBox(height: 2),
        ProfileGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              for (var index = 0; index < benefits.length; index++) ...[
                _BenefitLine(benefit: benefits[index]),
                if (index < benefits.length - 1) const SizedBox(height: 10),
              ],
              if (selectedPlan != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text.premiumTokenEstimate(
                      _estimatedVideoCount(selectedPlan!.tokenAllowance),
                      _estimatedPhotoCount(selectedPlan!.tokenAllowance),
                    ),
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.benefit});

  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Icon(Icons.check_circle_rounded, color: colors.textStrong, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            benefit.label,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(benefit.icon, color: colors.textMuted, size: 18),
      ],
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.state, required this.controller});

  final PremiumState state;
  final PremiumController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumChoosePlanTitle),
        const SizedBox(height: 2),
        for (final plan in state.plans) ...[
          _PlanCard(
            plan: plan,
            selected: plan.planCode == state.selectedPlanCode,
            onTap: () => controller.selectPlan(plan.planCode),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlanModel plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final borderColor = selected
        ? (plan.isPopular ? colors.accent : colors.gold)
        : colors.border;
    final approxMonthly = plan.billingInterval == 'yearly'
        ? plan.priceAmount / 12
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: ProfileGlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _planTitle(text, plan),
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (plan.isPopular) ...[
                            const SizedBox(width: 8),
                            ProfileStatusPill(
                              label: text.premiumPopularBadge,
                              leading: Icons.local_fire_department_rounded,
                              backgroundColor: colors.accent.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: colors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (plan.compareAtPriceAmount != null) ...[
                            Text(
                              _formatPrice(plan, plan.compareAtPriceAmount!),
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _formatPrice(plan, plan.priceAmount),
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 23,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              _periodLabel(text, plan),
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tokensLabel(text, plan),
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (approxMonthly != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PlanChip(
                              icon: Icons.calculate_rounded,
                              label:
                                  '${_formatPrice(plan, approxMonthly)} ${text.premiumMonthlyPeriod}',
                            ),
                            if (plan.discountPercent != null)
                              _PlanChip(
                                icon: Icons.savings_rounded,
                                label: text.premiumDiscountLabel(
                                  plan.discountPercent!,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? (plan.isPopular ? colors.accent : colors.gold)
                        : Colors.transparent,
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.surface,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlanChip(
                  icon: Icons.event_available_rounded,
                  label: text.premiumCancelAnytime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentProviderSection extends StatelessWidget {
  const _PaymentProviderSection({required this.state, required this.onSelect});

  final PremiumState state;
  final ValueChanged<PremiumPaymentProvider> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumPaymentTitle),
        const SizedBox(height: 2),
        ProfileGlassCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (final provider in state.availableProviders)
                _ProviderRow(
                  provider: provider,
                  paymentMethod: state.paymentMethods
                      .where((method) => method.provider == provider)
                      .cast<PremiumPaymentMethodModel?>()
                      .firstOrNull,
                  enabled: state.isProviderAvailable(provider),
                  selected: provider == state.selectedProvider,
                  onTap: () => onSelect(provider),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.paymentMethod,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final PremiumPaymentProvider provider;
  final PremiumPaymentMethodModel? paymentMethod;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final backendLabel = paymentMethod?.displayLabel?.trim();
    final backendSubtitle = paymentMethod?.displaySubtitle?.trim();
    final label = backendLabel == null || backendLabel.isEmpty
        ? _providerLabel(text, provider)
        : backendLabel;
    final subtitle = backendSubtitle == null || backendSubtitle.isEmpty
        ? paymentMethod?.notes
        : backendSubtitle;
    final icon = switch (provider) {
      PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
      PremiumPaymentProvider.googlePlay => Icons.shop_rounded,
      PremiumPaymentProvider.appStore => Icons.phone_iphone_rounded,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled
                  ? (selected ? colors.accent : colors.textMuted)
                  : colors.textMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? colors.textStrong
                          : colors.textMuted.withValues(alpha: 0.75),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle?.isNotEmpty == true)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (paymentMethod != null &&
                      (paymentMethod!.isRecommended ||
                          paymentMethod!.isSelectedByDefault ||
                          paymentMethod!.bonusTokensPercent > 0)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (paymentMethod!.isRecommended)
                          _PaymentMethodBadge(
                            label: text.premiumPaymentRecommendedBadge,
                          ),
                        if (paymentMethod!.isSelectedByDefault)
                          _PaymentMethodBadge(
                            label: text.premiumPaymentDefaultBadge,
                          ),
                        if (paymentMethod!.bonusTokensPercent > 0)
                          _PaymentMethodBadge(
                            label: text.paymentBonusPercentBadge(
                              paymentMethod!.bonusTokensPercent,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (paymentMethod?.requiresExternalWarning == true) ...[
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded, size: 16, color: colors.gold),
            ],
            const SizedBox(width: 8),
            Icon(
              enabled && selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: enabled && selected ? colors.accent : colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  const _PaymentMethodBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: colors.accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
