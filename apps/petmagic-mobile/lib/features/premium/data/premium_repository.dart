import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  return PremiumRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
  );
});

class PremiumRepository {
  PremiumRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
  }) : _dio = dio,
       _sessionStorage = sessionStorage;

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream;

  Future<List<PremiumPlanModel>> fetchPlans() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/economy/premium/plans',
      );

      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PremiumPlanModel.fromJson)
          .toList(growable: false)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: 'premium.plans_failed');
    }
  }

  Future<PremiumStatusModel> fetchStatus() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/economy/premium/status',
        options: _authOptions(session.accessToken),
      ),
    );

    return PremiumStatusModel.fromJson(response.data ?? const {});
  }

  Future<PremiumCheckoutModel> createStripeCheckout(
    PremiumPlanModel plan,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/checkout',
        data: {
          'planCode': plan.planCode,
          'paymentProvider': PremiumPaymentProvider.stripe.value,
        },
        options: _authOptions(session.accessToken),
      ),
    );

    return PremiumCheckoutModel.fromJson(response.data ?? const {});
  }

  Future<PremiumBillingPortalModel> createBillingPortal() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/economy/premium/manage',
        data: {'paymentProvider': PremiumPaymentProvider.stripe.value},
        options: _authOptions(session.accessToken),
      ),
    );

    return PremiumBillingPortalModel.fromJson(response.data ?? const {});
  }

  Future<({bool isAvailable, Set<String> productIds})> fetchStoreAvailability(
    List<PremiumPlanModel> plans,
    PremiumPaymentProvider provider,
  ) async {
    final requestedIds = plans
        .map((plan) => plan.productIdFor(provider))
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
      throw const AppException('premium.store_unavailable');
    }

    return (
      isAvailable: true,
      productIds: response.productDetails.map((product) => product.id).toSet(),
    );
  }

  Future<void> startStoreCheckout(
    PremiumPlanModel plan,
    PremiumPaymentProvider provider,
  ) async {
    final productId = plan.productIdFor(provider);
    if (productId == null || productId.isEmpty) {
      throw const AppException('premium.store_product_unavailable');
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      throw const AppException('premium.store_unavailable');
    }

    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null) {
      throw const AppException('premium.store_unavailable');
    }

    if (response.productDetails.isEmpty) {
      throw const AppException('premium.store_product_unavailable');
    }

    final launched = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
      ),
    );

    if (!launched) {
      throw const AppException('premium.checkout_failed');
    }
  }

  Future<PremiumStoreVerificationModel> verifyStorePurchase({
    required PremiumPlanModel plan,
    required PremiumPaymentProvider provider,
    required PurchaseDetails purchase,
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
        options: _authOptions(session.accessToken),
      ),
    );

    return PremiumStoreVerificationModel.fromJson(response.data ?? const {});
  }

  Future<void> restoreStorePurchases() {
    return _inAppPurchase.restorePurchases();
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
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

      throw _mapDioException(error, fallbackMessage: 'premium.request_failed');
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

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
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

      if (title != null &&
          (title.startsWith('economy.') || title.startsWith('premium.'))) {
        return AppException(
          title,
          statusCode: error.response?.statusCode,
          cause: error,
        );
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
