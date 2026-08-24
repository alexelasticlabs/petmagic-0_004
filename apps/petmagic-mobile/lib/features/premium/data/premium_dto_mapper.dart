import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';

PremiumPaymentMethodModel mapPremiumPaymentMethodFromJson(
  Map<String, dynamic> json,
) {
  return PremiumPaymentMethodModel(
    provider: PremiumPaymentProvider.fromValue(
      json['provider'] as String? ?? 'stripe',
    ),
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

PremiumLegalTextsModel mapPremiumLegalTextsFromJson(Map<String, dynamic> json) {
  return PremiumLegalTextsModel(
    storeNotice: json['storeNotice'] as String? ?? '',
    externalCheckoutNotice: json['externalCheckoutNotice'] as String? ?? '',
    stripeNotice: json['stripeNotice'] as String? ?? '',
  );
}

PremiumPaywallConfigModel mapPremiumPaywallConfigFromJson(
  Map<String, dynamic> json,
) {
  return PremiumPaywallConfigModel(
    plans: (json['plans'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(mapPremiumPlanFromJson)
        .toList(growable: false),
    recommendedPlanCode: json['recommendedPlan'] as String?,
    paymentMethods:
        (json['availablePaymentMethods'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(mapPremiumPaymentMethodFromJson)
            .toList(growable: false),
    legalTexts: mapPremiumLegalTextsFromJson(
      json['legalTexts'] as Map<String, dynamic>? ?? const {},
    ),
    externalPaymentWarningRequired:
        json['externalPaymentWarningRequired'] as bool? ?? false,
  );
}

PremiumPlanModel mapPremiumPlanFromJson(Map<String, dynamic> json) {
  return PremiumPlanModel(
    planCode: (json['planCode'] ?? json['planId']) as String? ?? '',
    billingInterval:
        (json['billingInterval'] ?? json['billingPeriod']) as String? ??
        'month',
    priceAmount: (json['priceAmount'] as num?)?.toDouble() ?? 0,
    compareAtPriceAmount: (json['compareAtPriceAmount'] as num?)?.toDouble(),
    currencyCode: json['currencyCode'] as String? ?? 'USD',
    tokenAllowance:
        ((json['tokenAllowance'] ?? json['monthlyTokenLimit']) as num?)
            ?.toInt() ??
        0,
    isPopular:
        (json['isPopular'] as bool?) ??
        (json['isRecommended'] as bool?) ??
        false,
    discountPercent: (json['discountPercent'] as num?)?.toInt(),
    sortOrder:
        ((json['sortOrder'] ?? json['displayOrder']) as num?)?.toInt() ?? 0,
    stripeCheckoutEnabled: json['stripeCheckoutEnabled'] as bool? ?? true,
    googlePlayProductId:
        (json['googlePlayProductId'] ?? json['googleProductId']) as String?,
    appStoreProductId:
        (json['appStoreProductId'] ?? json['appleProductId']) as String?,
  );
}

PremiumStatusModel mapPremiumStatusFromJson(Map<String, dynamic> json) {
  return PremiumStatusModel(
    isPremium: json['isPremium'] as bool? ?? false,
    canManageBilling:
        (json['canManageBilling'] as bool?) ??
        (json['canManageSubscription'] as bool?) ??
        false,
    paymentProvider: (json['paymentProvider'] ?? json['provider']) as String?,
    purchaseChannel: json['purchaseChannel'] as String?,
    status: json['status'] as String? ?? 'None',
    planName: json['planName'] as String?,
    billingPeriod: json['billingPeriod'] as String?,
    currentPeriodStartUtc: json['currentPeriodStartUtc'] == null
        ? null
        : DateTime.tryParse(json['currentPeriodStartUtc'] as String),
    currentPeriodEndUtc: json['currentPeriodEndUtc'] == null
        ? (json['currentPeriodEnd'] == null
              ? null
              : DateTime.tryParse(json['currentPeriodEnd'] as String))
        : DateTime.tryParse(json['currentPeriodEndUtc'] as String),
    lastTokenGrantAtUtc: json['lastTokenGrantAtUtc'] == null
        ? null
        : DateTime.tryParse(json['lastTokenGrantAtUtc'] as String),
    cardBrand: json['cardBrand'] as String?,
    cardLast4: json['cardLast4'] as String?,
    cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
    monthlyTokenLimit: (json['monthlyTokenLimit'] as num?)?.toInt() ?? 0,
    tokensAvailable: (json['tokensAvailable'] as num?)?.toInt() ?? 0,
    canManageSubscription: json['canManageSubscription'] as bool? ?? false,
    manageSubscriptionAction:
        json['manageSubscriptionAction'] as String? ?? 'None',
    weeklyGrantAmount: (json['weeklyGrantAmount'] as num?)?.toInt(),
  );
}

PremiumCheckoutModel mapPremiumCheckoutFromJson(Map<String, dynamic> json) {
  return PremiumCheckoutModel(
    paymentProvider: json['paymentProvider'] as String? ?? '',
    checkoutUrl: json['checkoutUrl'] as String? ?? '',
    status: json['status'] as String? ?? '',
    externalSubscriptionId: json['externalSubscriptionId'] as String? ?? '',
    paymentIntentClientSecret:
        json['paymentIntentClientSecret'] as String? ?? '',
    customerId: json['customerId'] as String? ?? '',
    customerEphemeralKeySecret:
        json['customerEphemeralKeySecret'] as String? ?? '',
    publishableKey: json['publishableKey'] as String? ?? '',
  );
}

PremiumBillingPortalModel mapPremiumBillingPortalFromJson(
  Map<String, dynamic> json,
) {
  return PremiumBillingPortalModel(
    paymentProvider: json['paymentProvider'] as String? ?? '',
    portalUrl: json['portalUrl'] as String? ?? '',
  );
}

PremiumStoreVerificationModel mapPremiumStoreVerificationFromJson(
  Map<String, dynamic> json,
) {
  return PremiumStoreVerificationModel(
    paymentProvider: json['paymentProvider'] as String? ?? '',
    productId: json['productId'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
    expiresAtUtc: json['expiresAtUtc'] == null
        ? null
        : DateTime.tryParse(json['expiresAtUtc'] as String),
    status: json['status'] as String? ?? '',
  );
}
