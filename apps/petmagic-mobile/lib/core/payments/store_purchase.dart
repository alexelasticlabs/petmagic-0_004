enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

final class StorePurchaseVerificationData {
  const StorePurchaseVerificationData({
    required this.localVerificationData,
    required this.serverVerificationData,
    required this.source,
  });

  final String localVerificationData;
  final String serverVerificationData;
  final String source;
}

final class StorePurchaseError {
  const StorePurchaseError({required this.message, this.code});

  final String message;
  final String? code;
}

final class StorePurchaseDetails {
  const StorePurchaseDetails({
    required this.productID,
    required this.status,
    required this.verificationData,
    required this.pendingCompletePurchase,
    this.purchaseID,
    this.transactionDate,
    this.error,
    this.platformHandle,
  });

  final String productID;
  final String? purchaseID;
  final String? transactionDate;
  final StorePurchaseStatus status;
  final StorePurchaseVerificationData verificationData;
  final StorePurchaseError? error;
  final bool pendingCompletePurchase;

  /// Opaque plugin object used only by data adapters for complete/consume.
  final Object? platformHandle;
}
