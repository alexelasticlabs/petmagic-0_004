import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

import 'widget_test_support.dart';
import 'wallet_page_test_support.dart';

void main() {
  configureWidgetTestHarness();

  test('wallet pack pricing copy uses backend template pricing source', () {
    final source = File(
      'lib/features/wallet/presentation/widgets/wallet_page_activity_widgets.dart',
    ).readAsStringSync();
    final pageSource = File(
      'lib/features/wallet/presentation/wallet_page.dart',
    ).readAsStringSync();
    final helperSource = File(
      'lib/features/wallet/presentation/wallet_page_helpers.part.dart',
    ).readAsStringSync();

    expect(source, contains('templatePricing.usageLabel'));
    expect(pageSource, contains('templatesControllerProvider'));
    expect(pageSource, isNot(contains('_kWalletApproxPhotoCostSpark')));
    expect(pageSource, isNot(contains('_kWalletApproxVideoCostSpark')));
    expect(source, isNot(contains('walletApproxPhotos')));
    expect(source, isNot(contains('walletApproxVideos')));
    expect(helperSource, contains('walletApproxGenerationRange'));
    expect(helperSource, contains('walletApproxGenerations'));
    expect(helperSource, contains('walletGenerationPricingUnavailable'));
    expect(helperSource, isNot(contains('walletApproxPhotosOnly')));
    expect(helperSource, isNot(contains('walletApproxPhotosOrVideos')));
    expect(source, isNot(contains(' или ')));
    expect(source, isNot(contains("'≈ ")));
  });

  testWidgets(
    'wallet hero cards keep mascot art visible and premium headline readable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpWalletPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: ledgerItemsFixture,
          packs: packsFixture,
          purchases: purchasesFixture,
        ),
      );

      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      expect(
        find.byWidgetPredicate((widget) {
          final child = widget is Opacity ? widget.child : null;
          final image = child is Image ? child.image : null;
          return widget is Opacity &&
              widget.opacity >= 0.7 &&
              image is AssetImage &&
              image.assetName == 'assets/rewards/wallet-hero-logo.png';
        }),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) {
          final child = widget is Opacity ? widget.child : null;
          final image = child is Image ? child.image : null;
          return widget is Opacity &&
              widget.opacity >= 0.8 &&
              image is AssetImage &&
              image.assetName == 'assets/rewards/premium-upsell-dog.png';
        }),
        findsOneWidget,
      );

      final headline = tester.widget<Text>(
        find.text(text.premiumUpsellHeadline),
      );
      expect(headline.maxLines, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet page stays stable on narrow screens and shows featured pricing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpWalletPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: ledgerItemsFixture,
          packs: packsFixture,
          purchases: purchasesFixture,
        ),
      );
      tester.testTextInput.hide();
      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      expect(find.text(text.walletBalanceEyebrow), findsOneWidget);
      expect(find.byTooltip(text.walletRefreshTooltip), findsNothing);
      expect(find.textContaining('Недельная награда'), findsNothing);
      expect(find.text('Способы оплаты'), findsNothing);

      expect(find.text(text.walletAdRewardCompactTitle), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(text.walletBuySparkTitle), findsWidgets);
      expect(
        find.text(text.walletApproxGenerationRange(2, 10)),
        findsOneWidget,
      );

      expect(find.text(text.walletPackDetailsAction), findsWidgets);

      await tester.tap(find.text(text.walletPackDetailsAction).first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(text.premiumPaymentStripe), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet page shows pricing fallback when template feed is unavailable',
    (tester) async {
      await pumpWalletPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: ledgerItemsFixture,
          packs: packsFixture,
          purchases: purchasesFixture,
        ),
        templatesController: StaticWalletTemplatesController(items: const []),
      );

      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(text.walletGenerationPricingUnavailable), findsWidgets);
    },
  );

  testWidgets('wallet soft warning uses non-danger warning tone', (
    tester,
  ) async {
    await pumpWalletPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
        failLedger: true,
      ),
    );

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);

    expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);

    expect(
      find.byWidgetPredicate((widget) {
        return widget is ProfileMessageCard &&
            widget.message == text.walletPartialActivityUnavailable &&
            widget.tone == const Color(0xFFFFC107);
      }),
      findsOneWidget,
    );
  });

  testWidgets('wallet page shows unified auth gate for guests', (tester) async {
    await pumpWalletPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      ),
      authenticated: false,
    );

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.authRequiredMessage), findsOneWidget);
    expect(find.text(text.appUnavailableServerTitle), findsNothing);
  });

  testWidgets(
    'wallet page skips deferred initial load after immediate sign out',
    (tester) async {
      final launchController = _MutableWalletAppLaunchController(false);
      final walletController = _TransitionWalletController(
        const WalletState(isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            walletControllerProvider.overrideWith(() => walletController),
            walletRepositoryProvider.overrideWithValue(
              defaultFakeWalletRepository(),
            ),
            templatesControllerProvider.overrideWith(
              StaticWalletTemplatesController.new,
            ),
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
                      const Material(child: WalletPage()),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(walletController.loadCalls, 0);

      launchController.setAuthenticated(true);
      launchController.setAuthenticated(false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(walletController.loadCalls, 0);
    },
  );

  testWidgets(
    'wallet page skips eager reload when wallet snapshot is already hydrated',
    (tester) async {
      final walletController = _TransitionWalletController(
        const WalletState(
          wallet: walletStateFixture,
          hasCompletedFullLoad: true,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedWalletAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            walletRepositoryProvider.overrideWithValue(
              defaultFakeWalletRepository(),
            ),
            templatesControllerProvider.overrideWith(
              StaticWalletTemplatesController.new,
            ),
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
                      const Material(child: WalletPage()),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);
    },
  );

  testWidgets('authenticated wallet unavailable state still shows retry card', (
    tester,
  ) async {
    await pumpWalletPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
        failWallet: true,
      ),
    );

    final walletContext = tester.element(find.byType(WalletPage));
    final text = AppLocalizations.of(walletContext);

    expect(find.byType(ProtectedAuthGate), findsNothing);
    expect(find.text(text.appUnavailableServerTitle), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);
  });

  testWidgets(
    'wallet auto refresh uses lightweight sync when only partial wallet snapshot is available',
    (tester) async {
      final repository = FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
        failPurchases: true,
      );

      await pumpWalletPage(tester, repository: repository);

      expect(repository.walletFetchCount, 1);
      expect(repository.ledgerFetchCount, 1);
      expect(repository.checkoutConfigFetchCount, 1);
      expect(repository.purchasesFetchCount, 1);

      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(repository.walletFetchCount, 2);
      expect(
        repository.ledgerFetchCount,
        1,
        reason: 'unchanged wallet snapshot should not re-fetch ledger pages',
      );
      expect(
        repository.checkoutConfigFetchCount,
        1,
        reason: 'background sync should not re-fetch checkout configuration',
      );
      expect(
        repository.purchasesFetchCount,
        1,
        reason: 'background sync should not re-fetch purchase history',
      );
    },
  );

  testWidgets(
    'wallet auto refresh pauses offline and resumes after internet restore',
    (tester) async {
      final repository = FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      );
      final networkStatusController = TestWalletNetworkStatusController(
        initialHasInternet: false,
      );

      await pumpWalletPage(
        tester,
        repository: repository,
        networkStatusController: networkStatusController,
      );

      expect(repository.walletFetchCount, 1);

      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        repository.walletFetchCount,
        1,
        reason:
            'offline wallet page should not keep background refresh traffic alive',
      );

      networkStatusController.setHasInternet(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        repository.walletFetchCount,
        2,
        reason: 'wallet page should resync once connectivity returns',
      );
    },
  );

  testWidgets('wallet auto refresh stops after sign out', (tester) async {
    final repository = FakeWalletRepository(
      wallet: walletStateFixture,
      ledger: ledgerItemsFixture,
      packs: packsFixture,
      purchases: purchasesFixture,
    );
    final launchController = _MutableWalletAppLaunchController(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
          walletRepositoryProvider.overrideWithValue(repository),
          templatesControllerProvider.overrideWith(
            StaticWalletTemplatesController.new,
          ),
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
                    const Material(child: WalletPage()),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.walletFetchCount, 1);

    launchController.setAuthenticated(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      repository.walletFetchCount,
      1,
      reason:
          'a stale wallet auto-refresh timer must not call private wallet APIs after sign out',
    );
  });

  testWidgets(
    'wallet page shows legal acceptance action for legal gate errors',
    (tester) async {
      await pumpWalletPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: ledgerItemsFixture,
          packs: packsFixture,
          purchases: purchasesFixture,
          walletError: AppException('auth.legal_acceptance_required'),
        ),
      );

      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      expect(find.text(text.appUnavailableServerTitle), findsNothing);
      expect(find.text(text.profileLegalAcceptanceRequired), findsOneWidget);
      expect(find.text(text.profileLegalAcceptAction), findsOneWidget);
    },
  );

  testWidgets('all transactions renders ledger rows lazily', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final largeLedger = List<WalletLedgerItem>.generate(
      80,
      (index) => WalletLedgerItem(
        entryId: 'entry-$index',
        userId: 'user-1',
        delta: index.isEven ? 5 : -3,
        balanceAfter: 1000 + index,
        source: index.isEven ? 'ad_reward' : 'generation_spend',
        reason: 'Ledger entry $index',
        createdAtUtc: DateTime.utc(2026, 1, 1, 12, index % 60),
      ),
      growable: false,
    );

    await pumpAllTransactionsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: largeLedger,
        packs: packsFixture,
        purchases: purchasesFixture,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-79')),
      findsNothing,
    );
  });

  testWidgets(
    'all transactions hides raw backend source keys behind localized fallback',
    (tester) async {
      const unknownSource = 'internal_manual_adjustment_v2';
      final unknownLedger = [
        WalletLedgerItem(
          entryId: 'entry-unknown',
          userId: 'user-1',
          delta: 7,
          balanceAfter: 107,
          source: unknownSource,
          reason: 'Fallback label validation',
          createdAtUtc: DateTime.utc(2026, 1, 1, 12),
        ),
      ];

      await pumpAllTransactionsPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: unknownLedger,
          packs: packsFixture,
          purchases: purchasesFixture,
        ),
      );

      final transactionsContext = tester.element(
        find.byType(AllTransactionsPage),
      );
      final text = AppLocalizations.of(transactionsContext);

      expect(find.text(text.walletSourceOther), findsOneWidget);
      expect(find.text(unknownSource), findsNothing);
    },
  );

  test(
    'wallet helper fallbacks do not expose raw backend keys for unknown values',
    () {
      final helpersSource = File(
        'lib/features/wallet/presentation/wallet_page_helpers.part.dart',
      ).readAsStringSync();
      final transactionsSource = [
        'lib/features/wallet/presentation/all_transactions_page.dart',
        'lib/features/wallet/presentation/widgets/all_transactions_widgets.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final overviewSource = File(
        'lib/features/wallet/presentation/widgets/wallet_page_overview_chrome.part.dart',
      ).readAsStringSync();

      expect(helpersSource, contains('text.premiumPaymentOther'));
      expect(helpersSource, isNot(contains('_ => method.provider')));
      expect(helpersSource, contains('text.walletSourceOther'));
      expect(helpersSource, contains('NumberFormat.decimalPatternDigits('));
      expect(helpersSource, contains('locale: text.localeName'));
      expect(helpersSource, contains('decimalDigits: 1'));
      expect(helpersSource, isNot(contains("NumberFormat('0.0')")));
      expect(helpersSource, contains('String _formatPrice('));
      expect(helpersSource, contains('locale: localeTag'));
      expect(helpersSource, isNot(contains('_formatPrice(pack);')));
      expect(overviewSource, contains('Localizations.localeOf(context)'));
      expect(overviewSource, contains('NumberFormat.decimalPattern('));
      expect(
        overviewSource,
        isNot(contains('NumberFormat.decimalPattern().format')),
      );
      expect(transactionsSource, contains('text.walletSourceOther'));
      expect(transactionsSource, isNot(contains('_ => source')));
    },
  );

  testWidgets(
    'all transactions shows auth gate for guests without loading wallet data',
    (tester) async {
      final repository = FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      );

      await pumpAllTransactionsPage(
        tester,
        repository: repository,
        authenticated: false,
      );

      final transactionsContext = tester.element(
        find.byType(AllTransactionsPage),
      );
      final text = AppLocalizations.of(transactionsContext);

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.text(text.authSignInRequired), findsOneWidget);
      expect(find.text(text.authRequiredMessage), findsOneWidget);
      expect(repository.walletFetchCount, 0);
      expect(repository.ledgerFetchCount, 0);
    },
  );

  testWidgets(
    'all transactions loads wallet data after guest signs in on the same route',
    (tester) async {
      final launchController = _MutableWalletAppLaunchController(false);
      final walletController = _TransitionWalletController(
        const WalletState(isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            walletControllerProvider.overrideWith(() => walletController),
            walletRepositoryProvider.overrideWithValue(
              defaultFakeWalletRepository(),
            ),
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
      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(walletController.loadCalls, 0);

      launchController.setAuthenticated(true);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProtectedAuthGate), findsNothing);
      expect(walletController.loadCalls, 1);
    },
  );

  testWidgets(
    'all transactions reloads when only partial wallet snapshot exists',
    (tester) async {
      final walletController = _TransitionWalletController(
        const WalletState(
          wallet: walletStateFixture,
          ledger: <WalletLedgerItem>[],
          hasCompletedFullLoad: false,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedWalletAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            walletRepositoryProvider.overrideWithValue(
              defaultFakeWalletRepository(),
            ),
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
      await tester.pump();

      expect(walletController.loadCalls, 1);
    },
  );

  testWidgets(
    'all transactions stays offline without loading and retries on reconnect',
    (tester) async {
      final repository = FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      );
      final networkController = TestWalletNetworkStatusController(
        initialHasInternet: false,
      );

      await pumpAllTransactionsPage(
        tester,
        repository: repository,
        networkStatusController: networkController,
      );

      final transactionsContext = tester.element(
        find.byType(AllTransactionsPage),
      );
      final text = AppLocalizations.of(transactionsContext);

      expect(repository.walletFetchCount, 0);
      expect(repository.ledgerFetchCount, 0);
      expect(find.text(text.appUnavailableOfflineTitle), findsOneWidget);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.walletFetchCount, 1);
      expect(repository.ledgerFetchCount, 1);
    },
  );

  testWidgets('all transactions error state exposes explicit safe retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = RetryLedgerWalletRepository(
      wallet: walletStateFixture,
      ledger: ledgerItemsFixture,
      packs: packsFixture,
      purchases: purchasesFixture,
    );

    await pumpAllTransactionsPage(tester, repository: repository);

    final transactionsContext = tester.element(
      find.byType(AllTransactionsPage),
    );
    final text = AppLocalizations.of(transactionsContext);

    expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);
    expect(find.text(text.walletNoActivity), findsNothing);
    expect(find.widgetWithText(FilledButton, text.retryAction), findsOneWidget);
    expect(repository.ledgerAttempts, 1);

    await tester.tap(find.widgetWithText(FilledButton, text.retryAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.ledgerAttempts, 2);
    expect(find.text(text.walletPartialActivityUnavailable), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all transactions loads more ledger when scrolled near bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final secondPageCompleter = Completer<void>();
    final pagedLedger = List<WalletLedgerItem>.generate(
      40,
      (index) => WalletLedgerItem(
        entryId: 'entry-$index',
        userId: 'user-1',
        delta: index.isEven ? 4 : -2,
        balanceAfter: 500 + index,
        source: index.isEven ? 'ad_reward' : 'generation_spend',
        reason: 'Ledger entry $index',
        createdAtUtc: DateTime.utc(2026, 1, 1, 9, index % 60),
      ),
      growable: false,
    );
    final repository = PagedLedgerWalletRepository(
      wallet: walletStateFixture,
      ledger: pagedLedger,
      packs: packsFixture,
      purchases: purchasesFixture,
      delayedLedgerSkips: {24: secondPageCompleter},
    );

    await pumpAllTransactionsPage(tester, repository: repository);

    expect(repository.ledgerSkips, [0]);
    expect(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-23')),
      findsNothing,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await tester.pump();

    expect(repository.ledgerSkips, [0, 24]);
    expect(
      find.byKey(const ValueKey<String>('wallet_transactions_load_more')),
      findsOneWidget,
    );

    secondPageCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-39')),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const ValueKey<String>('wallet_transaction_entry-39')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wallet_transactions_load_more')),
      findsNothing,
    );
  });

  testWidgets(
    'all transactions auto-loads more ledger when first page does not fill viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pagedLedger = List<WalletLedgerItem>.generate(
        40,
        (index) => WalletLedgerItem(
          entryId: 'entry-$index',
          userId: 'user-1',
          delta: index.isEven ? 4 : -2,
          balanceAfter: 500 + index,
          source: index.isEven ? 'ad_reward' : 'generation_spend',
          reason: 'Ledger entry $index',
          createdAtUtc: DateTime.utc(2026, 1, 1, 9, index % 60),
        ),
        growable: false,
      );
      final repository = PagedLedgerWalletRepository(
        wallet: walletStateFixture,
        ledger: pagedLedger,
        packs: packsFixture,
        purchases: purchasesFixture,
      );

      await pumpAllTransactionsPage(tester, repository: repository);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        repository.ledgerSkips,
        [0, 24],
        reason: 'short first page should auto-prefetch the next ledger page',
      );
      expect(
        find.byKey(const ValueKey<String>('wallet_transactions_load_more')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'all transactions keeps load-more failures explicit and manual-retry only',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pagedLedger = List<WalletLedgerItem>.generate(
        40,
        (index) => WalletLedgerItem(
          entryId: 'entry-$index',
          userId: 'user-1',
          delta: index.isEven ? 4 : -2,
          balanceAfter: 500 + index,
          source: index.isEven ? 'ad_reward' : 'generation_spend',
          reason: 'Ledger entry $index',
          createdAtUtc: DateTime.utc(2026, 1, 1, 9, index % 60),
        ),
        growable: false,
      );
      final repository = RetryPagedLedgerWalletRepository(
        wallet: walletStateFixture,
        ledger: pagedLedger,
        packs: packsFixture,
        purchases: purchasesFixture,
      );

      await pumpAllTransactionsPage(tester, repository: repository);

      final transactionsContext = tester.element(
        find.byType(AllTransactionsPage),
      );
      final text = AppLocalizations.of(transactionsContext);

      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pump();

      expect(repository.ledgerSkips, [0, 24]);
      expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, text.retryAction),
        findsOneWidget,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pump();

      expect(
        repository.ledgerSkips,
        [0, 24],
        reason: 'load more should not auto-retry after an explicit failure',
      );

      await tester.tap(find.widgetWithText(FilledButton, text.retryAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(repository.ledgerSkips, [0, 24, 24]);
      expect(find.text(text.walletPartialActivityUnavailable), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('wallet_transaction_entry-39')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet_transaction_entry-39')),
        findsOneWidget,
      );
    },
  );
}

class _MutableWalletAppLaunchController extends AppLaunchController {
  _MutableWalletAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

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

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _TransitionWalletController extends WalletController {
  _TransitionWalletController(this._initialState);

  final WalletState _initialState;
  int loadCalls = 0;

  @override
  WalletState build() => _initialState;

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    state = state.copyWith(isLoading: false);
  }
}
