part of 'premium_page.dart';

bool _isYearlyPlan(PremiumPlanModel plan) {
  return plan.billingInterval.toLowerCase().contains('year') ||
      plan.planCode.toLowerCase().contains('annual');
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.state,
    required this.controller,
    required this.isDark,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final monthlyPlans = state.plans
        .where((plan) => !_isYearlyPlan(plan))
        .toList();
    final yearlyPlans = state.plans.where(_isYearlyPlan).toList();

    PremiumPlanModel? selectedPlan;
    for (final plan in state.plans) {
      if (plan.planCode == state.selectedPlanCode) {
        selectedPlan = plan;
        break;
      }
    }

    final selectedIsYearly =
        selectedPlan != null && _isYearlyPlan(selectedPlan);
    final canChangePlan =
        !state.isPremium && !state.recentlyActivatedPremium && !state.isBuying;

    if (state.plans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            text.premiumChoosePlanTitle,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BillingChip(
                label: text.premiumMonthlyPlan,
                isActive: !selectedIsYearly,
                accent: accent,
                border: border,
                textColor: textColor,
                mutedColor: sub,
                onTap: monthlyPlans.isEmpty
                    ? null
                    : () {
                        if (!canChangePlan) {
                          return;
                        }

                        HapticFeedback.selectionClick();
                        controller.selectPlan(monthlyPlans.first.planCode);
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BillingChip(
                label: text.premiumYearlyPlan,
                isActive: selectedIsYearly,
                accent: accent,
                border: border,
                textColor: textColor,
                mutedColor: sub,
                onTap: yearlyPlans.isEmpty
                    ? null
                    : () {
                        if (!canChangePlan) {
                          return;
                        }

                        HapticFeedback.selectionClick();
                        controller.selectPlan(yearlyPlans.first.planCode);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.plans.map(
          (plan) => _PlanCard(
            plan: plan,
            displayPrice: state.storePriceFor(plan),
            isSelected: state.selectedPlanCode == plan.planCode,
            isDark: isDark,
            onTap: () {
              if (!canChangePlan) {
                return;
              }

              controller.selectPlan(plan.planCode);
            },
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.displayPrice,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final PremiumPlanModel plan;
  final String? displayPrice;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final surface = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final borderRadius = BorderRadius.circular(18);

    final isYearly = _isYearlyPlan(plan);
    final title =
        '${text.premiumPageTitle} ${isYearly ? text.premiumYearlyPlan : text.premiumMonthlyPlan}';
    final priceStr = displayPrice ?? '\$${plan.priceAmount.toStringAsFixed(2)}';
    final interval = isYearly
        ? text.premiumYearlyPeriod
        : text.premiumMonthlyPeriod;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
      builder: (context, glow, child) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: isSelected ? 1.0 : 0.985,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2 + (0.08 * glow)),
                    blurRadius: 16 + (8 * glow),
                    spreadRadius: 0.2 + (0.6 * glow),
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: accent.withValues(alpha: 0.16),
          highlightColor: accent.withValues(alpha: 0.08),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected ? accent.withValues(alpha: 0.05) : surface,
              borderRadius: borderRadius,
              border: Border.all(
                color: isSelected ? accent : border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.08),
                                Colors.transparent,
                                accent.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                key: ValueKey(
                                  '${plan.planCode}:${isSelected ? 'on' : 'off'}',
                                ),
                                color: isSelected
                                    ? accent
                                    : (isDark
                                          ? const Color(0xFF3A3B4E)
                                          : const Color(0xFF97A8BD)),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (isSelected)
                                    _PlanBadge(
                                      label: text.premiumSelectedBadge,
                                      textColor: accent,
                                      fill: accent.withValues(alpha: 0.14),
                                      stroke: accent.withValues(alpha: 0.36),
                                    ),
                                  if (isYearly)
                                    _PlanBadge(
                                      label: text.premiumBestValueBadge,
                                      textColor: isDark
                                          ? const Color(0xFF13141F)
                                          : Colors.white,
                                      fill: isSelected
                                          ? accent
                                          : accent.withValues(alpha: 0.7),
                                      stroke: Colors.transparent,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 30),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    text.premiumCancelAnytime,
                                    style: TextStyle(color: sub, fontSize: 12),
                                  ),
                                  if (isYearly) ...[
                                    const SizedBox(height: 6),
                                    _PlanBadge(
                                      label: text.premiumDiscountLabel(33),
                                      textColor: accent,
                                      fill: accent.withValues(alpha: 0.14),
                                      stroke: Colors.transparent,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  priceStr,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  interval,
                                  style: TextStyle(color: sub, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.textColor,
    required this.fill,
    required this.stroke,
  });

  final String label;
  final Color textColor;
  final Color fill;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _BillingChip extends StatelessWidget {
  const _BillingChip({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color accent;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? accent.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: isActive ? accent : border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  isActive ? Icons.bolt_rounded : Icons.circle_outlined,
                  key: ValueKey('$label:$isActive'),
                  size: 15,
                  color: isActive ? accent : mutedColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? textColor : mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
