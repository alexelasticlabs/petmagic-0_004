part of 'wallet_repository.dart';

mixin _WalletStoreRepositoryMixin on _WalletRepositoryBase {
  @override
  Future<
    ({
      bool isAvailable,
      Set<String> productIds,
      Map<String, String> productPrices,
    })
  >
  fetchStoreAvailability(
    List<CurrencyPackModel> packs,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    return _storePurchaseService.fetchAvailability(packs, paymentMethod);
  }

  @override
  Future<void> startStoreCheckout(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    final session = await _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      unauthorizedMessage: 'auth.sign_in_required',
      sessionExpiredMessage: 'auth.session_expired',
    );
    await _storePurchaseService.startCheckout(
      pack,
      paymentMethod,
      applicationUserName: session.user.userId,
    );
  }

  @override
  Future<PurchaseHistoryItem> verifyStorePurchase({
    required String orderId,
    required WalletPaymentMethodModel paymentMethod,
    required StorePurchaseDetails purchase,
  }) async {
    final encodedOrderId = _walletPathSegment(orderId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/$encodedOrderId/verify-store',
        data: {
          'paymentProvider': paymentMethod.provider,
          'productId': purchase.productID,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
          'localVerificationData':
              purchase.verificationData.localVerificationData,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return mapPurchaseHistoryItemFromJson(response.data ?? const {});
  }

  @override
  Future<StoreBillingValidationModel> validateStorePurchase({
    required String provider,
    required StorePurchaseDetails purchase,
  }) async {
    final normalizedProvider = provider.trim().toLowerCase();
    final serverVerificationData = purchase
        .verificationData
        .serverVerificationData
        .trim();
    if (serverVerificationData.isEmpty) {
      throw const AppException('wallet.payment_unavailable');
    }

    final response = await _authorizedRequest<Map<String, dynamic>>((session) {
      if (normalizedProvider == 'google_play') {
        return _dio.post<Map<String, dynamic>>(
          '/api/billing/google/validate',
          data: {
            'purchaseToken': serverVerificationData,
            'productId': purchase.productID,
            'packageName': AppConfig.androidPackageName,
          },
          options: authenticatedRequestOptions(session.accessToken),
        );
      }

      if (normalizedProvider == 'app_store') {
        return _dio.post<Map<String, dynamic>>(
          '/api/billing/apple/validate',
          data: {'signedTransactionInfo': serverVerificationData},
          options: authenticatedRequestOptions(session.accessToken),
        );
      }

      throw const AppException('wallet.payment_unavailable');
    }, retryTransientFailures: false);

    return mapStoreBillingValidationFromJson(response.data ?? const {});
  }

  @override
  Future<void> savePendingStorePurchase(PendingStoreWalletPurchase purchase) {
    return _storePurchaseRecoveryStore.savePendingPurchase(purchase);
  }

  @override
  Future<PendingStoreWalletPurchase?> readPendingStorePurchase() {
    return _storePurchaseRecoveryStore.readPendingPurchase();
  }

  @override
  Future<void> clearPendingStorePurchase({String? orderId}) {
    return _storePurchaseRecoveryStore.clearPendingPurchase(orderId: orderId);
  }

  @override
  Future<void> restoreStorePurchases() async {
    final session = await _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      unauthorizedMessage: 'auth.sign_in_required',
      sessionExpiredMessage: 'auth.session_expired',
    );
    await _storePurchaseService.restorePurchases(
      applicationUserName: session.user.userId,
    );
  }

  @override
  Future<void> completePurchase(StorePurchaseDetails purchase) {
    return _storePurchaseService.completePurchase(purchase);
  }

  @override
  Future<void> consumeVerifiedPurchase(StorePurchaseDetails purchase) {
    return _storePurchaseService.consumeVerifiedPurchase(purchase);
  }
}
