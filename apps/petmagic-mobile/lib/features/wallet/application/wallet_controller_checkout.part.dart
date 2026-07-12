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
  Future<void> verifyCheckoutStatus() async {
    final inFlight = _checkoutVerificationInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performCheckoutStatusVerification();
    _checkoutVerificationInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_checkoutVerificationInFlight, operation)) {
        _checkoutVerificationInFlight = null;
      }
    }
  }

  Future<void> _performCheckoutStatusVerification() async {
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

    final verificationRequestCancellation =
        _startCheckoutVerificationRequestCancellation();
    const maxAttempts = 6;
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!ref.mounted || verificationRequestCancellation.isCancelled) {
          return;
        }

        try {
          final purchase = await _repository.fetchPurchase(
            pendingOrderId,
            cancelToken: verificationRequestCancellation,
          );
          if (!ref.mounted || verificationRequestCancellation.isCancelled) {
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
        } on RequestCancelledException {
          return;
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
          if (!ref.mounted || verificationRequestCancellation.isCancelled) {
            return;
          }
        }
      }
    } finally {
      _clearActiveCheckoutVerification(verificationRequestCancellation);
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
    final inFlight = _checkoutVerificationInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performStripeCheckoutVerification(stripeReferenceId);
    _checkoutVerificationInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_checkoutVerificationInFlight, operation)) {
        _checkoutVerificationInFlight = null;
      }
    }
  }

  Future<void> _performStripeCheckoutVerification(
    String? stripeReferenceId,
  ) async {
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

    final verificationRequestCancellation =
        _startCheckoutVerificationRequestCancellation();
    const maxAttempts = 5;
    final normalizedReference = _normalizeStripeCheckoutReferenceId(
      stripeReferenceId,
    );

    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!ref.mounted || verificationRequestCancellation.isCancelled) {
          return;
        }

        try {
          final purchase = await _repository.verifyStripeCheckoutSession(
            orderId: pendingOrderId,
            stripeReferenceId: normalizedReference,
            cancelToken: verificationRequestCancellation,
          );
          if (!ref.mounted || verificationRequestCancellation.isCancelled) {
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
        } on RequestCancelledException {
          return;
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
          final purchase = await _repository.fetchPurchase(
            pendingOrderId,
            cancelToken: verificationRequestCancellation,
          );
          if (!ref.mounted || verificationRequestCancellation.isCancelled) {
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
        } on RequestCancelledException {
          return;
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
          if (!ref.mounted || verificationRequestCancellation.isCancelled) {
            return;
          }
        }
      }
    } finally {
      _clearActiveCheckoutVerification(verificationRequestCancellation);
    }

    await _performCheckoutStatusVerification();
  }

  @override
  Future<void> restoreStorePurchases() async {
    if (!_hasAuthenticatedWalletSession()) {
      return;
    }

    // A manual restore must not depend on a locally persisted checkout order:
    // after reinstall or storage loss, StoreKit/Google Play is the source of
    // the purchase update that lets the backend recover the order.
    await _repository.restoreStorePurchases();
  }

  @override
  Future<void> _handlePurchaseUpdates(
    List<StorePurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!ref.mounted) {
        return;
      }

      switch (purchase.status) {
        case StorePurchaseStatus.pending:
          _updateStateIfMounted(
            (state) => state.copyWith(isBuying: true, clearError: true),
          );
          break;
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case StorePurchaseStatus.error:
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
        case StorePurchaseStatus.canceled:
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

  Future<void> _verifyStorePurchase(StorePurchaseDetails purchase) async {
    final durablePending = await _repository.readPendingStorePurchase();
    if (!ref.mounted) {
      return;
    }
    final provider = _providerForStorePurchase(purchase, durablePending);
    if (provider == null || provider.isEmpty) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          checkoutErrorMessage: 'wallet.payment_unavailable',
          errorMessage: 'wallet.payment_unavailable',
        ),
      );
      return;
    }

    final pendingOrderId = _pendingOrderIdForStorePurchase(
      purchase,
      durablePending,
    );

    final paymentMethod = _paymentMethodForProvider(provider);

    if ((pendingOrderId == null || pendingOrderId.isEmpty) &&
        durablePending != null) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          pendingCheckoutOrderId: durablePending.orderId,
          pendingStoreProvider: durablePending.provider,
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.pending,
          clearCheckoutError: true,
        ),
      );
    }

    final verificationKey = _storePurchaseVerificationKey(
      orderId: pendingOrderId ?? 'recover',
      provider: provider,
      purchase: purchase,
    );
    if (verificationKey != null) {
      if (_storePurchaseVerifiedKeys.contains(verificationKey)) {
        if (purchase.pendingCompletePurchase) {
          await _repository.consumeVerifiedPurchase(purchase);
        }
        return;
      }

      if (!_storePurchaseVerificationInFlightKeys.add(verificationKey)) {
        return;
      }
    }

    try {
      _updateStateIfMounted(
        (state) => state.copyWith(
          checkoutVerificationState: WalletCheckoutVerificationState.checking,
          clearCheckoutError: true,
        ),
      );

      if (pendingOrderId != null &&
          pendingOrderId.isNotEmpty &&
          paymentMethod != null) {
        final verified = await _repository.verifyStorePurchase(
          orderId: pendingOrderId,
          paymentMethod: paymentMethod,
          purchase: purchase,
        );
        if (!ref.mounted) {
          return;
        }
        if (verified.status == 'succeeded') {
          if (verificationKey != null) {
            _rememberStorePurchaseVerifiedKey(verificationKey);
          }
          if (purchase.pendingCompletePurchase) {
            await _repository.consumeVerifiedPurchase(purchase);
            if (!ref.mounted) {
              return;
            }
          }
          await _repository.clearPendingStorePurchase(orderId: pendingOrderId);
          if (!ref.mounted) {
            return;
          }
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
        return;
      }

      final validation = await _repository.validateStorePurchase(
        provider: provider,
        purchase: purchase,
      );
      if (!ref.mounted) {
        return;
      }
      if (validation.isSettledTokenPack) {
        if (verificationKey != null) {
          _rememberStorePurchaseVerifiedKey(verificationKey);
        }
        if (purchase.pendingCompletePurchase) {
          await _repository.consumeVerifiedPurchase(purchase);
          if (!ref.mounted) {
            return;
          }
        }
        await _repository.clearPendingStorePurchase(orderId: pendingOrderId);
        if (!ref.mounted) {
          return;
        }
        await load(refresh: true);
        _updateStateIfMounted(
          (state) => state.copyWith(
            isBuying: false,
            checkoutVerificationState:
                WalletCheckoutVerificationState.succeeded,
            checkoutGrantedSpark: validation.tokenAmount,
            highlightedPurchaseOrderId: pendingOrderId,
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
    } catch (error) {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isBuying: false,
          checkoutVerificationState: WalletCheckoutVerificationState.error,
          checkoutErrorMessage: _errorMessage(error),
          errorMessage: _errorMessage(error),
        ),
      );
    } finally {
      if (verificationKey != null) {
        _storePurchaseVerificationInFlightKeys.remove(verificationKey);
      }
    }
  }

  @override
  Future<void> _recoverPendingStorePurchase({
    required bool requestStoreRestore,
  }) async {
    final inFlight = _storePurchaseRecoveryInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final operation = _performPendingStorePurchaseRecovery(
      requestStoreRestore: requestStoreRestore,
    );
    _storePurchaseRecoveryInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_storePurchaseRecoveryInFlight, operation)) {
        _storePurchaseRecoveryInFlight = null;
      }
    }
  }

  Future<void> _performPendingStorePurchaseRecovery({
    required bool requestStoreRestore,
  }) async {
    if (!_hasAuthenticatedWalletSession() ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    final pending = await _repository.readPendingStorePurchase();
    if (!ref.mounted || pending == null) {
      return;
    }

    _updateStateIfMounted(
      (state) => state.copyWith(
        pendingCheckoutOrderId: pending.orderId,
        pendingStoreProvider: pending.provider,
        checkoutVerificationState: WalletCheckoutVerificationState.pending,
        clearCheckoutError: true,
      ),
    );

    if (!requestStoreRestore || _storePurchaseRestoreRequestedThisSession) {
      return;
    }

    try {
      await _repository.restoreStorePurchases();
      _storePurchaseRestoreRequestedThisSession = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Wallet.Checkout',
        operation: 'store_purchase_restore_failed',
        message: 'Store purchase restore failed during wallet recovery',
        context: {
          'provider': pending.provider,
          'order_id': pending.orderId,
          'product_id': pending.productId,
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _pendingOrderIdForStorePurchase(
    StorePurchaseDetails purchase,
    PendingStoreWalletPurchase? durablePending,
  ) {
    final stateOrderId = state.pendingCheckoutOrderId?.trim();
    if (stateOrderId != null && stateOrderId.isNotEmpty) {
      return stateOrderId;
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

  String? _providerForStorePurchase(
    StorePurchaseDetails purchase,
    PendingStoreWalletPurchase? durablePending,
  ) {
    if (durablePending != null) {
      final pendingProductId = durablePending.productId.trim();
      final pendingProvider = durablePending.provider.trim();
      if (pendingProvider.isNotEmpty &&
          (pendingProductId.isEmpty ||
              pendingProductId == purchase.productID)) {
        return pendingProvider;
      }
    }

    final stateProvider = state.pendingStoreProvider?.trim();
    if (stateProvider != null && stateProvider.isNotEmpty) {
      return stateProvider;
    }

    for (final method in state.paymentMethods) {
      if (!method.isStoreNative) {
        continue;
      }

      final hasMatchingPack = state.packs.any((pack) {
        return pack.productIdForProvider(method.provider) == purchase.productID;
      });
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

  WalletPaymentMethodModel? _paymentMethodForProvider(String provider) {
    final normalized = provider.trim().toLowerCase();
    for (final method in state.paymentMethods) {
      if (method.provider.trim().toLowerCase() == normalized) {
        return method;
      }
    }
    return null;
  }

  String? _storePurchaseVerificationKey({
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

  void _rememberStorePurchaseVerifiedKey(String verificationKey) {
    _storePurchaseVerifiedKeys.add(verificationKey);
    while (_storePurchaseVerifiedKeys.length >
        _WalletControllerBase._maxStorePurchaseVerificationKeys) {
      _storePurchaseVerifiedKeys.remove(_storePurchaseVerifiedKeys.first);
    }
  }
}
// Checkout application state machine.
