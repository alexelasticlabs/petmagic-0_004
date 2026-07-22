import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

import 'wallet_page_test_support.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  for (final configuration in const [
    _RewardsGoldenConfiguration('compact', Size(320, 568)),
    _RewardsGoldenConfiguration('phone', Size(390, 844)),
    _RewardsGoldenConfiguration('tablet', Size(834, 1194)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'rewards ${configuration.name} ${brightness.name} visual baseline',
        (tester) async {
          tester.view.physicalSize = configuration.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpRewardsPage(
            tester,
            repository: FakeWalletRepository(
              wallet: walletStateFixture,
              ledger: ledgerItemsFixture,
              packs: packsFixture,
              purchases: purchasesFixture,
            ),
            networkStatusController: TestWalletNetworkStatusController(
              initialHasInternet: true,
            ),
            walletController: StaticRewardsWalletController(),
            brightness: brightness,
            disableAnimations: true,
          );

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('rewards_test_surface')),
            matchesGoldenFile(
              'goldens/rewards_${configuration.name}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }

  testWidgets('wallet auto refresh does not reschedule after page disposal', (
    tester,
  ) async {
    final controller = AutoRefreshProbeWalletController();
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
            AuthenticatedWalletAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => controller),
          walletRepositoryProvider.overrideWithValue(
            defaultFakeWalletRepository(),
          ),
          templatesControllerProvider.overrideWith(
            StaticWalletTemplatesController.new,
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
    await tester.pump();
    expect(controller.refreshCalls, 0);

    controller.delayNextLoad();
    await tester.pump(const Duration(seconds: 12));
    expect(controller.refreshCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.completeDelayedLoad();
    await tester.pump();

    await tester.pump(const Duration(seconds: 13));
    expect(controller.refreshCalls, 1);
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
            IdleWalletTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            IdleWalletGenerationHistoryController.new,
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
    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
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
    'rewards page loads wallet data after guest signs in on the same route',
    (tester) async {
      final launchController = _MutableRewardsAppLaunchController(false);
      final walletController = _TransitionRewardsWalletController(
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
                      const Material(child: RewardsPage()),
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
    'rewards page skips eager reload when wallet snapshot is already hydrated',
    (tester) async {
      final walletController = _TransitionRewardsWalletController(
        const WalletState(
          wallet: walletStateFixture,
          rewards: rewardsSummaryFixture,
          ledger: ledgerItemsFixture,
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
                      const Material(child: RewardsPage()),
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

  testWidgets(
    'rewards page stays offline without loading and retries on reconnect',
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

      await pumpRewardsPage(
        tester,
        repository: repository,
        networkStatusController: networkController,
      );

      final rewardsContext = tester.element(find.byType(RewardsPage));
      final text = AppLocalizations.of(rewardsContext);

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

  testWidgets(
    'rewards page shows legal acceptance action for legal gate errors',
    (tester) async {
      await pumpRewardsPage(
        tester,
        repository: FakeWalletRepository(
          wallet: walletStateFixture,
          ledger: ledgerItemsFixture,
          packs: packsFixture,
          purchases: purchasesFixture,
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

  test('rewards page lifecycle skips offline resume retries', () {
    final source = File(
      'lib/features/rewards/presentation/rewards_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        '    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;\n'
        '    if (!hasInternet) {\n'
        '      return;\n'
        '    }\n'
        '\n'
        '    final unavailableKind =',
      ),
    );
    expect(
      source,
      contains(
        '      if (previous?.hasInternet != false || !next.hasInternet) {\n'
        '        return;\n'
        '      }',
      ),
    );
    expect(
      source,
      contains('      unawaited(_loadRewardsIfOnline(refresh: true));'),
    );
  });

  testWidgets('wallet navigation hides while keyboard is open', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateGenerationControllerProvider.overrideWith(
            IdleWalletTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            IdleWalletGenerationHistoryController.new,
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
            IdleWalletTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            IdleWalletGenerationHistoryController.new,
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

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
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

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
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

  testWidgets('rewards promo submit button keeps app font family', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      ),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('rewards_promo_submit')));
    await tester.pump(const Duration(milliseconds: 300));

    final buttonFinder = find.byKey(const Key('rewards_promo_submit'));
    final button = tester.widget<FilledButton>(buttonFinder);
    final buttonContext = tester.element(buttonFinder);
    final resolvedTextStyle = button.style?.textStyle?.resolve({});

    expect(resolvedTextStyle, isNotNull);
    expect(
      resolvedTextStyle!.fontFamily,
      Theme.of(buttonContext).textTheme.labelLarge?.fontFamily,
    );
    expect(resolvedTextStyle.fontFamily, contains('Comfortaa'));
  });

  testWidgets('rewards page activates referral codes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
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

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
        failPurchases: true,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    expect(find.text(text.walletBalanceEyebrow), findsOneWidget);
    expect(find.text(text.rewardsPageTitle), findsOneWidget);
    expect(find.text(text.walletAdRewardCompactTitle), findsOneWidget);
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

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
      ),
    );

    final rewardsContext = tester.element(find.byType(RewardsPage));
    final text = AppLocalizations.of(rewardsContext);

    expect(find.text(text.gamificationStreakTitle), findsNothing);
    expect(find.text(text.gamificationChallengeTitle), findsNothing);
    expect(find.text(text.walletAdRewardCompactTitle), findsOneWidget);
    expect(find.text(text.rewardsPromoTitle), findsOneWidget);
    expect(find.text(text.rewardsReferralTitle), findsWidgets);
  });

  testWidgets('rewards page hides payment unavailable purchase hint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: ledgerItemsFixture,
        packs: packsFixture,
        purchases: purchasesFixture,
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

    await pumpRewardsPage(
      tester,
      repository: FakeWalletRepository(
        wallet: walletStateFixture,
        ledger: longLedger,
        packs: packsFixture,
        purchases: purchasesFixture,
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

class _RewardsGoldenConfiguration {
  const _RewardsGoldenConfiguration(this.name, this.size);

  final String name;
  final Size size;
}

class _MutableRewardsAppLaunchController extends AppLaunchController {
  _MutableRewardsAppLaunchController(this._isAuthenticated);

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

class _TransitionRewardsWalletController extends WalletController {
  _TransitionRewardsWalletController(this._initialState);

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
