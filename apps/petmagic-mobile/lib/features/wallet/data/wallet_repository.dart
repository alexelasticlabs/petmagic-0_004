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

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

class WalletRepository {
  WalletRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
    InAppPurchase? inAppPurchase,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage),
       _inAppPurchaseOverride = inAppPurchase;

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final InAppPurchase? _inAppPurchaseOverride;

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
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/ledger',
        queryParameters: {'skip': skip, 'take': take},
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
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases',
        queryParameters: {'skip': skip, 'take': take},
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
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases/$orderId',
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

  Future<({bool isAvailable, Set<String> productIds})> fetchStoreAvailability(
    List<CurrencyPackModel> packs,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    if (!paymentMethod.isStoreNative) {
      return (isAvailable: false, productIds: const <String>{});
    }

    final requestedIds = packs
        .map((pack) => pack.productIdForProvider(paymentMethod.provider))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();

    if (requestedIds.isEmpty) {
      return (isAvailable: false, productIds: const <String>{});
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      return (isAvailable: false, productIds: const <String>{});
    }

    final response = await _inAppPurchase.queryProductDetails(requestedIds);
    if (response.error != null) {
      throw const AppException('wallet.payment_unavailable');
    }

    return (
      isAvailable: true,
      productIds: response.productDetails.map((product) => product.id).toSet(),
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

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      throw const AppException('wallet.payment_unavailable');
    }

    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      throw const AppException('wallet.payment_unavailable');
    }

    final launched = await _inAppPurchase.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
      ),
    );
    if (!launched) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

  Future<PurchaseHistoryItem> verifyStorePurchase({
    required String orderId,
    required WalletPaymentMethodModel paymentMethod,
    required PurchaseDetails purchase,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/$orderId/verify-store',
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

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/$orderId/verify-stripe',
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
