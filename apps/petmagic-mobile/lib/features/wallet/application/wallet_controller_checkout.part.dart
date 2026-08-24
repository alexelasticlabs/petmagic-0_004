part of 'wallet_controller.dart';

mixin _WalletControllerCheckout
    on _WalletControllerBase, _WalletControllerLifecycle {
  @override
  Future<PurchaseCheckoutModel?> buyPack(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    if (state.isBuying) {
      return null;
    }

    String? durableStorePendingOrderId;
    if (!paymentMethod.isEnabled) {
      _updateStateIfMounted(
        (state) => state.copyWith(errorMessage: 'wallet.payment_unavailable'),
      );
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        isBuying: true,
        clearError: true,
        clearCheckoutUrl: true,
        clearPendingCheckout: true,
        checkoutVerificationState: WalletCheckoutVerificationState.idle,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    final checkoutRequestCancellation = _startCheckoutRequestCancellation();
    try {
      if (paymentMethod.isStoreNative) {
        final expectedProductId = pack.productIdForProvider(
          paymentMethod.provider,
        );
        if (expectedProductId == null || expectedProductId.isEmpty) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          return null;
        }

        final availability = await _repository.fetchStoreAvailability([
          pack,
        ], paymentMethod);
        if (!ref.mounted) {
          return null;
        }
        if (!availability.isAvailable ||
            !availability.productIds.contains(expectedProductId)) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          return null;
        }

        final durablePending = await _repository.readPendingStorePurchase();
        if (!ref.mounted) {
          return null;
        }
        if (durablePending != null) {
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              pendingCheckoutOrderId: durablePending.orderId,
              pendingStoreProvider: durablePending.provider,
              checkoutVerificationState:
                  WalletCheckoutVerificationState.pending,
              clearCheckoutError: true,
            ),
          );
          unawaited(_recoverPendingStorePurchase(requestStoreRestore: true));
          return null;
        }
      }

      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        _runtimeInfo.locale,
        cancelToken: checkoutRequestCancellation,
      );
      if (!ref.mounted || checkoutRequestCancellation.isCancelled) {
        return null;
      }

      if (paymentMethod.isStoreNative) {
        final productId = pack.productIdForProvider(paymentMethod.provider)!;
        final pendingPurchase = PendingStoreWalletPurchase(
          orderId: checkout.orderId,
          provider: paymentMethod.provider,
          productId: productId,
          packId: pack.packId,
          packCode: pack.code,
          createdAtUtc: DateTime.now().toUtc(),
        );
        await _repository.savePendingStorePurchase(pendingPurchase);
        durableStorePendingOrderId = checkout.orderId;
        if (!ref.mounted) {
          return null;
        }

        _updateStateIfMounted(
          (state) => state.copyWith(
            pendingCheckoutOrderId: checkout.orderId,
            pendingStoreProvider: paymentMethod.provider,
            isBuying: true,
          ),
        );

        await _repository.startStoreCheckout(pack, paymentMethod);
        _updateStateIfMounted((state) => state.copyWith(isBuying: false));
        return null;
      }

      if (checkout.hasNativeStripePaymentSheet) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            clearCheckoutUrl: true,
            pendingCheckoutOrderId: checkout.orderId,
            clearPendingStoreProvider: true,
          ),
        );
        return checkout;
      }

      final checkoutUrl = checkout.checkoutUrl.trim();
      if (checkoutUrl.isEmpty) {
        final payload = <String, Object>{
          'pack_id': pack.packId,
          'pack_code': pack.code,
          'provider': paymentMethod.provider,
          'order_id': checkout.orderId,
          'status': checkout.status,
        };
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'empty_checkout_url',
          message: 'Empty checkout URL received from purchase create API',
          context: payload,
          error: 'wallet.checkout_empty_url',
        );

        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            clearCheckoutUrl: true,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            errorMessage: 'payment_gateway_failed',
          ),
        );
        return null;
      }

      final safeCheckoutUri = parseSafePremiumExternalUri(checkoutUrl);
      if (safeCheckoutUri == null) {
        final payload = <String, Object>{
          'pack_id': pack.packId,
          'pack_code': pack.code,
          'provider': paymentMethod.provider,
          'order_id': checkout.orderId,
          'status': checkout.status,
        };
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'unsafe_checkout_url',
          message: 'Unsafe checkout URL received from purchase create API',
          context: payload,
          error: 'wallet.checkout_unsafe_url',
        );

        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            clearCheckoutUrl: true,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            errorMessage: 'payment_gateway_failed',
          ),
        );
        return null;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutUrl: safeCheckoutUri.toString(),
          pendingCheckoutOrderId: checkout.orderId,
          clearPendingStoreProvider: true,
        ),
      );
      return checkout;
    } on RequestCancelledException {
      _updateStateIfMounted((state) => state.copyWith(isBuying: false));
      return null;
    } catch (error) {
      if (durableStorePendingOrderId != null) {
        await _repository.clearPendingStorePurchase(
          orderId: durableStorePendingOrderId,
        );
      }
      AppLogger.error(
        feature: 'Wallet.Checkout',
        operation: 'checkout_failed',
        message: 'Checkout failed',
        context: {'pack_code': pack.code, 'provider': paymentMethod.provider},
        error: error,
      );
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          clearPendingCheckout: true,
          clearPendingStoreProvider: true,
          errorMessage: _errorMessage(error),
        ),
      );
      return null;
    } finally {
      _clearActiveCheckout(checkoutRequestCancellation);
    }
  }

  @override
  Future<void> claimAdReward() async {
    _updateStateIfMounted(
      (state) => state.copyWith(isClaimingAd: true, clearError: true),
    );

    try {
      final wallet = await _repository.claimAdReward();
      final ledger = await _repository.fetchLedger(
        take: _WalletControllerBase.walletLedgerPageSize,
      );
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          ledger: ledger.items,
          ledgerHasMore: ledger.hasMore,
          isClaimingAd: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isClaimingAd: false,
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }

  @override
  Future<String?> applyRedeemCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(isRedeeming: true, clearError: true),
    );

    try {
      final wallet = await _repository.applyRedeemCode(code);
      final ledger = await _repository.fetchLedger(
        take: _WalletControllerBase.walletLedgerPageSize,
      );
      final rewards = await _repository.fetchRewards();
      _updateStateIfMounted(
        (state) => state.copyWith(
          wallet: wallet,
          rewards: rewards,
          ledger: ledger.items,
          ledgerHasMore: ledger.hasMore,
          isRedeeming: false,
          clearError: true,
        ),
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      _updateStateIfMounted(
        (state) => state.copyWith(isRedeeming: false, errorMessage: message),
      );
      return message;
    }
  }

  @override
  Future<String?> applyReferralCode(String code) async {
    if (code.trim().isEmpty) {
      return null;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(isApplyingReferral: true, clearError: true),
    );

    try {
      final rewards = await _repository.applyReferralCode(code);
      _updateStateIfMounted(
        (state) => state.copyWith(
          rewards: rewards,
          isApplyingReferral: false,
          clearError: true,
        ),
      );
      return null;
    } catch (error) {
      final message = _errorMessage(error);
      _updateStateIfMounted(
        (state) =>
            state.copyWith(isApplyingReferral: false, errorMessage: message),
      );
      return message;
    }
  }

  @override
  void consumeCheckoutUrl() {
    state = state.copyWith(clearCheckoutUrl: true);
  }

  @override
  void resetCheckoutVerification() {
    state = state.copyWith(
      checkoutVerificationState: WalletCheckoutVerificationState.idle,
      clearCheckoutGrantedSpark: true,
      clearCheckoutError: true,
      clearHighlightedPurchaseOrderId: true,
    );
  }

  @override
  Future<void> verifyCheckoutStatus() {
    _ensureCheckoutCoordinators();
    return _checkoutVerificationCoordinator!.verifyCheckoutStatus();
  }

  @override
  Future<void> verifyStripeCheckout(String? stripeReferenceId) {
    _ensureCheckoutCoordinators();
    return _checkoutVerificationCoordinator!.verifyStripeCheckout(
      stripeReferenceId,
    );
  }

  @override
  Future<void> restoreStorePurchases() {
    _ensureCheckoutCoordinators();
    return _storePurchaseCoordinator!.restoreStorePurchases();
  }

  @override
  Future<void> _handlePurchaseUpdates(List<StorePurchaseDetails> purchases) {
    _ensureCheckoutCoordinators();
    return _storePurchaseCoordinator!.handlePurchaseUpdates(purchases);
  }

  @override
  Future<void> _recoverPendingStorePurchase({
    required bool requestStoreRestore,
  }) {
    _ensureCheckoutCoordinators();
    return _storePurchaseCoordinator!.recoverPendingPurchase(
      requestStoreRestore: requestStoreRestore,
    );
  }
}
// Checkout application state machine.
