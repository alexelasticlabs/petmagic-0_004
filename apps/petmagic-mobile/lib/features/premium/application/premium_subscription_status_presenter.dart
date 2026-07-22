enum PremiumSubscriptionStatusKind {
  inactive,
  cancelled,
  active,
  paymentFailed,
  expired,
  pending,
}

PremiumSubscriptionStatusKind classifyPremiumSubscriptionStatus({
  required bool isPremium,
  required bool cancelAtPeriodEnd,
  required String status,
}) {
  if (!isPremium) {
    return PremiumSubscriptionStatusKind.inactive;
  }

  if (cancelAtPeriodEnd) {
    return PremiumSubscriptionStatusKind.cancelled;
  }

  return switch (status.trim().toLowerCase()) {
    'active' || 'trialing' => PremiumSubscriptionStatusKind.active,
    'past_due' || 'unpaid' => PremiumSubscriptionStatusKind.paymentFailed,
    'canceled' => PremiumSubscriptionStatusKind.expired,
    'incomplete' ||
    'incomplete_expired' => PremiumSubscriptionStatusKind.pending,
    _ => PremiumSubscriptionStatusKind.active,
  };
}
