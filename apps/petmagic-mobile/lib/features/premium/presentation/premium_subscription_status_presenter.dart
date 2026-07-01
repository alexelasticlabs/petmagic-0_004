import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

String premiumSubscriptionStatusLabel({
  required AppLocalizations text,
  required bool isPremium,
  required bool cancelAtPeriodEnd,
  required String status,
}) {
  if (!isPremium) {
    return text.subscriptionStatusInactive;
  }

  if (cancelAtPeriodEnd) {
    return text.subscriptionStatusCancelled;
  }

  return switch (status.trim().toLowerCase()) {
    'active' || 'trialing' => text.subscriptionStatusActive,
    'past_due' || 'unpaid' => text.subscriptionStatusPaymentFailed,
    'canceled' => text.subscriptionStatusExpired,
    'incomplete' || 'incomplete_expired' => text.subscriptionStatusPending,
    _ => text.subscriptionStatusActive,
  };
}
