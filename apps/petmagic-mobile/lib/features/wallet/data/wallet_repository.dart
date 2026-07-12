export 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart'
    show WalletRepositoryPort, walletRepositoryProvider;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_dto_mapper.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_recovery_store.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:petmagic_mobile/shared/payments/store_purchase_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dioWalletRepositoryProvider = Provider<WalletRepositoryPort>((ref) {
  return WalletRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    storePurchaseRecoveryStore: ref.watch(
      walletStorePurchaseRecoveryStoreProvider,
    ),
  );
});

class WalletRepository implements WalletRepositoryPort {
  static const _storeAvailabilityTimeout = Duration(seconds: 8);

  WalletRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
    InAppPurchase? inAppPurchase,
    WalletStorePurchaseRecoveryStore? storePurchaseRecoveryStore,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage),
       _inAppPurchaseOverride = inAppPurchase,
       _storePurchaseRecoveryStore =
           storePurchaseRecoveryStore ??
           WalletStorePurchaseRecoveryStore(
             preferences: SharedPreferencesAsync(),
           );

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final InAppPurchase? _inAppPurchaseOverride;
  final WalletStorePurchaseRecoveryStore _storePurchaseRecoveryStore;

  InAppPurchase get _inAppPurchase =>
      _inAppPurchaseOverride ?? InAppPurchase.instance;

  @override
  Stream<List<StorePurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream.map(
        (purchases) =>
            purchases.map(mapPlatformStorePurchase).toList(growable: false),
      );

  @override
  Future<WalletStateModel> fetchWallet({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapWalletStateFromJson(response.data ?? const {});
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    RequestCancellation? cancelToken,
  }) async {
    final pagination = _walletOffsetPaginationQuery(skip: skip, take: take);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/ledger',
        queryParameters: pagination,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapOffsetPageFromJson(
      response.data ?? const {},
      mapWalletLedgerItemFromJson,
    );
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/rewards',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapRewardsSummaryFromJson(response.data ?? const {});
  }

  @override
  Future<List<CurrencyPackModel>> fetchPacks() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/economy/packs');
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(mapCurrencyPackFromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'wallet.packs_failed');
    }
  }

  @override
  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required AppLocale locale,
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/checkout-config',
        queryParameters: {
          'platform': _platformValue(),
          'appVersion': AppConfig.appVersion,
          'country': locale.countryCode ?? '*',
          'locale': locale.languageTag,
        },
        cancelToken: cancelToken.toDioCancelToken(),
      );

      return mapWalletCheckoutConfigFromJson(response.data ?? const {});
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      throw _mapDioException(error, fallbackMessage: 'wallet.packs_failed');
    }
  }

  @override
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    RequestCancellation? cancelToken,
  }) async {
    final pagination = _walletOffsetPaginationQuery(skip: skip, take: take);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases',
        queryParameters: pagination,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapOffsetPageFromJson(
      response.data ?? const {},
      mapPurchaseHistoryItemFromJson,
    );
  }

  @override
  Future<PurchaseHistoryItem> fetchPurchase(
    String orderId, {
    RequestCancellation? cancelToken,
  }) async {
    final encodedOrderId = _walletPathSegment(orderId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases/$encodedOrderId',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapPurchaseHistoryItemFromJson(response.data ?? const {});
  }

  @override
  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    AppLocale locale, {
    RequestCancellation? cancelToken,
  }) async {
    final platform = _platformValue();
    final payload = <String, Object?>{
      'packId': pack.packId,
      'currencyCode': pack.currencyCode,
      'paymentProvider': paymentMethod.provider,
      'platform': platform,
      'appVersion': AppConfig.appVersion,
      'country': locale.countryCode ?? '*',
      'locale': locale.languageTag,
    };

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/create',
        data: payload,
        options: authenticatedRequestOptions(
          session.accessToken,
          extraHeaders: {'X-PetMagic-Platform': platform},
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPurchaseCheckoutFromJson(response.data ?? const {});
  }

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
    if (!paymentMethod.isStoreNative) {
      return (
        isAvailable: false,
        productIds: const <String>{},
        productPrices: const <String, String>{},
      );
    }

    final requestedIds = packs
        .map((pack) => pack.productIdForProvider(paymentMethod.provider))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();

    if (requestedIds.isEmpty) {
      return (
        isAvailable: false,
        productIds: const <String>{},
        productPrices: const <String, String>{},
      );
    }

    final availability = await sharedStoreProductAvailabilityCache.read(
      requestedIds,
      loader: _loadStoreAvailabilitySnapshot,
      scopeKey: paymentMethod.provider,
    );

    return (
      isAvailable: availability.isAvailable,
      productIds: availability.productIds,
      productPrices: availability.productPrices,
    );
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
    final productId = pack.productIdForProvider(paymentMethod.provider);
    if (productId == null || productId.isEmpty) {
      throw const AppException('wallet.payment_unavailable');
    }

    final availability = await sharedStoreProductAvailabilityCache.read(
      {productId},
      loader: _loadStoreAvailabilitySnapshot,
      scopeKey: paymentMethod.provider,
    );
    final productDetails = availability.productDetailsById[productId];
    if (!availability.isAvailable || productDetails == null) {
      throw const AppException('wallet.payment_unavailable');
    }

    final launched = await _inAppPurchase.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: productDetails,
        applicationUserName: session.user.userId,
      ),
      autoConsume: false,
    );
    if (!launched) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

  Future<StoreProductAvailabilitySnapshot> _loadStoreAvailabilitySnapshot(
    Set<String> requestedProductIds,
  ) async {
    final isAvailable = await _inAppPurchase.isAvailable().timeout(
      _storeAvailabilityTimeout,
    );
    if (!isAvailable) {
      return const StoreProductAvailabilitySnapshot(isAvailable: false);
    }

    final response = await _inAppPurchase
        .queryProductDetails(requestedProductIds)
        .timeout(_storeAvailabilityTimeout);
    if (response.error != null) {
      throw const AppException('wallet.payment_unavailable');
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
    await _inAppPurchase.restorePurchases(
      applicationUserName: session.user.userId,
    );
  }

  @override
  Future<void> completePurchase(StorePurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(
      requirePlatformStorePurchase(purchase),
    );
  }

  @override
  Future<void> consumeVerifiedPurchase(StorePurchaseDetails purchase) async {
    final platformPurchase = requirePlatformStorePurchase(purchase);
    if (!Platform.isAndroid) {
      await _inAppPurchase.completePurchase(platformPurchase);
      return;
    }

    final addition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await addition.consumePurchase(platformPurchase);
    if (result.responseCode != BillingResponse.ok) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

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

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'wallet.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }

  String _platformValue() {
    if (Platform.isIOS) {
      return 'ios';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    return 'web';
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'wallet.network_unavailable',
      );
    }

    if (NetworkErrorMapper.isServerError(error)) {
      return NetworkErrorMapper.fromMessage(error, 'wallet.server_unavailable');
    }

    final payload = NetworkErrorMapper.parseApiPayload(error);
    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(error, safeMessage);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}

String _walletPathSegment(String value) {
  return Uri.encodeComponent(value.trim());
}

Map<String, int> _walletOffsetPaginationQuery({
  required int skip,
  required int take,
}) {
  return {'skip': skip < 0 ? 0 : skip, 'take': take.clamp(1, 100)};
}
