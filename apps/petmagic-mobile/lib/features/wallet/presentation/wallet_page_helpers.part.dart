part of 'wallet_page.dart';

String _walletProviderLabel(
  AppLocalizations text,
  WalletPaymentMethodModel method,
) {
  final provider = method.provider.trim().toLowerCase();
  final customLabel = method.displayLabel?.trim();
  if (customLabel != null && customLabel.isNotEmpty) {
    return customLabel;
  }

  return switch (provider) {
    'stripe' => text.premiumPaymentStripe,
    'google_play' => text.premiumPaymentGooglePlay,
    'app_store' => text.premiumPaymentApple,
    _ => text.premiumPaymentOther,
  };
}

IconData _walletProviderIcon(WalletPaymentMethodModel method) {
  final provider = method.provider.trim().toLowerCase();
  return switch (provider) {
    'stripe' => Icons.credit_card_rounded,
    'google_play' => Icons.android_rounded,
    'app_store' => Icons.apple_rounded,
    _ => Icons.payments_rounded,
  };
}

String? _walletStoreUnavailableSubtitle(
  AppLocalizations text,
  WalletPaymentMethodModel method,
) {
  final provider = method.provider.trim().toLowerCase();
  return switch (provider) {
    'google_play' => text.walletPaymentStoreUnavailableGooglePlay,
    'app_store' => text.walletPaymentStoreUnavailableAppStore,
    _ => method.displaySubtitle,
  };
}

String _valuePerCurrencyLabel(AppLocalizations text, CurrencyPackModel pack) {
  if (pack.priceAmount <= 0) {
    return '-';
  }

  final sparkPerUnit = pack.totalSpark / pack.priceAmount;
  final formatted = NumberFormat('0.0').format(sparkPerUnit);
  return '$formatted ${text.walletBalanceUnit} / ${pack.currencyCode}1';
}

String _formatPrice(CurrencyPackModel pack) {
  return NumberFormat.simpleCurrency(
    name: pack.currencyCode,
  ).format(pack.priceAmount);
}

String? _storePriceForPack(
  CurrencyPackModel pack,
  Map<String, String> storeProductPrices,
) {
  final googlePrice = pack.googlePlayProductId == null
      ? null
      : storeProductPrices[pack.googlePlayProductId];
  if (googlePrice != null && googlePrice.isNotEmpty) {
    return googlePrice;
  }

  final appStorePrice = pack.appStoreProductId == null
      ? null
      : storeProductPrices[pack.appStoreProductId];
  return appStorePrice?.isEmpty == true ? null : appStorePrice;
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AppLocalizations.of(context).walletPending;
  }

  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value.toLocal());
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' => text.walletSourcePackPurchase,
    'generation_spend' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'promo_redeem' || 'redeem_code' => text.walletSourcePromoCode,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
    _ => text.walletSourceOther,
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'pack_purchase' => Icons.account_balance_wallet_rounded,
    'generation_spend' => Icons.auto_awesome_rounded,
    'generation_refund' => Icons.undo_rounded,
    'weekly_grant' ||
    'premium_subscription_weekly_grant' => Icons.card_giftcard_rounded,
    'ad_reward' => Icons.play_circle_fill_rounded,
    'promo_redeem' || 'redeem_code' => Icons.confirmation_number_rounded,
    'admin_grant' => Icons.support_agent_rounded,
    'admin_debit' => Icons.remove_circle_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _purchaseStatusLabel(AppLocalizations text, String status) {
  return switch (status) {
    'succeeded' => text.walletPurchaseCompleted,
    'failed' => text.walletPurchaseFailed,
    _ => text.walletPending,
  };
}

Color _purchaseStatusColor(String status, PetMagicColors colors) {
  return switch (status) {
    'succeeded' => colors.accent,
    'failed' => colors.danger,
    _ => colors.gold,
  };
}

Color _ledgerTone(WalletLedgerItem item, PetMagicColors colors) {
  return switch (item.source) {
    'generation_spend' || 'admin_debit' => colors.danger,
    'generation_refund' => colors.textMuted,
    _ => item.delta >= 0 ? colors.accent : colors.danger,
  };
}

String _friendlyError(AppLocalizations text, String value) {
  final authMessage = mapCommonAuthFeedbackMessage(
    text,
    value,
    preferAuthRequiredMessage: true,
  );
  if (authMessage != null) {
    return authMessage;
  }

  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return text.walletPartialActivityUnavailable;
  }

  if (value.contains('payment_gateway_failed')) {
    return text.walletPaymentGatewayUnavailableError;
  }

  if (value.contains('wallet.payment_unavailable')) {
    return text.walletPaymentUnavailableError;
  }

  if (value.contains('economy.pack_not_found')) {
    return text.walletPackUnavailableError;
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

  if (value.contains('economy.insufficient_balance')) {
    return text.walletInsufficientBalanceError;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable')) {
    return text.walletRedeemServerError;
  }

  if (value.contains('wallet.request_failed') ||
      value.contains('wallet.bad_request')) {
    return text.walletRedeemServerError;
  }

  if (value.toLowerCase().contains('debugpaintbaselinesenabled')) {
    return text.walletDataUnavailableFallback;
  }

  if (value.contains('wallet.server_error') ||
      value.contains('wallet.internal_error') ||
      value.contains('processing your request')) {
    return text.walletRedeemServerError;
  }

  return text.walletDataUnavailableFallback;
}

bool _isWalletPartialError(String value) {
  return value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed');
}
