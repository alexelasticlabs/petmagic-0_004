export 'package:petmagic_mobile/features/premium/application/premium_repository.dart'
    show PremiumRepositoryPort, premiumRepositoryProvider;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_dto_mapper.dart';
import 'package:petmagic_mobile/features/premium/application/premium_repository.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:petmagic_mobile/shared/payments/store_purchase_adapter.dart';

part 'premium_repository_transport.part.dart';

final dioPremiumRepositoryProvider = Provider<PremiumRepositoryPort>((ref) {
  return PremiumRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

class PremiumRepository implements PremiumRepositoryPort {
  PremiumRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
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

  @override
  Stream<List<StorePurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream.map(
        (purchases) =>
            purchases.map(mapPlatformStorePurchase).toList(growable: false),
      );

  @override
  Future<PremiumPaywallConfigModel> fetchPaywallConfig({
    required AppLocale locale,
    RequestCancellation? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/economy/subscriptions/paywall-config',
        queryParameters: {
          'platform': _platformValue(),
          'appVersion': AppConfig.appVersion,
          'country': locale.countryCode ?? '*',
          'locale': locale.languageTag,
        },
        cancelToken: cancelToken.toDioCancelToken(),
      );

      return mapPremiumPaywallConfigFromJson(response.data ?? const {});
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }
      throw _mapDioException(error, fallbackMessage: 'premium.plans_failed');
    }
  }

  @override
  Future<List<PremiumPlanModel>> fetchPlans() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/economy/premium/plans',
      );

      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(mapPremiumPlanFromJson)
          .toList(growable: false)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'premium.plans_failed');
    }
  }

  @override
  Future<PremiumStatusModel> fetchStatus({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/me/subscription',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );

    return mapPremiumStatusFromJson(response.data ?? const {});
  }

  @override
  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
    AppLocale locale, {
    RequestCancellation? cancelToken,
  }) async {
    final platform = _platformValue();
    final payload = <String, Object?>{
      'planCode': plan.planCode,
      'paymentProvider': PremiumPaymentProvider.stripe.value,
      'platform': platform,
      'appVersion': AppConfig.appVersion,
      'country': locale.countryCode ?? '*',
      'locale': locale.languageTag,
    };

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/checkout',
        data: payload,
        options: authenticatedRequestOptions(
          session.accessToken,
          extraHeaders: {'X-PetMagic-Platform': platform},
        ),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    final checkout = mapPremiumCheckoutFromJson(response.data ?? const {});
    if (platform == 'web' ||
        checkout.hasNativeStripePaymentSheet ||
        checkout.checkoutUrl.trim().isNotEmpty) {
      return checkout;
    }

    throw const AppException('premium.checkout_failed');
  }

  @override
  Future<PremiumBillingPortalModel> createBillingPortal({
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/manage',
        data: {'paymentProvider': PremiumPaymentProvider.stripe.value},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPremiumBillingPortalFromJson(response.data ?? const {});
  }

  @override
  Future<PremiumStatusModel> cancelSubscription({
    PremiumPaymentProvider provider = PremiumPaymentProvider.stripe,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/cancel',
        data: {'paymentProvider': provider.value},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPremiumStatusFromJson(response.data ?? const {});
  }

  @override
  Future<String> createManagementUrl(
    PremiumStatusModel status, {
    RequestCancellation? cancelToken,
  }) async {
    switch (status.manageSubscriptionAction) {
      case 'AppleSettings':
        return 'https://apps.apple.com/account/subscriptions';
      case 'GooglePlaySettings':
        return 'https://play.google.com/store/account/subscriptions';
      case 'StripeCustomerPortal':
        final portal = await createBillingPortal(cancelToken: cancelToken);
        return portal.portalUrl;
      default:
        throw const AppException('premium.manage_failed');
    }
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
    List<PremiumPlanModel> plans,
    PremiumPaymentProvider provider,
  ) async {
    final requestedIds = plans
        .map((plan) => plan.productIdFor(provider))
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
      scopeKey: provider.value,
    );

    return (
      isAvailable: availability.isAvailable,
      productIds: availability.productIds,
      productPrices: availability.productPrices,
    );
  }

  @override
  Future<void> startStoreCheckout(
    PremiumPlanModel plan,
    PremiumPaymentProvider provider,
  ) async {
    final session = await _authSessionCoordinator.requireValidSession(
      mapError: _mapDioException,
      unauthorizedMessage: 'auth.sign_in_required',
      sessionExpiredMessage: 'auth.session_expired',
    );
    final productId = plan.productIdFor(provider);
    if (productId == null || productId.isEmpty) {
      throw const AppException('premium.store_product_unavailable');
    }

    final availability = await sharedStoreProductAvailabilityCache.read(
      {productId},
      loader: _loadStoreAvailabilitySnapshot,
      scopeKey: provider.value,
    );
    if (!availability.isAvailable) {
      throw const AppException('premium.store_unavailable');
    }

    final productDetails = availability.productDetailsById[productId];
    if (productDetails == null) {
      throw const AppException('premium.store_product_unavailable');
    }

    final launched = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: productDetails,
        applicationUserName: session.user.userId,
      ),
    );

    if (!launched) {
      throw const AppException('premium.checkout_failed');
    }
  }

  Future<StoreProductAvailabilitySnapshot> _loadStoreAvailabilitySnapshot(
    Set<String> requestedProductIds,
  ) => _PremiumRepositoryTransport.loadStoreAvailabilitySnapshot(
    _inAppPurchase,
    requestedProductIds,
  );

  @override
  Future<PremiumStoreVerificationModel> verifyStorePurchase({
    required PremiumPlanModel plan,
    required PremiumPaymentProvider provider,
    required StorePurchaseDetails purchase,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/store/verify',
        data: {
          'planCode': plan.planCode,
          'paymentProvider': provider.value,
          'productId': purchase.productID,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
          'localVerificationData':
              purchase.verificationData.localVerificationData,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );

    return mapPremiumStoreVerificationFromJson(response.data ?? const {});
  }

  @override
  Future<void> verifyStripeSubscriptionCheckout({
    required String planCode,
    required String externalSubscriptionId,
    RequestCancellation? cancelToken,
  }) async {
    await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/verify-stripe',
        data: {
          'planCode': planCode,
          'externalSubscriptionId': externalSubscriptionId,
        },
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
  }

  String _platformValue() => _PremiumRepositoryTransport.platformValue();

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

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) => _PremiumRepositoryTransport.authorizedRequest(
    _authSessionCoordinator,
    request,
    retryTransientFailures: retryTransientFailures,
  );

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) => _PremiumRepositoryTransport.mapDioException(
    error,
    fallbackMessage: fallbackMessage,
  );
}
