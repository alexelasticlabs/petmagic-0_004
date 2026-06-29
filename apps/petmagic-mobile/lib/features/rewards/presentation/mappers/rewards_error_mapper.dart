import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';

String? rewardsWarningMessage(AppLocalizations text, String? raw) {
  if (raw == null) {
    return null;
  }

  final value = raw.toLowerCase();
  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return null;
  }
  // Referral/promo actions are already shown as in-app push toasts.
  if (value.contains('referral_') ||
      value.contains('redeem_code') ||
      value.contains('users cannot activate their own referral code') ||
      value.contains('already linked') ||
      value.contains('already activated referral code')) {
    return null;
  }

  return friendlyRewardsError(text, raw);
}

String friendlyRewardsError(AppLocalizations text, String raw) {
  final authMessage = mapCommonAuthFeedbackMessage(
    text,
    raw,
    preferAuthRequiredMessage: true,
  );
  if (authMessage != null) {
    return authMessage;
  }

  final value = raw.toLowerCase();

  if (value.contains('referral_code_not_found')) {
    return text.rewardsReferralCodeNotFoundError;
  }

  if (value.contains('referral_self_referral')) {
    return text.rewardsReferralSelfError;
  }
  if (value.contains('users cannot activate their own referral code')) {
    return text.rewardsReferralSelfError;
  }

  if (value.contains('referral_already_linked')) {
    return text.rewardsReferralAlreadyLinkedError;
  }
  if (value.contains('already linked') ||
      value.contains('already activated referral code')) {
    return text.rewardsReferralAlreadyLinkedError;
  }

  if (value.contains('referral_paid_user_ineligible')) {
    return text.rewardsReferralPaidUserError;
  }

  if (value.contains('redeem_code_not_found')) {
    return text.walletRedeemCodeNotFoundError;
  }

  if (value.contains('redeem_code_already_used')) {
    return text.walletRedeemCodeAlreadyUsedError;
  }

  if (value.contains('redeem_code_expired')) {
    return text.walletRedeemCodeExpiredError;
  }

  if (value.contains('redeem_code_inactive')) {
    return text.walletRedeemCodeInactiveError;
  }

  if (value.contains('redeem_code_exhausted')) {
    return text.walletRedeemCodeExhaustedError;
  }

  if (value.contains('redeem_code_user_limit_reached')) {
    return text.walletRedeemCodeUserLimitError;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable') ||
      value.contains('rewards.summary_failed')) {
    return text.walletRedeemServerError;
  }

  // Never expose raw backend text to end users.
  return text.walletRedeemServerError;
}
