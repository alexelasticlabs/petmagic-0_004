/// Domain snapshot of the user's wallet.
class WalletStateModel {
  const WalletStateModel({
    required this.userId,
    required this.balance,
    required this.adRewardsRemainingToday,
    required this.isPremium,
    required this.updatedAtUtc,
    this.nextWeeklyGrantAtUtc,
  });

  final String userId;
  final int balance;
  final DateTime? nextWeeklyGrantAtUtc;
  final int adRewardsRemainingToday;
  final bool isPremium;
  final DateTime? updatedAtUtc;
}

class WalletLedgerItem {
  const WalletLedgerItem({
    required this.entryId,
    required this.userId,
    required this.delta,
    required this.balanceAfter,
    required this.source,
    required this.reason,
    required this.createdAtUtc,
  });

  final String entryId;
  final String userId;
  final int delta;
  final int balanceAfter;
  final String source;
  final String reason;
  final DateTime? createdAtUtc;
}

class RewardsSummaryModel {
  const RewardsSummaryModel({
    required this.referralCode,
    required this.referralBonusSpark,
    required this.referralStatus,
    required this.totalReferralBonusEarned,
    required this.referredUsersCount,
    required this.pendingReferredUsersCount,
    required this.rewardedReferredUsersCount,
    this.referrerCode,
    this.referralActivatedAtUtc,
    this.referralQualifiedAtUtc,
  });

  final String referralCode;
  final int referralBonusSpark;
  final String referralStatus;
  final String? referrerCode;
  final DateTime? referralActivatedAtUtc;
  final DateTime? referralQualifiedAtUtc;
  final int totalReferralBonusEarned;
  final int referredUsersCount;
  final int pendingReferredUsersCount;
  final int rewardedReferredUsersCount;

  bool get hasActivatedReferral => referralStatus != 'none';
  bool get isReferralRewarded => referralStatus == 'rewarded';
}

class CurrencyPackModel {
  const CurrencyPackModel({
    required this.packId,
    required this.code,
    required this.displayName,
    required this.currencyCode,
    required this.priceAmount,
    required this.grantedSpark,
    required this.bonusSpark,
    required this.totalSpark,
    this.googlePlayProductId,
    this.appStoreProductId,
  });

  final String packId;
  final String code;
  final String displayName;
  final String currencyCode;
  final double priceAmount;
  final int grantedSpark;
  final int bonusSpark;
  final int totalSpark;
  final String? googlePlayProductId;
  final String? appStoreProductId;
  String? productIdForProvider(String provider) {
    final normalizedProvider = provider.trim().toLowerCase();
    return switch (normalizedProvider) {
      'google_play' => googlePlayProductId,
      'app_store' => appStoreProductId,
      _ => null,
    };
  }
}

class WalletPaymentMethodModel {
  const WalletPaymentMethodModel({
    required this.provider,
    required this.purchaseChannel,
    required this.platform,
    required this.region,
    required this.isEnabled,
    required this.isSelectedByDefault,
    required this.requiresExternalWarning,
    required this.requiresStoreDisclosure,
    required this.isRecommended,
    required this.bonusTokensPercent,
    this.displayLabel,
    this.displaySubtitle,
    this.warningTitle,
    this.warningMessage,
    this.notes,
  });

  final String provider;
  final String purchaseChannel;
  final String platform;
  final String region;
  final bool isEnabled;
  final bool isSelectedByDefault;
  final bool requiresExternalWarning;
  final bool requiresStoreDisclosure;
  final bool isRecommended;
  final int bonusTokensPercent;
  final String? displayLabel;
  final String? displaySubtitle;
  final String? warningTitle;
  final String? warningMessage;
  final String? notes;

  bool get isStripe => provider.toLowerCase() == 'stripe';

  bool get isStoreNative {
    final normalized = provider.toLowerCase();
    return normalized == 'google_play' || normalized == 'app_store';
  }
}

class WalletCheckoutConfigModel {
  const WalletCheckoutConfigModel({
    required this.packs,
    required this.paymentMethods,
    required this.externalPaymentWarningRequired,
  });

  final List<CurrencyPackModel> packs;
  final List<WalletPaymentMethodModel> paymentMethods;
  final bool externalPaymentWarningRequired;
}

class PurchaseCheckoutModel {
  const PurchaseCheckoutModel({
    required this.orderId,
    required this.paymentProvider,
    required this.checkoutUrl,
    required this.externalPaymentId,
    required this.status,
    this.paymentIntentClientSecret = '',
    this.customerId = '',
    this.customerEphemeralKeySecret = '',
    this.publishableKey = '',
  });

  final String orderId;
  final String paymentProvider;
  final String checkoutUrl;
  final String externalPaymentId;
  final String status;
  final String paymentIntentClientSecret;
  final String customerId;
  final String customerEphemeralKeySecret;
  final String publishableKey;

  bool get hasNativeStripePaymentSheet =>
      paymentIntentClientSecret.trim().isNotEmpty &&
      customerId.trim().isNotEmpty &&
      customerEphemeralKeySecret.trim().isNotEmpty &&
      publishableKey.trim().isNotEmpty;
}

class PurchaseHistoryItem {
  const PurchaseHistoryItem({
    required this.orderId,
    required this.packDisplayName,
    required this.paymentProvider,
    required this.status,
    required this.priceAmount,
    required this.currencyCode,
    required this.sparkToGrant,
    required this.createdAtUtc,
    this.confirmedAtUtc,
  });

  final String orderId;
  final String packDisplayName;
  final String paymentProvider;
  final String status;
  final double priceAmount;
  final String currencyCode;
  final int sparkToGrant;
  final DateTime? createdAtUtc;
  final DateTime? confirmedAtUtc;
}

class StoreBillingValidationModel {
  const StoreBillingValidationModel({
    required this.provider,
    required this.productType,
    required this.productId,
    required this.status,
    required this.tokensGranted,
    required this.tokenAmount,
    required this.isPremium,
    this.expiresAtUtc,
  });

  final String provider;
  final String productType;
  final String productId;
  final String status;
  final bool tokensGranted;
  final int tokenAmount;
  final bool isPremium;
  final DateTime? expiresAtUtc;

  bool get isTokenPack => productType.toLowerCase() == 'tokenpack';

  bool get isSettledTokenPack {
    final normalizedStatus = status.trim().toLowerCase();
    return isTokenPack &&
        (tokensGranted ||
            normalizedStatus == 'succeeded' ||
            normalizedStatus == 'settled' ||
            normalizedStatus == 'already_settled');
  }
}

class OffsetPagedModel<T> {
  const OffsetPagedModel({
    required this.items,
    required this.skip,
    required this.take,
    required this.hasMore,
  });

  final List<T> items;
  final int skip;
  final int take;
  final bool hasMore;
}
