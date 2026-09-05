import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/application/gamification_providers.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  for (final configuration in const [
    _ProfileGoldenConfiguration('compact', Size(320, 568)),
    _ProfileGoldenConfiguration('phone', Size(390, 844)),
    _ProfileGoldenConfiguration('tablet', Size(834, 1194)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'profile ${configuration.name} ${brightness.name} visual baseline',
        (tester) async {
          tester.view.physicalSize = configuration.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final router = GoRouter(
            initialLocation: ProfilePage.routePath,
            routes: [
              GoRoute(
                path: ProfilePage.routePath,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RepaintBoundary(
                    key: Key('profile_golden_surface'),
                    child: ProfilePage(),
                  ),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appLaunchControllerProvider.overrideWith(
                  _AuthenticatedProfileAppLaunchController.new,
                ),
                networkStatusControllerProvider.overrideWith(
                  () => _TestProfileNetworkStatusController(
                    initialHasInternet: true,
                  ),
                ),
                profileControllerProvider.overrideWith(
                  _FakeProfileController.new,
                ),
                walletControllerProvider.overrideWith(
                  _FakeWalletController.new,
                ),
                gamificationSummaryProvider.overrideWith(
                  (ref) async => const GamificationSummaryModel(),
                ),
                achievementsProvider.overrideWith(
                  (ref) async => const <AchievementModel>[],
                ),
                premiumSubscriptionSummaryProvider.overrideWith(
                  (ref) async => const PremiumSubscriptionSummaryView(
                    isPremium: false,
                    canManageSubscription: false,
                    status: 'inactive',
                    manageSubscriptionAction: '',
                    provider: PremiumSubscriptionProviderView.unknown,
                  ),
                ),
              ],
              child: MaterialApp.router(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: AppNavigationScope(
                    navigator: GoRouterAppNavigator(router),
                    child: child!,
                  ),
                ),
                routerConfig: router,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('profile_golden_surface')),
            matchesGoldenFile(
              'goldens/profile_${configuration.name}_${brightness.name}.png',
            ),
          );
        },
        tags: const ['platform-golden'],
      );
    }
  }

  testWidgets('profile page shows unified auth gate for guests', (
    tester,
  ) async {
    final walletController = _CountingWalletController(
      initialState: const WalletState(isLoading: false),
    );
    var premiumSummaryReads = 0;
    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: AuthEntryPage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: Scaffold(body: Text('Auth route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedProfileAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(_GuestProfileController.new),
          walletControllerProvider.overrideWith(() => walletController),
          premiumSubscriptionSummaryProvider.overrideWith((ref) async {
            premiumSummaryReads++;
            return const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            );
          }),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 500));

    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    expect(
      router.routeInformationProvider.value.uri.path,
      ProfilePage.routePath,
    );
    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text(text.authRequiredTitle), findsOneWidget);
    expect(find.text(text.authRequiredMessage), findsOneWidget);
    expect(find.text('Auth route'), findsNothing);
    expect(walletController.syncSnapshotCalls, 0);
    expect(premiumSummaryReads, 0);
  });

  testWidgets('profile page reacts to auth transitions on the same route', (
    tester,
  ) async {
    final launchController = _MutableProfileAppLaunchController(false);
    final profileController = _AuthReactiveProfileController();

    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(() => launchController),
          profileControllerProvider.overrideWith(() => profileController),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            ),
          ),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(profileController.initializeCalls, 0);

    launchController.setAuthenticated(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ProtectedAuthGate), findsNothing);
    expect(find.text('Pet User'), findsOneWidget);
    expect(profileController.initializeCalls, 1);

    launchController.setAuthenticated(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text('Pet User'), findsNothing);
    expect(profileController.initializeCalls, 2);
  });

  testWidgets(
    'profile page skips deferred reload after immediate sign out on the same route',
    (tester) async {
      final launchController = _MutableProfileAppLaunchController(false);
      final profileController = _AuthReactiveProfileController();

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            profileControllerProvider.overrideWith(() => profileController),
            walletControllerProvider.overrideWith(_FakeWalletController.new),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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

      launchController.setAuthenticated(true);
      launchController.setAuthenticated(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.text('Pet User'), findsNothing);
      expect(profileController.initializeCalls, 0);
    },
  );

  testWidgets(
    'profile page skips wallet preload when wallet snapshot already exists',
    (tester) async {
      final walletController = _CountingWalletController(
        initialState: const WalletState(
          wallet: WalletStateModel(
            userId: 'user-1',
            balance: 130,
            adRewardsRemainingToday: 3,
            isPremium: false,
            updatedAtUtc: null,
            nextWeeklyGrantAtUtc: null,
          ),
          hasCompletedFullLoad: true,
          isLoading: false,
        ),
      );

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(() => walletController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(walletController.syncSnapshotCalls, 0);
    },
  );

  testWidgets(
    'profile page preloads wallet once for authenticated users without snapshot',
    (tester) async {
      final walletController = _CountingWalletController(
        initialState: const WalletState(isLoading: true),
      );

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(() => walletController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(walletController.syncSnapshotCalls, 1);
      expect(walletController.loadCalls, 0);
    },
  );

  testWidgets('profile page does not reload a partial wallet snapshot', (
    tester,
  ) async {
    final walletController = _CountingWalletController(
      initialState: const WalletState(
        wallet: WalletStateModel(
          userId: 'user-1',
          balance: 130,
          adRewardsRemainingToday: 3,
          isPremium: false,
          updatedAtUtc: null,
          nextWeeklyGrantAtUtc: null,
        ),
        hasCompletedFullLoad: false,
        isLoading: false,
      ),
    );

    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: ProfileSettingsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Settings route')),
          ),
        ),
        GoRoute(
          path: SupportChatPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Support route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedProfileAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          walletControllerProvider.overrideWith(() => walletController),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            ),
          ),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(walletController.syncSnapshotCalls, 0);
    expect(walletController.loadCalls, 0);
  });

  testWidgets(
    'profile page defers wallet preload while offline and retries on reconnect',
    (tester) async {
      final walletController = _CountingWalletController(
        initialState: const WalletState(isLoading: false),
      );
      final networkController = _TestProfileNetworkStatusController(
        initialHasInternet: false,
      );

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(() => walletController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Pet User'), findsOneWidget);
      expect(walletController.syncSnapshotCalls, 0);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(walletController.syncSnapshotCalls, 1);
    },
  );

  testWidgets(
    'profile page retry restores profile and preloads wallet after unavailable state',
    (tester) async {
      final walletController = _CountingWalletController(
        initialState: const WalletState(isLoading: false),
      );

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(
              _UnavailableThenLoadedProfileController.new,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      final profileContext = tester.element(find.byType(ProfilePage));
      final text = AppLocalizations.of(profileContext);

      expect(find.text(text.retryAction), findsOneWidget);
      expect(walletController.syncSnapshotCalls, 0);

      await tester.tap(find.text(text.retryAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Pet User'), findsOneWidget);
      expect(walletController.syncSnapshotCalls, 1);
    },
  );

  testWidgets(
    'profile page does not refetch unavailable state on offline resume and retries on reconnect',
    (tester) async {
      final profileController = _UnavailableThenLoadedProfileController();
      final walletController = _CountingWalletController(
        initialState: const WalletState(isLoading: false),
      );
      final networkController = _TestProfileNetworkStatusController(
        initialHasInternet: false,
      );

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
            profileControllerProvider.overrideWith(() => profileController),
            walletControllerProvider.overrideWith(() => walletController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      final initialInitializeCalls = profileController.initializeCalls;
      expect(initialInitializeCalls, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(profileController.initializeCalls, initialInitializeCalls);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        profileController.initializeCalls,
        greaterThan(initialInitializeCalls),
      );
      expect(find.text('Pet User'), findsOneWidget);
      expect(walletController.syncSnapshotCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile legal shortcut opens legal detail route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: ProfileSettingsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Settings route')),
          ),
        ),
        GoRoute(
          path: ProfileSettingsDetailPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Legal detail route')),
          ),
        ),
        GoRoute(
          path: SupportChatPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Support route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedProfileAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          gamificationSummaryProvider.overrideWith(
            (ref) async => const GamificationSummaryModel(
              streak: StreakModel(
                currentStreak: 4,
                longestStreak: 8,
                freezesAvailable: 1,
                freezesPerWeek: 1,
                lastActiveDate: '2026-06-29',
                activeDaysThisWeek: ['mon', 'tue', 'wed', 'thu'],
              ),
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) async => const [
              AchievementModel(
                key: 'first_magic',
                category: 'generation',
                rarity: 'common',
                titleKey: 'achievementFirstMagic',
                descriptionKey: 'achievementFirstMagicDesc',
                requirementValue: 1,
                currentProgress: 1,
                rewardSpark: 10,
                isSecret: false,
                isUnlocked: true,
                iconEmoji: '✨',
              ),
            ],
          ),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            ),
          ),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
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
    await tester.pump(const Duration(milliseconds: 250));

    final legalShortcut = find.byKey(const ValueKey('profile_legal_shortcut'));
    await tester.scrollUntilVisible(
      legalShortcut,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(legalShortcut);
    await tester.pumpAndSettle();

    expect(find.text('Legal detail route'), findsOneWidget);
    expect(find.text('Settings route'), findsNothing);
  });

  testWidgets('subscription action returns safely after profile disposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final profileController = _FakeProfileController();
    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: PremiumPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Premium route')),
          ),
        ),
        GoRoute(
          path: SubscriptionManagementPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Subscription route')),
          ),
        ),
        GoRoute(
          path: '/away',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: Scaffold(body: Text('Away route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedProfileAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(() => profileController),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: true,
              canManageSubscription: true,
              status: 'active',
              manageSubscriptionAction: 'manage',
              provider: PremiumSubscriptionProviderView.stripe,
            ),
          ),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 250));
    final initialInitializeCalls = profileController.initializeCalls;
    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);

    await tester.tap(find.text(text.premiumManageAction));
    await tester.pumpAndSettle();
    expect(find.text('Subscription route'), findsOneWidget);

    router.go('/away');
    await tester.pumpAndSettle();

    expect(find.text('Away route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(profileController.initializeCalls, initialInitializeCalls);
  });

  testWidgets(
    'profile subscription summary uses generic label for unknown providers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: PremiumPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Premium route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(_FakeWalletController.new),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: true,
                canManageSubscription: true,
                status: 'active',
                manageSubscriptionAction: 'manage',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 250));

      final profileContext = tester.element(find.byType(ProfilePage));
      final text = AppLocalizations.of(profileContext);

      expect(find.text(text.premiumPaymentOther), findsAtLeastNWidgets(1));
      expect(find.text(text.premiumPaymentStripe), findsNothing);
    },
  );

  testWidgets(
    'profile subscription summary shows localized canonical status label',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: PremiumPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Premium route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(_FakeWalletController.new),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: true,
                canManageSubscription: true,
                status: 'past_due',
                manageSubscriptionAction: 'manage',
                provider: PremiumSubscriptionProviderView.stripe,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
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
      await tester.pump(const Duration(milliseconds: 250));

      final profileContext = tester.element(find.byType(ProfilePage));
      final text = AppLocalizations.of(profileContext);

      expect(find.text(text.subscriptionStatusPaymentFailed), findsOneWidget);
      expect(find.text('past_due'), findsNothing);
    },
  );

  testWidgets('profile keeps a single achievements entrypoint and opens it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: ProfilePage.routePath,
      routes: [
        GoRoute(
          path: ProfilePage.routePath,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
        GoRoute(
          path: AchievementsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Achievements route')),
          ),
        ),
        GoRoute(
          path: ProfileSettingsPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Settings route')),
          ),
        ),
        GoRoute(
          path: SupportChatPage.routePath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Scaffold(body: Text('Support route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedProfileAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          walletControllerProvider.overrideWith(_FakeWalletController.new),
          gamificationSummaryProvider.overrideWith(
            (ref) async => const GamificationSummaryModel(
              streak: StreakModel(
                currentStreak: 4,
                longestStreak: 8,
                freezesAvailable: 1,
                freezesPerWeek: 1,
                lastActiveDate: '2026-06-29',
                activeDaysThisWeek: ['mon', 'tue', 'wed', 'thu'],
              ),
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) async => const [
              AchievementModel(
                key: 'first_magic',
                category: 'generation',
                rarity: 'common',
                titleKey: 'achievementFirstMagic',
                descriptionKey: 'achievementFirstMagicDesc',
                requirementValue: 1,
                currentProgress: 1,
                rewardSpark: 10,
                isSecret: false,
                isUnlocked: true,
                iconEmoji: '✨',
              ),
            ],
          ),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: false,
              canManageSubscription: false,
              status: 'inactive',
              manageSubscriptionAction: '',
              provider: PremiumSubscriptionProviderView.unknown,
            ),
          ),
        ],
        child: MaterialApp.router(
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
          routerConfig: router,
          theme: AppTheme.dark(),
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 500));

    final profileContext = tester.element(find.byType(ProfilePage));
    final text = AppLocalizations.of(profileContext);
    final achievementsEntry = find.byKey(
      const ValueKey('profile_gamification_achievements_stat'),
    );
    await tester.ensureVisible(achievementsEntry);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(text.gamificationAchievementsTitle), findsOneWidget);
    await tester.tap(achievementsEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Achievements route'), findsOneWidget);
  });

  testWidgets(
    'profile keeps achievements entry visible and exposes retry when gamification preview fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: ProfilePage.routePath,
        routes: [
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: AchievementsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Achievements route')),
            ),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Settings route')),
            ),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Text('Support route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedProfileAppLaunchController.new,
            ),
            profileControllerProvider.overrideWith(_FakeProfileController.new),
            walletControllerProvider.overrideWith(_FakeWalletController.new),
            gamificationSummaryProvider.overrideWith(
              (ref) async =>
                  throw const AppException('gamification.server_unavailable'),
            ),
            achievementsProvider.overrideWith(
              (ref) async =>
                  throw const AppException('gamification.server_unavailable'),
            ),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: false,
                canManageSubscription: false,
                status: 'inactive',
                manageSubscriptionAction: '',
                provider: PremiumSubscriptionProviderView.unknown,
              ),
            ),
          ],
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
            routerConfig: router,
            theme: AppTheme.dark(),
            locale: const Locale('en'),
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
      await tester.pump(const Duration(milliseconds: 500));

      final profileContext = tester.element(find.byType(ProfilePage));
      final text = AppLocalizations.of(profileContext);

      final achievementsEntry = find.byKey(
        const ValueKey('profile_gamification_achievements_stat'),
      );
      await tester.ensureVisible(achievementsEntry);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(text.gamificationAchievementsTitle), findsOneWidget);
      expect(find.text(text.appUnavailableServerTitle), findsOneWidget);
      expect(find.widgetWithText(TextButton, text.retryAction), findsOneWidget);

      await tester.tap(achievementsEntry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Achievements route'), findsOneWidget);
    },
  );
}

class _ProfileGoldenConfiguration {
  const _ProfileGoldenConfiguration(this.name, this.size);

  final String name;
  final Size size;
}

class _FakeProfileController extends ProfileController {
  int initializeCalls = 0;

  @override
  ProfileState build() {
    final profile = _profile;
    return ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: profile.displayName ?? '',
      email: profile.email,
      password: '',
      confirmPassword: '',
      profile: profile,
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {
    initializeCalls++;
  }

  @override
  Future<void> logout() async {}
}

class _AuthReactiveProfileController extends ProfileController {
  int initializeCalls = 0;

  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {
    initializeCalls++;
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    if (isAuthenticated) {
      state = ProfileState(
        isLoading: false,
        isSaving: false,
        displayName: _profile.displayName ?? '',
        email: _profile.email,
        password: '',
        confirmPassword: '',
        profile: _profile,
      );
      return;
    }

    state = const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
  }

  @override
  Future<void> logout() async {}
}

class _GuestProfileController extends ProfileController {
  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {}

  @override
  Future<void> logout() async {}
}

class _UnavailableThenLoadedProfileController extends ProfileController {
  int _initializeCalls = 0;

  int get initializeCalls => _initializeCalls;

  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
      errorMessage: 'templates.network_unavailable',
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {
    _initializeCalls++;
    if (_initializeCalls == 1) {
      return;
    }

    state = ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: _profile.displayName ?? '',
      email: _profile.email,
      password: '',
      confirmPassword: '',
      profile: _profile,
    );
  }

  @override
  Future<void> logout() async {}
}

class _TestProfileNetworkStatusController extends NetworkStatusController {
  _TestProfileNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

class _MutableProfileAppLaunchController extends AppLaunchController {
  _MutableProfileAppLaunchController(this._isAuthenticated);

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

class _AuthenticatedProfileAppLaunchController extends AppLaunchController {
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

class _UnauthenticatedProfileAppLaunchController extends AppLaunchController {
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

class _FakeWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 130,
        adRewardsRemainingToday: 3,
        isPremium: false,
        updatedAtUtc: null,
        nextWeeklyGrantAtUtc: null,
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _CountingWalletController extends WalletController {
  _CountingWalletController({required this.initialState});

  final WalletState initialState;
  int loadCalls = 0;
  int syncSnapshotCalls = 0;

  @override
  WalletState build() => initialState;

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }

  @override
  Future<void> syncSnapshot({bool forceRefresh = false}) async {
    syncSnapshotCalls++;
  }
}

const _profile = MobileUserProfile(
  userId: 'user-1',
  email: 'user@example.com',
  displayName: 'Pet User',
  isPremium: false,
  emailConfirmed: true,
  termsOfUseAccepted: true,
  privacyPolicyAccepted: true,
  marketingEmailsEnabled: true,
  legalAcceptance: MobileLegalAcceptanceStatus(
    termsOfUseAccepted: true,
    termsOfUseAcceptedVersion: '1.0',
    termsOfUseAcceptedAtUtc: null,
    privacyPolicyAccepted: true,
    privacyPolicyAcceptedVersion: '1.0',
    privacyPolicyAcceptedAtUtc: null,
    currentTermsOfUseVersion: '1.0',
    currentPrivacyPolicyVersion: '1.0',
    requiresAcceptance: false,
  ),
  roles: ['user'],
  avatar: null,
);
