part of 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.selectedPlan});

  final PremiumPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final tokenAllowance = selectedPlan?.tokenAllowance;
    final benefits = <_BenefitCardData>[
      _BenefitCardData(
        icon: Icons.workspace_premium_rounded,
        title: text.premiumComparisonPremiumTemplates,
        subtitle: text.premiumBenefitExclusive,
        tone: colors.purple,
      ),
      _BenefitCardData(
        icon: Icons.opacity_rounded,
        title: text.premiumComparisonNoWatermark,
        subtitle: text.premiumBenefitHighQuality,
        tone: colors.blue,
      ),
      _BenefitCardData(
        icon: Icons.bolt_rounded,
        title: text.premiumComparisonFast,
        subtitle: text.premiumBenefitFastGeneration,
        tone: colors.accent,
      ),
      _BenefitCardData(
        icon: Icons.hd_rounded,
        title: text.premiumComparisonHighQuality,
        subtitle: tokenAllowance == null
            ? text.premiumComparisonPremiumTokensFallback
            : text.premiumComparisonPremiumTokens(tokenAllowance),
        tone: colors.gold,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionLabel(label: text.premiumIncludesTitle),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 560
                ? 4
                : constraints.maxWidth > 420
                ? 2
                : 1;
            final spacing = 10.0;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final benefit in benefits)
                  SizedBox(
                    width: width,
                    child: _BenefitCard(data: benefit),
                  ),
              ],
            );
          },
        ),
        if (selectedPlan != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.gold.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.gold.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  size: 18,
                  color: colors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.premiumTokenEstimate(
                      _estimatedVideoCount(selectedPlan!.tokenAllowance),
                      _estimatedPhotoCount(selectedPlan!.tokenAllowance),
                    ),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.data});

  final _BenefitCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: data.tone.withValues(alpha: 0.14),
                border: Border.all(color: data.tone.withValues(alpha: 0.4)),
              ),
              child: Icon(data.icon, size: 18, color: data.tone),
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 13.5,
                height: 1.22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            if (state.plans.isEmpty) {
              return const SizedBox.shrink();
            }

            final compact = constraints.maxWidth < 420;
            final cardWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final plan in state.plans)
                  SizedBox(
                    width: cardWidth,
                    child: _PlanCard(
                      plan: plan,
                      selected: plan.planCode == state.selectedPlanCode,
                      onTap: () => controller.selectPlan(plan.planCode),
                    ),
                  ),
              ],
            );
          },
        ),
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
    final accent = plan.isPopular ? colors.gold : colors.accent;
    final approxMonthly =
        plan.billingInterval == 'year' || plan.billingInterval == 'yearly'
        ? plan.priceAmount / 12
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? accent : colors.border.withValues(alpha: 0.64),
          width: selected ? 1.8 : 1.1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.94),
            colors.surface.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plan.isPopular || plan.discountPercent != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors.gold.withValues(alpha: 0.2),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: colors.gold),
                      const SizedBox(width: 4),
                      Text(
                        plan.discountPercent != null
                            ? text.premiumDiscountLabel(plan.discountPercent!)
                            : text.premiumPopularBadge,
                        style: TextStyle(
                          color: colors.gold,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _planTitle(text, plan),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? accent
                            : colors.border.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      color: selected
                          ? accent.withValues(alpha: 0.22)
                          : Colors.transparent,
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, size: 16, color: accent)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatPrice(plan, plan.priceAmount),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 44,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.25,
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
                  Icon(Icons.bolt_rounded, color: colors.accent, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    _tokensLabel(text, plan),
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (approxMonthly != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${_formatPrice(plan, approxMonthly)} ${text.premiumMonthlyPeriod}',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutActionsSection extends StatelessWidget {
  const _CheckoutActionsSection({
    required this.state,
    required this.storeProvider,
    required this.stripeAvailable,
    required this.onStoreCheckout,
    required this.onStripeCheckout,
  });

  final PremiumState state;
  final PremiumPaymentProvider? storeProvider;
  final bool stripeAvailable;
  final VoidCallback? onStoreCheckout;
  final VoidCallback? onStripeCheckout;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final storeForeground = colors.textStrong;
    final hasStore = storeProvider != null;
    final hasStripe = stripeAvailable;

    if (!hasStore && !hasStripe) {
      return ProfileMessageCard(
        message: text.premiumStoreUnavailable,
        tone: colors.gold,
      );
    }

    final storeIsBusy =
        hasStore && state.isBuying && state.selectedProvider == storeProvider;
    final stripeIsBusy =
        hasStripe &&
        state.isBuying &&
        state.selectedProvider == PremiumPaymentProvider.stripe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.availableProviders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final provider in state.availableProviders)
                  _PaymentProviderPill(
                    provider: provider,
                    selected: provider == state.selectedProvider,
                  ),
              ],
            ),
          ),
        if (hasStore)
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: state.isBuying ? null : onStoreCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: colors.gold,
                foregroundColor: storeForeground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: storeIsBusy
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          storeForeground,
                        ),
                      ),
                    )
                  : Icon(
                      storeProvider == PremiumPaymentProvider.appStore
                          ? Icons.phone_iphone_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                    ),
              label: Text(
                '${text.premiumContinueAction} · ${_providerLabel(text, storeProvider!)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        if (hasStore && hasStripe) const SizedBox(height: 10),
        if (hasStripe)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: state.isBuying ? null : onStripeCheckout,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: stripeIsBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.credit_card_rounded,
                      size: 18,
                      color: colors.accent,
                    ),
              label: Text(
                '${text.premiumContinueAction} · Stripe',
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PaymentProviderPill extends StatelessWidget {
  const _PaymentProviderPill({required this.provider, required this.selected});

  final PremiumPaymentProvider provider;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final icon = switch (provider) {
      PremiumPaymentProvider.stripe => Icons.credit_card_rounded,
      PremiumPaymentProvider.googlePlay => Icons.play_circle_outline_rounded,
      PremiumPaymentProvider.appStore => Icons.phone_iphone_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? colors.accent.withValues(alpha: 0.16)
            : colors.surfaceStrong.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? colors.accent.withValues(alpha: 0.5)
              : colors.border.withValues(alpha: 0.7),
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
              color: selected ? colors.accent : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              _providerLabel(text, provider),
              style: TextStyle(
                color: selected ? colors.textStrong : colors.textSoft,
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

class _BenefitCardData {
  const _BenefitCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
}
