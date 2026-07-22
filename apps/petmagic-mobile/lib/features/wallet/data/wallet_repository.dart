export 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart'
    show WalletRepositoryPort, walletRepositoryProvider;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'wallet_store_repository_mixin.part.dart';
part 'wallet_actions_repository_mixin.part.dart';

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

abstract class _WalletRepositoryBase implements WalletRepositoryPort {
  _WalletRepositoryBase({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
    InAppPurchase? inAppPurchase,
    WalletStorePurchaseRecoveryStore? storePurchaseRecoveryStore,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage),
       _storePurchaseService = WalletStorePurchaseService(
         inAppPurchase: inAppPurchase,
       ),
       _storePurchaseRecoveryStore =
           storePurchaseRecoveryStore ??
           WalletStorePurchaseRecoveryStore(
             preferences: SharedPreferencesAsync(),
           );

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final WalletStorePurchaseService _storePurchaseService;
  final WalletStorePurchaseRecoveryStore _storePurchaseRecoveryStore;

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

class WalletRepository extends _WalletRepositoryBase
    with _WalletStoreRepositoryMixin, _WalletActionsRepositoryMixin {
  WalletRepository({
    required super.dio,
    required super.sessionStorage,
    super.authSessionCoordinator,
    super.inAppPurchase,
    super.storePurchaseRecoveryStore,
  });
  @override
  Stream<List<StorePurchaseDetails>> get purchaseUpdates =>
      _storePurchaseService.purchaseUpdates;

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
