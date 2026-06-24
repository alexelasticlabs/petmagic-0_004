class WalletCheckoutState {
  const WalletCheckoutState({
    this.checkoutUrl,
    this.pendingOrderId,
    this.pendingStoreProvider,
    this.storeProductPrices = const <String, String>{},
    this.verificationState = WalletCheckoutVerificationState.idle,
    this.grantedSpark,
    this.errorMessage,
    this.highlightedPurchaseOrderId,
  });

  final String? checkoutUrl;
  final String? pendingOrderId;
  final String? pendingStoreProvider;
  final Map<String, String> storeProductPrices;
  final WalletCheckoutVerificationState verificationState;
  final int? grantedSpark;
  final String? errorMessage;
  final String? highlightedPurchaseOrderId;

  WalletCheckoutState copyWith({
    String? checkoutUrl,
    String? pendingOrderId,
    String? pendingStoreProvider,
    Map<String, String>? storeProductPrices,
    WalletCheckoutVerificationState? verificationState,
    int? grantedSpark,
    String? errorMessage,
    String? highlightedPurchaseOrderId,
    bool clearCheckoutUrl = false,
    bool clearPendingOrderId = false,
    bool clearPendingStoreProvider = false,
    bool clearGrantedSpark = false,
    bool clearError = false,
    bool clearHighlightedPurchaseOrderId = false,
  }) {
    return WalletCheckoutState(
      checkoutUrl:
          clearCheckoutUrl ? null : checkoutUrl ?? this.checkoutUrl,
      pendingOrderId: clearPendingOrderId
          ? null
          : pendingOrderId ?? this.pendingOrderId,
      pendingStoreProvider: clearPendingStoreProvider
          ? null
          : pendingStoreProvider ?? this.pendingStoreProvider,
      storeProductPrices: storeProductPrices ?? this.storeProductPrices,
      verificationState: verificationState ?? this.verificationState,
      grantedSpark:
          clearGrantedSpark ? null : grantedSpark ?? this.grantedSpark,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      highlightedPurchaseOrderId: clearHighlightedPurchaseOrderId
          ? null
          : highlightedPurchaseOrderId ?? this.highlightedPurchaseOrderId,
    );
  }
}

enum WalletCheckoutVerificationState { idle, verifying, success, failed }
