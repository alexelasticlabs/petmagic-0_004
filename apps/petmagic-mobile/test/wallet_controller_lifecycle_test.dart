import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wallet lifecycle side effects are initialized once outside build', () {
    final source = File(
      'lib/features/wallet/presentation/wallet_controller.dart',
    ).readAsStringSync();
    final buildBody = _methodBody(source, 'build');
    final lifecycleBody = _methodBody(source, '_ensureWalletLifecycleStarted');

    expect(buildBody, contains('_ensureWalletLifecycleStarted();'));
    expect(buildBody, isNot(contains('WidgetsBinding.instance.addObserver')));
    expect(buildBody, isNot(contains('Timer.periodic')));
    expect(buildBody, isNot(contains('purchaseUpdates.listen')));
    expect(source, isNot(contains('Timer.periodic')));
    expect(source, isNot(contains('_walletSyncTimer')));

    expect(source, contains('bool _walletLifecycleStarted = false;'));
    expect(lifecycleBody, contains('if (_walletLifecycleStarted)'));
    expect(lifecycleBody, contains('_walletLifecycleStarted = true;'));
    expect(
      lifecycleBody,
      contains('WidgetsBinding.instance.addObserver(this)'),
    );
    expect(lifecycleBody, contains('_repository.purchaseUpdates.listen'));
    expect(lifecycleBody, contains('ref.onDispose'));
  });

  test('wallet load completes safely after provider disposal', () async {
    final repository = _DelayedWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );

    final controller = container.read(walletControllerProvider.notifier);
    final loadFuture = controller.load();

    await repository.fetchWalletStarted.future;
    container.dispose();
    expect(repository.fetchWalletCancelToken?.isCancelled, isTrue);
    repository.completeFetchWallet();

    await expectLater(loadFuture, completes);
  });

  test(
    'stripe verification completes safely after provider disposal',
    () async {
      final repository = _DelayedWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );

      final controller = container.read(walletControllerProvider.notifier);
      final checkout = await controller.buyPack(_pack, _stripeMethod);
      expect(checkout?.orderId, 'order-1');

      final verificationFuture = controller.verifyStripeCheckout('cs_test_123');
      await repository.verifyStripeStarted.future;

      container.dispose();
      repository.completeVerifyStripe();

      await expectLater(verificationFuture, completes);
    },
  );

  test(
    'wallet checkout rejects unsafe external checkout url before state update',
    () async {
      final repository = _DelayedWalletRepository(
        checkoutUrl: 'https://checkout.stripe.com@evil.example/session',
      );
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final checkout = await container
          .read(walletControllerProvider.notifier)
          .buyPack(_pack, _stripeMethod);

      final state = container.read(walletControllerProvider);
      expect(checkout, isNull);
      expect(state.checkoutUrl, isNull);
      expect(state.pendingCheckoutOrderId, isNull);
      expect(state.errorMessage, 'payment_gateway_failed');
      expect(state.isBuying, isFalse);
    },
  );

  test(
    'stripe verification logging does not include raw payment reference',
    () {
      final source = File(
        'lib/features/wallet/presentation/wallet_controller.dart',
      ).readAsStringSync();
      final verifyBody = _methodBody(source, 'verifyStripeCheckout');

      expect(verifyBody, contains("'reference_type'"));
      expect(verifyBody, contains('_stripeReferenceType(normalizedReference)'));
      expect(verifyBody, isNot(contains("'reference': normalizedReference")));
      expect(
        verifyBody,
        isNot(contains("'reference': normalizedReference ??")),
      );
      expect(source, contains("String _stripeReferenceType(String? value)"));
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:WalletState|void|Future<[^>]+>)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = source.indexOf('{', methodMatch.start);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

class _DelayedWalletRepository extends WalletRepository {
  _DelayedWalletRepository({
    this.checkoutUrl = 'https://checkout.stripe.com/session',
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final String checkoutUrl;
  final Completer<void> fetchWalletStarted = Completer<void>();
  final Completer<void> _fetchWalletCompleter = Completer<void>();
  final Completer<void> verifyStripeStarted = Completer<void>();
  final Completer<void> _verifyStripeCompleter = Completer<void>();
  CancelToken? fetchWalletCancelToken;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  void completeFetchWallet() {
    if (!_fetchWalletCompleter.isCompleted) {
      _fetchWalletCompleter.complete();
    }
  }

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    fetchWalletCancelToken = cancelToken;
    if (!fetchWalletStarted.isCompleted) {
      fetchWalletStarted.complete();
    }

    await _fetchWalletCompleter.future;
    return _wallet();
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    return const OffsetPagedModel(items: [], skip: 0, take: 20, hasMore: false);
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    return const RewardsSummaryModel(
      referralCode: '',
      referralBonusSpark: 0,
      referralStatus: 'none',
      totalReferralBonusEarned: 0,
      referredUsersCount: 0,
      pendingReferredUsersCount: 0,
      rewardedReferredUsersCount: 0,
    );
  }

  @override
  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required Locale locale,
    CancelToken? cancelToken,
  }) async {
    return const WalletCheckoutConfigModel(
      packs: [],
      paymentMethods: [],
      externalPaymentWarningRequired: false,
    );
  }

  @override
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    return const OffsetPagedModel(items: [], skip: 0, take: 20, hasMore: false);
  }

  @override
  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    Locale locale,
  ) async {
    return PurchaseCheckoutModel(
      orderId: 'order-1',
      paymentProvider: 'stripe',
      checkoutUrl: checkoutUrl,
      externalPaymentId: 'cs_test_123',
      paymentIntentClientSecret: null,
      customerId: null,
      customerEphemeralKeySecret: null,
      publishableKey: null,
      status: 'pending',
    );
  }

  @override
  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
  }) async {
    if (!verifyStripeStarted.isCompleted) {
      verifyStripeStarted.complete();
    }

    await _verifyStripeCompleter.future;
    return PurchaseHistoryItem(
      orderId: orderId,
      packDisplayName: 'Starter Sparks',
      paymentProvider: 'stripe',
      status: 'succeeded',
      priceAmount: 4.99,
      currencyCode: 'USD',
      sparkToGrant: 100,
      createdAtUtc: DateTime.utc(2026, 1, 1),
      confirmedAtUtc: DateTime.utc(2026, 1, 1, 0, 1),
    );
  }

  void completeVerifyStripe() {
    if (!_verifyStripeCompleter.isCompleted) {
      _verifyStripeCompleter.complete();
    }
  }
}

const _pack = CurrencyPackModel(
  packId: 'pack-1',
  code: 'starter',
  displayName: 'Starter Sparks',
  currencyCode: 'USD',
  priceAmount: 4.99,
  grantedSpark: 100,
  bonusSpark: 0,
  totalSpark: 100,
);

const _stripeMethod = WalletPaymentMethodModel(
  provider: 'stripe',
  purchaseChannel: 'external_checkout',
  platform: 'android',
  region: '*',
  isEnabled: true,
  isSelectedByDefault: true,
  requiresExternalWarning: false,
  requiresStoreDisclosure: false,
  isRecommended: true,
  bonusTokensPercent: 0,
);

WalletStateModel _wallet() {
  return WalletStateModel(
    userId: 'user-1',
    balance: 10,
    adRewardsRemainingToday: 1,
    isPremium: false,
    updatedAtUtc: DateTime.utc(2026, 1, 1),
  );
}
