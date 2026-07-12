import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_pet_repository_adapter.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'templates_page_lifecycle_test_support.dart';
import 'test_permission_fakes.dart';

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

  test(
    'template of the day pet flow uses canonical generation analytics event',
    () {
      final source = readTemplatesPageLibrarySource();

      expect(source, isNot(contains('generation_started_from_pet')));
      expect(source, contains("'generation_started'"));
      expect(source, contains('generationId: generation.generationId'));
    },
  );

  test('templates route preserves pet launch query parameters', () {
    final uri = Uri.parse(
      TemplatesPage.location(
        petId: 'pet/42 #x?kind=dog&name=Bella',
        petPhotoId: 'photo/7 #main?pose=1&tag=a',
      ),
    );

    expect(uri.path, TemplatesPage.routePath);
    expect(
      uri.queryParameters[TemplatesPage.petIdQueryParam],
      'pet/42 #x?kind=dog&name=Bella',
    );
    expect(
      uri.queryParameters[TemplatesPage.petPhotoIdQueryParam],
      'photo/7 #main?pose=1&tag=a',
    );
    expect(TemplatesPage.location(), TemplatesPage.routePath);
  });

  testWidgets('template selection loads detail payload before preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = RandomTemplatesRepository(
      templateDetailsById: {
        'feed-template': templateFixture('feed-template', 'Detail payload'),
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _templatesPageForState(state),
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('feed-template', 'Feed payload')],
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

    final feedTemplate = find.text('Feed payload').first;
    await tester.ensureVisible(feedTemplate);
    await tester.pump();
    await tester.tap(feedTemplate);
    await tester.pumpAndSettle();

    expect(repository.fetchTemplateCalls, 1);
    expect(find.text('opened:Detail payload'), findsOneWidget);
  });

  testWidgets('templates gallery denial shows localized permission warning', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final permissionCoordinator = FakeAppPermissionCoordinator(
      states: const {AppPermissionType.photos: AppPermissionState.denied},
    );
    final repository = RandomTemplatesRepository(
      templateDetailsById: {
        'feed-template': templateFixture('feed-template', 'Detail payload'),
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _templatesPageForState(state),
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
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('feed-template', 'Feed payload')],
            ),
          ),
          templatesRepositoryProvider.overrideWithValue(repository),
          appPermissionCoordinatorProvider.overrideWithValue(
            permissionCoordinator,
          ),
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

    await tester.tap(find.text('Feed payload').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Upload').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Gallery'));
    await tester.pump();

    final notification = PetMagicNotificationCenter.instance.current;
    expect(
      notification?.message,
      'Allow access to your gallery to choose a photo.',
    );
    expect(notification?.action, isNull);
    await PetMagicNotificationCenter.instance.clearQueue();
    await tester.pump();
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
    final generationRepository = PetFlowGenerationRepository(
      photoId: petPhotoId,
    );
    final router = GoRouter(
      initialLocation: Uri(
        path: TemplatesPage.routePath,
        queryParameters: {'petId': petId, 'petPhotoId': petPhotoId},
      ).toString(),
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => _templatesPageForState(state),
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(FundedWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          petRepositoryProvider.overrideWithValue(
            TemplateGenerationPetRepositoryAdapter(generationRepository),
          ),
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

    final petTemplate = find.text('Pet portrait').first;
    await tester.ensureVisible(petTemplate);
    await tester.pump();
    await tester.tap(petTemplate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Create magic'), findsOneWidget);
    await tester.tap(find.text('Create magic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.startFromPetCalls, 1);
    expect(generationRepository.lastPetId, petId);
    expect(generationRepository.lastPetPhotoId, petPhotoId);
    expect(generationRepository.lastTemplateId, 'template-pet');
    expect(generationRepository.rememberedGenerationIds, ['generation-pet-1']);
    expect(find.text('status:generation-pet-1'), findsOneWidget);
  });

  testWidgets('guest pet flow sign in preserves template pet redirect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const petId = 'pet/42 #x?kind=dog&name=Bella';
    const petPhotoId = 'photo/7 #main?pose=1&tag=a';
    final expectedRedirect = TemplatesPage.location(
      petId: petId,
      petPhotoId: petPhotoId,
    );
    final repository = RandomTemplatesRepository(
      templateDetailsById: {
        'template-pet': templateFixture('template-pet', 'Pet portrait'),
      },
    );
    final router = GoRouter(
      initialLocation: expectedRedirect,
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => _templatesPageForState(state),
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
          path: AuthEntryPage.routePath,
          builder: (context, state) => Scaffold(
            body: Text('auth:${state.uri.queryParameters['redirect'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: RegisterEntryPage.routePath,
          builder: (context, state) => Scaffold(
            body: Text(
              'register:${state.uri.queryParameters['redirect'] ?? ''}',
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
            UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('template-pet', 'Pet portrait')],
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

    await tester.tap(find.text('Pet portrait').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    await tester.tap(find.text(text.profileSignInAction).last);
    await tester.pumpAndSettle();

    expect(find.text('auth:$expectedRedirect'), findsOneWidget);
  });

  testWidgets('templates top bar sign in preserves template pet redirect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const petId = 'pet/42 #x?kind=dog&name=Bella';
    const petPhotoId = 'photo/7 #main?pose=1&tag=a';
    final expectedRedirect = TemplatesPage.location(
      petId: petId,
      petPhotoId: petPhotoId,
    );
    final router = GoRouter(
      initialLocation: expectedRedirect,
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => _templatesPageForState(state),
        ),
        GoRoute(
          path: AuthEntryPage.routePath,
          builder: (context, state) => Scaffold(
            body: Text('auth:${state.uri.queryParameters['redirect'] ?? ''}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(FakeTemplatesController.new),
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

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    await tester.tap(find.text(text.profileSignInAction).first);
    await tester.pumpAndSettle();

    expect(find.text('auth:$expectedRedirect'), findsOneWidget);
  });

  testWidgets('guest pet flow sign up preserves template pet redirect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const petId = 'pet/42 #x?kind=dog&name=Bella';
    const petPhotoId = 'photo/7 #main?pose=1&tag=a';
    final expectedRedirect = TemplatesPage.location(
      petId: petId,
      petPhotoId: petPhotoId,
    );
    final repository = RandomTemplatesRepository(
      templateDetailsById: {
        'template-pet': templateFixture('template-pet', 'Pet portrait'),
      },
    );
    final router = GoRouter(
      initialLocation: expectedRedirect,
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => _templatesPageForState(state),
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
          path: AuthEntryPage.routePath,
          builder: (context, state) => Scaffold(
            body: Text('auth:${state.uri.queryParameters['redirect'] ?? ''}'),
          ),
        ),
        GoRoute(
          path: RegisterEntryPage.routePath,
          builder: (context, state) => Scaffold(
            body: Text(
              'register:${state.uri.queryParameters['redirect'] ?? ''}',
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
            UnauthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(IdleWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('template-pet', 'Pet portrait')],
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

    await tester.tap(find.text('Pet portrait').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    await tester.tap(find.text(text.authSignUpAction).last);
    await tester.pumpAndSettle();

    expect(find.text('register:$expectedRedirect'), findsOneWidget);
  });

  testWidgets('selected pet dropdown preserves selected pet photo', (
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
    final generationRepository = CrossGalleryPetFlowRepository();
    final router = GoRouter(
      initialLocation: '/templates?petId=pet-42&petPhotoId=photo-7',
      routes: [
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => _templatesPageForState(state),
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(FundedWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          petRepositoryProvider.overrideWithValue(
            TemplateGenerationPetRepositoryAdapter(generationRepository),
          ),
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Bella').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.text('Bella').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final petTemplate = find.text('Pet portrait').first;
    await tester.ensureVisible(petTemplate);
    await tester.tap(petTemplate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Create magic'));
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

    final generationRepository = CrossGalleryPetFlowRepository();
    final historyController = PetFlowHistoryController(generationRepository);
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
          builder: (context, state) => _templatesPageForState(state),
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
            AuthenticatedAppLaunchController.new,
          ),
          walletControllerProvider.overrideWith(FundedWalletController.new),
          profileControllerProvider.overrideWith(FakeProfileController.new),
          templatesControllerProvider.overrideWith(
            () => FakeTemplatesController(
              items: [templateFixture('template-pet', 'Pet portrait')],
            ),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          petRepositoryProvider.overrideWithValue(
            TemplateGenerationPetRepositoryAdapter(generationRepository),
          ),
          generationHistoryControllerProvider.overrideWith(
            () => historyController,
          ),
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
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Bella').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable).first,
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

    await tester.tap(find.text('Create magic'));
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
}

Widget _templatesPageForState(GoRouterState state) {
  return Scaffold(
    body: TemplatesPage(
      initialPetId: state.uri.queryParameters[TemplatesPage.petIdQueryParam],
      initialPetPhotoId:
          state.uri.queryParameters[TemplatesPage.petPhotoIdQueryParam],
    ),
  );
}
