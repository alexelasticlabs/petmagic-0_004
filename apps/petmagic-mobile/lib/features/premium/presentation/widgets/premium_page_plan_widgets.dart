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
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceGlass.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.gold.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var index = 0; index < benefits.length; index++) ...[
                  _BenefitLine(benefit: benefits[index]),
                  if (index < benefits.length - 1) ...[
                    const SizedBox(height: 12),
                    Divider(
                      color: colors.border.withValues(alpha: 0.15),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (selectedPlan != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.gold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.gold.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text.premiumTokenEstimate(
                              _estimatedVideoCount(
                                selectedPlan!.tokenAllowance,
                              ),
                              _estimatedPhotoCount(
                                selectedPlan!.tokenAllowance,
                              ),
                            ),
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.gold.withValues(alpha: 0.18),
          ),
          child: Icon(Icons.check_rounded, color: colors.gold, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            benefit.label,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(benefit.icon, color: colors.gold, size: 16),
        ),
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

    // Choose beautiful color branding based on plan.isPopular or gold accents
    final activeColor = plan.isPopular ? colors.accent : colors.gold;
    final borderColor = selected
        ? activeColor
        : colors.border.withValues(alpha: 0.5);

    final approxMonthly = plan.billingInterval == 'yearly'
        ? plan.priceAmount / 12
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected
            ? colors.surfaceStrong.withValues(alpha: 0.95)
            : colors.surfaceGlass.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: selected ? 2.0 : 1.2),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                                  color: selected
                                      ? colors.textStrong
                                      : colors.textStrong.withValues(
                                          alpha: 0.9,
                                        ),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (plan.isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.accent.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ProfileStatusPill(
                                  label: text.premiumPopularBadge,
                                  leading: Icons.local_fire_department_rounded,
                                  backgroundColor: colors.accent.withValues(
                                    alpha: 0.22,
                                  ),
                                  foregroundColor: colors.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (plan.compareAtPriceAmount != null) ...[
                              Text(
                                _formatPrice(plan, plan.compareAtPriceAmount!),
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _periodLabel(text, plan),
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: selected ? colors.gold : colors.textSoft,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _tokensLabel(text, plan),
                              style: TextStyle(
                                color: selected
                                    ? colors.textStrong
                                    : colors.textSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (approxMonthly != null) ...[
                          const SizedBox(height: 12),
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
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.gold.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: _PlanChip(
                                    icon: Icons.savings_rounded,
                                    label: text.premiumDiscountLabel(
                                      plan.discountPercent!,
                                    ),
                                    accentColor: colors.gold,
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
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? activeColor : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? activeColor
                            : colors.border.withValues(alpha: 0.7),
                        width: 2.0,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                      ],
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
              const SizedBox(height: 14),
              Divider(color: colors.border.withValues(alpha: 0.3), height: 1),
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
