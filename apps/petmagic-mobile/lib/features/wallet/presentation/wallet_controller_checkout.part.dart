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
      }

      final checkout = await _repository.createPurchase(
        pack,
        paymentMethod,
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      if (!ref.mounted) {
        return null;
      }

      if (paymentMethod.isStoreNative) {
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

      final checkoutUrl = checkout.checkoutUrl.trim();
      if (checkoutUrl.isEmpty && !checkout.usesPaymentSheet) {
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

      final safeCheckoutUri = checkout.usesPaymentSheet
          ? null
          : parseSafePremiumExternalUri(checkoutUrl);
      if (!checkout.usesPaymentSheet && safeCheckoutUri == null) {
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
          checkoutUrl: safeCheckoutUri?.toString() ?? checkoutUrl,
          pendingCheckoutOrderId: checkout.orderId,
          clearPendingStoreProvider: true,
        ),
      );
      return checkout;
    } catch (error) {
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
  Future<void> verifyCheckoutStatus() async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.checking,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!ref.mounted) {
        return;
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (!ref.mounted) {
          return;
        }
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            checkoutVerificationState: WalletCheckoutVerificationState.error,
            checkoutErrorMessage: _errorMessage(error),
          ),
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!ref.mounted) {
          return;
        }
      }
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.pending,
        clearCheckoutError: true,
      ),
    );
  }

  @override
  Future<void> verifyStripeCheckout(String? stripeReferenceId) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    if (pendingOrderId == null || pendingOrderId.isEmpty) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        checkoutVerificationState: WalletCheckoutVerificationState.checking,
        clearCheckoutGrantedSpark: true,
        clearCheckoutError: true,
        clearHighlightedPurchaseOrderId: true,
      ),
    );

    const maxAttempts = 5;
    final normalizedReference = stripeReferenceId?.trim();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!ref.mounted) {
        return;
      }

      try {
        final purchase = await _repository.verifyStripeCheckoutSession(
          orderId: pendingOrderId,
          stripeReferenceId: normalizedReference,
        );
        if (!ref.mounted) {
          return;
        }

        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error) {
        AppLogger.warn(
          feature: 'Wallet.Checkout',
          operation: 'stripe_verify_attempt_failed',
          message: 'Stripe verify attempt failed',
          context: {
            'order_id': pendingOrderId,
            'attempt': attempt + 1,
            'reference_type': _stripeReferenceType(normalizedReference),
          },
          error: error,
        );
      }

      try {
        final purchase = await _repository.fetchPurchase(pendingOrderId);
        if (!ref.mounted) {
          return;
        }
        if (purchase.status == 'succeeded') {
          await load(refresh: true);
          _updateStateIfMounted(
            (state) => state.copyWith(
              checkoutVerificationState:
                  WalletCheckoutVerificationState.succeeded,
              checkoutGrantedSpark: purchase.sparkToGrant,
              highlightedPurchaseOrderId: purchase.orderId,
              clearPendingCheckout: true,
              clearPendingStoreProvider: true,
              clearCheckoutError: true,
            ),
          );
          return;
        }
      } catch (error, stackTrace) {
        _logWalletLoadFailure(
          'fetch_purchase_for_verification',
          error,
          stackTrace,
        );
        // Keep retrying verify endpoint; failures here should not interrupt confirmation loop.
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!ref.mounted) {
          return;
        }
      }
    }

    await verifyCheckoutStatus();
  }

  @override
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!ref.mounted) {
        return;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _updateStateIfMounted(
            (state) => state.copyWith(isBuying: true, clearError: true),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              checkoutVerificationState: WalletCheckoutVerificationState.error,
              checkoutErrorMessage: _purchaseErrorMessage(
                purchase.error?.message,
              ),
              errorMessage: _purchaseErrorMessage(purchase.error?.message),
            ),
          );
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }
          _updateStateIfMounted(
            (state) => state.copyWith(
              isBuying: false,
              errorMessage: 'wallet.payment_unavailable',
            ),
          );
          break;
      }
    }
  }

  Future<void> _verifyStorePurchase(PurchaseDetails purchase) async {
    final pendingOrderId = state.pendingCheckoutOrderId;
    final provider = state.pendingStoreProvider;
    if (pendingOrderId == null ||
        pendingOrderId.isEmpty ||
        provider == null ||
        provider.isEmpty) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }
      return;
    }

    WalletPaymentMethodModel? paymentMethod;
    for (final method in state.paymentMethods) {
      if (method.provider == provider) {
        paymentMethod = method;
        break;
      }
    }

    if (paymentMethod == null) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: 'wallet.payment_unavailable',
          errorMessage: 'wallet.payment_unavailable',
        ),
      );
      return;
    }

    try {
      _updateStateIfMounted(
        (state) => state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.checking,
          clearCheckoutError: true,
        ),
      );

      final verified = await _repository.verifyStorePurchase(
        orderId: pendingOrderId,
        paymentMethod: paymentMethod,
        purchase: purchase,
      );
      if (!ref.mounted) {
        return;
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }

      if (verified.status == 'succeeded') {
        await load(refresh: true);
        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: verified.sparkToGrant,
            highlightedPurchaseOrderId: verified.orderId,
            clearPendingCheckout: true,
            clearPendingStoreProvider: true,
            clearCheckoutError: true,
          ),
        );
        return;
      }

      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          clearCheckoutError: true,
        ),
      );
      await verifyCheckoutStatus();
    } catch (error) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
        if (!ref.mounted) {
          return;
        }
      }
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: _errorMessage(error),
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }
}
