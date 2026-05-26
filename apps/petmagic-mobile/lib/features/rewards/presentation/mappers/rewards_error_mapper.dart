import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

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

  return friendlyRewardsError(text, raw);
}

String friendlyRewardsError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('auth.sign_in_required')) {
    return text.authRequiredMessage;
  }

  if (value.contains('auth.session_expired')) {
    return text.authExternalSessionExpired;
  }

  if (value.contains('referral_code_not_found')) {
    return text.rewardsReferralCodeNotFoundError;
  }

  if (value.contains('referral_self_referral')) {
    return text.rewardsReferralSelfError;
  }

  if (value.contains('referral_already_linked')) {
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

  return raw;
}
