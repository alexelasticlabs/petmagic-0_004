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
  });

  final String packId;
  final String code;
  final String displayName;
  final String currencyCode;
  final double priceAmount;
  final int grantedSpark;
  final int bonusSpark;
  final int totalSpark;

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
    );
  }
}

class PurchaseCheckoutModel {
  const PurchaseCheckoutModel({
    required this.orderId,
    required this.paymentProvider,
    required this.checkoutUrl,
    required this.status,
  });

  final String orderId;
  final String paymentProvider;
  final String checkoutUrl;
  final String status;

  factory PurchaseCheckoutModel.fromJson(Map<String, dynamic> json) {
    return PurchaseCheckoutModel(
      orderId: json['orderId'] as String? ?? '',
      paymentProvider: json['paymentProvider'] as String? ?? '',
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.paymentMethodId,
    required this.paymentProvider,
    required this.brand,
    required this.last4,
    required this.isDefault,
    required this.createdAtUtc,
    this.expMonth,
    this.expYear,
  });

  final String paymentMethodId;
  final String paymentProvider;
  final String brand;
  final String last4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;
  final DateTime? createdAtUtc;

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      paymentMethodId: json['paymentMethodId'] as String? ?? '',
      paymentProvider: json['paymentProvider'] as String? ?? '',
      brand: json['brand'] as String? ?? 'card',
      last4: json['last4'] as String? ?? '',
      expMonth: (json['expMonth'] as num?)?.toInt(),
      expYear: (json['expYear'] as num?)?.toInt(),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAtUtc: json['createdAtUtc'] is String
          ? DateTime.tryParse(json['createdAtUtc'] as String)
          : null,
    );
  }
}

class PaymentMethodSetupModel {
  const PaymentMethodSetupModel({
    required this.paymentProvider,
    required this.externalSetupId,
    required this.checkoutUrl,
  });

  final String paymentProvider;
  final String externalSetupId;
  final String checkoutUrl;

  factory PaymentMethodSetupModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSetupModel(
      paymentProvider: json['paymentProvider'] as String? ?? '',
      externalSetupId: json['externalSetupId'] as String? ?? '',
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
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
