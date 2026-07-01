import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';

class IdleWalletTemplateGenerationController
    extends TemplateGenerationController {
  @override
  TemplateGenerationState build() {
    return const TemplateGenerationState();
  }
}

class IdleWalletGenerationHistoryController
    extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }
}

class AuthenticatedWalletAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class UnauthenticatedWalletAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

Future<void> pumpAllTransactionsPage(
  WidgetTester tester, {
  required WalletRepository repository,
  bool authenticated = true,
}) async {
  addTearDown(() => PetMagicNotificationCenter.instance.clearQueue());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? AuthenticatedWalletAppLaunchController.new
              : UnauthenticatedWalletAppLaunchController.new,
        ),
        walletRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('de'),
          Locale('es'),
          Locale('fr'),
          Locale('it'),
          Locale('pl'),
        ],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Material(child: AllTransactionsPage()),
            ),
          ],
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pumpWalletPage(
  WidgetTester tester, {
  required WalletRepository repository,
  bool authenticated = true,
}) async {
  addTearDown(() => PetMagicNotificationCenter.instance.clearQueue());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? AuthenticatedWalletAppLaunchController.new
              : UnauthenticatedWalletAppLaunchController.new,
        ),
        walletRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('de'),
          Locale('es'),
          Locale('fr'),
          Locale('it'),
          Locale('pl'),
        ],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Material(child: WalletPage()),
            ),
          ],
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pumpRewardsPage(
  WidgetTester tester, {
  required WalletRepository repository,
  bool authenticated = true,
}) async {
  addTearDown(() => PetMagicNotificationCenter.instance.clearQueue());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? AuthenticatedWalletAppLaunchController.new
              : UnauthenticatedWalletAppLaunchController.new,
        ),
        walletRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('de'),
          Locale('es'),
          Locale('fr'),
          Locale('it'),
          Locale('pl'),
        ],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Material(child: RewardsPage()),
            ),
          ],
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
}

class AutoRefreshProbeWalletController extends WalletController {
  int loadCalls = 0;
  int syncSnapshotCalls = 0;
  Completer<void>? _delayedLoad;

  int get refreshCalls => loadCalls + syncSnapshotCalls;

  @override
  WalletState build() {
    return const WalletState(
      wallet: walletStateFixture,
      rewards: rewardsSummaryFixture,
      ledger: ledgerItemsFixture,
      packs: packsFixture,
      paymentMethods: paymentMethodsFixture,
      purchases: purchasesFixture,
      hasCompletedFullLoad: true,
    );
  }

  void delayNextLoad() {
    _delayedLoad = Completer<void>();
  }

  void completeDelayedLoad() {
    _delayedLoad?.complete();
    _delayedLoad = null;
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    final delayed = _delayedLoad;
    if (delayed != null) {
      return delayed.future;
    }
  }

  @override
  Future<void> syncSnapshot({bool forceRefresh = false}) async {
    syncSnapshotCalls++;
    final delayed = _delayedLoad;
    if (delayed != null) {
      return delayed.future;
    }
  }
}

class FakeWalletRepository extends WalletRepository {
  FakeWalletRepository({
    required this.wallet,
    required this.ledger,
    required this.packs,
    required this.purchases,
    this.failWallet = false,
    this.walletError,
    this.failLedger = false,
    this.failPurchases = false,
    this.redeemError,
    this.paymentMethods = paymentMethodsFixture,
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final WalletStateModel wallet;
  final List<WalletLedgerItem> ledger;
  final List<CurrencyPackModel> packs;
  final List<PurchaseHistoryItem> purchases;
  final bool failWallet;
  final AppException? walletError;
  final bool failLedger;
  final bool failPurchases;
  final AppException? redeemError;
  final List<WalletPaymentMethodModel> paymentMethods;
  int walletFetchCount = 0;
  int ledgerFetchCount = 0;
  int checkoutConfigFetchCount = 0;
  int purchasesFetchCount = 0;

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
    walletFetchCount++;
    final configuredWalletError = walletError;
    if (configuredWalletError != null) {
      throw configuredWalletError;
    }

    if (failWallet) {
      throw Exception('wallet failed');
    }

    return wallet;
  }

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    ledgerFetchCount++;
    if (failLedger) {
      throw Exception('ledger failed');
    }

    return OffsetPagedModel(
      items: ledger,
      skip: skip,
      take: take,
      hasMore: false,
    );
  }

  @override
  Future<List<CurrencyPackModel>> fetchPacks() async => packs;

  @override
  Future<WalletCheckoutConfigModel> fetchCheckoutConfig({
    required Locale locale,
    CancelToken? cancelToken,
  }) async {
    checkoutConfigFetchCount++;
    return WalletCheckoutConfigModel(
      packs: packs,
      paymentMethods: paymentMethods,
      externalPaymentWarningRequired: false,
    );
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async =>
      rewardsSummaryFixture;

  @override
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    purchasesFetchCount++;
    if (failPurchases) {
      throw Exception('purchases failed');
    }

    return OffsetPagedModel(
      items: purchases,
      skip: skip,
      take: take,
      hasMore: false,
    );
  }

  @override
  Future<WalletStateModel> applyRedeemCode(String code) async {
    if (redeemError != null) {
      throw redeemError!;
    }

    return wallet;
  }

  @override
  Future<RewardsSummaryModel> applyReferralCode(String code) async {
    return const RewardsSummaryModel(
      referralCode: 'PMME12345',
      referralBonusSpark: 15,
      referralStatus: 'pending',
      referrerCode: 'PMFRIEND1',
      totalReferralBonusEarned: 0,
      referredUsersCount: 0,
      pendingReferredUsersCount: 0,
      rewardedReferredUsersCount: 0,
    );
  }
}

class RetryLedgerWalletRepository extends FakeWalletRepository {
  RetryLedgerWalletRepository({
    required super.wallet,
    required super.ledger,
    required super.packs,
    required super.purchases,
  });

  int ledgerAttempts = 0;

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    ledgerAttempts++;
    if (ledgerAttempts == 1) {
      throw Exception('ledger failed');
    }

    return OffsetPagedModel(
      items: ledger,
      skip: skip,
      take: take,
      hasMore: false,
    );
  }
}

class PagedLedgerWalletRepository extends FakeWalletRepository {
  PagedLedgerWalletRepository({
    required super.wallet,
    required super.ledger,
    required super.packs,
    required super.purchases,
    this.delayedLedgerSkips = const {},
  });

  final Map<int, Completer<void>> delayedLedgerSkips;
  final List<int> ledgerSkips = <int>[];

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    ledgerSkips.add(skip);
    final pending = delayedLedgerSkips[skip];
    if (pending != null && !pending.isCompleted) {
      await pending.future;
    }

    final start = skip.clamp(0, ledger.length);
    final end = (start + take).clamp(0, ledger.length);

    return OffsetPagedModel(
      items: ledger.sublist(start, end),
      skip: skip,
      take: take,
      hasMore: end < ledger.length,
    );
  }
}

class RetryPagedLedgerWalletRepository extends PagedLedgerWalletRepository {
  RetryPagedLedgerWalletRepository({
    required super.wallet,
    required super.ledger,
    required super.packs,
    required super.purchases,
  });

  bool _failedSecondPage = false;

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
    ledgerSkips.add(skip);
    if (skip == 24 && !_failedSecondPage) {
      _failedSecondPage = true;
      throw const AppException('wallet.ledger_failed');
    }

    final start = skip.clamp(0, ledger.length);
    final end = (start + take).clamp(0, ledger.length);

    return OffsetPagedModel(
      items: ledger.sublist(start, end),
      skip: skip,
      take: take,
      hasMore: end < ledger.length,
    );
  }
}

const rewardsSummaryFixture = RewardsSummaryModel(
  referralCode: 'PMME12345',
  referralBonusSpark: 15,
  referralStatus: 'none',
  totalReferralBonusEarned: 15,
  referredUsersCount: 1,
  pendingReferredUsersCount: 0,
  rewardedReferredUsersCount: 1,
);

const walletStateFixture = WalletStateModel(
  userId: 'user-1',
  balance: 172,
  adRewardsRemainingToday: 3,
  isPremium: false,
  updatedAtUtc: null,
  nextWeeklyGrantAtUtc: null,
);

const ledgerItemsFixture = [
  WalletLedgerItem(
    entryId: 'entry-1',
    userId: 'user-1',
    delta: 15,
    balanceAfter: 172,
    source: 'ad_reward',
    reason: 'Ad reward',
    createdAtUtc: null,
  ),
  WalletLedgerItem(
    entryId: 'entry-2',
    userId: 'user-1',
    delta: 12,
    balanceAfter: 157,
    source: 'redeem_code',
    reason: 'Promo code',
    createdAtUtc: null,
  ),
  WalletLedgerItem(
    entryId: 'entry-3',
    userId: 'user-1',
    delta: 100,
    balanceAfter: 145,
    source: 'weekly_grant',
    reason: 'Weekly reward',
    createdAtUtc: null,
  ),
];

const packsFixture = [
  CurrencyPackModel(
    packId: 'starter',
    code: 'starter',
    displayName: 'Tiny Treat',
    currencyCode: 'EUR',
    priceAmount: 6.29,
    grantedSpark: 20,
    bonusSpark: 0,
    totalSpark: 20,
  ),
  CurrencyPackModel(
    packId: 'creator',
    code: 'creator',
    displayName: 'Happy Pack',
    currencyCode: 'EUR',
    priceAmount: 13.49,
    grantedSpark: 45,
    bonusSpark: 0,
    totalSpark: 45,
  ),
  CurrencyPackModel(
    packId: 'viral',
    code: 'viral',
    displayName: 'Magic Boost',
    currencyCode: 'EUR',
    priceAmount: 26.99,
    grantedSpark: 100,
    bonusSpark: 0,
    totalSpark: 100,
  ),
];

const paymentMethodsFixture = [
  WalletPaymentMethodModel(
    provider: 'stripe',
    purchaseChannel: 'web',
    platform: 'web',
    region: '*',
    isEnabled: true,
    isSelectedByDefault: true,
    requiresExternalWarning: false,
    requiresStoreDisclosure: false,
    isRecommended: true,
    bonusTokensPercent: 0,
  ),
];

const purchasesFixture = [
  PurchaseHistoryItem(
    orderId: 'order-1',
    packDisplayName: 'Happy Pack',
    paymentProvider: 'stripe',
    status: 'succeeded',
    priceAmount: 13.49,
    currencyCode: 'EUR',
    sparkToGrant: 45,
    createdAtUtc: null,
    confirmedAtUtc: null,
  ),
];
