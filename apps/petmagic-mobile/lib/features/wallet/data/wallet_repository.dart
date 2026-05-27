import 'dart:io';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
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
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<WalletStateModel> fetchWallet() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet',
        options: _authOptions(session.accessToken),
      ),
    );

    return WalletStateModel.fromJson(response.data ?? const {});
  }

  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/wallet/ledger',
        queryParameters: {'skip': skip, 'take': take},
        options: _authOptions(session.accessToken),
      ),
    );

    return OffsetPagedModel.fromJson(
      response.data ?? const {},
      WalletLedgerItem.fromJson,
    );
  }

  Future<RewardsSummaryModel> fetchRewards() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/rewards',
        options: _authOptions(session.accessToken),
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
      );

      return WalletCheckoutConfigModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'wallet.packs_failed');
    }
  }

  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/purchases',
        queryParameters: {'skip': skip, 'take': take},
        options: _authOptions(session.accessToken),
      ),
    );

    return OffsetPagedModel.fromJson(
      response.data ?? const {},
      PurchaseHistoryItem.fromJson,
    );
  }

  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    Locale locale,
  ) async {
    final payload = <String, Object?>{
      'packId': pack.packId,
      'currencyCode': pack.currencyCode,
      'paymentProvider': paymentMethod.provider,
      'platform': _platformValue(),
      'appVersion': AppConfig.appVersion,
      'country': locale.countryCode ?? '*',
      'locale': locale.toLanguageTag(),
    };

    developer.log(
      'POST /api/economy/purchases/create (packId=${pack.packId}, provider=${paymentMethod.provider}, currency=${pack.currencyCode}, country=${locale.countryCode ?? '*'})',
      name: 'PetMagic.Wallet.Api',
    );

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/create',
        data: payload,
        options: _authOptions(session.accessToken),
      ),
    );

    developer.log(
      'POST /api/economy/purchases/create -> ${response.statusCode}',
      name: 'PetMagic.Wallet.Api',
    );

    return PurchaseCheckoutModel.fromJson(response.data ?? const {});
  }

  Future<WalletStateModel> claimAdReward() async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/wallet/claim-ad',
        options: _authOptions(session.accessToken),
      ),
    );

    return fetchWallet();
  }

  Future<WalletStateModel> applyRedeemCode(String code) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/wallet/redeem',
        data: {'code': code.trim()},
        options: _authOptions(session.accessToken),
      ),
    );

    return fetchWallet();
  }

  Future<RewardsSummaryModel> applyReferralCode(String code) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/referrals/activate',
        data: {'code': code.trim()},
        options: _authOptions(session.accessToken),
      ),
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
        options: _authOptions(session.accessToken),
      ),
    );

    return PurchaseHistoryItem.fromJson(response.data ?? const {});
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'wallet.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  Options _authOptions(String accessToken) {
    return Options(
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
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
    if (payload.flattened != null) {
      return NetworkErrorMapper.fromMessage(error, payload.flattened!);
    }

    if (payload.detail != null) {
      return NetworkErrorMapper.fromMessage(error, payload.detail!);
    }

    if (payload.title != null) {
      return NetworkErrorMapper.fromMessage(error, payload.title!);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}
