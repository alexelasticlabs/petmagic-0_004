import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/router/app_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_result_input_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  testWidgets('profile tab shows sign-in gate for guest', (tester) async {
    SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

    final authStorage = TestAuthSessionStorage();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWith(
          (ref) => Dio(BaseOptions(baseUrl: 'https://petmagic.test')),
        ),
        authSessionStorageProvider.overrideWith((ref) => authStorage),
        templatesRepositoryProvider.overrideWith(
          (ref) => FakeTemplatesRepository(items: const [sampleTemplate]),
        ),
        templateGenerationControllerProvider.overrideWith(
          IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          IdleGenerationHistoryController.new,
        ),
        walletControllerProvider.overrideWith(IdleWidgetWalletController.new),
        profileRepositoryProvider.overrideWith(
          (ref) => FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => FakeExternalAuthRepository(),
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appLaunchControllerProvider.notifier)
        .continueAsGuest();
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await pumpTestFrames(tester);

    router.go('/profile');
    await pumpTestFrames(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(find.text(text.authSignInRequired), findsOneWidget);
    expect(find.text(text.authRequiredMessage), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, text.profileSignInAction),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'app router shows auth gates for guest gallery routes without fetching',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

      final authStorage = TestAuthSessionStorage();
      final generationRepository = RouterTemplateGenerationRepository();
      final historyController = TrackingGenerationHistoryController();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWith(
            (ref) => Dio(BaseOptions(baseUrl: 'https://petmagic.test')),
          ),
          authSessionStorageProvider.overrideWith((ref) => authStorage),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          templatesRepositoryProvider.overrideWith(
            (ref) => FakeTemplatesRepository(items: const [sampleTemplate]),
          ),
          templateGenerationControllerProvider.overrideWith(
            IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            () => historyController,
          ),
          walletControllerProvider.overrideWith(IdleWidgetWalletController.new),
          profileRepositoryProvider.overrideWith(
            (ref) => FakeProfileRepository(),
          ),
          externalAuthRepositoryProvider.overrideWith(
            (ref) => FakeExternalAuthRepository(),
          ),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appLaunchControllerProvider.notifier)
          .continueAsGuest();
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await pumpTestFrames(tester);
      final initialFetchPetsCalls = generationRepository.fetchPetsCalls;

      final text = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );

      router.go(GenerationsGalleryPage.routePath);
      await pumpTestFrames(tester);
      await tester.pumpAndSettle();
      expect(find.byType(GenerationsGalleryPage), findsOneWidget);
      expect(find.text(text.authSignInRequired), findsAtLeastNWidgets(1));
      expect(
        find.text(text.generationStatusEmptyMessage),
        findsAtLeastNWidgets(1),
      );
      expect(historyController.loadCalls, isEmpty);
      expect(historyController.screenVisibilityCalls, contains(false));

      router.go(MyPetsPage.routePath);
      await pumpTestFrames(tester);
      expect(find.byType(MyPetsPage), findsOneWidget);
      expect(find.text(text.petsAuthRequiredTitle), findsAtLeastNWidgets(1));
      expect(find.text(text.petsAuthRequiredMessage), findsAtLeastNWidgets(1));
      expect(generationRepository.fetchPetsCalls, initialFetchPetsCalls);

      router.go(PetDetailsPage.location('pet-router'));
      await pumpTestFrames(tester);
      expect(find.byType(PetDetailsPage), findsOneWidget);
      expect(find.text(text.petsAuthRequiredTitle), findsAtLeastNWidgets(1));
      expect(find.text(text.petsAuthRequiredMessage), findsAtLeastNWidgets(1));
      expect(generationRepository.fetchPetsCalls, initialFetchPetsCalls);
      expect(generationRepository.fetchPetPhotosCalls, 0);
      expect(generationRepository.fetchPetGenerationsCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'app router registers pet details creations and generation status routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        onboardingSeenKey: true,
        sessionKey: buildSessionJson(),
      });

      final generationRepository = RouterTemplateGenerationRepository();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWith(
            (ref) => Dio(BaseOptions(baseUrl: 'https://petmagic.test')),
          ),
          authSessionStorageProvider.overrideWith(
            (ref) => TestAuthSessionStorage(rawSessionJson: buildSessionJson()),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          templatesRepositoryProvider.overrideWith(
            (ref) => FakeTemplatesRepository(items: const [sampleTemplate]),
          ),
          templateGenerationControllerProvider.overrideWith(
            IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            IdleGenerationHistoryController.new,
          ),
          walletControllerProvider.overrideWith(IdleWidgetWalletController.new),
          profileRepositoryProvider.overrideWith(
            (ref) => FakeProfileRepository(),
          ),
          externalAuthRepositoryProvider.overrideWith(
            (ref) => FakeExternalAuthRepository(),
          ),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(appLaunchControllerProvider.notifier).markSignedIn();
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await pumpTestFrames(tester);

      router.go(MyPetsPage.routePath);
      await pumpTestFrames(tester);
      expect(find.byType(MyPetsPage), findsOneWidget);

      router.go(PetDetailsPage.location('pet-router'));
      await pumpTestFrames(tester);
      expect(find.byType(PetDetailsPage), findsOneWidget);
      expect(
        tester.widget<PetDetailsPage>(find.byType(PetDetailsPage)).petId,
        'pet-router',
      );

      const encodedPetId = 'pet/router #1?x=2';
      router.go(PetDetailsPage.location(encodedPetId));
      await pumpTestFrames(tester);
      expect(find.byType(PetDetailsPage), findsOneWidget);
      expect(
        tester.widget<PetDetailsPage>(find.byType(PetDetailsPage)).petId,
        encodedPetId,
      );

      router.go(GenerationsGalleryPage.routePath);
      await pumpTestFrames(tester);
      expect(find.byType(GenerationsGalleryPage), findsOneWidget);

      router.go(GenerationStatusPage.routeFor('generation-router'));
      await pumpTestFrames(tester);
      expect(find.byType(GenerationStatusPage), findsOneWidget);
      expect(
        tester
            .widget<GenerationStatusPage>(find.byType(GenerationStatusPage))
            .generationId,
        'generation-router',
      );

      const encodedGenerationId = 'generation/router #1?x=2';
      router.go(GenerationStatusPage.routeFor(encodedGenerationId));
      await pumpTestFrames(tester);
      expect(find.byType(GenerationStatusPage), findsOneWidget);
      expect(
        tester
            .widget<GenerationStatusPage>(find.byType(GenerationStatusPage))
            .generationId,
        encodedGenerationId,
      );

      final resultInputUri = Uri.parse(
        GenerationResultInputPage.routeFor(encodedGenerationId),
      );
      expect(resultInputUri.pathSegments, [
        'generation-results',
        encodedGenerationId,
        'use-input',
      ]);
      expect(resultInputUri.query, isEmpty);
      expect(resultInputUri.fragment, isEmpty);

      final supportUri = Uri.parse(
        SupportChatPage.routeFor(
          initialMessage: 'Report\n$encodedGenerationId',
          relatedGenerationId: encodedGenerationId,
        ),
      );
      expect(supportUri.path, SupportChatPage.routePath);
      expect(
        supportUri.queryParameters[SupportChatPage.initialMessageQueryParam],
        'Report\n$encodedGenerationId',
      );
      expect(
        supportUri.queryParameters[SupportChatPage
            .relatedGenerationIdQueryParam],
        encodedGenerationId,
      );

      generationRepository.fetchGenerationCalls.clear();
      generationRepository.fetchCompatibleTemplateCalls.clear();
      router.go(GenerationResultInputPage.routeFor(encodedGenerationId));
      await pumpTestFrames(tester);
      expect(find.byType(GenerationResultInputPage), findsOneWidget);
      expect(
        tester
            .widget<GenerationResultInputPage>(
              find.byType(GenerationResultInputPage),
            )
            .generationId,
        encodedGenerationId,
      );
      expect(generationRepository.fetchGenerationCalls, [encodedGenerationId]);
      expect(generationRepository.fetchCompatibleTemplateCalls, [
        encodedGenerationId,
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(minutes: 5, milliseconds: 1));
    },
  );

  testWidgets(
    'authenticated user can open legal detail pages from profile settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        onboardingSeenKey: true,
        sessionKey: buildSessionJson(),
      });

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWith(
            (ref) => FakeProfileRepository(),
          ),
          authSessionStorageProvider.overrideWith(
            (ref) => TestAuthSessionStorage(rawSessionJson: buildSessionJson()),
          ),
          templatesRepositoryProvider.overrideWith(
            (ref) => FakeTemplatesRepository(items: const [sampleTemplate]),
          ),
          templateGenerationControllerProvider.overrideWith(
            IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            IdleGenerationHistoryController.new,
          ),
          walletControllerProvider.overrideWith(IdleWidgetWalletController.new),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(profileControllerProvider.notifier).initialize();
      container.read(appLaunchControllerProvider.notifier).markSignedIn();

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await pumpTestFrames(tester);

      router.go(
        ProfileSettingsDetailPage.location(ProfileSettingsDetailKind.terms),
      );
      await pumpTestFrames(tester);

      expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
      expect(
        tester
            .widget<ProfileSettingsDetailPage>(
              find.byType(ProfileSettingsDetailPage),
            )
            .kind,
        ProfileSettingsDetailKind.terms,
      );

      router.go(
        ProfileSettingsDetailPage.location(ProfileSettingsDetailKind.privacy),
      );
      await pumpTestFrames(tester);

      expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
      expect(
        tester
            .widget<ProfileSettingsDetailPage>(
              find.byType(ProfileSettingsDetailPage),
            )
            .kind,
        ProfileSettingsDetailKind.privacy,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(minutes: 5, milliseconds: 1));
    },
  );

  testWidgets('settings screen renders account and preferences sections', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository()
      ..storedSession = AuthSession.fromJson(
        jsonDecode(buildSessionJson()) as Map<String, dynamic>,
      );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(rawSessionJson: buildSessionJson()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileControllerProvider.notifier).initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: testRouter(const ProfileSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('App theme'), findsOneWidget);
  });

  testWidgets('account details screen renders stored profile fields', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository()
      ..storedSession = AuthSession.fromJson(
        jsonDecode(buildSessionJson()) as Map<String, dynamic>,
      );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(rawSessionJson: buildSessionJson()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileControllerProvider.notifier).initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: testRouter(const ProfileAccountInfoPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileAccountInfoPage)),
    );

    expect(find.text(text.profileSettingsAccountInfoTitle), findsOneWidget);
    expect(find.text('Pet Parent'), findsWidgets);
    expect(find.text('pet@example.com'), findsWidgets);
    expect(find.text(text.profileAccountDetailsSubtitle), findsOneWidget);
    expect(find.text('User ID'), findsNothing);
  });

  testWidgets('delete account detail screen reflects destructive live flow', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository()
      ..storedSession = AuthSession.fromJson(
        jsonDecode(buildSessionJson()) as Map<String, dynamic>,
      );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(rawSessionJson: buildSessionJson()),
        ),
        templateGenerationControllerProvider.overrideWith(
          IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          IdleGenerationHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileControllerProvider.notifier).initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: testRouter(
            const ProfileSettingsDetailPage(
              kind: ProfileSettingsDetailKind.deleteAccount,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Delete account'),
      ),
      findsOneWidget,
    );
    expect(find.text('Delete account'), findsWidgets);
    expect(find.text('CURRENT STATUS'), findsOneWidget);
    expect(
      find.textContaining('Deletion is available from this screen'),
      findsOneWidget,
    );
    expect(
      find.textContaining('review the warning, and confirm deletion'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Deletion is not available as a one-tap action'),
      findsNothing,
    );
  });
}
