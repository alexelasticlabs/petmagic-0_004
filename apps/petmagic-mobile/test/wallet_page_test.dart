import 'dart:async';
import 'dart:io';

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
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  test('wallet pack approximation copy uses localizations', () {
    final source = File(
      'lib/features/wallet/presentation/widgets/wallet_page_activity_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('walletApproxPhotosOnly'));
    expect(source, contains('walletApproxPhotosOrVideos'));
    expect(source, isNot(contains(' или ')));
    expect(source, isNot(contains("'≈ ")));
  });

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
      tester.testTextInput.hide();
      final walletContext = tester.element(find.byType(WalletPage));
      final text = AppLocalizations.of(walletContext);

      expect(find.text(text.walletBalanceEyebrow), findsOneWidget);
      expect(find.byTooltip(text.walletRefreshTooltip), findsNothing);
      expect(find.textContaining('Недельная награда'), findsNothing);
      expect(find.text('Способы оплаты'), findsNothing);

      expect(find.text(text.walletPromoTitle), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(text.walletBuySparkTitle), findsWidgets);

      expect(find.text(text.walletPackDetailsAction), findsWidgets);

      await tester.tap(find.text(text.walletPackDetailsAction).first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(text.premiumPaymentStripe), findsAtLeastNWidgets(1));
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
        return widget is ProfileMessageCard &&
            widget.message == text.walletPartialActivityUnavailable &&
            widget.tone == const Color(0xFFFFC107);
      }),
      findsOneWidget,
    );
  });

  testWidgets('wallet page shows unified auth gate for guests', (tester) async {
    await _pumpWalletPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
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

  testWidgets('authenticated wallet unavailable state still shows retry card', (
    tester,
  ) async {
    await _pumpWalletPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
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
    'wallet page shows legal acceptance action for legal gate errors',
    (tester) async {
      await _pumpWalletPage(
        tester,
        repository: _FakeWalletRepository(
          wallet: _walletState,
          ledger: _ledgerItems,
          packs: _packs,
          purchases: _purchases,
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

    await _pumpAllTransactionsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: largeLedger,
        packs: _packs,
        purchases: _purchases,
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

  testWidgets('all transactions error state exposes explicit safe retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _RetryLedgerWalletRepository(
      wallet: _walletState,
      ledger: _ledgerItems,
      packs: _packs,
      purchases: _purchases,
    );

    await _pumpAllTransactionsPage(tester, repository: repository);

    final transactionsContext = tester.element(
      find.byType(AllTransactionsPage),
    );
    final text = AppLocalizations.of(transactionsContext);

    expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);
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
    final repository = _PagedLedgerWalletRepository(
      wallet: _walletState,
      ledger: pagedLedger,
      packs: _packs,
      purchases: _purchases,
      delayedLedgerSkips: {24: secondPageCompleter},
    );

    await _pumpAllTransactionsPage(tester, repository: repository);

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
      final repository = _RetryPagedLedgerWalletRepository(
        wallet: _walletState,
        ledger: pagedLedger,
        packs: _packs,
        purchases: _purchases,
      );

      await _pumpAllTransactionsPage(tester, repository: repository);

      final transactionsContext = tester.element(
        find.byType(AllTransactionsPage),
      );
      final text = AppLocalizations.of(transactionsContext);

      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pump();

      expect(repository.ledgerSkips, [0, 24]);
      expect(find.text(text.walletPartialActivityUnavailable), findsOneWidget);
      expect(find.widgetWithText(FilledButton, text.retryAction), findsOneWidget);

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

  testWidgets('wallet auto refresh does not reschedule after page disposal', (
    tester,
  ) async {
    final controller = _AutoRefreshProbeWalletController();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Material(child: WalletPage()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
        ),
      ),
    );
    await tester.pump();
    expect(controller.loadCalls, 1);

    controller.delayNextLoad();
    await tester.pump(const Duration(seconds: 12));
    expect(controller.loadCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.completeDelayedLoad();
    await tester.pump();

    await tester.pump(const Duration(seconds: 13));
    expect(controller.loadCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rewards tab replaces wallet in bottom navigation', (
    tester,
  ) async {
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
              path: RewardsPage.routePath,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Text('Rewards route')),
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
      ProviderScope(
        overrides: [
          templateGenerationControllerProvider.overrideWith(
            _IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Бонусы'), findsOneWidget);
    expect(find.text('Кошелек'), findsNothing);
    expect(find.text('Галерея'), findsOneWidget);

    await tester.tap(find.text('Бонусы'));
    await tester.pumpAndSettle();

    expect(find.text('Rewards route'), findsOneWidget);
  });

  testWidgets('rewards page shows unified auth gate for guests', (
    tester,
  ) async {
    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
      ),
      authenticated: false,
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.authRequiredMessage), findsOneWidget);
  });

  testWidgets(
    'rewards page shows legal acceptance action for legal gate errors',
    (tester) async {
      await _pumpRewardsPage(
        tester,
        repository: _FakeWalletRepository(
          wallet: _walletState,
          ledger: _ledgerItems,
          packs: _packs,
          purchases: _purchases,
          walletError: AppException('auth.legal_acceptance_required'),
        ),
      );

      final rewardsContext = tester.element(find.byType(RewardsPage));
      final text = AppLocalizations.of(rewardsContext);

      expect(find.text(text.appUnavailableServerTitle), findsNothing);
      expect(find.text(text.profileLegalAcceptanceRequired), findsOneWidget);
      expect(find.text(text.profileLegalAcceptAction), findsOneWidget);
    },
  );

  testWidgets('wallet navigation hides while keyboard is open', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationControllerProvider.overrideWith(
            _IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
          child: MaterialApp(
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
            home: const PetMagicShell(
              location: WalletPage.routePath,
              child: Scaffold(body: Text('Wallet route')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Бонусы'), findsNothing);
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('bottom navigation blurs over iOS home indicator area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationControllerProvider.overrideWith(
            _IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
          child: MaterialApp(
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
            home: const PetMagicShell(
              location: WalletPage.routePath,
              child: Scaffold(body: Text('Wallet route')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final solidSafeAreaBand = find.byWidgetPredicate((widget) {
      return widget is Positioned &&
          widget.left == 0 &&
          widget.right == 0 &&
          widget.bottom == 0 &&
          widget.height == 44;
    });

    expect(solidSafeAreaBand, findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is Positioned &&
            widget.left == 0 &&
            widget.right == 0 &&
            widget.bottom == 0 &&
            widget.height == 150;
      }),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(2));
  });

  testWidgets('rewards page redeems promo codes with friendly errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
        redeemError: const AppException('wallet.network_unavailable'),
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('rewards_promo_input')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('rewards_promo_input')),
      'WELCOME-100',
    );
    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('rewards_promo_submit')),
    );
    submitButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(text.walletRedeemOfflineError, skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('rewards page validates empty promo code input', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 300));

    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('rewards_promo_submit')),
    );
    submitButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.rewardsPromoEmptyError), findsOneWidget);
  });

  testWidgets('rewards page activates referral codes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1080));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(
      find.byKey(const Key('rewards_referral_show_input')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('rewards_referral_show_input')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('rewards_referral_input')),
      'PMFRIEND1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.rewardsReferralStatusPending), findsOneWidget);
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('rewards page hides purchase soft warnings from wallet preload', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
        failPurchases: true,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    expect(find.text(text.walletBalanceEyebrow), findsOneWidget);
    expect(find.text(text.rewardsPageTitle), findsOneWidget);
    expect(find.text(text.rewardsPromoTitle), findsOneWidget);
    expect(find.text(text.walletPartialActivityUnavailable), findsNothing);
    expect(find.text('wallet.purchases_failed'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, -620));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.rewardsReferralTitle), findsWidgets);
    expect(find.byKey(const Key('rewards_referral_show_input')), findsWidgets);
  });

  testWidgets('rewards page keeps gamification content out of bonuses flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    expect(find.text(text.gamificationStreakTitle), findsNothing);
    expect(find.text(text.gamificationChallengeTitle), findsNothing);
    expect(find.text(text.rewardsPromoTitle), findsOneWidget);
    expect(find.text(text.rewardsReferralTitle), findsWidgets);
  });

  testWidgets('rewards page hides payment unavailable purchase hint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: _ledgerItems,
        packs: _packs,
        purchases: _purchases,
        paymentMethods: const [],
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    await tester.drag(find.byType(ListView).first, const Offset(0, -620));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.walletPaymentGatewayUnavailableError), findsNothing);
    expect(find.textContaining('wallet.payment_unavailable'), findsNothing);
  });

  testWidgets('rewards history sheet builds long ledger lazily', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longLedger = List<WalletLedgerItem>.generate(
      120,
      (index) => WalletLedgerItem(
        entryId: 'reward-$index',
        userId: 'user-1',
        delta: index.isEven ? 10 : -4,
        balanceAfter: 200 - index,
        source: index.isEven ? 'ad_reward' : 'generation_spend',
        reason: 'Reward history row $index',
        createdAtUtc: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
      ),
    );

    await _pumpRewardsPage(
      tester,
      repository: _FakeWalletRepository(
        wallet: _walletState,
        ledger: longLedger,
        packs: _packs,
        purchases: _purchases,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    await tester.tap(find.text(text.rewardsHistoryTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Reward history row 0'), findsOneWidget);
    expect(find.text('Reward history row 119'), findsNothing);
  });
}

class _IdleTemplateGenerationController extends TemplateGenerationController {
  @override
  TemplateGenerationState build() {
    return const TemplateGenerationState();
  }
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
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

class _UnauthenticatedAppLaunchController extends AppLaunchController {
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

Future<void> _pumpAllTransactionsPage(
  WidgetTester tester, {
  required WalletRepository repository,
}) async {
  addTearDown(() => PetMagicNotificationCenter.instance.clearQueue());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
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

Future<void> _pumpWalletPage(
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
              ? _AuthenticatedAppLaunchController.new
              : _UnauthenticatedAppLaunchController.new,
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

Future<void> _pumpRewardsPage(
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
              ? _AuthenticatedAppLaunchController.new
              : _UnauthenticatedAppLaunchController.new,
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

class _AutoRefreshProbeWalletController extends WalletController {
  int loadCalls = 0;
  Completer<void>? _delayedLoad;

  @override
  WalletState build() {
    return const WalletState(
      wallet: _walletState,
      rewards: _rewardsSummary,
      ledger: _ledgerItems,
      packs: _packs,
      paymentMethods: _paymentMethods,
      purchases: _purchases,
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
}

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository({
    required this.wallet,
    required this.ledger,
    required this.packs,
    required this.purchases,
    this.failWallet = false,
    this.walletError,
    this.failLedger = false,
    this.failPurchases = false,
    this.redeemError,
    this.paymentMethods = _paymentMethods,
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

  @override
  Future<WalletStateModel> fetchWallet({CancelToken? cancelToken}) async {
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
    return WalletCheckoutConfigModel(
      packs: packs,
      paymentMethods: paymentMethods,
      externalPaymentWarningRequired: false,
    );
  }

  @override
  Future<RewardsSummaryModel> fetchRewards({CancelToken? cancelToken}) async =>
      _rewardsSummary;

  @override
  Future<OffsetPagedModel<PurchaseHistoryItem>> fetchPurchases({
    int skip = 0,
    int take = 20,
    CancelToken? cancelToken,
  }) async {
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

class _RetryLedgerWalletRepository extends _FakeWalletRepository {
  _RetryLedgerWalletRepository({
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

class _PagedLedgerWalletRepository extends _FakeWalletRepository {
  _PagedLedgerWalletRepository({
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

class _RetryPagedLedgerWalletRepository extends _PagedLedgerWalletRepository {
  _RetryPagedLedgerWalletRepository({
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

const _rewardsSummary = RewardsSummaryModel(
  referralCode: 'PMME12345',
  referralBonusSpark: 15,
  referralStatus: 'none',
  totalReferralBonusEarned: 15,
  referredUsersCount: 1,
  pendingReferredUsersCount: 0,
  rewardedReferredUsersCount: 1,
);

const _walletState = WalletStateModel(
  userId: 'user-1',
  balance: 172,
  adRewardsRemainingToday: 3,
  isPremium: false,
  updatedAtUtc: null,
  nextWeeklyGrantAtUtc: null,
);

const _ledgerItems = [
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

const _packs = [
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

const _paymentMethods = [
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

const _purchases = [
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
