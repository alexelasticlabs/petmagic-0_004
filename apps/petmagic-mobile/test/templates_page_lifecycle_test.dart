import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'templates_page_lifecycle_test_support.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() async {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  for (final configuration in const [
    _TemplatesGoldenConfiguration('compact', Size(320, 568)),
    _TemplatesGoldenConfiguration('phone', Size(390, 844)),
    _TemplatesGoldenConfiguration('tablet', Size(834, 1194)),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'discover ${configuration.name} ${brightness.name} visual baseline',
        (tester) async {
          const pathProviderChannel = MethodChannel(
            'plugins.flutter.io/path_provider',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pathProviderChannel,
            (call) async => Directory.systemTemp.path,
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              pathProviderChannel,
              null,
            );
          });
          tester.view.physicalSize = configuration.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appLaunchControllerProvider.overrideWith(
                  AuthenticatedAppLaunchController.new,
                ),
                networkStatusControllerProvider.overrideWith(
                  () => TestTemplatesNetworkStatusController(
                    initialHasInternet: true,
                  ),
                ),
                walletControllerProvider.overrideWith(IdleWalletController.new),
                templatesControllerProvider.overrideWith(
                  FakeTemplatesController.new,
                ),
                realtimeClientProvider.overrideWith(
                  (ref) => const NoopRealtimeClient(),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const RepaintBoundary(
                  key: Key('discover_golden_surface'),
                  child: Scaffold(body: TemplatesPage()),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('discover_golden_surface')),
            matchesGoldenFile(
              'goldens/discover_${configuration.name}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }

  testWidgets('templates page does not reload when tab is hidden and shown', (
    tester,
  ) async {
    final controller = FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: const TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);

    final hostState = tester.state<TemplatesTickerModeHostState>(
      find.byType(TemplatesTickerModeHost),
    );

    hostState.setEnabled(false);
    await tester.pump();
    await tester.pump();

    hostState.setEnabled(true);
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);
    expect(controller.setScreenVisibleCalls, [true, false, true]);
  });

  testWidgets(
    'templates page drops deferred provider work after it is unmounted',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(IdleWalletController.new),
            templatesControllerProvider.overrideWith(
              FakeTemplatesController.new,
            ),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'templates page preserves active filters and visible feed on return',
    (tester) async {
      const activeQuery = TemplatesQuery(
        type: TemplateType.video,
        category: 'Search',
        search: 'magic',
      );
      final controller = FakeTemplatesController(
        query: activeQuery,
        categories: const ['Portrait', 'Search'],
        items: [
          templateFixture(
            'search-video-template-1',
            'Magic video',
            type: TemplateType.video,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(IdleWalletController.new),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: const TemplatesTickerModeHost(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.loadInitialCalls, [false]);
      expect(find.text('Magic video'), findsOneWidget);
      expect(controller.state.query, activeQuery);
      expect(controller.state.itemsQueryKey, activeQuery.cacheKey);
      expect(_searchFieldText(tester), 'magic');

      final hostState = tester.state<TemplatesTickerModeHostState>(
        find.byType(TemplatesTickerModeHost),
      );

      hostState.setEnabled(false);
      await tester.pump();
      await tester.pump();

      hostState.setEnabled(true);
      await tester.pump();
      await tester.pump();

      expect(controller.loadInitialCalls, [false]);
      expect(controller.setScreenVisibleCalls, [true, false, true]);
      expect(controller.state.query, activeQuery);
      expect(controller.state.itemsQueryKey, activeQuery.cacheKey);
      expect(_searchFieldText(tester), 'magic');
      expect(find.text('Magic video'), findsOneWidget);
    },
  );

  testWidgets('templates page reloads empty feed when tab is shown again', (
    tester,
  ) async {
    final controller = FakeTemplatesController(items: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: const TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);

    final hostState = tester.state<TemplatesTickerModeHostState>(
      find.byType(TemplatesTickerModeHost),
    );

    hostState.setEnabled(false);
    await tester.pump();
    await tester.pump();

    hostState.setEnabled(true);
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false, true]);
    expect(controller.setScreenVisibleCalls, [true, false, true]);
  });

  testWidgets('templates page keeps guest browsing UI without auth gate', (
    tester,
  ) async {
    final controller = FakeTemplatesController();
    final walletController = TrackingWalletController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.createMagicTitle), findsOneWidget);
    expect(find.byType(ProtectedAuthGate), findsNothing);
    expect(find.text(text.authSignInRequired), findsNothing);
    expect(walletController.loadCalls, 0);
  });

  testWidgets('templates page preloads wallet only for authenticated users', (
    tester,
  ) async {
    final controller = FakeTemplatesController();
    final walletController = TrackingWalletController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(walletController.loadCalls, 1);
  });

  testWidgets(
    'templates page defers access preload while offline and retries on reconnect',
    (tester) async {
      final controller = FakeTemplatesController();
      final walletController = TrackingWalletController();
      final profileController = TrackingProfileBootstrapController();
      final networkController = TestTemplatesNetworkStatusController(
        initialHasInternet: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
            profileControllerProvider.overrideWith(() => profileController),
            walletControllerProvider.overrideWith(() => walletController),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);
      expect(walletController.syncSnapshotCalls, 0);
      expect(profileController.initializeCalls, 0);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 1);
      expect(profileController.initializeCalls, 1);
    },
  );

  test(
    'templates controller cancels active feed work when network goes offline',
    () async {
      final feedCompleter = Completer<TemplatesFeedPage>();
      final repository = RandomTemplatesRepository(
        feedCompleter: feedCompleter,
      );
      final networkController = TestTemplatesNetworkStatusController(
        initialHasInternet: true,
      );
      final container = ProviderContainer(
        overrides: [
          networkStatusControllerProvider.overrideWith(() => networkController),
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(templatesControllerProvider.notifier);
      unawaited(controller.loadInitial());
      await Future<void>.delayed(Duration.zero);

      final loadingState = container.read(templatesControllerProvider);
      expect(loadingState.isLoading || loadingState.isRefreshing, isTrue);
      expect(repository.cancelPendingFeedRequestCalls, 0);
      expect(repository.cancelPendingMetadataRequestsCalls, 0);

      networkController.setHasInternet(false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(templatesControllerProvider).isLoading, isFalse);
      expect(repository.cancelPendingFeedRequestCalls, 1);
      expect(repository.cancelPendingMetadataRequestsCalls, 1);
      expect(controller.preloadCancellations, 0);

      feedCompleter.complete(
        TemplatesFeedPage(items: const [], hasMore: false),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets(
    'templates page syncs premium snapshot when wallet is fully hydrated',
    (tester) async {
      final controller = FakeTemplatesController();
      final walletController = TrackingWalletController(
        hasWallet: true,
        hasCompletedFullLoad: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);
      expect(walletController.syncSnapshotCalls, 1);
    },
  );

  testWidgets(
    'templates page syncs premium snapshot while hydrated wallet refreshes',
    (tester) async {
      final controller = FakeTemplatesController(
        items: [templateFixture('1', 'Premium access check')],
      );
      final walletController = TrackingWalletController(
        hasWallet: true,
        hasCompletedFullLoad: true,
        isRefreshing: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(walletController.loadCalls, 0);
      expect(walletController.syncSnapshotCalls, 1);
    },
  );

  testWidgets('wallet.isPremium=false keeps premium template locked', (
    tester,
  ) async {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => Directory.systemTemp.path,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      );
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = FakeTemplatesController(
      items: [
        templateFixture(
          'premium-template',
          'Premium portrait',
          isPremium: true,
        ),
      ],
    );
    final walletController = TrackingWalletController(
      hasWallet: true,
      hasCompletedFullLoad: true,
      initialIsPremium: false,
      syncedIsPremium: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          networkStatusControllerProvider.overrideWith(
            () =>
                TestTemplatesNetworkStatusController(initialHasInternet: true),
          ),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(
      tester.widget<TemplateCard>(find.byType(TemplateCard)).hasPremiumAccess,
      isFalse,
    );
    expect(find.text(text.templateUnlockPremiumAction), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/shared_locked.png'),
    );
  });

  testWidgets('wallet.isPremium=true unlocks premium template cards', (
    tester,
  ) async {
    final controller = FakeTemplatesController(
      items: [
        templateFixture(
          'premium-template',
          'Premium portrait',
          isPremium: true,
        ),
      ],
    );
    final walletController = TrackingWalletController(
      hasWallet: true,
      hasCompletedFullLoad: true,
      initialIsPremium: true,
      syncedIsPremium: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(
      tester.widget<TemplateCard>(find.byType(TemplateCard)).hasPremiumAccess,
      isTrue,
    );
    expect(find.text(text.templateUnlockPremiumAction), findsNothing);
    expect(find.text(text.templateTryAction), findsOneWidget);
  });

  testWidgets('profile.isPremium=true unlocks stale wallet premium cards', (
    tester,
  ) async {
    final controller = FakeTemplatesController(
      items: [
        templateFixture(
          'premium-template',
          'Premium portrait',
          isPremium: true,
        ),
      ],
    );
    final walletController = TrackingWalletController(
      hasWallet: true,
      hasCompletedFullLoad: true,
      initialIsPremium: false,
      syncedIsPremium: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          profileControllerProvider.overrideWith(
            () => FakeProfileController(isPremium: true),
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(
      tester.widget<TemplateCard>(find.byType(TemplateCard)).hasPremiumAccess,
      isTrue,
    );
    expect(find.text(text.templateUnlockPremiumAction), findsNothing);
    expect(find.text(text.templateTryAction), findsOneWidget);
  });

  testWidgets('templates page updates premium cards after wallet sync', (
    tester,
  ) async {
    final syncCompleter = Completer<void>();
    final controller = FakeTemplatesController(
      items: [
        templateFixture(
          'premium-template',
          'Premium portrait',
          isPremium: true,
        ),
      ],
    );
    final walletController = TrackingWalletController(
      hasWallet: true,
      hasCompletedFullLoad: true,
      initialIsPremium: false,
      syncedIsPremium: true,
      syncCompleter: syncCompleter,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(walletController.syncSnapshotCalls, 1);
    expect(
      tester.widget<TemplateCard>(find.byType(TemplateCard)).hasPremiumAccess,
      isFalse,
    );
    expect(find.text(text.templateUnlockPremiumAction), findsOneWidget);

    syncCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TemplateCard>(find.byType(TemplateCard)).hasPremiumAccess,
      isTrue,
    );
    expect(find.text(text.templateUnlockPremiumAction), findsNothing);
    expect(find.text(text.templateTryAction), findsOneWidget);
  });

  testWidgets('templates page preloads wallet for partial wallet snapshot', (
    tester,
  ) async {
    final controller = FakeTemplatesController();
    final walletController = TrackingWalletController(hasWallet: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(() => walletController),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(walletController.loadCalls, 1);
  });

  testWidgets('templates page debounces backend search input', (tester) async {
    final controller = FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'c');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 359));

    expect(controller.setSearchValues, isEmpty);

    await tester.pump(const Duration(milliseconds: 2));

    expect(controller.setSearchValues, ['cat']);
  });

  testWidgets('templates page cancels pending search debounce when hidden', (
    tester,
  ) async {
    final controller = FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 120));

    final hostState = tester.state<TemplatesTickerModeHostState>(
      find.byType(TemplatesTickerModeHost),
    );
    hostState.setEnabled(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.setScreenVisibleCalls, [true, false]);
    expect(controller.setSearchValues, isEmpty);
  });

  testWidgets('templates page keeps 1000 item feed lazy during fast scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = FakeTemplatesController(
      items: List<TemplateItem>.generate(
        1005,
        (index) => templateFixture(
          'template-$index',
          'Template ${index.toString().padLeft(4, '0')}',
        ),
      ),
      hasMore: true,
      nextCursor: 'cursor-2',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final topCardCount = find.byType(TemplateCard).evaluate().length;
    expect(topCardCount, greaterThan(0));
    expect(topCardCount, lessThan(40));

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 14; i++) {
      await tester.fling(scrollable, const Offset(0, -1400), 9000);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));

    final scrolledCardCount = find.byType(TemplateCard).evaluate().length;
    expect(scrolledCardCount, greaterThan(0));
    expect(scrolledCardCount, lessThan(60));

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollableState.position.jumpTo(
      scrollableState.position.maxScrollExtent - 500,
    );
    await tester.pump();

    expect(controller.loadMoreCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('templates page shows template of the day as first grid card', (
    tester,
  ) async {
    final featured = TemplateOfTheDayItem(
      templateId: 'template-2',
      title: 'Daily portrait',
      subtitle: 'Today magic idea',
      badgeText: 'Template of the Day',
      templateType: TemplateType.image,
      isPremium: false,
      requiredPlan: 'free',
      date: DateTime.utc(2026, 6, 14),
      source: 'manual',
      category: 'Portrait',
      tags: const ['daily', 'portrait'],
      tokenCost: 5,
    );
    final controller = FakeTemplatesController(
      items: [
        templateFixture('template-1', 'Template 1'),
        templateFixture('template-2', 'Daily portrait'),
      ],
      templateOfTheDay: featured,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    final visibleCards = tester
        .widgetList<TemplateCard>(find.byType(TemplateCard))
        .toList();

    expect(visibleCards, isNotEmpty);
    expect(visibleCards.first.template.templateId, 'template-2');
    expect(visibleCards.first.template.tokenCost, 5);
    expect(visibleCards.first.featuredData, isNotNull);
    expect(find.text(text.templateOfTheDayTitle), findsNothing);
    expect(find.text('Daily portrait'), findsOneWidget);
    expect(find.textContaining('#daily'), findsOneWidget);
    expect(find.text(text.templateOfTheDayTryAction), findsOneWidget);
    expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
  });

  testWidgets(
    'template feed promotes template of the day and removes duplicate',
    (tester) async {
      final featured = TemplateOfTheDayItem(
        templateId: 'template-2',
        title: 'Daily portrait',
        subtitle: 'Today magic idea',
        badgeText: 'Template of the Day',
        templateType: TemplateType.image,
        isPremium: false,
        requiredPlan: 'free',
        date: DateTime.utc(2026, 6, 14),
        source: 'manual',
      );
      final controller = FakeTemplatesController(
        items: [
          templateFixture('template-1', 'Template 1'),
          templateFixture('template-2', 'Daily portrait'),
          templateFixture('template-3', 'Template 3'),
        ],
        templateOfTheDay: featured,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(IdleWalletController.new),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(TemplatesPage));
      final text = AppLocalizations.of(context);
      final visibleCardIds = tester
          .widgetList<TemplateCard>(find.byType(TemplateCard))
          .map((card) => card.template.templateId)
          .toList();

      expect(visibleCardIds.length, greaterThanOrEqualTo(2));
      expect(visibleCardIds.take(2).toList(), ['template-2', 'template-1']);
      expect(visibleCardIds.where((id) => id == 'template-2'), hasLength(1));
      expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
    },
  );

  testWidgets('template of the day load failure keeps regular grid visible', (
    tester,
  ) async {
    final controller = FakeTemplatesController(
      items: [templateFixture('template-1', 'Template 1')],
      templateOfTheDayError: 'templates.template_of_the_day_load_failed',
      isTemplateOfTheDayLoading: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(find.text('Could not load Template of the Day'), findsNothing);
    expect(find.text('Template 1'), findsOneWidget);
    expect(find.text(text.retryAction), findsNothing);
    expect(controller.loadInitialCalls, isNot(contains(true)));
  });

  testWidgets(
    'template of the day featured card renders on narrow dark premium video layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final featured = TemplateOfTheDayItem(
        templateId: 'template-premium-video',
        title: 'Cinematic pet runway transformation',
        subtitle: 'A compact dark mode recommendation for today',
        badgeText: 'Template of the Day',
        templateType: TemplateType.video,
        isPremium: true,
        requiredPlan: 'premium',
        date: DateTime.utc(2026, 6, 14),
        source: 'auto',
      );
      final controller = FakeTemplatesController(
        items: [
          templateFixture(
            'template-premium-video',
            'Cinematic pet runway transformation',
            type: TemplateType.video,
          ),
        ],
        templateOfTheDay: featured,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(IdleWalletController.new),
            templatesControllerProvider.overrideWith(() => controller),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(TemplatesPage));
      final text = AppLocalizations.of(context);
      final firstCard = tester.widget<TemplateCard>(
        find.byType(TemplateCard).first,
      );

      expect(tester.takeException(), isNull);
      expect(firstCard.template.templateId, 'template-premium-video');
      expect(firstCard.featuredData, isNotNull);
      expect(firstCard.template.isPremium, isTrue);
      expect(find.text(text.templateOfTheDayTitle), findsNothing);
      expect(find.text(text.templateUnlockPremiumAction), findsOneWidget);
      expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
    },
  );
}

class _TemplatesGoldenConfiguration {
  const _TemplatesGoldenConfiguration(this.name, this.size);

  final String name;
  final Size size;
}

String _searchFieldText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('templates-search-field')),
  );
  return field.controller?.text ?? '';
}
