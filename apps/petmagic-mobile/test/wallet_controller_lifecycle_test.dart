import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

import 'wallet_controller_test_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wallet lifecycle side effects are initialized once outside build', () {
    final source = readWalletControllerLibrarySource();
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
      contains(
        'AppLifecycleSignal.instance.addListener(_appLifecycleListener!)',
      ),
    );
    expect(lifecycleBody, contains('_handleAppLifecycleSignal'));
    expect(lifecycleBody, contains('_repository.purchaseUpdates.listen'));
    expect(lifecycleBody, contains('ref.onDispose'));
  });

  test('wallet page defers activate refresh until after frame', () {
    final source = File(
      'lib/features/wallet/presentation/wallet_page.dart',
    ).readAsStringSync();
    final activateBody = _methodBody(source, 'activate');

    expect(
      activateBody,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
    );
    expect(
      activateBody,
      isNot(contains('unawaited(_walletController.load(refresh: true))')),
    );
    expect(
      activateBody,
      contains('unawaited(_refreshVisibleWalletData(forceRefresh: true))'),
    );
  });

  test(
    'wallet page uses lightweight snapshot refresh after full hydration',
    () {
      final source = File(
        'lib/features/wallet/presentation/wallet_page.dart',
      ).readAsStringSync();

      expect(source, contains('if (state.wallet != null)'));
      expect(
        source,
        contains('await controller.syncSnapshot(forceRefresh: forceRefresh);'),
      );
      expect(source, contains('await controller.load(refresh: true);'));
    },
  );

  test('all transactions page keeps wallet surface marked visible', () {
    final source = File(
      'lib/features/wallet/presentation/all_transactions_page.dart',
    ).readAsStringSync();

    expect(source, contains('_walletController.setWalletPageVisible(true);'));
    expect(source, contains('_walletController.setWalletPageVisible(false);'));
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

  test('wallet load normalizes wrapped backend error keys', () async {
    final repository = _ErrorWalletRepository(
      fetchWalletError: const AppException(
        '  RuntimeError: WALLET.NETWORK_UNAVAILABLE  ',
      ),
    );
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    final state = container.read(walletControllerProvider);
    expect(state.errorMessage, 'wallet.network_unavailable');
    expect(state.isLoading, isFalse);
  });

  test('wallet checkout normalizes wrapped purchase error keys', () async {
    final repository = _ErrorWalletRepository(
      createPurchaseError: const AppException(
        ' AppException: wallet.payment_unavailable ',
      ),
    );
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    final checkout = await controller.buyPack(_pack, _stripeMethod);

    final state = container.read(walletControllerProvider);
    expect(checkout, isNull);
    expect(state.errorMessage, 'wallet.payment_unavailable');
    expect(state.isBuying, isFalse);
  });

  test(
    'buyPack double-submit guard ignores second call while first is in flight',
    () async {
      final repository = _DelayedWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);

      final firstFuture = controller.buyPack(_pack, _stripeMethod);

      // Second call while isBuying=true must be a no-op.
      final secondResult = await controller.buyPack(_pack, _stripeMethod);
      expect(secondResult, isNull);

      await firstFuture;
    },
  );

  test('wallet resume sync refreshes ledger pagination snapshot', () async {
    final repository = _LifecycleSyncWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    var state = container.read(walletControllerProvider);
    expect(state.wallet?.balance, 10);
    expect(state.ledgerHasMore, isFalse);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await repository.syncCompleted.future;
    await Future<void>.delayed(Duration.zero);

    state = container.read(walletControllerProvider);
    expect(state.wallet?.balance, 42);
    expect(state.ledger, hasLength(1));
    expect(state.ledger.first.entryId, 'entry-sync');
    expect(state.ledgerHasMore, isTrue);
  });

  test(
    'wallet load marks full snapshot as hydrated after ancillary requests',
    () async {
      final repository = _LifecycleSyncWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();

      final state = container.read(walletControllerProvider);
      expect(state.hasCompletedFullLoad, isTrue);
    },
  );

  test(
    'wallet load keeps snapshot unhydrated when ancillary request fails',
    () async {
      final repository = _PartialWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();

      final state = container.read(walletControllerProvider);
      expect(state.wallet, isNotNull);
      expect(state.errorMessage, 'rewards.summary_failed');
      expect(state.hasCompletedFullLoad, isFalse);
    },
  );

  test(
    'wallet resume sync skips duplicate snapshot refresh while wallet page is visible',
    () async {
      final repository = _LifecycleSyncWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();
      controller.setWalletPageVisible(true);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(walletControllerProvider);
      expect(repository.walletFetchCount, 1);
      expect(state.wallet?.balance, 10);
      expect(repository.syncCompleted.isCompleted, isFalse);
    },
  );

  test(
    'wallet resume sync preserves already loaded older ledger pages without duplicates',
    () async {
      final repository = _LedgerPreservingSyncWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();
      await controller.loadMoreLedger();

      var state = container.read(walletControllerProvider);
      expect(state.ledger, hasLength(26));
      expect(state.ledger.first.entryId, 'entry-26');
      expect(state.ledger.last.entryId, 'entry-1');
      expect(state.ledgerHasMore, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await repository.syncCompleted.future;
      await Future<void>.delayed(Duration.zero);

      state = container.read(walletControllerProvider);
      expect(state.wallet?.balance, 42);
      expect(state.ledger, hasLength(27));
      expect(state.ledger.first.entryId, 'entry-27');
      expect(
        state.ledger.map((item) => item.entryId).toSet().length,
        state.ledger.length,
      );
      expect(state.ledger.take(4).map((item) => item.entryId), [
        'entry-27',
        'entry-26',
        'entry-25',
        'entry-24',
      ]);
      expect(state.ledger.last.entryId, 'entry-1');
      expect(state.ledgerHasMore, isTrue);
    },
  );

  test('wallet refresh cancels in-flight ledger load more request', () async {
    final repository = _CancelableLedgerLoadMoreWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    final loadMoreFuture = controller.loadMoreLedger();
    await repository.loadMoreStarted.future;

    expect(
      container.read(walletControllerProvider).isLoadingMoreLedger,
      isTrue,
    );

    final refreshFuture = controller.load(refresh: true);
    expect(repository.loadMoreCancelToken?.isCancelled, isTrue);

    repository.completeLoadMore();

    await loadMoreFuture;
    await refreshFuture;

    final state = container.read(walletControllerProvider);
    expect(state.isLoadingMoreLedger, isFalse);
    expect(state.ledgerLoadMoreErrorMessage, isNull);
    expect(state.ledger.map((item) => item.entryId), ['entry-1']);
  });

  test(
    'wallet load more skips duplicate ledger entries from overlapping pages',
    () async {
      final repository = _OverlappingLedgerLoadMoreWalletRepository();
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();
      await controller.loadMoreLedger();

      final state = container.read(walletControllerProvider);
      expect(state.ledger.map((item) => item.entryId), [
        'entry-24',
        'entry-23',
        'entry-22',
        'entry-21',
        'entry-20',
        'entry-19',
      ]);
      expect(state.ledgerHasMore, isFalse);
    },
  );

  test('claim ad reward refreshes ledger pagination snapshot', () async {
    final repository = _MutationLedgerWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    await controller.claimAdReward();

    final state = container.read(walletControllerProvider);
    expect(state.wallet?.balance, 25);
    expect(state.ledger, hasLength(1));
    expect(state.ledger.first.entryId, 'entry-claim');
    expect(state.ledgerHasMore, isTrue);
  });

  test('redeem code refreshes ledger pagination snapshot', () async {
    final repository = _MutationLedgerWalletRepository();
    final container = ProviderContainer(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    await controller.applyRedeemCode('PROMO');

    final state = container.read(walletControllerProvider);
    expect(state.wallet?.balance, 25);
    expect(state.ledger, hasLength(1));
    expect(state.ledger.first.entryId, 'entry-redeem');
    expect(state.ledgerHasMore, isTrue);
  });

  test(
    'stripe verification logging does not include raw payment reference',
    () {
      final source = readWalletControllerLibrarySource();
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
    r'(?:@override\s+)?(?:WalletState|void|Future<[^>]+>)\s+' +
        methodName +
        r'\s*\([^)]*\)\s*(?:async\s*)?\{',
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

class _ErrorWalletRepository extends _DelayedWalletRepository {
  _ErrorWalletRepository({this.fetchWalletError, this.createPurchaseError});

  final Object? fetchWalletError;
  final Object? createPurchaseError;

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    if (fetchWalletError != null) {
      throw fetchWalletError!;
    }
    return _wallet();
  }

  @override
  Future<PurchaseCheckoutModel> createPurchase(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
    Locale locale,
  ) async {
    if (createPurchaseError != null) {
      throw createPurchaseError!;
    }
    return super.createPurchase(pack, paymentMethod, locale);
  }
}

class _LifecycleSyncWalletRepository extends WalletRepository {
  _LifecycleSyncWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> syncCompleted = Completer<void>();
  int _walletFetchCount = 0;

  int get walletFetchCount => _walletFetchCount;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    _walletFetchCount++;
    return WalletStateModel(
      userId: 'user-1',
      balance: _walletFetchCount == 1 ? 10 : 42,
      adRewardsRemainingToday: 1,
      isPremium: false,
      updatedAtUtc: DateTime.utc(2026, 1, 1, 12, _walletFetchCount),
    );
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    final page = _walletFetchCount <= 1
        ? const OffsetPagedModel<WalletLedgerItem>(
            items: [],
            skip: 0,
            take: 20,
            hasMore: false,
          )
        : OffsetPagedModel(
            items: [
              WalletLedgerItem(
                entryId: 'entry-sync',
                userId: 'user-1',
                delta: 32,
                balanceAfter: 42,
                source: 'purchase_reward',
                reason: 'Synced entry',
                createdAtUtc: DateTime.utc(2026, 1, 1, 12, 2),
              ),
            ],
            skip: skip,
            take: take,
            hasMore: true,
          );

    if (_walletFetchCount > 1 && !syncCompleted.isCompleted) {
      syncCompleted.complete();
    }
    return page;
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    return _emptyRewards();
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
}

class _LedgerPreservingSyncWalletRepository extends WalletRepository {
  _LedgerPreservingSyncWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> syncCompleted = Completer<void>();
  int _walletFetchCount = 0;
  final List<WalletLedgerItem> _initialLedger = List.generate(
    26,
    (index) => WalletLedgerItem(
      entryId: 'entry-${26 - index}',
      userId: 'user-1',
      delta: 1,
      balanceAfter: 100 - index,
      source: 'weekly_grant',
      reason: 'Initial ledger item ${26 - index}',
      createdAtUtc: DateTime.utc(2026, 1, 1, 12, index),
    ),
  );
  late final List<WalletLedgerItem> _syncedLedger = [
    WalletLedgerItem(
      entryId: 'entry-27',
      userId: 'user-1',
      delta: 5,
      balanceAfter: 105,
      source: 'ad_reward',
      reason: 'Synced top-up',
      createdAtUtc: DateTime.utc(2026, 1, 1, 13),
    ),
    ..._initialLedger,
  ];

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    _walletFetchCount++;
    return WalletStateModel(
      userId: 'user-1',
      balance: _walletFetchCount == 1 ? 10 : 42,
      adRewardsRemainingToday: 1,
      isPremium: false,
      updatedAtUtc: DateTime.utc(2026, 1, 1, 12, _walletFetchCount),
    );
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    final ledger = _walletFetchCount <= 1 ? _initialLedger : _syncedLedger;
    final start = skip.clamp(0, ledger.length);
    final end = (start + take).clamp(0, ledger.length);
    final page = OffsetPagedModel(
      items: ledger.sublist(start, end),
      skip: start,
      take: take,
      hasMore: end < ledger.length,
    );

    if (_walletFetchCount > 1 && !syncCompleted.isCompleted) {
      syncCompleted.complete();
    }

    return page;
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
}

class _MutationLedgerWalletRepository extends WalletRepository {
  _MutationLedgerWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  _MutationLedgerPhase _phase = _MutationLedgerPhase.initial;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    final balance = _phase == _MutationLedgerPhase.initial ? 10 : 25;
    return WalletStateModel(
      userId: 'user-1',
      balance: balance,
      adRewardsRemainingToday: 1,
      isPremium: false,
      updatedAtUtc: DateTime.utc(2026, 1, 1, 13, balance),
    );
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    return switch (_phase) {
      _MutationLedgerPhase.initial => const OffsetPagedModel(
        items: <WalletLedgerItem>[],
        skip: 0,
        take: 20,
        hasMore: false,
      ),
      _MutationLedgerPhase.claimed => OffsetPagedModel(
        items: [
          WalletLedgerItem(
            entryId: 'entry-claim',
            userId: 'user-1',
            delta: 15,
            balanceAfter: 25,
            source: 'ad_reward',
            reason: 'Ad reward',
            createdAtUtc: DateTime.utc(2026, 1, 1, 13, 1),
          ),
        ],
        skip: skip,
        take: take,
        hasMore: true,
      ),
      _MutationLedgerPhase.redeemed => OffsetPagedModel(
        items: [
          WalletLedgerItem(
            entryId: 'entry-redeem',
            userId: 'user-1',
            delta: 15,
            balanceAfter: 25,
            source: 'redeem_code',
            reason: 'Promo code',
            createdAtUtc: DateTime.utc(2026, 1, 1, 13, 2),
          ),
        ],
        skip: skip,
        take: take,
        hasMore: true,
      ),
    };
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    return _emptyRewards();
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
  Future<WalletStateModel> claimAdReward() async {
    _phase = _MutationLedgerPhase.claimed;
    return fetchWallet();
  }

  @override
  Future<WalletStateModel> applyRedeemCode(String code) async {
    _phase = _MutationLedgerPhase.redeemed;
    return fetchWallet();
  }
}

enum _MutationLedgerPhase { initial, claimed, redeemed }

class _CancelableLedgerLoadMoreWalletRepository extends WalletRepository {
  _CancelableLedgerLoadMoreWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> loadMoreStarted = Completer<void>();
  final Completer<void> _loadMoreCompleter = Completer<void>();
  CancelToken? loadMoreCancelToken;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  void completeLoadMore() {
    if (!_loadMoreCompleter.isCompleted) {
      _loadMoreCompleter.complete();
    }
  }

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    return _wallet();
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    if (skip == 0) {
      return OffsetPagedModel(
        items: [
          WalletLedgerItem(
            entryId: 'entry-1',
            userId: 'user-1',
            delta: 5,
            balanceAfter: 10,
            source: 'weekly_grant',
            reason: 'Initial page',
            createdAtUtc: DateTime.utc(2026, 1, 1, 12),
          ),
        ],
        skip: skip,
        take: take,
        hasMore: true,
      );
    }

    loadMoreCancelToken = cancelToken;
    if (!loadMoreStarted.isCompleted) {
      loadMoreStarted.complete();
    }

    await _loadMoreCompleter.future;
    if (cancelToken?.isCancelled ?? false) {
      throw const RequestCancelledException();
    }

    return OffsetPagedModel(
      items: [
        WalletLedgerItem(
          entryId: 'entry-older',
          userId: 'user-1',
          delta: 1,
          balanceAfter: 5,
          source: 'generation_refund',
          reason: 'Older page',
          createdAtUtc: DateTime.utc(2025, 12, 31, 23),
        ),
      ],
      skip: skip,
      take: take,
      hasMore: false,
    );
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    return _emptyRewards();
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
}

class _OverlappingLedgerLoadMoreWalletRepository extends WalletRepository {
  _OverlappingLedgerLoadMoreWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => const Stream.empty();

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    return _wallet();
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    final items = switch (skip) {
      0 => [
        WalletLedgerItem(
          entryId: 'entry-24',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 24,
          source: 'weekly_grant',
          reason: 'Latest page item 24',
          createdAtUtc: DateTime.utc(2026, 1, 1, 12, 0),
        ),
        WalletLedgerItem(
          entryId: 'entry-23',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 23,
          source: 'weekly_grant',
          reason: 'Latest page item 23',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 59),
        ),
        WalletLedgerItem(
          entryId: 'entry-22',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 22,
          source: 'weekly_grant',
          reason: 'Latest page item 22',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 58),
        ),
        WalletLedgerItem(
          entryId: 'entry-21',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 21,
          source: 'weekly_grant',
          reason: 'Latest page item 21',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 57),
        ),
      ],
      _ => [
        WalletLedgerItem(
          entryId: 'entry-21',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 21,
          source: 'weekly_grant',
          reason: 'Overlapping page item 21',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 57),
        ),
        WalletLedgerItem(
          entryId: 'entry-20',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 20,
          source: 'generation_refund',
          reason: 'Older page item 20',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 56),
        ),
        WalletLedgerItem(
          entryId: 'entry-19',
          userId: 'user-1',
          delta: 4,
          balanceAfter: 19,
          source: 'generation_refund',
          reason: 'Older page item 19',
          createdAtUtc: DateTime.utc(2026, 1, 1, 11, 55),
        ),
      ],
    };

    return OffsetPagedModel(
      items: items,
      skip: skip,
      take: take,
      hasMore: skip == 0,
    );
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    return _emptyRewards();
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
}

class _PartialWalletRepository extends _LifecycleSyncWalletRepository {
  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async {
    throw const AppException('rewards.summary_failed');
  }
}

RewardsSummaryModel _emptyRewards() {
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
