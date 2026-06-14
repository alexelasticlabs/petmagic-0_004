import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() async {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('templates page does not reload when tab is hidden and shown', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: const _TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controller.loadInitialCalls, [false]);

    final hostState = tester.state<_TemplatesTickerModeHostState>(
      find.byType(_TemplatesTickerModeHost),
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

  testWidgets('templates page keeps guest browsing UI without auth gate', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
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
  });

  testWidgets('templates page shows template of the day hero and feed badge', (
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
    );
    final controller = _FakeTemplatesController(
      items: [
        _template('template-1', 'Template 1'),
        _template('template-2', 'Daily portrait'),
      ],
      templateOfTheDay: featured,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
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

    expect(find.text(text.templateOfTheDayTitle), findsOneWidget);
    expect(find.text('Daily portrait'), findsWidgets);
    expect(find.text(text.templateOfTheDayTryAction), findsOneWidget);
    expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
  });

  testWidgets(
    'template of the day hero renders on narrow dark premium video layout',
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
      final controller = _FakeTemplatesController(
        items: [
          _template(
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
              _AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(_IdleWalletController.new),
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

      expect(tester.takeException(), isNull);
      expect(find.text(text.templateOfTheDayTitle), findsOneWidget);
      expect(find.text(text.videoLabel), findsWidgets);
      expect(find.text(text.premiumLabel), findsWidgets);
      expect(find.text(text.templateUnlockPremiumAction), findsOneWidget);
      expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
    },
  );

  test(
    'template of the day pet flow uses canonical generation analytics event',
    () {
      final source = File(
        'lib/features/templates/presentation/templates_page.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('generation_started_from_pet')));
      expect(source, contains("'generation_started'"));
      expect(source, contains('generationId: generation.generationId'));
    },
  );

  testWidgets('templates page opens random template mode sheet', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
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

    expect(find.text(text.randomTemplateAction), findsOneWidget);

    await tester.tap(find.text(text.randomTemplateAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.randomTemplateAny), findsOneWidget);
    expect(find.text(text.randomTemplateImage), findsOneWidget);
    expect(find.text(text.randomTemplateVideo), findsOneWidget);
  });

  testWidgets('random template action is disabled during initial loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(
            () => _LoadingTemplatesController(),
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

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(text.randomTemplateAction),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('random template empty result shows localized notification', (
    tester,
  ) async {
    await PetMagicNotificationCenter.instance.clearQueue();
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(
            _RandomTemplatesRepository(items: []),
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
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await tester.tap(find.text(text.randomTemplateAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text.randomTemplateImage));
    await tester.pump();

    expect(
      PetMagicNotificationCenter.instance.current?.message,
      text.randomTemplateNoImageTemplates,
    );

    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets(
    'random template uses full synced catalog instead of visible list',
    (tester) async {
      final repository = _RandomTemplatesRepository(
        items: [
          _template(
            'catalog-image',
            'Catalog image',
            thumbnailUrl: 'https://cdn.petmagic.test/catalog-image.jpg',
          ),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: TemplatesPage()),
          ),
          GoRoute(
            path: TemplatePreviewPage.routePath,
            builder: (context, state) {
              final args = state.extra! as TemplatePreviewRouteArgs;
              return Scaffold(body: Text('opened:${args.template.templateId}'));
            },
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
            walletControllerProvider.overrideWith(_IdleWalletController.new),
            templatesControllerProvider.overrideWith(
              () => _FakeTemplatesController(
                items: [
                  _template(
                    'visible-video',
                    'Visible video',
                    type: TemplateType.video,
                    thumbnailUrl: 'https://cdn.petmagic.test/visible-video.jpg',
                  ),
                ],
              ),
            ),
            templatesRepositoryProvider.overrideWithValue(repository),
            realtimeClientProvider.overrideWith(
              (ref) => const NoopRealtimeClient(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(TemplatesPage));
      final text = AppLocalizations.of(context);

      await tester.tap(find.text(text.randomTemplateAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(text.randomTemplateImage));
      await tester.pumpAndSettle();

      expect(repository.readSyncedCatalogItemsCalls, 1);
      expect(find.text('opened:catalog-image'), findsOneWidget);
    },
  );

  testWidgets('random template load failure shows localized notification', (
    tester,
  ) async {
    await PetMagicNotificationCenter.instance.clearQueue();
    final controller = _FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(
            _RandomTemplatesRepository(throwOnRead: true),
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
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await tester.tap(find.text(text.randomTemplateAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text.randomTemplateAny));
    await tester.pump();

    expect(
      PetMagicNotificationCenter.instance.current?.message,
      text.randomTemplateLoadFailed,
    );

    await PetMagicNotificationCenter.instance.clearQueue();
  });
}

class _TemplatesTickerModeHost extends StatefulWidget {
  const _TemplatesTickerModeHost();

  @override
  State<_TemplatesTickerModeHost> createState() =>
      _TemplatesTickerModeHostState();
}

class _TemplatesTickerModeHostState extends State<_TemplatesTickerModeHost> {
  bool _enabled = true;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _enabled,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TemplatesPage()),
      ),
    );
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

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _LoadingTemplatesController extends TemplatesController {
  @override
  TemplatesState build() {
    return const TemplatesState(isLoading: true);
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {}

  @override
  void setScreenVisible(bool visible) {}
}

class _FakeTemplatesController extends TemplatesController {
  _FakeTemplatesController({this.items, this.templateOfTheDay});

  final List<TemplateItem>? items;
  final TemplateOfTheDayItem? templateOfTheDay;
  final List<bool> loadInitialCalls = <bool>[];
  final List<bool> setScreenVisibleCalls = <bool>[];

  @override
  TemplatesState build() {
    return const TemplatesState();
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    loadInitialCalls.add(forceRefresh);
    state = TemplatesState(
      items: items ?? [_template('template-1', 'Template 1')],
      templateOfTheDay: templateOfTheDay,
      isLoading: false,
      isRefreshing: false,
    );
  }

  @override
  void setScreenVisible(bool visible) {
    setScreenVisibleCalls.add(visible);
    super.setScreenVisible(visible);
  }
}

TemplateItem _template(
  String id,
  String title, {
  TemplateType type = TemplateType.image,
  String? thumbnailUrl,
}) {
  return TemplateItem(
    templateId: id,
    templateType: type,
    title: title,
    shortDescription: title,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
    thumbnailUrl: thumbnailUrl,
  );
}

class _RandomTemplatesRepository implements TemplatesRepository {
  _RandomTemplatesRepository({this.items = const [], this.throwOnRead = false});

  final List<TemplateItem> items;
  final bool throwOnRead;
  int readSyncedCatalogItemsCalls = 0;

  @override
  Future<List<String>> fetchCategories() async => const ['Portrait'];

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: 1,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> fetchCatalogVersion() async => 1;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return TemplatesFeedPage(items: items, hasMore: false);
  }

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return TemplatesFeedPage(items: items, hasMore: false);
  }

  @override
  Future<int> readLocalCatalogVersion() async => 1;

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    readSyncedCatalogItemsCalls++;
    if (throwOnRead) {
      throw StateError('catalog unavailable');
    }

    return items;
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async => null;

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {}

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    return knownRemoteVersion ?? 1;
  }
}
