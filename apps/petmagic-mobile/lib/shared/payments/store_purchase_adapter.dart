import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';

StorePurchaseDetails mapPlatformStorePurchase(PurchaseDetails purchase) {
  return StorePurchaseDetails(
    productID: purchase.productID,
    purchaseID: purchase.purchaseID,
    transactionDate: purchase.transactionDate,
    status: switch (purchase.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.purchased,
      PurchaseStatus.restored => StorePurchaseStatus.restored,
      PurchaseStatus.error => StorePurchaseStatus.error,
      PurchaseStatus.canceled => StorePurchaseStatus.canceled,
    },
    verificationData: StorePurchaseVerificationData(
      localVerificationData: purchase.verificationData.localVerificationData,
      serverVerificationData: purchase.verificationData.serverVerificationData,
      source: purchase.verificationData.source,
    ),
    error: purchase.error == null
        ? null
        : StorePurchaseError(
            message: purchase.error!.message,
            code: purchase.error!.code,
          ),
    pendingCompletePurchase: purchase.pendingCompletePurchase,
    platformHandle: purchase,
  );
}

PurchaseDetails requirePlatformStorePurchase(StorePurchaseDetails purchase) {
  final handle = purchase.platformHandle;
  if (handle is PurchaseDetails) {
    return handle;
  }

  throw const AppException('wallet.payment_unavailable');
}
