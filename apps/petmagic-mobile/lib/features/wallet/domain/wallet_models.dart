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

  factory WalletStateModel.fromJson(Map<String, dynamic> json) {
    return WalletStateModel(
      userId: json['userId'] as String? ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      nextWeeklyGrantAtUtc: json['nextWeeklyGrantAtUtc'] is String
          ? DateTime.tryParse(json['nextWeeklyGrantAtUtc'] as String)
          : null,
      adRewardsRemainingToday:
          (json['adRewardsRemainingToday'] as num?)?.toInt() ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      updatedAtUtc: json['updatedAtUtc'] is String
          ? DateTime.tryParse(json['updatedAtUtc'] as String)
          : null,
    );
  }
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

  factory WalletLedgerItem.fromJson(Map<String, dynamic> json) {
    return WalletLedgerItem(
      entryId: json['entryId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      createdAtUtc: json['createdAtUtc'] is String
          ? DateTime.tryParse(json['createdAtUtc'] as String)
          : null,
    );
  }
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

  factory RewardsSummaryModel.fromJson(Map<String, dynamic> json) {
    return RewardsSummaryModel(
      referralCode: json['referralCode'] as String? ?? '',
      referralBonusSpark: (json['referralBonusSpark'] as num?)?.toInt() ?? 0,
      referralStatus: json['referralStatus'] as String? ?? 'none',
      referrerCode: json['referrerCode'] as String?,
      referralActivatedAtUtc: json['referralActivatedAtUtc'] is String
          ? DateTime.tryParse(json['referralActivatedAtUtc'] as String)
          : null,
      referralQualifiedAtUtc: json['referralQualifiedAtUtc'] is String
          ? DateTime.tryParse(json['referralQualifiedAtUtc'] as String)
          : null,
      totalReferralBonusEarned:
          (json['totalReferralBonusEarned'] as num?)?.toInt() ?? 0,
      referredUsersCount: (json['referredUsersCount'] as num?)?.toInt() ?? 0,
      pendingReferredUsersCount:
          (json['pendingReferredUsersCount'] as num?)?.toInt() ?? 0,
      rewardedReferredUsersCount:
          (json['rewardedReferredUsersCount'] as num?)?.toInt() ?? 0,
    );
  }
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

  factory CurrencyPackModel.fromJson(Map<String, dynamic> json) {
    return CurrencyPackModel(
      packId: json['packId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      priceAmount: (json['priceAmount'] as num?)?.toDouble() ?? 0,
      grantedSpark: (json['grantedSpark'] as num?)?.toInt() ?? 0,
      bonusSpark: (json['bonusSpark'] as num?)?.toInt() ?? 0,
      totalSpark: (json['totalSpark'] as num?)?.toInt() ?? 0,
      googlePlayProductId: json['googlePlayProductId'] as String?,
      appStoreProductId: json['appStoreProductId'] as String?,
    );
  }

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

  factory WalletPaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return WalletPaymentMethodModel(
      provider: json['provider'] as String? ?? 'stripe',
      purchaseChannel: json['purchaseChannel'] as String? ?? 'web',
      platform: json['platform'] as String? ?? '',
      region: json['region'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? false,
      isSelectedByDefault: json['isSelectedByDefault'] as bool? ?? false,
      requiresExternalWarning:
          json['requiresExternalWarning'] as bool? ?? false,
      requiresStoreDisclosure:
          json['requiresStoreDisclosure'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      bonusTokensPercent: (json['bonusTokensPercent'] as num?)?.toInt() ?? 0,
      displayLabel: json['displayLabel'] as String?,
      displaySubtitle: json['displaySubtitle'] as String?,
      warningTitle: json['warningTitle'] as String?,
      warningMessage: json['warningMessage'] as String?,
      notes: json['notes'] as String?,
    );
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

  factory WalletCheckoutConfigModel.fromJson(Map<String, dynamic> json) {
    return WalletCheckoutConfigModel(
      packs: (json['packs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CurrencyPackModel.fromJson)
          .toList(growable: false),
      paymentMethods:
          (json['availablePaymentMethods'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WalletPaymentMethodModel.fromJson)
              .toList(growable: false),
      externalPaymentWarningRequired:
          json['externalPaymentWarningRequired'] as bool? ?? false,
    );
  }
}

class PurchaseCheckoutModel {
  const PurchaseCheckoutModel({
    required this.orderId,
    required this.paymentProvider,
    required this.checkoutUrl,
    required this.externalPaymentId,
    required this.status,
  });

  final String orderId;
  final String paymentProvider;
  final String checkoutUrl;
  final String externalPaymentId;
  final String status;

  factory PurchaseCheckoutModel.fromJson(Map<String, dynamic> json) {
    return PurchaseCheckoutModel(
      orderId: json['orderId'] as String? ?? '',
      paymentProvider: json['paymentProvider'] as String? ?? '',
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
      externalPaymentId: json['externalPaymentId'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
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

  factory PurchaseHistoryItem.fromJson(Map<String, dynamic> json) {
    return PurchaseHistoryItem(
      orderId: json['orderId'] as String? ?? '',
      packDisplayName: json['packDisplayName'] as String? ?? '',
      paymentProvider: json['paymentProvider'] as String? ?? '',
      status: json['status'] as String? ?? '',
      priceAmount: (json['priceAmount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      sparkToGrant: (json['sparkToGrant'] as num?)?.toInt() ?? 0,
      createdAtUtc: json['createdAtUtc'] is String
          ? DateTime.tryParse(json['createdAtUtc'] as String)
          : null,
      confirmedAtUtc: json['confirmedAtUtc'] is String
          ? DateTime.tryParse(json['confirmedAtUtc'] as String)
          : null,
    );
  }
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

  factory StoreBillingValidationModel.fromJson(Map<String, dynamic> json) {
    return StoreBillingValidationModel(
      provider: json['provider'] as String? ?? '',
      productType: json['productType'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      tokensGranted: json['tokensGranted'] as bool? ?? false,
      tokenAmount: (json['tokenAmount'] as num?)?.toInt() ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      expiresAtUtc: json['expiresAtUtc'] is String
          ? DateTime.tryParse(json['expiresAtUtc'] as String)
          : null,
    );
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

  factory OffsetPagedModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    return OffsetPagedModel(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(itemFromJson)
          .toList(growable: false),
      skip: (json['skip'] as num?)?.toInt() ?? 0,
      take: (json['take'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
