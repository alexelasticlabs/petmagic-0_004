import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'templates_page_lifecycle_test_support.dart';

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

  testWidgets('templates page opens full-screen random settings sheet', (
    tester,
  ) async {
    final controller = FakeTemplatesController();
    final randomCompleter = Completer<TemplateItem?>();
    final repository = RandomTemplatesRepository(
      randomTemplateCompleter: randomCompleter,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: buildTemplatesPageApp(child: const TemplatesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.randomTemplateAction), findsNothing);
    expect(randomTemplateActionFinder(), findsOneWidget);

    await tapRandomTemplateAction(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(text.randomTemplateAction), findsOneWidget);
    expect(find.text(text.randomTemplateSheetDescription), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BottomSheet).last).dy,
      0,
      reason: 'Random template settings must begin at the top edge.',
    );
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(
            () => LoadingTemplatesController(),
          ),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: buildTemplatesPageApp(child: const TemplatesPage()),
      ),
    );
    await tester.pump();

    expect(randomTemplateActionFinder(), findsOneWidget);

    await tapRandomTemplateAction(tester);
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
    final controller = FakeTemplatesController();
    final repository = RandomTemplatesRepository(items: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(repository),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: buildTemplatesPageApp(child: const TemplatesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await tapRandomTemplateAction(tester);
    await tester.pump();
    await tapFindRandomTemplateAction(tester, text);
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
      final repository = RandomTemplatesRepository(
        items: [
          templateFixture(
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
              AuthenticatedAppLaunchController.new,
            ),
            walletControllerProvider.overrideWith(IdleWalletController.new),
            templatesControllerProvider.overrideWith(
              () => FakeTemplatesController(
                query: const TemplatesQuery(
                  type: TemplateType.image,
                  category: 'Portrait',
                ),
                categories: const ['Portrait'],
                items: [
                  templateFixture(
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
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
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

      await tapRandomTemplateAction(tester);
      await tester.pump();
      await tapSheetText(tester, text.randomTemplateAccessPremium);
      await tapFindRandomTemplateAction(tester, text);
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
    final repository = RandomTemplatesRepository(
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              query: const TemplatesQuery(type: TemplateType.video),
              items: [
                templateFixture(
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
        child: TemplatesTickerModeHost(
          child: MaterialApp.router(
            builder: (context, child) => AppNavigationScope(
              navigator: GoRouterAppNavigator(router),
              child: child!,
            ),
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

    await tapRandomTemplateAction(tester);
    await tester.pump();
    await tapFindRandomTemplateAction(tester, text);

    expect(repository.fetchRandomTemplateCalls, 1);
    expect(repository.lastRandomMode, TemplateRandomMode.video);

    final hostState = tester.state<TemplatesTickerModeHostState>(
      find.byType(TemplatesTickerModeHost),
    );
    hostState.setEnabled(false);
    await tester.pump();

    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);

    randomCompleter.complete(
      templateFixture(
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
    final repository = RandomTemplatesRepository(
      randomTemplateCompleter: randomCompleter,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [
                templateFixture(
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
        child: buildTemplatesPageApp(child: const TemplatesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await tapRandomTemplateAction(tester);
    await tester.pump();
    await tapFindRandomTemplateAction(tester, text);

    expect(repository.fetchRandomTemplateCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.cancelPendingRandomTemplateRequestCalls, 1);

    randomCompleter.complete(
      templateFixture(
        'disposed-random-image',
        'Disposed random image',
        thumbnailUrl: 'https://cdn.petmagic.test/disposed-random.jpg',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('random template load failure shows sheet error state', (
    tester,
  ) async {
    await PetMagicNotificationCenter.instance.clearQueue();
    final controller = FakeTemplatesController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          templatesRepositoryProvider.overrideWithValue(
            RandomTemplatesRepository(throwOnRandom: true),
          ),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: buildTemplatesPageApp(child: const TemplatesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tapRandomTemplateAction(tester);
    await tester.pump();

    final context = tester.element(find.byType(TemplatesPage));
    final text = AppLocalizations.of(context);

    await tapFindRandomTemplateAction(tester, text);
    await tester.pump();

    expect(find.text(text.randomTemplateLoadFailed), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(PetMagicNotificationCenter.instance.current, isNull);

    await PetMagicNotificationCenter.instance.clearQueue();
  });
}
