enum PremiumPaymentProvider {
  stripe('stripe'),
  googlePlay('google_play'),
  appStore('app_store');

  const PremiumPaymentProvider(this.value);

  final String value;

  static PremiumPaymentProvider fromValue(String value) {
    return PremiumPaymentProvider.values.firstWhere(
      (provider) => provider.value == value,
      orElse: () => PremiumPaymentProvider.stripe,
    );
  }
}

class PremiumPaymentMethodModel {
  const PremiumPaymentMethodModel({
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

  final PremiumPaymentProvider provider;
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

  bool get isStoreNative =>
      purchaseChannel == 'in_app' && provider != PremiumPaymentProvider.stripe;

  bool get isExternalStripeFlow =>
      provider == PremiumPaymentProvider.stripe &&
      purchaseChannel != 'web' &&
      purchaseChannel != 'in_app';

  factory PremiumPaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PremiumPaymentMethodModel(
      provider: PremiumPaymentProvider.fromValue(
        json['provider'] as String? ?? 'stripe',
      ),
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

class PremiumLegalTextsModel {
  const PremiumLegalTextsModel({
    required this.storeNotice,
    required this.externalCheckoutNotice,
    required this.stripeNotice,
  });

  final String storeNotice;
  final String externalCheckoutNotice;
  final String stripeNotice;

  factory PremiumLegalTextsModel.fromJson(Map<String, dynamic> json) {
    return PremiumLegalTextsModel(
      storeNotice: json['storeNotice'] as String? ?? '',
      externalCheckoutNotice: json['externalCheckoutNotice'] as String? ?? '',
      stripeNotice: json['stripeNotice'] as String? ?? '',
    );
  }
}

class PremiumPaywallConfigModel {
  const PremiumPaywallConfigModel({
    required this.plans,
    required this.paymentMethods,
    required this.legalTexts,
    required this.externalPaymentWarningRequired,
    this.recommendedPlanCode,
  });

  final List<PremiumPlanModel> plans;
  final String? recommendedPlanCode;
  final List<PremiumPaymentMethodModel> paymentMethods;
  final PremiumLegalTextsModel legalTexts;
  final bool externalPaymentWarningRequired;

  factory PremiumPaywallConfigModel.fromJson(Map<String, dynamic> json) {
    return PremiumPaywallConfigModel(
      plans: (json['plans'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PremiumPlanModel.fromJson)
          .toList(growable: false),
      recommendedPlanCode: json['recommendedPlan'] as String?,
      paymentMethods:
          (json['availablePaymentMethods'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PremiumPaymentMethodModel.fromJson)
              .toList(growable: false),
      legalTexts: PremiumLegalTextsModel.fromJson(
        json['legalTexts'] as Map<String, dynamic>? ?? const {},
      ),
      externalPaymentWarningRequired:
          json['externalPaymentWarningRequired'] as bool? ?? false,
    );
  }
}

class PremiumPlanModel {
  const PremiumPlanModel({
    required this.planCode,
    required this.billingInterval,
    required this.priceAmount,
    required this.currencyCode,
    required this.tokenAllowance,
    required this.isPopular,
    required this.sortOrder,
    required this.stripeCheckoutEnabled,
    this.googlePlayProductId,
    this.appStoreProductId,
    this.compareAtPriceAmount,
    this.discountPercent,
  });

  final String planCode;
  final String billingInterval;
  final double priceAmount;
  final double? compareAtPriceAmount;
  final String currencyCode;
  final int tokenAllowance;
  final bool isPopular;
  final int? discountPercent;
  final int sortOrder;
  final bool stripeCheckoutEnabled;
  final String? googlePlayProductId;
  final String? appStoreProductId;

  factory PremiumPlanModel.fromJson(Map<String, dynamic> json) {
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

  String? productIdFor(PremiumPaymentProvider provider) {
    return switch (provider) {
      PremiumPaymentProvider.stripe => null,
      PremiumPaymentProvider.googlePlay => googlePlayProductId,
      PremiumPaymentProvider.appStore => appStoreProductId,
    };
  }
}

class PremiumStatusModel {
  const PremiumStatusModel({
    required this.isPremium,
    required this.canManageBilling,
    required this.status,
    required this.cancelAtPeriodEnd,
    required this.monthlyTokenLimit,
    required this.tokensAvailable,
    required this.canManageSubscription,
    required this.manageSubscriptionAction,
    this.paymentProvider,
    this.purchaseChannel,
    this.planName,
    this.billingPeriod,
    this.currentPeriodEndUtc,
  });

  final bool isPremium;
  final bool canManageBilling;
  final String? paymentProvider;
  final String? purchaseChannel;
  final String status;
  final String? planName;
  final String? billingPeriod;
  final DateTime? currentPeriodEndUtc;
  final bool cancelAtPeriodEnd;
  final int monthlyTokenLimit;
  final int tokensAvailable;
  final bool canManageSubscription;
  final String manageSubscriptionAction;

  PremiumPaymentProvider? get provider {
    final rawValue = paymentProvider;
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return PremiumPaymentProvider.fromValue(rawValue);
  }

  factory PremiumStatusModel.fromJson(Map<String, dynamic> json) {
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
      currentPeriodEndUtc: json['currentPeriodEndUtc'] == null
          ? (json['currentPeriodEnd'] == null
                ? null
                : DateTime.tryParse(json['currentPeriodEnd'] as String))
          : DateTime.tryParse(json['currentPeriodEndUtc'] as String),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      monthlyTokenLimit: (json['monthlyTokenLimit'] as num?)?.toInt() ?? 0,
      tokensAvailable: (json['tokensAvailable'] as num?)?.toInt() ?? 0,
      canManageSubscription: json['canManageSubscription'] as bool? ?? false,
      manageSubscriptionAction:
          json['manageSubscriptionAction'] as String? ?? 'None',
    );
  }
}

class PremiumCheckoutModel {
  const PremiumCheckoutModel({
    required this.paymentProvider,
    required this.checkoutUrl,
    required this.status,
  });

  final String paymentProvider;
  final String checkoutUrl;
  final String status;

  factory PremiumCheckoutModel.fromJson(Map<String, dynamic> json) {
    return PremiumCheckoutModel(
      paymentProvider: json['paymentProvider'] as String? ?? '',
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class PremiumBillingPortalModel {
  const PremiumBillingPortalModel({
    required this.paymentProvider,
    required this.portalUrl,
  });

  final String paymentProvider;
  final String portalUrl;

  factory PremiumBillingPortalModel.fromJson(Map<String, dynamic> json) {
    return PremiumBillingPortalModel(
      paymentProvider: json['paymentProvider'] as String? ?? '',
      portalUrl: json['portalUrl'] as String? ?? '',
    );
  }
}

class PremiumStoreVerificationModel {
  const PremiumStoreVerificationModel({
    required this.paymentProvider,
    required this.productId,
    required this.isActive,
    required this.status,
    this.expiresAtUtc,
  });

  final String paymentProvider;
  final String productId;
  final bool isActive;
  final DateTime? expiresAtUtc;
  final String status;

  factory PremiumStoreVerificationModel.fromJson(Map<String, dynamic> json) {
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
}
