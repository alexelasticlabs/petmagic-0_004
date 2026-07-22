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
}
