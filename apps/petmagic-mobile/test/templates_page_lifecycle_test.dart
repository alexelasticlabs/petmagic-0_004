import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  testWidgets(
    'templates page preserves active filters and visible feed on return',
    (tester) async {
      const activeQuery = TemplatesQuery(
        type: TemplateType.video,
        category: 'Search',
        search: 'magic',
      );
      final controller = _FakeTemplatesController(
        query: activeQuery,
        categories: const ['Portrait', 'Search'],
        items: [
          _template(
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
      expect(find.text('Magic video'), findsOneWidget);
      expect(controller.state.query, activeQuery);
      expect(controller.state.itemsQueryKey, activeQuery.cacheKey);
      expect(_searchFieldText(tester), 'magic');

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
      expect(controller.state.query, activeQuery);
      expect(controller.state.itemsQueryKey, activeQuery.cacheKey);
      expect(_searchFieldText(tester), 'magic');
      expect(find.text('Magic video'), findsOneWidget);
    },
  );

  testWidgets('templates page reloads empty feed when tab is shown again', (
    tester,
  ) async {
    final controller = _FakeTemplatesController(items: const []);

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

    expect(controller.loadInitialCalls, [false, true]);
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

  testWidgets('templates page debounces backend search input', (tester) async {
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
        child: _TemplatesTickerModeHost(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 120));

    final hostState = tester.state<_TemplatesTickerModeHostState>(
      find.byType(_TemplatesTickerModeHost),
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

    final controller = _FakeTemplatesController(
      items: List<TemplateItem>.generate(
        1005,
        (index) => _template(
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
      category: 'Portrait',
      tags: const ['daily', 'portrait'],
      tokenCost: 5,
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
    expect(find.text('#daily'), findsOneWidget);
    expect(find.text('5 PawSpark'), findsOneWidget);
    expect(find.text(text.templateOfTheDayTryAction), findsOneWidget);
    expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
  });

  testWidgets('template feed preserves backend order with daily badge', (
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
        _template('template-3', 'Template 3'),
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
    final visibleCardIds = tester
        .widgetList<TemplateCard>(find.byType(TemplateCard))
        .map((card) => card.template.templateId)
        .toList();

    expect(visibleCardIds.length, greaterThanOrEqualTo(2));
    expect(visibleCardIds.take(2).toList(), ['template-1', 'template-2']);
    expect(find.text(text.templateOfTheDayFeedBadge), findsOneWidget);
  });

  testWidgets('template of the day error state stays compact and retries', (
    tester,
  ) async {
    final controller = _FakeTemplatesController(
      items: [_template('template-1', 'Template 1')],
      templateOfTheDayError: 'templates.template_of_the_day_load_failed',
      isTemplateOfTheDayLoading: false,
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

    expect(find.text('Could not load Template of the Day'), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);

    await tester.tap(find.text(text.retryAction));
    await tester.pump();

    expect(controller.loadInitialCalls, contains(true));
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

  testWidgets('templates page opens compact random settings sheet', (
    tester,
  ) async {
    final controller = _FakeTemplatesController();
    final randomCompleter = Completer<TemplateItem?>();
    final repository = _RandomTemplatesRepository(
      randomTemplateCompleter: randomCompleter,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(repository),
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

    expect(find.text(text.randomTemplateAction), findsNothing);
    expect(_randomTemplateActionFinder(), findsOneWidget);

    await _tapRandomTemplateAction(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.randomTemplateAction), findsOneWidget);
    expect(find.text(text.randomTemplateSheetDescription), findsOneWidget);
    expect(repository.fetchRandomTemplateCalls, 0);
    expect(find.text(text.randomTemplateAny), findsNothing);
    expect(find.text(text.randomTemplateImage), findsNothing);
    expect(find.text(text.randomTemplateVideo), findsNothing);
    expect(PetMagicNotificationCenter.instance.current, isNull);
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

    expect(_randomTemplateActionFinder(), findsOneWidget);

    await _tapRandomTemplateAction(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);
    expect(find.text(text.randomTemplateAction), findsNothing);
  });

  testWidgets('random template empty result shows sheet empty state', (
    tester,
  ) async {
    await PetMagicNotificationCenter.instance.clearQueue();
    final controller = _FakeTemplatesController();
    final repository = _RandomTemplatesRepository(items: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(repository),
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

    await _tapRandomTemplateAction(tester);
    await tester.pump();
    await _tapFindRandomTemplateAction(tester, text);
    await tester.pump();

    expect(repository.fetchRandomTemplateCalls, 1);
    expect(repository.lastRandomMode, TemplateRandomMode.any);
    expect(find.text(text.randomTemplateNoMatches), findsOneWidget);
    expect(find.text(text.randomTemplateNoMatchesHint), findsOneWidget);
    expect(find.text(text.randomTemplateResetFilters), findsOneWidget);
    expect(PetMagicNotificationCenter.instance.current, isNull);

    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets(
    'random template uses backend selection instead of visible list',
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
                query: const TemplatesQuery(
                  type: TemplateType.image,
                  category: 'Portrait',
                ),
                categories: const ['Portrait'],
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

      await _tapRandomTemplateAction(tester);
      await tester.pump();
      await _tapSheetText(tester, text.randomTemplateAccessPremium);
      await _tapFindRandomTemplateAction(tester, text);
      await tester.pumpAndSettle();

      expect(repository.fetchRandomTemplateCalls, 1);
      expect(repository.lastRandomMode, TemplateRandomMode.image);
      expect(repository.lastRandomCategory, 'Portrait');
      expect(repository.lastIncludePremium, false);
      expect(repository.lastRandomAccess, TemplateRandomAccess.premium);
      expect(find.text('opened:catalog-image'), findsOneWidget);
      expect(repository.cancelPendingRandomTemplateRequestCalls, 0);
    },
  );

  testWidgets('random template result is ignored after templates tab hides', (
    tester,
  ) async {
    final randomCompleter = Completer<TemplateItem?>();
    final repository = _RandomTemplatesRepository(
      randomTemplateCompleter: randomCompleter,
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
              query: const TemplatesQuery(type: TemplateType.video),
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
        child: _TemplatesTickerModeHost(
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
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await _tapRandomTemplateAction(tester);
    await tester.pump();
    await _tapFindRandomTemplateAction(tester, text);

    expect(repository.fetchRandomTemplateCalls, 1);
    expect(repository.lastRandomMode, TemplateRandomMode.video);

    final hostState = tester.state<_TemplatesTickerModeHostState>(
      find.byType(_TemplatesTickerModeHost),
    );
    hostState.setEnabled(false);
    await tester.pump();

    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);

    randomCompleter.complete(
      _template(
        'hidden-random-image',
        'Hidden random image',
        thumbnailUrl: 'https://cdn.petmagic.test/hidden-random.jpg',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('opened:hidden-random-image'), findsNothing);
    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);
  });

  testWidgets('random template request is cancelled safely on dispose', (
    tester,
  ) async {
    final randomCompleter = Completer<TemplateItem?>();
    final repository = _RandomTemplatesRepository(
      randomTemplateCompleter: randomCompleter,
    );

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
                  'visible-image',
                  'Visible image',
                  thumbnailUrl: 'https://cdn.petmagic.test/visible-image.jpg',
                ),
              ],
            ),
          ),
          templatesRepositoryProvider.overrideWithValue(repository),
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

    await _tapRandomTemplateAction(tester);
    await tester.pump();
    await _tapFindRandomTemplateAction(tester, text);

    expect(repository.fetchRandomTemplateCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);

    randomCompleter.complete(
      _template(
        'disposed-random-image',
        'Disposed random image',
        thumbnailUrl: 'https://cdn.petmagic.test/disposed-random.jpg',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('template selection loads detail payload before preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _RandomTemplatesRepository(
      templateDetailsById: {
        'feed-template': _template('feed-template', 'Detail payload'),
      },
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
            return Scaffold(body: Text('opened:${args.template.title}'));
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
              items: [_template('feed-template', 'Feed payload')],
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

    final feedTemplate = find.text('Feed payload').first;
    await tester.ensureVisible(feedTemplate);
    await tester.pump();
    await tester.tap(feedTemplate);
    await tester.pumpAndSettle();

    expect(repository.fetchTemplateCalls, 1);
    expect(find.text('opened:Detail payload'), findsOneWidget);
  });

  testWidgets('pet route starts generation with selected pet photo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousPreferencesPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferencesPlatform;
    });
    const petId = 'pet/42 #x?kind=dog&name=Bella';
    const petPhotoId = 'photo/7 #main?pose=1&tag=a';
    final generationRepository = _PetFlowGenerationRepository();
    final router = GoRouter(
      initialLocation: Uri(
        path: TemplatesPage.routePath,
        queryParameters: {'petId': petId, 'petPhotoId': petPhotoId},
      ).toString(),
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => const Scaffold(body: TemplatesPage()),
        ),
        GoRoute(
          path: TemplatePreviewPage.routePath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop<TemplateDetailAction>(
                  TemplateDetailAction.upload,
                ),
                child: const Text('Upload'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '${GenerationStatusPage.routePrefix}/:generationId',
          builder: (context, state) {
            return Scaffold(
              body: Text(
                'status:${state.pathParameters['generationId'] ?? ''}',
              ),
            );
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
          walletControllerProvider.overrideWith(_FundedWalletController.new),
          templatesControllerProvider.overrideWith(
            () => _FakeTemplatesController(
              items: [_template('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
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

    final petTemplate = find.text('Pet portrait').first;
    await tester.ensureVisible(petTemplate);
    await tester.pump();
    await tester.tap(petTemplate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.startFromPetCalls, 1);
    expect(generationRepository.lastPetId, petId);
    expect(generationRepository.lastPetPhotoId, petPhotoId);
    expect(generationRepository.lastTemplateId, 'template-pet');
    expect(generationRepository.rememberedGenerationIds, ['generation-pet-1']);
    expect(find.text('status:generation-pet-1'), findsOneWidget);
  });

  testWidgets('selected pet shortcut preserves selected pet photo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousPreferencesPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferencesPlatform;
    });
    final generationRepository = _CrossGalleryPetFlowRepository();
    final router = GoRouter(
      initialLocation: '/templates?petId=pet-42&petPhotoId=photo-7',
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => const Scaffold(body: TemplatesPage()),
        ),
        GoRoute(
          path: TemplatePreviewPage.routePath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop<TemplateDetailAction>(
                  TemplateDetailAction.upload,
                ),
                child: const Text('Upload'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '${GenerationStatusPage.routePrefix}/:generationId',
          builder: (context, state) {
            return Scaffold(
              body: Text(
                'status:${state.pathParameters['generationId'] ?? ''}',
              ),
            );
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
          walletControllerProvider.overrideWith(_FundedWalletController.new),
          templatesControllerProvider.overrideWith(
            () => _FakeTemplatesController(
              items: [_template('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Bella').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final petTemplate = find.text('Pet portrait').first;
    await tester.ensureVisible(petTemplate);
    await tester.tap(petTemplate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.lastPetId, 'pet-42');
    expect(generationRepository.lastPetPhotoId, 'photo-7');
    expect(generationRepository.lastTemplateId, 'template-pet');
    expect(find.text('status:generation-pet-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet photo generation appears in Creations after status route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousPreferencesPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() {
      SharedPreferencesAsyncPlatform.instance = previousPreferencesPlatform;
    });

    final generationRepository = _CrossGalleryPetFlowRepository();
    final historyController = _PetFlowHistoryController(generationRepository);
    final router = GoRouter(
      initialLocation: MyPetsPage.routePath,
      routes: [
        GoRoute(
          path: MyPetsPage.routePath,
          builder: (context, state) => const Scaffold(body: MyPetsPage()),
        ),
        GoRoute(
          path: PetDetailsPage.routePath,
          builder: (context, state) =>
              PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
        ),
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => const Scaffold(body: TemplatesPage()),
        ),
        GoRoute(
          path: TemplatePreviewPage.routePath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop<TemplateDetailAction>(
                  TemplateDetailAction.upload,
                ),
                child: const Text('Upload'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '${GenerationStatusPage.routePrefix}/:generationId',
          builder: (context, state) {
            return Scaffold(
              body: Text(
                'status:${state.pathParameters['generationId'] ?? ''}',
              ),
            );
          },
        ),
        GoRoute(
          path: GenerationsGalleryPage.routePath,
          builder: (context, state) => const GenerationsGalleryPage(),
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
          walletControllerProvider.overrideWith(_FundedWalletController.new),
          templatesControllerProvider.overrideWith(
            () => _FakeTemplatesController(
              items: [_template('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          generationHistoryControllerProvider.overrideWith(
            () => historyController,
          ),
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
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Bella').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byTooltip('Use for generation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final petTemplate = find.text('Pet portrait').first;
    await tester.ensureVisible(petTemplate);
    await tester.tap(petTemplate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.lastPetId, 'pet-42');
    expect(generationRepository.lastPetPhotoId, 'photo-7');
    expect(generationRepository.createdCreations.single.outputUrl, isNotNull);
    expect(find.text('status:generation-pet-1'), findsOneWidget);

    router.go(GenerationsGalleryPage.routePath);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(historyController.loadCalls, greaterThan(0));
    expect(find.byType(GenerationsGalleryPage), findsOneWidget);
    expect(find.text('Pet portrait'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open status'), findsOneWidget);
  });

  testWidgets('random template load failure shows sheet error state', (
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
            _RandomTemplatesRepository(throwOnRandom: true),
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

    await _tapRandomTemplateAction(tester);
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await _tapFindRandomTemplateAction(tester, text);
    await tester.pump();

    expect(find.text(text.randomTemplateLoadFailed), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(PetMagicNotificationCenter.instance.current, isNull);

    await PetMagicNotificationCenter.instance.clearQueue();
  });
}

String _searchFieldText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('templates-search-field')),
  );
  return field.controller?.text ?? '';
}

Finder _randomTemplateActionFinder() {
  return find.byKey(const ValueKey('templates-random-floating-button'));
}

Future<void> _tapRandomTemplateAction(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pump();
  await tester.tap(_randomTemplateActionFinder());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapFindRandomTemplateAction(
  WidgetTester tester,
  AppLocalizations text,
) async {
  final button = find.widgetWithText(
    FilledButton,
    text.randomTemplateFindAction,
  );
  await tester.tap(button);
  await tester.pump();
}

Future<void> _tapSheetText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

class _TemplatesTickerModeHost extends StatefulWidget {
  const _TemplatesTickerModeHost({this.child});

  final Widget? child;

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
      child:
          widget.child ??
          MaterialApp(
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

class _FundedWalletController extends WalletController {
  int loadCalls = 0;

  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 50,
        adRewardsRemainingToday: 0,
        isPremium: false,
        updatedAtUtc: DateTime.utc(2035),
      ),
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }
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
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}
}

class _FakeTemplatesController extends TemplatesController {
  _FakeTemplatesController({
    this.items,
    this.templateOfTheDay,
    this.templateOfTheDayError,
    this.isTemplateOfTheDayLoading = false,
    this.query = const TemplatesQuery(),
    this.categories = const [],
    this.hasMore = false,
    this.nextCursor,
  });

  final List<TemplateItem>? items;
  final TemplateOfTheDayItem? templateOfTheDay;
  final String? templateOfTheDayError;
  final bool isTemplateOfTheDayLoading;
  final TemplatesQuery query;
  final List<String> categories;
  final bool hasMore;
  final String? nextCursor;
  final List<bool> loadInitialCalls = <bool>[];
  final List<bool> setScreenVisibleCalls = <bool>[];
  final List<String> setSearchValues = <String>[];
  int loadMoreCalls = 0;

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
      query: query,
      items: items ?? [_template('template-1', 'Template 1')],
      itemsQueryKey: query.cacheKey,
      categories: categories,
      templateOfTheDay: templateOfTheDay,
      isTemplateOfTheDayLoading: isTemplateOfTheDayLoading,
      templateOfTheDayError: templateOfTheDayError,
      isLoading: false,
      isRefreshing: false,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  void setSearch(String value) {
    setSearchValues.add(value);
  }

  @override
  void setScreenVisible(bool visible) {
    setScreenVisibleCalls.add(visible);
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
  _RandomTemplatesRepository({
    this.items = const [],
    this.templateDetailsById = const {},
    this.throwOnRandom = false,
    this.randomTemplateCompleter,
  });

  final List<TemplateItem> items;
  final Map<String, TemplateItem> templateDetailsById;
  final bool throwOnRandom;
  final Completer<TemplateItem?>? randomTemplateCompleter;
  int readSyncedCatalogItemsCalls = 0;
  int fetchRandomTemplateCalls = 0;
  int cancelPendingRandomTemplateRequestCalls = 0;
  int fetchTemplateCalls = 0;
  TemplateRandomMode? lastRandomMode;
  String? lastRandomCategory;
  bool? lastIncludePremium;
  TemplateRandomAccess? lastRandomAccess;

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
  void cancelPendingFeedRequest() {}

  @override
  void cancelPendingRandomTemplateRequest() {
    cancelPendingRandomTemplateRequestCalls++;
  }

  @override
  void cancelPendingMetadataRequests() {}

  @override
  Future<TemplateItem> fetchTemplate(String templateId) async {
    fetchTemplateCalls++;
    final detail = templateDetailsById[templateId];
    if (detail != null) {
      return detail;
    }

    return items.firstWhere((item) => item.templateId == templateId);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    fetchRandomTemplateCalls++;
    lastRandomMode = mode;
    lastRandomCategory = category;
    lastIncludePremium = includePremium;
    lastRandomAccess = access;
    if (throwOnRandom) {
      throw StateError('random template unavailable');
    }

    final delayedResult = randomTemplateCompleter;
    if (delayedResult != null) {
      return delayedResult.future;
    }

    return items.isEmpty ? null : items.first;
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

class _PetFlowGenerationRepository extends TemplateGenerationRepository {
  _PetFlowGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  int startFromPetCalls = 0;
  String? lastPetId;
  String? lastPetPhotoId;
  String? lastTemplateId;
  final rememberedGenerationIds = <String>[];

  @override
  Future<({String? correlationId, String generationId})?>
  readActiveGeneration() async {
    return null;
  }

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    return const [];
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    startFromPetCalls++;
    lastPetId = petId;
    lastPetPhotoId = petPhotoId;
    lastTemplateId = templateId;
    final now = DateTime.utc(2035);
    return TemplateGenerationResult(
      generationId: 'generation-pet-1',
      userId: 'user-1',
      templateId: templateId,
      status: TemplateGenerationStatus.queued,
      tokenCost: 1,
      attemptCount: 1,
      createdAtUtc: now,
      updatedAtUtc: now,
      userMediaExpired: false,
      templateTitle: 'Pet portrait',
      templateType: 'image',
      petId: petId,
      petPhotoId: petPhotoId,
    );
  }

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    rememberedGenerationIds.add(generationId);
  }
}

class _CrossGalleryPetFlowRepository extends _PetFlowGenerationRepository {
  final createdCreations = <TemplateGenerationResult>[];

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    return [
      PetProfile(
        id: 'pet-42',
        name: 'Bella',
        type: 'dog',
        breed: 'Corgi',
        avatarUrl: 'https://cdn.petmagic.test/bella-avatar.jpg',
        photosCount: 1,
        generationsCount: createdCreations.length,
        createdAtUtc: DateTime.utc(2035),
        updatedAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return [
      PetPhoto(
        id: 'photo-7',
        petId: petId,
        mediaAssetId: 'pet-photo-asset-7',
        url: 'https://cdn.petmagic.test/bella-original.jpg',
        thumbnailUrl: 'https://cdn.petmagic.test/bella-thumb.jpg',
        fileName: 'bella.jpg',
        contentType: 'image/jpeg',
        isFavorite: true,
        isAvatar: true,
        sortOrder: 1,
        createdAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final generation = await super.startGenerationFromPet(
      petId: petId,
      petPhotoId: petPhotoId,
      templateId: templateId,
      correlationId: correlationId,
      cancelToken: cancelToken,
    );
    final completedAtUtc = DateTime.utc(2035, 1, 1, 12, 1);
    createdCreations
      ..clear()
      ..add(
        generation.copyWith(
          status: TemplateGenerationStatus.completed,
          outputUrl: 'https://cdn.petmagic.test/generated-bella.jpg',
          resultPreviewUrl:
              'https://cdn.petmagic.test/generated-bella-thumb.jpg',
          completedAtUtc: completedAtUtc,
          updatedAtUtc: completedAtUtc,
          isUnread: true,
        ),
      );
    return generation;
  }
}

class _PetFlowHistoryController extends GenerationHistoryController {
  _PetFlowHistoryController(this.repository);

  final _CrossGalleryPetFlowRepository repository;
  int loadCalls = 0;

  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    loadCalls++;
    final nextFilter = filter ?? state.filter;
    final items = _filter(repository.createdCreations, nextFilter);
    state = GenerationHistoryState(
      items: items,
      filter: nextFilter,
      unreadCount: items.where((item) => item.isUnread).length,
      lastSyncedAtUtc: DateTime.utc(2035, 1, 1, 12, 1),
    );
  }

  @override
  Future<void> markRead(String generationId) async {
    final updated = [
      for (final item in state.items)
        item.generationId == generationId
            ? item.copyWith(isUnread: false)
            : item,
    ];
    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
    );
  }

  List<TemplateGenerationResult> _filter(
    List<TemplateGenerationResult> items,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => List<TemplateGenerationResult>.from(items),
      GenerationHistoryFilter.active =>
        items.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        items.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        items.where((item) => item.isFailed).toList(growable: false),
    };
  }
}
