import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
  );
});

class WalletRepository {
  WalletRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
  }) : _dio = dio,
       _sessionStorage = sessionStorage;

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;

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
          'appVersion': '1.0.0',
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
      'appVersion': '1.0.0',
      'country': locale.countryCode ?? '*',
      'locale': locale.toLanguageTag(),
    };

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/purchases/create',
        data: payload,
        options: _authOptions(session.accessToken),
      ),
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

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    var session = await _sessionStorage.read();
    if (session == null) {
      throw const AppException('Sign in is required.', statusCode: 401);
    }

    try {
      return await request(session);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        session = await _refreshSession(session.refreshToken);
        return request(session);
      }

      throw _mapDioException(error, fallbackMessage: 'wallet.request_failed');
    }
  }

  Future<AuthSession> _refreshSession(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final refreshed = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(refreshed);
      return refreshed;
    } on DioException catch (error) {
      await _sessionStorage.clear();
      throw _mapDioException(error, fallbackMessage: 'Session expired.');
    }
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
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.response == null) {
      return AppException(
        'wallet.network_unavailable',
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return AppException(
        'wallet.server_unavailable',
        statusCode: statusCode,
        cause: error,
      );
    }

    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] as String?;
      final title = responseData['title'] as String?;
      final errors = responseData['errors'];
      if (errors is Map<String, dynamic>) {
        final flattened = errors.values
            .whereType<List<dynamic>>()
            .expand((value) => value.whereType<String>())
            .join(' ');
        if (flattened.isNotEmpty) {
          return AppException(
            flattened,
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
      }

      if (detail != null && detail.isNotEmpty) {
        return AppException(
          detail,
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }

      if (title != null && title.isNotEmpty) {
        return AppException(
          title,
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }
    }

    return AppException(
      fallbackMessage,
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }
}
