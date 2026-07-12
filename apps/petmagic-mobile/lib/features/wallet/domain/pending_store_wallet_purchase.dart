class PendingStoreWalletPurchase {
  const PendingStoreWalletPurchase({
    required this.orderId,
    required this.provider,
    required this.productId,
    required this.packId,
    required this.packCode,
    required this.createdAtUtc,
  });

  final String orderId;
  final String provider;
  final String productId;
  final String packId;
  final String packCode;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() => {
    'orderId': orderId,
    'provider': provider,
    'productId': productId,
    'packId': packId,
    'packCode': packCode,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
  };

  factory PendingStoreWalletPurchase.fromJson(Map<String, dynamic> json) {
    return PendingStoreWalletPurchase(
      orderId: json['orderId'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      packId: json['packId'] as String? ?? '',
      packCode: json['packCode'] as String? ?? '',
      createdAtUtc: json['createdAtUtc'] is String
          ? DateTime.tryParse(json['createdAtUtc'] as String)?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
