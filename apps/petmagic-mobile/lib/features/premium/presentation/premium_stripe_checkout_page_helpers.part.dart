part of 'premium_stripe_checkout_page.dart';

String _planTitle(AppLocalizations text, PremiumPlanModel plan) {
  return _isYearlyPlan(plan) ? text.premiumYearlyPlan : text.premiumMonthlyPlan;
}

String _planPeriodLabel(AppLocalizations text, PremiumPlanModel plan) {
  return _isYearlyPlan(plan)
      ? text.premiumCheckoutPeriodYearly
      : text.premiumCheckoutPeriodMonthly;
}

bool _isYearlyPlan(PremiumPlanModel plan) {
  final value = '${plan.billingInterval}:${plan.planCode}'.toLowerCase();
  return value.contains('year') || value.contains('annual');
}
