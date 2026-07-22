part of 'wallet_controller.dart';

mixin _WalletControllerCoordinatorCallbacks on _WalletControllerBase {
  Future<void> _handleCheckoutVerificationSucceeded(
    PurchaseHistoryItem purchase,
  ) async {
    await load(refresh: true);
    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.succeeded,
        checkoutGrantedSpark: purchase.sparkToGrant,
        highlightedPurchaseOrderId: purchase.orderId,
        clearPendingCheckout: true,
        clearPendingStoreProvider: true,
        clearCheckoutError: true,
      ),
    );
  }

  void _applyStorePurchaseStateChange(WalletStorePurchaseStateChange change) {
    _updateStateIfMounted((state) {
      return switch (change.phase) {
        WalletStorePurchasePhase.purchasePending => state.copyWith(
          isBuying: true,
          clearError: true,
        ),
        WalletStorePurchasePhase.recoveredPending => state.copyWith(
          pendingCheckoutOrderId: change.pendingPurchase?.orderId,
          pendingStoreProvider: change.pendingPurchase?.provider,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          clearCheckoutError: true,
        ),
        WalletStorePurchasePhase.pendingWithoutOrder => state.copyWith(
          pendingCheckoutOrderId: change.pendingPurchase?.orderId,
          pendingStoreProvider: change.pendingPurchase?.provider,
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          clearCheckoutError: true,
        ),
        WalletStorePurchasePhase.checking => state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.checking,
          clearCheckoutError: true,
        ),
        WalletStorePurchasePhase.succeeded => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.succeeded,
          checkoutGrantedSpark: change.grantedSpark,
          highlightedPurchaseOrderId: change.orderId,
          clearPendingCheckout: true,
          clearPendingStoreProvider: true,
          clearCheckoutError: true,
        ),
        WalletStorePurchasePhase.pending => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          checkoutErrorMessage: change.errorMessage,
          errorMessage: change.errorMessage,
          clearCheckoutError: change.errorMessage == null,
        ),
        WalletStorePurchasePhase.error => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: change.errorMessage,
          errorMessage: change.errorMessage,
        ),
        WalletStorePurchasePhase.cancelled => state.copyWith(
          isBuying: false,
          errorMessage: change.errorMessage,
        ),
      };
    });
  }
}
