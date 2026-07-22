import 'dart:io';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';

import 'template_generation_repository_test_support.dart';

void main() {
  test('store purchase verification forwards cancel token', () async {
    final cancelToken = RequestCancellation();
    RequestOptions? request;
    CancelToken? dioCancelToken;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        request = options;
        expect(options.path, '/api/economy/premium/store/verify');
        expect(
          options.headers[HttpHeaders.authorizationHeader],
          'Bearer access-token',
        );
        dioCancelToken = options.cancelToken;
        expect(dioCancelToken, isNotNull);
        expect(dioCancelToken!.isCancelled, isFalse);
        return jsonResponse({
          'paymentProvider': 'google_play',
          'productId': 'com.petmagic.app.premium.monthly',
          'isActive': true,
          'status': 'Active',
          'expiresAtUtc': '2026-12-01T00:00:00Z',
        });
      });
    final repository = PremiumRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
    );

    final result = await repository.verifyStorePurchase(
      plan: _premiumPlan(),
      provider: PremiumPaymentProvider.googlePlay,
      purchase: _storePurchase(),
      cancelToken: cancelToken,
    );

    expect(request, isNotNull);
    expect(result.isActive, isTrue);
    cancelToken.cancel('test_cancelled');
    expect(dioCancelToken!.isCancelled, isTrue);
  });
}

PremiumPlanModel _premiumPlan() {
  return const PremiumPlanModel(
    planCode: 'monthly',
    billingInterval: 'month',
    priceAmount: 14.99,
    currencyCode: 'USD',
    tokenAllowance: 500,
    isPopular: false,
    sortOrder: 1,
    stripeCheckoutEnabled: true,
    googlePlayProductId: 'com.petmagic.app.premium.monthly',
    appStoreProductId: 'com.petmagic.app.premium.monthly',
  );
}

StorePurchaseDetails _storePurchase() {
  return StorePurchaseDetails(
    purchaseID: 'gp-subscription-1',
    productID: 'com.petmagic.app.premium.monthly',
    verificationData: StorePurchaseVerificationData(
      localVerificationData: 'local-store-data',
      serverVerificationData: 'gp-premium-token-1',
      source: 'google_play',
    ),
    transactionDate: DateTime.utc(2026, 7, 4).millisecondsSinceEpoch.toString(),
    status: StorePurchaseStatus.purchased,
    pendingCompletePurchase: false,
  );
}
