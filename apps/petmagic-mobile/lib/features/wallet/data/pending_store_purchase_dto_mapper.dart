import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';

PendingStoreWalletPurchase mapPendingStorePurchaseDto(
  Map<String, dynamic> json,
) {
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

Map<String, Object?> mapPendingStorePurchaseToJson(
  PendingStoreWalletPurchase purchase,
) => {
  'orderId': purchase.orderId,
  'provider': purchase.provider,
  'productId': purchase.productId,
  'packId': purchase.packId,
  'packCode': purchase.packCode,
  'createdAtUtc': purchase.createdAtUtc.toUtc().toIso8601String(),
};
