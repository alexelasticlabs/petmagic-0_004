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
      planCode: json['planCode'] as String? ?? '',
      billingInterval: json['billingInterval'] as String? ?? 'month',
      priceAmount: (json['priceAmount'] as num?)?.toDouble() ?? 0,
      compareAtPriceAmount: (json['compareAtPriceAmount'] as num?)?.toDouble(),
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      tokenAllowance: (json['tokenAllowance'] as num?)?.toInt() ?? 0,
      isPopular: json['isPopular'] as bool? ?? false,
      discountPercent: (json['discountPercent'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      stripeCheckoutEnabled: json['stripeCheckoutEnabled'] as bool? ?? false,
      googlePlayProductId: json['googlePlayProductId'] as String?,
      appStoreProductId: json['appStoreProductId'] as String?,
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
    this.paymentProvider,
  });

  final bool isPremium;
  final bool canManageBilling;
  final String? paymentProvider;

  factory PremiumStatusModel.fromJson(Map<String, dynamic> json) {
    return PremiumStatusModel(
      isPremium: json['isPremium'] as bool? ?? false,
      canManageBilling: json['canManageBilling'] as bool? ?? false,
      paymentProvider: json['paymentProvider'] as String?,
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
