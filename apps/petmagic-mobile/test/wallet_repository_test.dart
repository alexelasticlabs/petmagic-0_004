import 'dart:io';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'template_generation_repository_test_support.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'purchase order IDs are encoded before being used as path segments',
    () async {
      const orderId = 'order/../admin?x=1&next=/wallet#frag';
      final encodedOrderId = Uri.encodeComponent(orderId);
      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          paths.add(options.path);
          expect(
            options.headers[HttpHeaders.authorizationHeader],
            'Bearer access-token',
          );
          expect(options.path, isNot(contains(orderId)));
          return jsonResponse(_purchaseJson(orderId));
        });

      final repository = WalletRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
      );

      await repository.fetchPurchase(orderId);
      await repository.verifyStripeCheckoutSession(
        orderId: orderId,
        stripeReferenceId: 'cs_test_validSession123',
      );
      await repository.verifyStorePurchase(
        orderId: orderId,
        paymentMethod: const WalletPaymentMethodModel(
          provider: 'google_play',
          purchaseChannel: 'in_app',
          platform: 'android',
          region: '*',
          requiresExternalWarning: false,
          requiresStoreDisclosure: true,
          bonusTokensPercent: 0,
          displayLabel: 'Google Play',
          displaySubtitle: null,
          isEnabled: true,
          isRecommended: false,
          isSelectedByDefault: false,
        ),
        purchase: _storePurchase(),
      );

      expect(paths, [
        '/api/economy/purchases/$encodedOrderId',
        '/api/economy/purchases/$encodedOrderId/verify-stripe',
        '/api/economy/purchases/$encodedOrderId/verify-store',
      ]);
    },
  );

  test('offset pagination query values are clamped before requests', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        expect(
          options.headers[HttpHeaders.authorizationHeader],
          'Bearer access-token',
        );

        if (options.path == '/api/economy/wallet/ledger') {
          return jsonResponse({
            'items': const <Map<String, Object?>>[],
            'skip': 0,
            'take': 100,
            'hasMore': false,
          });
        }

        if (options.path == '/api/economy/purchases') {
          return jsonResponse({
            'items': const <Map<String, Object?>>[],
            'skip': 0,
            'take': 1,
            'hasMore': false,
          });
        }

        throw StateError('Unexpected path: ${options.path}');
      });

    final repository = WalletRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
    );

    await repository.fetchLedger(skip: -10, take: 1000);
    await repository.fetchPurchases(skip: -1, take: 0);

    expect(requests, hasLength(2));
    expect(requests[0].queryParameters, {'skip': 0, 'take': 100});
    expect(requests[1].queryParameters, {'skip': 0, 'take': 1});
  });

  test(
    'wallet repository isolates store plugin operations without changing semantics',
    () {
      final repositorySource = File(
        'lib/features/wallet/data/wallet_repository.dart',
      ).readAsStringSync();
      final storeServiceSource = File(
        'lib/features/wallet/data/wallet_store_purchase_service.dart',
      ).readAsStringSync();

      expect(repositorySource, contains('WalletStorePurchaseService('));
      expect(
        repositorySource,
        contains('_storePurchaseService.purchaseUpdates'),
      );
      expect(
        repositorySource,
        contains('_storePurchaseService.startCheckout('),
      );
      expect(
        repositorySource,
        contains('applicationUserName: session.user.userId'),
      );
      expect(storeServiceSource, contains('autoConsume: false'));
      expect(
        storeServiceSource,
        contains('applicationUserName: applicationUserName'),
      );
      expect(storeServiceSource, contains('.restorePurchases('));
      expect(storeServiceSource, contains('consumePurchase(platformPurchase)'));
      expect(storeServiceSource, contains('BillingResponse.ok'));
    },
  );
}

Map<String, Object?> _purchaseJson(String orderId) {
  return {
    'orderId': orderId,
    'packDisplayName': 'Starter Sparks',
    'paymentProvider': 'stripe',
    'status': 'succeeded',
    'priceAmount': 4.99,
    'currencyCode': 'USD',
    'sparkToGrant': 100,
    'createdAtUtc': '2026-01-01T00:00:00Z',
    'confirmedAtUtc': '2026-01-01T00:01:00Z',
  };
}

StorePurchaseDetails _storePurchase() {
  return StorePurchaseDetails(
    purchaseID: 'gp-purchase-1',
    productID: 'com.petmagic.app.tokens.google.pack100',
    verificationData: StorePurchaseVerificationData(
      localVerificationData: 'local-store-data',
      serverVerificationData: 'gp-token-pack-1',
      source: 'google_play',
    ),
    transactionDate: DateTime.utc(2026, 7, 2).millisecondsSinceEpoch.toString(),
    status: StorePurchaseStatus.purchased,
    pendingCompletePurchase: false,
  );
}
