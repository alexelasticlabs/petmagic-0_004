part of 'premium_repository.dart';

abstract final class _PremiumRepositoryTransport {
  static Future<StoreProductAvailabilitySnapshot> loadStoreAvailabilitySnapshot(
    InAppPurchase inAppPurchase,
    Set<String> requestedProductIds,
  ) async {
    final isAvailable = await inAppPurchase.isAvailable();
    if (!isAvailable) {
      return const StoreProductAvailabilitySnapshot(isAvailable: false);
    }

    final response = await inAppPurchase.queryProductDetails(
      requestedProductIds,
    );
    if (response.error != null) {
      throw const AppException('premium.store_unavailable');
    }

    return StoreProductAvailabilitySnapshot(
      isAvailable: true,
      productIds: response.productDetails.map((product) => product.id).toSet(),
      productPrices: {
        for (final product in response.productDetails)
          product.id: product.price,
      },
      productDetailsById: {
        for (final product in response.productDetails) product.id: product,
      },
    );
  }

  static String platformValue() {
    if (Platform.isIOS) {
      return 'ios';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    return 'web';
  }

  static Future<Response<T>> authorizedRequest<T>(
    AuthSessionCoordinator authSessionCoordinator,
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: mapDioException,
      requestFailedMessage: 'premium.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  static AppException mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.network_unavailable',
        includeCause: false,
      );
    }

    if (NetworkErrorMapper.isServerError(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'premium.store_unavailable',
        includeCause: false,
      );
    }

    final payload = NetworkErrorMapper.parseApiPayload(error);
    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(error, safeMessage);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}
