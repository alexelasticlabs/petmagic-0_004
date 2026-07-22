import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

WalletStateModel mapWalletStateFromJson(Map<String, dynamic> json) {
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

WalletLedgerItem mapWalletLedgerItemFromJson(Map<String, dynamic> json) {
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

RewardsSummaryModel mapRewardsSummaryFromJson(Map<String, dynamic> json) {
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

CurrencyPackModel mapCurrencyPackFromJson(Map<String, dynamic> json) {
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

WalletPaymentMethodModel mapWalletPaymentMethodFromJson(
  Map<String, dynamic> json,
) {
  return WalletPaymentMethodModel(
    provider: json['provider'] as String? ?? 'stripe',
    purchaseChannel: json['purchaseChannel'] as String? ?? 'web',
    platform: json['platform'] as String? ?? '',
    region: json['region'] as String? ?? '',
    isEnabled: json['isEnabled'] as bool? ?? false,
    isSelectedByDefault: json['isSelectedByDefault'] as bool? ?? false,
    requiresExternalWarning: json['requiresExternalWarning'] as bool? ?? false,
    requiresStoreDisclosure: json['requiresStoreDisclosure'] as bool? ?? false,
    isRecommended: json['isRecommended'] as bool? ?? false,
    bonusTokensPercent: (json['bonusTokensPercent'] as num?)?.toInt() ?? 0,
    displayLabel: json['displayLabel'] as String?,
    displaySubtitle: json['displaySubtitle'] as String?,
    warningTitle: json['warningTitle'] as String?,
    warningMessage: json['warningMessage'] as String?,
    notes: json['notes'] as String?,
  );
}

WalletCheckoutConfigModel mapWalletCheckoutConfigFromJson(
  Map<String, dynamic> json,
) {
  return WalletCheckoutConfigModel(
    packs: (json['packs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(mapCurrencyPackFromJson)
        .toList(growable: false),
    paymentMethods:
        (json['availablePaymentMethods'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(mapWalletPaymentMethodFromJson)
            .toList(growable: false),
    externalPaymentWarningRequired:
        json['externalPaymentWarningRequired'] as bool? ?? false,
  );
}

PurchaseCheckoutModel mapPurchaseCheckoutFromJson(Map<String, dynamic> json) {
  return PurchaseCheckoutModel(
    orderId: json['orderId'] as String? ?? '',
    paymentProvider: json['paymentProvider'] as String? ?? '',
    checkoutUrl: json['checkoutUrl'] as String? ?? '',
    externalPaymentId: json['externalPaymentId'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

PurchaseHistoryItem mapPurchaseHistoryItemFromJson(Map<String, dynamic> json) {
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

StoreBillingValidationModel mapStoreBillingValidationFromJson(
  Map<String, dynamic> json,
) {
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

OffsetPagedModel<T> mapOffsetPageFromJson<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) mapItem,
) {
  return OffsetPagedModel(
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(mapItem)
        .toList(growable: false),
    skip: (json['skip'] as num?)?.toInt() ?? 0,
    take: (json['take'] as num?)?.toInt() ?? 0,
    hasMore: json['hasMore'] as bool? ?? false,
  );
}
