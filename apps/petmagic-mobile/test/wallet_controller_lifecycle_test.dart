import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_recovery_store.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'wallet_controller_test_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferencesAsyncPlatform? previousPreferencesPlatform;

  setUp(() {
    previousPreferencesPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = previousPreferencesPlatform;
  });

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
    expect(source, isNot(contains('late final WalletRepository _repository')));
    expect(source, isNot(contains('_repositoryInitialized')));
    expect(
      source,
      contains(
        'WalletRepository get _repository => ref.read(walletRepositoryProvider)',
      ),
    );

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

  test(
    'wallet external checkout and verification requests are cancel-aware',
    () {
      final source = readWalletControllerLibrarySource();
      final repositorySource = File(
        'lib/features/wallet/data/wallet_repository.dart',
      ).readAsStringSync();
      final lifecycleBody = _methodBody(
        source,
        '_ensureWalletLifecycleStarted',
      );
      final offlineBody = _methodBody(source, '_handleNetworkStatusChanged');
      final buyPackBody = _methodBody(source, 'buyPack');
      final checkoutStatusBody = _methodBody(
        source,
        '_performCheckoutStatusVerification',
      );
      final stripeVerificationBody = _methodBody(
        source,
        '_performStripeCheckoutVerification',
      );
      expect(source, contains('CancelToken? _activeCheckoutCancelToken;'));
      expect(
        source,
        contains('CancelToken? _activeCheckoutVerificationCancelToken;'),
      );
      expect(lifecycleBody, contains('_cancelActiveCheckout();'));
      expect(lifecycleBody, contains('_cancelActiveCheckoutVerification();'));
      expect(offlineBody, contains('_cancelActiveCheckout();'));
      expect(offlineBody, contains('_cancelActiveCheckoutVerification();'));
      expect(offlineBody, contains('isBuying: false'));

      expect(buyPackBody, contains('_startCheckoutCancelToken()'));
      expect(buyPackBody, contains('cancelToken: checkoutCancelToken'));
      expect(buyPackBody, contains('checkoutCancelToken.isCancelled'));
      expect(buyPackBody, contains('on RequestCancelledException'));
      expect(
        buyPackBody,
        contains('_clearActiveCheckout(checkoutCancelToken)'),
      );

      expect(
        checkoutStatusBody,
        contains('_startCheckoutVerificationCancelToken()'),
      );
      expect(
        checkoutStatusBody,
        contains('cancelToken: verificationCancelToken'),
      );
      expect(
        checkoutStatusBody,
        contains('verificationCancelToken.isCancelled'),
      );
      expect(
        checkoutStatusBody,
        contains('_clearActiveCheckoutVerification(verificationCancelToken)'),
      );

      expect(
        stripeVerificationBody,
        contains('_startCheckoutVerificationCancelToken()'),
      );
      expect(
        stripeVerificationBody,
        contains('cancelToken: verificationCancelToken'),
      );
      expect(
        stripeVerificationBody,
        contains('verificationCancelToken.isCancelled'),
      );
      expect(
        stripeVerificationBody,
        contains('_clearActiveCheckoutVerification(verificationCancelToken)'),
      );

      expect(
        repositorySource,
        contains('Future<PurchaseCheckoutModel> createPurchase('),
      );
      expect(repositorySource, contains("'/api/economy/purchases/create'"));
      expect(
        repositorySource,
        contains('Future<PurchaseHistoryItem> verifyStripeCheckoutSession({'),
      );
      expect(
        repositorySource,
        contains("'/api/economy/purchases/\$encodedOrderId/verify-stripe'"),
      );
      expect(repositorySource, contains('CancelToken? cancelToken,'));
      expect(repositorySource, contains('cancelToken: cancelToken,'));
    },
  );

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

    expect(source, contains('_setWalletPageVisible(true);'));
    expect(source, contains('_setStoredWalletPageVisible(false);'));
    expect(source, contains('_visibleWalletController?.setWalletPageVisible'));
    expect(source, contains('ref.listenManual<WalletState>'));
    expect(source, contains('_syncVisibleWalletController()'));
    expect(
      source,
      contains("!ref.read(appLaunchControllerProvider).isAuthenticated"),
    );
    expect(
      _methodBody(source, 'dispose'),
      contains(
        '_walletSubscription?.close();\n    _setStoredWalletPageVisible(false);\n    _scrollController.dispose();',
      ),
    );
  });

  test('wallet pages do not cache notifier across session resets', () {
    final walletPageSource = File(
      'lib/features/wallet/presentation/wallet_page.dart',
    ).readAsStringSync();
    final allTransactionsSource = File(
      'lib/features/wallet/presentation/all_transactions_page.dart',
    ).readAsStringSync();

    expect(walletPageSource, isNot(contains('late final WalletController')));
    expect(
      allTransactionsSource,
      isNot(contains('late final WalletController')),
    );
    expect(
      walletPageSource,
      contains('ref.read(walletControllerProvider.notifier).load();'),
    );
    expect(walletPageSource, contains('ref.listenManual<WalletState>'));
    expect(walletPageSource, contains('_syncVisibleWalletController()'));
    expect(walletPageSource, isNot(contains('_walletController.load')));
    expect(allTransactionsSource, contains('.loadMoreLedger(force: force);'));
    expect(
      allTransactionsSource,
      isNot(contains('_walletController.loadMoreLedger')),
    );
  });

  test('wallet load completes safely after provider disposal', () async {
    final repository = _DelayedWalletRepository();
    final container = _walletTestContainer(repository);

    final controller = container.read(walletControllerProvider.notifier);
    final loadFuture = controller.load();

    await repository.fetchWalletStarted.future;
    container.dispose();
    expect(repository.fetchWalletCancelToken?.isCancelled, isTrue);
    repository.completeFetchWallet();

    await expectLater(loadFuture, completes);
  });

  test(
    'wallet load cancels in-flight request when network goes offline',
    () async {
      final repository = _DelayedWalletRepository();
      final networkStatusController =
          _TestWalletLifecycleNetworkStatusController(initialHasInternet: true);
      final container = _walletTestContainer(
        repository,
        networkStatusController: networkStatusController,
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      final loadFuture = controller.load();

      await repository.fetchWalletStarted.future;
      expect(repository.fetchWalletCancelToken?.isCancelled, isFalse);

      networkStatusController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(walletControllerProvider);
      expect(repository.fetchWalletCancelToken?.isCancelled, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);

      repository.completeFetchWallet();
      await expectLater(loadFuture, completes);

      state = container.read(walletControllerProvider);
      expect(state.wallet, isNull);
    },
  );

  test(
    'stripe verification completes safely after provider disposal',
    () async {
      final repository = _DelayedWalletRepository();
      final container = _walletTestContainer(repository);

      final controller = container.read(walletControllerProvider.notifier);
      final checkout = await controller.buyPack(_pack, _stripeMethod);
      expect(checkout?.orderId, 'order-1');

      final verificationFuture = controller.verifyStripeCheckout(
        'cs_test_validSession123',
      );
      final cancelToken = await repository.verifyStripeStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      container.dispose();
      expect(cancelToken.isCancelled, isTrue);
      repository.completeVerifyStripe();

      await expectLater(verificationFuture, completes);
    },
  );

  test('concurrent stripe verification shares one in-flight request', () async {
    final repository = _DelayedWalletRepository();
    final container = _walletTestContainer(repository);
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    final checkout = await controller.buyPack(_pack, _stripeMethod);
    expect(checkout?.orderId, 'order-1');

    final firstVerification = controller.verifyStripeCheckout(
      'cs_test_validSession123',
    );
    await repository.verifyStripeStarted.future;

    final secondVerification = controller.verifyStripeCheckout(
      'cs_test_validSession123',
    );
    await Future<void>.delayed(Duration.zero);

    repository.completeVerifyStripe();
    repository.completeFetchWallet();
    await Future.wait([firstVerification, secondVerification]);

    expect(repository.verifyStripeCalls, 1);
  });

  test(
    'stripe verification drops malformed reference before repository call',
    () async {
      final repository = _DelayedWalletRepository();
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      final checkout = await controller.buyPack(_pack, _stripeMethod);
      expect(checkout?.orderId, 'order-1');

      final verification = controller.verifyStripeCheckout(
        'https://evil.test/return?session_id=cs_test_bad',
      );
      await repository.verifyStripeStarted.future;

      expect(repository.lastStripeReferenceId, isNull);

      repository.completeVerifyStripe();
      repository.completeFetchWallet();
      await verification;
    },
  );

  test(
    'concurrent checkout status verification shares one in-flight polling loop',
    () async {
      final repository = _DelayedPurchaseStatusWalletRepository();
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      final checkout = await controller.buyPack(_pack, _stripeMethod);
      expect(checkout?.orderId, 'order-1');

      final firstVerification = controller.verifyCheckoutStatus();
      await repository.fetchPurchaseStarted.future;

      final secondVerification = controller.verifyCheckoutStatus();
      await Future<void>.delayed(Duration.zero);

      repository.completeFetchPurchase();
      repository.completeFetchWallet();
      await Future.wait([firstVerification, secondVerification]);

      expect(repository.fetchPurchaseCalls, 1);
      final state = container.read(walletControllerProvider);
      expect(
        state.checkoutVerificationState,
        WalletCheckoutVerificationState.succeeded,
      );
    },
  );

  test(
    'wallet checkout rejects unsafe external checkout url before state update',
    () async {
      final repository = _DelayedWalletRepository(
        checkoutUrl: 'https://checkout.stripe.com@evil.example/session',
      );
      final container = _walletTestContainer(repository);
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
    final container = _walletTestContainer(repository);
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
    final container = _walletTestContainer(repository);
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
      final container = _walletTestContainer(repository);
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
    final container = _walletTestContainer(repository);
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

  test('wallet resume sync skips background refresh while offline', () async {
    final repository = _LifecycleSyncWalletRepository();
    final container = _walletTestContainer(
      repository,
      networkStatusController: _TestWalletLifecycleNetworkStatusController(
        initialHasInternet: false,
      ),
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(walletControllerProvider);
    expect(repository.walletFetchCount, 1);
    expect(state.wallet?.balance, 10);
  });

  test('wallet resume sync skips background refresh for guests', () async {
    final repository = _LifecycleSyncWalletRepository();
    final container = _walletTestContainer(repository, authenticated: false);
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(walletControllerProvider);
    expect(repository.walletFetchCount, 1);
    expect(state.wallet?.balance, 10);
  });

  test(
    'wallet load marks full snapshot as hydrated after ancillary requests',
    () async {
      final repository = _LifecycleSyncWalletRepository();
      final container = _walletTestContainer(repository);
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
      final container = _walletTestContainer(repository);
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
      final container = _walletTestContainer(repository);
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
      final container = _walletTestContainer(repository);
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
    final container = _walletTestContainer(repository);
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
    'wallet load more cancels in-flight request when network goes offline',
    () async {
      final repository = _CancelableLedgerLoadMoreWalletRepository();
      final networkStatusController =
          _TestWalletLifecycleNetworkStatusController(initialHasInternet: true);
      final container = _walletTestContainer(
        repository,
        networkStatusController: networkStatusController,
      );
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();

      final loadMoreFuture = controller.loadMoreLedger();
      await repository.loadMoreStarted.future;

      expect(repository.loadMoreCancelToken?.isCancelled, isFalse);
      expect(
        container.read(walletControllerProvider).isLoadingMoreLedger,
        isTrue,
      );

      networkStatusController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      var state = container.read(walletControllerProvider);
      expect(repository.loadMoreCancelToken?.isCancelled, isTrue);
      expect(state.isLoadingMoreLedger, isFalse);
      expect(state.ledgerLoadMoreErrorMessage, isNull);

      repository.completeLoadMore();
      await expectLater(loadMoreFuture, completes);

      state = container.read(walletControllerProvider);
      expect(state.ledger.map((item) => item.entryId), ['entry-1']);
      expect(state.ledgerHasMore, isTrue);
    },
  );

  test(
    'wallet load more skips duplicate ledger entries from overlapping pages',
    () async {
      final repository = _OverlappingLedgerLoadMoreWalletRepository();
      final container = _walletTestContainer(repository);
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

  test('wallet load more stops after duplicate-only page', () async {
    final repository = _DuplicateOnlyLedgerLoadMoreWalletRepository();
    final container = _walletTestContainer(repository);
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    await controller.loadMoreLedger();
    await controller.loadMoreLedger();

    final state = container.read(walletControllerProvider);
    expect(repository.ledgerFetchCalls, 2);
    expect(state.ledger.map((item) => item.entryId), ['entry-1']);
    expect(state.ledgerHasMore, isFalse);
  });

  test('wallet load more stays idle after sign-out', () async {
    final repository = _OverlappingLedgerLoadMoreWalletRepository();
    final launchController = _MutableWalletLifecycleAppLaunchController(false);
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(repository),
        walletStorePurchaseRecoverySecureStorageProvider.overrideWithValue(
          _FakeSecureStorage(),
        ),
        appLaunchControllerProvider.overrideWith(() => launchController),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.loadMoreLedger();

    expect(repository.ledgerFetchCalls, 0);
    expect(
      container.read(walletControllerProvider).isLoadingMoreLedger,
      isFalse,
    );
  });

  test('claim ad reward refreshes ledger pagination snapshot', () async {
    final repository = _MutationLedgerWalletRepository();
    final container = _walletTestContainer(repository);
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
    final container = _walletTestContainer(repository);
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
      final verifyBody = _methodBody(
        source,
        '_performStripeCheckoutVerification',
      );

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

  test(
    'store purchase verification deduplicates non-secret purchase updates',
    () {
      final source = readWalletControllerLibrarySource();
      final verifyBody = _methodBody(source, '_verifyStorePurchase');

      expect(
        source,
        contains('Set<String> _storePurchaseVerificationInFlightKeys'),
      );
      expect(source, contains('Set<String> _storePurchaseVerifiedKeys'));
      expect(
        verifyBody,
        contains('_storePurchaseVerificationInFlightKeys.add'),
      );
      expect(verifyBody, contains('_storePurchaseVerifiedKeys.contains'));
      expect(verifyBody, contains('_rememberStorePurchaseVerifiedKey'));
      expect(
        verifyBody,
        contains('_storePurchaseVerificationInFlightKeys.remove'),
      );
      expect(source, contains('_maxStorePurchaseVerificationKeys = 32'));
      expect(source, contains('_storePurchaseVerifiedKeys.remove'));
      expect(source, contains('String? _storePurchaseVerificationKey'));
      expect(source, contains('orderId'));
      expect(source, contains('provider'));
      expect(source, contains('purchase.purchaseID'));
      expect(source, contains('purchase.transactionDate'));
      expect(source, contains('purchase.productID'));
      expect(source, isNot(contains('serverVerificationData')));
      expect(source, isNot(contains('localVerificationData')));
    },
  );

  test(
    'wallet store pending purchase storage survives controller restart',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      final store = WalletStorePurchaseRecoveryStore(
        preferences: preferences,
        secureStorage: secureStorage,
        clock: () => DateTime.utc(2026, 7, 2, 10, 5),
      );
      final pending = PendingStoreWalletPurchase(
        orderId: 'order-store-1',
        provider: 'google_play',
        productId: 'com.petmagic.app.tokens.google.pack100',
        packId: 'pack-100',
        packCode: 'pack100',
        createdAtUtc: DateTime.utc(2026, 7, 2, 10),
      );

      await store.savePendingPurchase(pending);

      final restartedStore = WalletStorePurchaseRecoveryStore(
        preferences: preferences,
        secureStorage: secureStorage,
        clock: () => DateTime.utc(2026, 7, 2, 10, 5),
      );
      final restored = await restartedStore.readPendingPurchase();

      expect(restored?.orderId, 'order-store-1');
      expect(restored?.provider, 'google_play');
      expect(restored?.productId, 'com.petmagic.app.tokens.google.pack100');
      expect(restored?.packCode, 'pack100');
      expect(
        await preferences.getString(
          WalletStorePurchaseRecoveryStore.legacyPendingPurchaseKey,
        ),
        isNull,
      );
      expect(
        secureStorage.values,
        contains(
          WalletStorePurchaseRecoveryStore.pendingPurchaseSecureStorageKey,
        ),
      );
    },
  );

  test('expired wallet store pending purchase is cleared', () async {
    final preferences = SharedPreferencesAsync();
    final secureStorage = _FakeSecureStorage();
    final store = WalletStorePurchaseRecoveryStore(
      preferences: preferences,
      secureStorage: secureStorage,
      clock: () => DateTime.utc(2026, 7, 20),
    );
    await store.savePendingPurchase(
      PendingStoreWalletPurchase(
        orderId: 'order-store-expired',
        provider: 'google_play',
        productId: 'com.petmagic.app.tokens.google.pack100',
        packId: 'pack-100',
        packCode: 'pack100',
        createdAtUtc: DateTime.utc(2026, 7, 2, 10),
      ),
    );

    final restored = await store.readPendingPurchase();

    expect(restored, isNull);
    expect(
      await preferences.getString(
        WalletStorePurchaseRecoveryStore.legacyPendingPurchaseKey,
      ),
      isNull,
    );
    expect(
      secureStorage.values,
      isNot(
        contains(
          WalletStorePurchaseRecoveryStore.pendingPurchaseSecureStorageKey,
        ),
      ),
    );
  });

  test('malformed wallet store pending purchase payload is cleared', () async {
    final preferences = SharedPreferencesAsync();
    final secureStorage = _FakeSecureStorage({
      WalletStorePurchaseRecoveryStore.pendingPurchaseSecureStorageKey:
          jsonEncode({
            'orderId': 42,
            'provider': 'google_play',
            'productId': 'com.petmagic.app.tokens.google.pack100',
            'packId': 'pack-100',
            'packCode': 'pack100',
            'createdAtUtc': '2026-07-02T10:00:00Z',
          }),
    });
    final store = WalletStorePurchaseRecoveryStore(
      preferences: preferences,
      secureStorage: secureStorage,
      clock: () => DateTime.utc(2026, 7, 2, 10, 5),
    );

    final restored = await store.readPendingPurchase();

    expect(restored, isNull);
    expect(
      secureStorage.values,
      isNot(
        contains(
          WalletStorePurchaseRecoveryStore.pendingPurchaseSecureStorageKey,
        ),
      ),
    );
  });

  test(
    'legacy wallet store pending purchase is migrated to secure storage',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      final store = WalletStorePurchaseRecoveryStore(
        preferences: preferences,
        secureStorage: secureStorage,
        clock: () => DateTime.utc(2026, 7, 2, 10, 5),
      );
      await preferences.setString(
        WalletStorePurchaseRecoveryStore.legacyPendingPurchaseKey,
        jsonEncode(
          PendingStoreWalletPurchase(
            orderId: 'legacy-order-store-1',
            provider: 'google_play',
            productId: 'com.petmagic.app.tokens.google.pack100',
            packId: 'pack-100',
            packCode: 'pack100',
            createdAtUtc: DateTime.utc(2026, 7, 2, 10),
          ),
        ),
      );

      final restored = await store.readPendingPurchase();

      expect(restored?.orderId, 'legacy-order-store-1');
      expect(
        await preferences.getString(
          WalletStorePurchaseRecoveryStore.legacyPendingPurchaseKey,
        ),
        isNull,
      );
      expect(
        secureStorage.values[WalletStorePurchaseRecoveryStore
            .pendingPurchaseSecureStorageKey],
        contains('legacy-order-store-1'),
      );
    },
  );

  test(
    'pending store purchase recovery restores checkout state and requests store restore once',
    () async {
      final repository = _StoreRecoveryWalletRepository(
        pendingStorePurchase: PendingStoreWalletPurchase(
          orderId: 'order-store-1',
          provider: 'google_play',
          productId: 'com.petmagic.app.tokens.google.pack100',
          packId: 'pack-100',
          packCode: 'pack100',
          createdAtUtc: DateTime.utc(2026, 7, 2, 10),
        ),
      );
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      final controller = container.read(walletControllerProvider.notifier);
      await controller.load();
      await Future<void>.delayed(Duration.zero);
      controller.setWalletPageVisible(true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(walletControllerProvider);
      expect(state.pendingCheckoutOrderId, 'order-store-1');
      expect(state.pendingStoreProvider, 'google_play');
      expect(
        state.checkoutVerificationState,
        WalletCheckoutVerificationState.pending,
      );
      expect(repository.restoreStorePurchasesCalls, 1);
    },
  );

  test(
    'manual store restore runs without a locally persisted checkout order',
    () async {
      final repository = _StoreRecoveryWalletRepository();
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      await container
          .read(walletControllerProvider.notifier)
          .restoreStorePurchases();

      expect(repository.restoreStorePurchasesCalls, 1);
    },
  );

  test(
    'lost wallet store order falls back to billing validation before completing purchase',
    () async {
      final repository = _StoreRecoveryWalletRepository(
        validationResponse: const StoreBillingValidationModel(
          provider: 'google_play',
          productType: 'TokenPack',
          productId: 'com.petmagic.app.tokens.google.pack100',
          status: 'already_settled',
          tokensGranted: false,
          tokenAmount: 120,
          isPremium: false,
        ),
      );
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      container.read(walletControllerProvider);
      repository.emitPurchase(_storePurchase());

      await repository.validationStarted.future;
      for (var attempt = 0; attempt < 10; attempt++) {
        if (container
                .read(walletControllerProvider)
                .checkoutVerificationState ==
            WalletCheckoutVerificationState.succeeded) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(walletControllerProvider);
      expect(repository.validateStorePurchaseCalls, 1);
      expect(repository.completePurchaseCalls, 1);
      expect(
        state.checkoutVerificationState,
        WalletCheckoutVerificationState.succeeded,
      );
      expect(state.checkoutGrantedSpark, 120);
    },
  );

  test(
    'store purchase is not completed when backend settlement fails',
    () async {
      final repository = _StoreRecoveryWalletRepository(
        validationError: const AppException('wallet.server_unavailable'),
      );
      final container = _walletTestContainer(repository);
      addTearDown(container.dispose);

      container.read(walletControllerProvider);
      repository.emitPurchase(_storePurchase());

      await repository.validationStarted.future;
      await Future<void>.delayed(Duration.zero);

      final state = container.read(walletControllerProvider);
      expect(repository.validateStorePurchaseCalls, 1);
      expect(repository.completePurchaseCalls, 0);
      expect(
        state.checkoutVerificationState,
        WalletCheckoutVerificationState.error,
      );
      expect(state.errorMessage, 'wallet.server_unavailable');
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:@override\s+)?(?:WalletState|String\?|void|Future<[^>]+>)\s+' +
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

ProviderContainer _walletTestContainer(
  WalletRepository repository, {
  bool authenticated = true,
  NetworkStatusController? networkStatusController,
}) {
  return ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      walletStorePurchaseRecoverySecureStorageProvider.overrideWithValue(
        _FakeSecureStorage(),
      ),
      appLaunchControllerProvider.overrideWith(
        () => _MutableWalletLifecycleAppLaunchController(authenticated),
      ),
      if (networkStatusController != null)
        networkStatusControllerProvider.overrideWith(
          () => networkStatusController,
        ),
    ],
  );
}

class _TestWalletLifecycleNetworkStatusController
    extends NetworkStatusController {
  _TestWalletLifecycleNetworkStatusController({
    required this.initialHasInternet,
  });

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

class _NoopWalletRepository extends WalletRepository {
  _NoopWalletRepository({Dio? dio, AuthSessionStorage? sessionStorage})
    : super(
        dio: dio ?? Dio(),
        sessionStorage: sessionStorage ?? AuthSessionStorage(),
      );

  @override
  Future<PendingStoreWalletPurchase?> readPendingStorePurchase() async => null;

  @override
  Future<void> savePendingStorePurchase(
    PendingStoreWalletPurchase purchase,
  ) async {}

  @override
  Future<void> clearPendingStorePurchase({String? orderId}) async {}
}

class _DelayedWalletRepository extends _NoopWalletRepository {
  _DelayedWalletRepository({
    this.checkoutUrl = 'https://checkout.stripe.com/session',
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final String checkoutUrl;
  final Completer<void> fetchWalletStarted = Completer<void>();
  final Completer<void> _fetchWalletCompleter = Completer<void>();
  final Completer<CancelToken> verifyStripeStarted = Completer<CancelToken>();
  final Completer<void> _verifyStripeCompleter = Completer<void>();
  CancelToken? fetchWalletCancelToken;
  int verifyStripeCalls = 0;
  String? lastStripeReferenceId;

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
    Locale locale, {
    CancelToken? cancelToken,
  }) async {
    return PurchaseCheckoutModel(
      orderId: 'order-1',
      paymentProvider: 'stripe',
      checkoutUrl: checkoutUrl,
      externalPaymentId: 'cs_test_validSession123',
      status: 'pending',
    );
  }

  @override
  Future<PurchaseHistoryItem> verifyStripeCheckoutSession({
    required String orderId,
    String? stripeReferenceId,
    CancelToken? cancelToken,
  }) async {
    verifyStripeCalls++;
    lastStripeReferenceId = stripeReferenceId;
    final token = cancelToken ?? CancelToken();
    if (!verifyStripeStarted.isCompleted) {
      verifyStripeStarted.complete(token);
    }

    await Future.any<void>([
      _verifyStripeCompleter.future,
      token.whenCancel.then((_) => throw const RequestCancelledException()),
    ]);
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

class _DelayedPurchaseStatusWalletRepository extends _DelayedWalletRepository {
  final Completer<void> fetchPurchaseStarted = Completer<void>();
  final Completer<void> _fetchPurchaseCompleter = Completer<void>();
  int fetchPurchaseCalls = 0;

  @override
  Future<PurchaseHistoryItem> fetchPurchase(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    fetchPurchaseCalls++;
    if (!fetchPurchaseStarted.isCompleted) {
      fetchPurchaseStarted.complete();
    }

    await _fetchPurchaseCompleter.future;
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

  void completeFetchPurchase() {
    if (!_fetchPurchaseCompleter.isCompleted) {
      _fetchPurchaseCompleter.complete();
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
    Locale locale, {
    CancelToken? cancelToken,
  }) async {
    if (createPurchaseError != null) {
      throw createPurchaseError!;
    }
    return super.createPurchase(
      pack,
      paymentMethod,
      locale,
      cancelToken: cancelToken,
    );
  }
}

class _LifecycleSyncWalletRepository extends _NoopWalletRepository {
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

class _LedgerPreservingSyncWalletRepository extends _NoopWalletRepository {
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

class _MutationLedgerWalletRepository extends _NoopWalletRepository {
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

class _CancelableLedgerLoadMoreWalletRepository extends _NoopWalletRepository {
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

class _OverlappingLedgerLoadMoreWalletRepository extends _NoopWalletRepository {
  _OverlappingLedgerLoadMoreWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int ledgerFetchCalls = 0;

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
    ledgerFetchCalls++;
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

class _DuplicateOnlyLedgerLoadMoreWalletRepository
    extends _NoopWalletRepository {
  _DuplicateOnlyLedgerLoadMoreWalletRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int ledgerFetchCalls = 0;

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
    ledgerFetchCalls++;
    return OffsetPagedModel(
      items: [
        WalletLedgerItem(
          entryId: 'entry-1',
          userId: 'user-1',
          delta: 5,
          balanceAfter: 10,
          source: 'weekly_grant',
          reason: 'Already loaded page item',
          createdAtUtc: DateTime.utc(2026, 1, 1, 12),
        ),
      ],
      skip: skip,
      take: take,
      hasMore: true,
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

class _StoreRecoveryWalletRepository extends WalletRepository {
  _StoreRecoveryWalletRepository({
    this.pendingStorePurchase,
    this.validationResponse,
    this.validationError,
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final _streamController = StreamController<List<PurchaseDetails>>.broadcast();
  PendingStoreWalletPurchase? pendingStorePurchase;
  final StoreBillingValidationModel? validationResponse;
  final Object? validationError;
  final Completer<void> validationStarted = Completer<void>();
  int restoreStorePurchasesCalls = 0;
  int validateStorePurchaseCalls = 0;
  int completePurchaseCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates => _streamController.stream;

  void emitPurchase(PurchaseDetails purchase) {
    _streamController.add([purchase]);
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
    return const OffsetPagedModel(items: [], skip: 0, take: 20, hasMore: false);
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
      packs: [
        CurrencyPackModel(
          packId: 'pack-100',
          code: 'pack100',
          displayName: 'Pack 100',
          currencyCode: 'USD',
          priceAmount: 4.99,
          grantedSpark: 100,
          bonusSpark: 20,
          totalSpark: 120,
          googlePlayProductId: 'com.petmagic.app.tokens.google.pack100',
          appStoreProductId: 'com.petmagic.app.tokens.apple.pack100',
        ),
      ],
      paymentMethods: [
        WalletPaymentMethodModel(
          provider: 'google_play',
          purchaseChannel: 'in_app',
          platform: 'android',
          region: '*',
          isEnabled: true,
          isSelectedByDefault: true,
          requiresExternalWarning: false,
          requiresStoreDisclosure: true,
          isRecommended: true,
          bonusTokensPercent: 0,
        ),
      ],
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
  Future<PendingStoreWalletPurchase?> readPendingStorePurchase() async {
    return pendingStorePurchase;
  }

  @override
  Future<void> savePendingStorePurchase(
    PendingStoreWalletPurchase purchase,
  ) async {
    pendingStorePurchase = purchase;
  }

  @override
  Future<void> clearPendingStorePurchase({String? orderId}) async {
    if (orderId == null ||
        orderId.isEmpty ||
        pendingStorePurchase?.orderId == orderId) {
      pendingStorePurchase = null;
    }
  }

  @override
  Future<void> restoreStorePurchases() async {
    restoreStorePurchasesCalls++;
  }

  @override
  Future<StoreBillingValidationModel> validateStorePurchase({
    required String provider,
    required PurchaseDetails purchase,
  }) async {
    validateStorePurchaseCalls++;
    if (!validationStarted.isCompleted) {
      validationStarted.complete();
    }
    final error = validationError;
    if (error != null) {
      throw error;
    }

    return validationResponse ??
        StoreBillingValidationModel(
          provider: provider,
          productType: 'TokenPack',
          productId: purchase.productID,
          status: 'succeeded',
          tokensGranted: true,
          tokenAmount: 120,
          isPremium: false,
        );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalls++;
    purchase.pendingCompletePurchase = false;
  }

  @override
  Future<void> consumeVerifiedPurchase(PurchaseDetails purchase) {
    return completePurchase(purchase);
  }
}

class _MutableWalletLifecycleAppLaunchController extends AppLaunchController {
  _MutableWalletLifecycleAppLaunchController(this._isAuthenticated);

  final bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
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

PurchaseDetails _storePurchase({
  String productId = 'com.petmagic.app.tokens.google.pack100',
  String source = 'google_play',
}) {
  final purchase = PurchaseDetails(
    purchaseID: 'gp-purchase-1',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-store-data',
      serverVerificationData: 'gp-token-pack-1',
      source: source,
    ),
    transactionDate: DateTime.utc(2026, 7, 2).millisecondsSinceEpoch.toString(),
    status: PurchaseStatus.purchased,
  );
  purchase.pendingCompletePurchase = true;
  return purchase;
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? initialValues])
    : values = initialValues ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
      return;
    }

    values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
