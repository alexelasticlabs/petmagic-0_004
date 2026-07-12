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
    this.currentPeriodStartUtc,
    this.currentPeriodEndUtc,
    this.lastTokenGrantAtUtc,
    this.cardBrand,
    this.cardLast4,
    this.weeklyGrantAmount,
  });

  final bool isPremium;
  final bool canManageBilling;
  final String? paymentProvider;
  final String? purchaseChannel;
  final String status;
  final String? planName;
  final String? billingPeriod;
  final DateTime? currentPeriodStartUtc;
  final DateTime? currentPeriodEndUtc;
  final DateTime? lastTokenGrantAtUtc;
  final String? cardBrand;
  final String? cardLast4;
  final bool cancelAtPeriodEnd;
  final int monthlyTokenLimit;
  final int tokensAvailable;
  final bool canManageSubscription;
  final String manageSubscriptionAction;
  final int? weeklyGrantAmount;

  PremiumPaymentProvider? get provider {
    final rawValue = paymentProvider;
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return PremiumPaymentProvider.fromValue(rawValue);
  }
}

class PremiumCheckoutModel {
  const PremiumCheckoutModel({
    required this.paymentProvider,
    required this.checkoutUrl,
    required this.status,
    required this.externalSubscriptionId,
  });

  final String paymentProvider;
  final String checkoutUrl;
  final String status;
  final String externalSubscriptionId;
}

class PremiumBillingPortalModel {
  const PremiumBillingPortalModel({
    required this.paymentProvider,
    required this.portalUrl,
  });

  final String paymentProvider;
  final String portalUrl;
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
}

// Premium domain read models. JSON mapping remains compatibility-preserving.
