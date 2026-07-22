import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/pending_store_wallet_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

class WalletStorePurchaseResolver {
  const WalletStorePurchaseResolver();

  String? pendingOrderId({
    required StorePurchaseDetails purchase,
    required PendingStoreWalletPurchase? durablePending,
    required String? stateOrderId,
  }) {
    final normalizedStateOrderId = stateOrderId?.trim();
    if (normalizedStateOrderId != null && normalizedStateOrderId.isNotEmpty) {
      return normalizedStateOrderId;
    }
    if (durablePending == null) {
      return null;
    }

    final pendingProductId = durablePending.productId.trim();
    if (pendingProductId.isNotEmpty && pendingProductId != purchase.productID) {
      return null;
    }
    final orderId = durablePending.orderId.trim();
    return orderId.isEmpty ? null : orderId;
  }

  String? provider({
    required StorePurchaseDetails purchase,
    required PendingStoreWalletPurchase? durablePending,
    required String? stateProvider,
    required List<WalletPaymentMethodModel> paymentMethods,
    required List<CurrencyPackModel> packs,
  }) {
    if (durablePending != null) {
      final pendingProductId = durablePending.productId.trim();
      final pendingProvider = durablePending.provider.trim();
      if (pendingProvider.isNotEmpty &&
          (pendingProductId.isEmpty ||
              pendingProductId == purchase.productID)) {
        return pendingProvider;
      }
    }

    final normalizedStateProvider = stateProvider?.trim();
    if (normalizedStateProvider != null && normalizedStateProvider.isNotEmpty) {
      return normalizedStateProvider;
    }

    for (final method in paymentMethods) {
      if (!method.isStoreNative) {
        continue;
      }
      final hasMatchingPack = packs.any(
        (pack) =>
            pack.productIdForProvider(method.provider) == purchase.productID,
      );
      if (hasMatchingPack) {
        return method.provider;
      }
    }

    final source = purchase.verificationData.source.toLowerCase();
    if (source.contains('google')) {
      return 'google_play';
    }
    if (source.contains('app_store') ||
        source.contains('storekit') ||
        source.contains('sk_payment_queue')) {
      return 'app_store';
    }
    return null;
  }

  WalletPaymentMethodModel? paymentMethodForProvider(
    String provider,
    List<WalletPaymentMethodModel> paymentMethods,
  ) {
    final normalized = provider.trim().toLowerCase();
    for (final method in paymentMethods) {
      if (method.provider.trim().toLowerCase() == normalized) {
        return method;
      }
    }
    return null;
  }

  String? verificationKey({
    required String orderId,
    required String provider,
    required StorePurchaseDetails purchase,
  }) {
    final purchaseId = purchase.purchaseID?.trim();
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return '$orderId:$provider:${purchase.productID}:purchase:$purchaseId';
    }

    final transactionDate = purchase.transactionDate?.trim();
    if (transactionDate != null && transactionDate.isNotEmpty) {
      return '$orderId:$provider:${purchase.productID}:transaction:$transactionDate';
    }
    return null;
  }
}
