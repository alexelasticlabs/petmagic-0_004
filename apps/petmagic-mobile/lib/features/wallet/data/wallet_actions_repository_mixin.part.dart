part of 'wallet_repository.dart';

mixin _WalletActionsRepositoryMixin on _WalletRepositoryBase {
  @override
  Future<WalletStateModel> claimAdReward() async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/wallet/claim-ad',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return fetchWallet();
  }

  @override
  Future<WalletStateModel> applyRedeemCode(String code) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/wallet/redeem',
        data: {'code': code.trim()},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return fetchWallet();
  }

  @override
  Future<RewardsSummaryModel> applyReferralCode(String code) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/referrals/activate',
        data: {'code': code.trim()},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    return fetchRewards();
  }

  @override
  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
    RequestCancellation? cancelToken,
  }) async {
    final normalizedReference = stripeReferenceId?.trim();
    final payload = <String, Object?>{};
    if (normalizedReference != null && normalizedReference.isNotEmpty) {
      payload['stripeReferenceId'] = normalizedReference;
    }

    final encodedOrderId = _walletPathSegment(orderId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/$encodedOrderId/verify-stripe',
        data: payload,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPurchaseHistoryItemFromJson(response.data ?? const {});
  }

  @override
  Future<PurchaseHistoryItem> cancelStripePurchase({
    required String orderId,
    RequestCancellation? cancelToken,
  }) async {
    final encodedOrderId = _walletPathSegment(orderId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/$encodedOrderId/cancel',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPurchaseHistoryItemFromJson(response.data ?? const {});
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? locale,
  }) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.put<Map<String, dynamic>>(
        '/api/economy/notifications/push-token',
        data: {
          'token': token,
          'platform': platform,
          'deviceId': null,
          'appVersion': AppConfig.appVersion,
          'locale': locale,
        },
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.delete<Map<String, dynamic>>(
        '/api/economy/notifications/push-token',
        data: {'token': token},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }
}
