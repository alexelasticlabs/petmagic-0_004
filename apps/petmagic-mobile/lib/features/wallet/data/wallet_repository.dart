import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_recovery_store.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
    storePurchaseRecoveryStore: ref.watch(
      walletStorePurchaseRecoveryStoreProvider,
    ),
  );
});

class WalletRepository {
  WalletRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
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

  Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream;

  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return WalletStateModel.fromJson(response.data ?? const {});
  }

  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    final pagination = _walletOffsetPaginationQuery(skip: skip, take: take);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/ledger',
        queryParameters: pagination,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return OffsetPagedModel.fromJson(
      response.data ?? const {},
      WalletLedgerItem.fromJson,
    );
  }

  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/rewards',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return RewardsSummaryModel.fromJson(response.data ?? const {});
  }

  Future<List<CurrencyPackModel>> fetchPacks() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/economy/packs');
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CurrencyPackModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'wallet.packs_failed');
    }
  }

  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required Locale locale,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/checkout-config',
        queryParameters: {
          'platform': _platformValue(),
          'appVersion': AppConfig.appVersion,
          'country': locale.countryCode ?? '*',
          'locale': locale.toLanguageTag(),
        },
        cancelToken: cancelToken,
      );

      return WalletCheckoutConfigModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      throw _mapDioException(error, fallbackMessage: 'wallet.packs_failed');
    }
  }

  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    final pagination = _walletOffsetPaginationQuery(skip: skip, take: take);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases',
        queryParameters: pagination,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return OffsetPagedModel.fromJson(
      response.data ?? const {},
      PurchaseHistoryItem.fromJson,
    );
  }

  Future<PurchaseHistoryItem> fetchPurchase(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    final encodedOrderId = _walletPathSegment(orderId);
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases/$encodedOrderId',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );

    return PurchaseHistoryItem.fromJson(response.data ?? const {});
  }

  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    Locale locale,
  ) async {
    final platform = _platformValue();
    final payload = <String, Object?>{
      'packId': pack.packId,
      'currencyCode': pack.currencyCode,
      'paymentProvider': paymentMethod.provider,
      'platform': platform,
      'appVersion': AppConfig.appVersion,
      'country': locale.countryCode ?? '*',
      'locale': locale.toLanguageTag(),
    };

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/create',
        data: payload,
        options: authenticatedRequestOptions(
          session.accessToken,
          extraHeaders: {'X-PetMagic-Platform': platform},
        ),
      ),
      retryTransientFailures: false,
    );

    return PurchaseCheckoutModel.fromJson(response.data ?? const {});
  }

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

  Future<void> startStoreCheckout(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  ) async {
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
      purchaseParam: PurchaseParam(productDetails: productDetails),
    );
    if (!launched) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

  Future<StoreProductAvailabilitySnapshot> _loadStoreAvailabilitySnapshot(
    Set<String> requestedProductIds,
  ) async {
    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      return const StoreProductAvailabilitySnapshot(isAvailable: false);
    }

    final response = await _inAppPurchase.queryProductDetails(
      requestedProductIds,
    );
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

  Future<PurchaseHistoryItem> verifyStorePurchase({
    required String orderId,
    required WalletPaymentMethodModel paymentMethod,
    required PurchaseDetails purchase,
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

    return PurchaseHistoryItem.fromJson(response.data ?? const {});
  }

  Future<StoreBillingValidationModel> validateStorePurchase({
    required String provider,
    required PurchaseDetails purchase,
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

    return StoreBillingValidationModel.fromJson(response.data ?? const {});
  }

  Future<void> savePendingStorePurchase(PendingStoreWalletPurchase purchase) {
    return _storePurchaseRecoveryStore.savePendingPurchase(purchase);
  }

  Future<PendingStoreWalletPurchase?> readPendingStorePurchase() {
    return _storePurchaseRecoveryStore.readPendingPurchase();
  }

  Future<void> clearPendingStorePurchase({String? orderId}) {
    return _storePurchaseRecoveryStore.clearPendingPurchase(orderId: orderId);
  }

  Future<void> restoreStorePurchases() {
    return _inAppPurchase.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
  }

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

  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
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
      ),
      retryTransientFailures: false,
    );

    return PurchaseHistoryItem.fromJson(response.data ?? const {});
  }

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
