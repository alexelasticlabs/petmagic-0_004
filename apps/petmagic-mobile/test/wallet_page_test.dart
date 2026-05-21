import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

void main() {
  testWidgets(
    'wallet page stays stable on narrow screens and shows featured pricing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpWalletPage(
        tester,
        repository: _FakeWalletRepository(
          wallet: _walletState,
          ledger: _ledgerItems,
          packs: _packs,
          purchases: _purchases,
        ),
      );

      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      expect(find.text(text.walletBalanceEyebrow), findsOneWidget);
      expect(find.textContaining('Недельная награда'), findsNothing);
      expect(find.text('Способы оплаты'), findsNothing);

      await tester.scrollUntilVisible(
        find.text(text.walletAdRewardCompactTitle),
        120,
      );
      expect(find.text(text.walletAdRewardCompactTitle), findsOneWidget);

      await tester.scrollUntilVisible(find.text(text.walletPromoTitle), 120);
      expect(find.text(text.walletPromoTitle), findsOneWidget);

      await tester.scrollUntilVisible(find.text(text.walletBuySparkTitle), 220);
      await tester.pumpAndSettle();

      expect(find.text(text.walletPackDetailsAction), findsWidgets);

      await tester.tap(find.text(text.walletPackDetailsAction).first);
      await tester.pumpAndSettle();

      expect(find.text(text.walletPackDetailSubtitle), findsOneWidget);
      expect(
        find.textContaining(text.walletBuyForPrice('').trim()),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wallet soft warning uses non-danger warning tone', (
    tester,
  ) async {
    await _pumpWalletPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
        failLedger: true,
      ),
    );

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);

    expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
          return false;
        }

        final decoration = widget.decoration as BoxDecoration;
        return decoration.color ==
            const Color(0xFFD7A44A).withValues(alpha: 0.12);
      }),
      findsWidgets,
    );
  });

  testWidgets('wallet tab is available in bottom navigation', (tester) async {
    final router = GoRouter(
      initialLocation: '/templates',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              PetMagicShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/templates',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Text('Templates route')),
              ),
            ),
            GoRoute(
              path: '/creations',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Text('Creations route')),
              ),
            ),
            GoRoute(
              path: WalletPage.routePath,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Text('Wallet route')),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Text('Profile route')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('en', 'US'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Кошелек'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);

    await tester.tap(find.text('Кошелек'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('wallet navigation hides while keyboard is open', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('en', 'US'),
          ],
          home: const PetMagicShell(
            location: WalletPage.routePath,
            child: Scaffold(body: Text('Wallet route')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Кошелек'), findsNothing);
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('redeem sheet keeps focus and shows friendly error on failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWalletPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
        redeemError: const AppException('wallet.network_unavailable'),
      ),
    );

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);
    final walletScrollView = find.byType(Scrollable).first;

    final promoCardTitle = find.text(text.walletPromoTitle).last;
    await tester.scrollUntilVisible(
      promoCardTitle,
      120,
      scrollable: walletScrollView,
    );
    await tester.tap(promoCardTitle);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'WELCOME-100');
    await tester.tap(find.text(text.walletApplyCode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(text.walletRedeemSheetTitle), findsOneWidget);
    expect(find.text(text.walletRedeemOfflineError), findsAtLeastNWidgets(1));
  });

  testWidgets('redeem sheet hides bottom navigation and can be canceled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository(
              wallet: _walletState,
              ledger: _ledgerItems,
              packs: _packs,
              purchases: _purchases,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
            Locale('en', 'US'),
          ],
          home: const PetMagicShell(
            location: WalletPage.routePath,
            child: WalletPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);
    final walletScrollView = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.text(text.walletPromoTitle).last,
      120,
      scrollable: walletScrollView,
    );
    await tester.tap(find.text(text.walletPromoTitle).last);
    await tester.pumpAndSettle();

    expect(find.text(text.walletRedeemSheetTitle), findsOneWidget);
    expect(find.text('Кошелек'), findsNothing);

    await tester.tap(find.text(text.walletRedeemCancelAction));
    await tester.pumpAndSettle();

    expect(find.text(text.walletRedeemSheetTitle), findsNothing);
    expect(find.text('Кошелек'), findsOneWidget);
  });

  testWidgets(
    'redeem sheet stays above bottom safe area when keyboard is closed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
          child: ProviderScope(
            overrides: [
              walletRepositoryProvider.overrideWithValue(
                _FakeWalletRepository(
                  wallet: _walletState,
                  ledger: _ledgerItems,
                  packs: _packs,
                  purchases: _purchases,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: const [
                Locale('ru'),
                Locale('en'),
                Locale('en', 'US'),
              ],
              home: const PetMagicShell(
                location: WalletPage.routePath,
                child: WalletPage(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);
      final walletScrollView = find.byType(Scrollable).first;
      final reservedBottomInset = petMagicBottomNavInset(walletContext);

      await tester.scrollUntilVisible(
        find.text(text.walletPromoTitle).last,
        120,
        scrollable: walletScrollView,
      );
      await tester.tap(find.text(text.walletPromoTitle).last);
      await tester.pumpAndSettle();

      final cancelRect = tester.getRect(
        find.text(text.walletRedeemCancelAction),
      );
      final applyRect = tester.getRect(find.text(text.walletApplyCode));
      final lowestButtonBottom = cancelRect.bottom > applyRect.bottom
          ? cancelRect.bottom
          : applyRect.bottom;

      expect(lowestButtonBottom, lessThanOrEqualTo(900 - reservedBottomInset));
      expect(find.text(text.walletRedeemCancelAction), findsOneWidget);
      expect(find.text(text.walletApplyCode), findsOneWidget);
    },
  );
}

Future<void> _pumpWalletPage(
  WidgetTester tester, {
  required WalletRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('en', 'US'),
        ],
        home: const WalletPage(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository({
    required this.wallet,
    required this.ledger,
    required this.packs,
    required this.purchases,
    this.failLedger = false,
    this.redeemError,
  }) : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final WalletStateModel wallet;
  final List<WalletLedgerItem> ledger;
  final List<CurrencyPackModel> packs;
  final List<PurchaseHistoryItem> purchases;
  final bool failLedger;
  final AppException? redeemError;

  @override
  Future<WalletStateModel> fetchWallet() async => wallet;

  @override
  Future<OffsetPagedModel<WalletLedgerItem>> fetchLedger({
    int skip = 0,
    int take = 20,
  }) async {
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
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
  }) async {
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
}

const _walletState = WalletStateModel(
  userId: 'user-1',
  balance: 130,
  adRewardsRemainingToday: 3,
  isPremium: false,
  updatedAtUtc: null,
  nextWeeklyGrantAtUtc: null,
);

const _ledgerItems = [
  WalletLedgerItem(
    entryId: 'entry-1',
    userId: 'user-1',
    delta: 100,
    balanceAfter: 130,
    source: 'weekly_grant',
    reason: 'Weekly reward',
    createdAtUtc: null,
  ),
  WalletLedgerItem(
    entryId: 'entry-2',
    userId: 'user-1',
    delta: -20,
    balanceAfter: 30,
    source: 'generation_spend',
    reason: 'Generated video',
    createdAtUtc: null,
  ),
];

const _packs = [
  CurrencyPackModel(
    packId: 'starter',
    code: 'starter',
    displayName: 'Starter PawSpark',
    currencyCode: 'EUR',
    priceAmount: 2.79,
    grantedSpark: 100,
    bonusSpark: 10,
    totalSpark: 110,
  ),
  CurrencyPackModel(
    packId: 'creator',
    code: 'creator',
    displayName: 'Creator PawSpark',
    currencyCode: 'EUR',
    priceAmount: 9.99,
    grantedSpark: 350,
    bonusSpark: 30,
    totalSpark: 380,
  ),
];

const _purchases = [
  PurchaseHistoryItem(
    orderId: 'order-1',
    packDisplayName: 'Creator PawSpark',
    paymentProvider: 'stripe',
    status: 'succeeded',
    priceAmount: 9.99,
    currencyCode: 'EUR',
    sparkToGrant: 380,
    createdAtUtc: null,
    confirmedAtUtc: null,
  ),
];
