import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/router/app_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';
part 'widget_test_support.part.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('shows welcome screen for first-time guest', (tester) async {
    await _pumpApp(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(find.text(text.startupWelcomeTitle), findsOneWidget);
    expect(find.text(text.startupWelcomeContinueGuest), findsOneWidget);
  });

  test('auth social providers are platform-specific and ordered', () {
    expect(authSocialProvidersForPlatform(isIOS: false), [
      ExternalAuthProvider.google,
    ]);
    expect(authSocialProvidersForPlatform(isIOS: true), [
      ExternalAuthProvider.apple,
      ExternalAuthProvider.google,
    ]);
  });

  testWidgets('onboarding guest action resets after startup failure', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      appLaunchController: _ThrowingGuestLaunchController.new,
    );

    final guestButton = find.widgetWithText(
      OutlinedButton,
      'Continue as guest',
    );
    expect(tester.widget<OutlinedButton>(guestButton).onPressed, isNotNull);

    await tester.tap(guestButton);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<OutlinedButton>(guestButton).onPressed, isNotNull);

    await PetMagicNotificationCenter.instance.clearQueue();
    await tester.pump();
  });

  testWidgets('shows short welcome for returning guest', (tester) async {
    await _pumpApp(tester, sharedPrefs: const {_onboardingSeenKey: true});

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(find.text(text.startupWelcomeTitle), findsOneWidget);
    expect(find.text(text.startupWelcomeContinueGuest), findsOneWidget);
    expect(find.text('View onboarding'), findsNothing);
  });

  testWidgets('guest can open auth and registration pages', (tester) async {
    await _pumpApp(tester, sharedPrefs: const {_onboardingSeenKey: true});

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Apple'),
      Platform.isIOS ? findsOneWidget : findsNothing,
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Display name (optional)'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(
      find.text('I want to receive updates and offers from PetMagic'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Continue with Apple'),
      Platform.isIOS ? findsOneWidget : findsNothing,
    );
  });

  testWidgets('registration requires accepting terms', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      profileRepository: _FakeProfileRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password123');

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You need to accept the Terms of Use and Privacy Policy to create an account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('guest can open password reset and request a code', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository();
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'pet@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(profileRepository.passwordResetRequestedFor, 'pet@example.com');
    expect(find.text('Enter the code from your email'), findsOneWidget);
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('password reset returns to sign in with prefilled email', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository();
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'pet@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.enterText(find.byType(TextField).at(2), 'pet123');
    await tester.enterText(find.byType(TextField).at(3), 'pet123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save new password'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(profileRepository.passwordResetConfirmedFor, 'pet@example.com');
    expect(find.text('Welcome back!'), findsOneWidget);
    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.controller?.text, 'pet@example.com');
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets('registers a new user and opens email verification', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
      profileRepository: _FakeProfileRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Pet Parent');
    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password123');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Verify email'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
  });

  testWidgets('registration forwards consent and marketing flags', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository();

    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'pet123');
    await tester.enterText(find.byType(TextField).at(3), 'pet123');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(profileRepository.lastTermsOfUseAccepted, isTrue);
    expect(profileRepository.lastMarketingEmailsEnabled, isTrue);
  });

  testWidgets('shows validation error when passwords do not match', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      profileRepository: _FakeProfileRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password321');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('continues with Google and opens templates', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
      externalAuthRepository: _FakeExternalAuthRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await tester.pump();
    await _pumpFrames(tester);

    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('shows localized message when external sign-in is cancelled', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      externalAuthRepository: _FailingExternalAuthRepository(
        const AppException('auth.external_cancelled'),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await _pumpFrames(tester);

    expect(find.text('Sign-in was cancelled.'), findsOneWidget);
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  test(
    'failed external sign-in does not block retrying regular auth',
    () async {
      SharedPreferences.setMockInitialValues(const {_onboardingSeenKey: true});

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWith(
            (ref) => _FakeProfileRepository(),
          ),
          externalAuthRepositoryProvider.overrideWith(
            (ref) => _ThrowingExternalAuthRepository(),
          ),
          authSessionStorageProvider.overrideWith(
            (ref) => _TestAuthSessionStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(appLaunchControllerProvider);
      final controller = container.read(profileControllerProvider.notifier);

      await controller.initialize();
      await controller.authenticateWithProvider(ExternalAuthProvider.google);

      final failedState = container.read(profileControllerProvider);
      expect(failedState.isSaving, isFalse);
      expect(failedState.isAuthenticated, isFalse);
      expect(failedState.errorMessage, 'auth.external_invalid');

      controller.updateEmail('pet@example.com');
      controller.updatePassword('Password123');
      await controller.login();

      final signedInState = container.read(profileControllerProvider);
      expect(signedInState.isSaving, isFalse);
      expect(signedInState.isAuthenticated, isTrue);
      expect(
        container.read(appLaunchControllerProvider).isAuthenticated,
        isTrue,
      );
    },
  );

  test('logout clears cached google session', () async {
    SharedPreferences.setMockInitialValues(const {_onboardingSeenKey: true});

    final profileRepository = _FakeProfileRepository();
    final externalAuthRepository = _TrackingExternalAuthRepository();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository,
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => _TestAuthSessionStorage(),
        ),
      ],
    );

    container.read(appLaunchControllerProvider);
    final controller = container.read(profileControllerProvider.notifier);

    await controller.initialize();
    await controller.login();
    await controller.logout();

    final loggedOutState = container.read(profileControllerProvider);
    expect(loggedOutState.isAuthenticated, isFalse);
    expect(loggedOutState.successMessage, 'logout');
    expect(
      externalAuthRepository.clearedProviders,
      contains(ExternalAuthProvider.google),
    );
    expect(
      externalAuthRepository.clearedProviders,
      contains(ExternalAuthProvider.apple),
    );
    expect(
      container.read(appLaunchControllerProvider).isAuthenticated,
      isFalse,
    );
  });

  testWidgets('opens templates directly for authenticated user', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: {_onboardingSeenKey: true, _sessionKey: _buildSessionJson()},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('guest can continue from welcome into template browsing', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Magic Studio'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Try template'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Try template'), findsOneWidget);
  });

  testWidgets('welcome guest action resets after startup failure', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      appLaunchController: _ThrowingGuestLaunchController.new,
    );

    final guestButton = find.widgetWithText(
      OutlinedButton,
      'Continue as guest',
    );
    expect(tester.widget<OutlinedButton>(guestButton).onPressed, isNotNull);

    await tester.tap(guestButton);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Magic Studio'), findsNothing);
    expect(tester.widget<OutlinedButton>(guestButton).onPressed, isNotNull);

    await PetMagicNotificationCenter.instance.clearQueue();
    await tester.pump();
  });

  testWidgets('profile tab shows sign-in gate for guest', (tester) async {
    SharedPreferences.setMockInitialValues(const {_onboardingSeenKey: true});

    final authStorage = _TestAuthSessionStorage();
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWith(
          (ref) => Dio(BaseOptions(baseUrl: 'https://petmagic.test')),
        ),
        authSessionStorageProvider.overrideWith((ref) => authStorage),
        templatesRepositoryProvider.overrideWith(
          (ref) => _FakeTemplatesRepository(items: const [_sampleTemplate]),
        ),
        templateGenerationControllerProvider.overrideWith(
          _IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          _IdleGenerationHistoryController.new,
        ),
        walletControllerProvider.overrideWith(_IdleWalletController.new),
        profileRepositoryProvider.overrideWith(
          (ref) => _FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => _FakeExternalAuthRepository(),
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
    await _pumpFrames(tester);

    router.go('/profile');
    await _pumpFrames(tester);

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
    'authenticated user can open legal detail pages from profile settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        _onboardingSeenKey: true,
        _sessionKey: _buildSessionJson(),
      });

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWith(
            (ref) => _FakeProfileRepository(),
          ),
          authSessionStorageProvider.overrideWith(
            (ref) =>
                _TestAuthSessionStorage(rawSessionJson: _buildSessionJson()),
          ),
          templatesRepositoryProvider.overrideWith(
            (ref) => _FakeTemplatesRepository(items: const [_sampleTemplate]),
          ),
          templateGenerationControllerProvider.overrideWith(
            _IdleTemplateGenerationController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
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
      await _pumpFrames(tester);

      router.go(
        ProfileSettingsDetailPage.location(ProfileSettingsDetailKind.terms),
      );
      await _pumpFrames(tester);

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
      await _pumpFrames(tester);

      expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
      expect(
        tester
            .widget<ProfileSettingsDetailPage>(
              find.byType(ProfileSettingsDetailPage),
            )
            .kind,
        ProfileSettingsDetailKind.privacy,
      );
    },
  );

  testWidgets('settings screen renders account and preferences sections', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith(
          (ref) => _FakeProfileRepository(),
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => _TestAuthSessionStorage(rawSessionJson: _buildSessionJson()),
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
          routerConfig: _testRouter(const ProfileSettingsPage()),
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
    final profileRepository = _FakeProfileRepository()
      ..storedSession = AuthSession.fromJson(
        jsonDecode(_buildSessionJson()) as Map<String, dynamic>,
      );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        authSessionStorageProvider.overrideWith(
          (ref) => _TestAuthSessionStorage(rawSessionJson: _buildSessionJson()),
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
          routerConfig: _testRouter(const ProfileAccountInfoPage()),
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

  testWidgets('delete account detail screen stays informational', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository()
      ..storedSession = AuthSession.fromJson(
        jsonDecode(_buildSessionJson()) as Map<String, dynamic>,
      );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        authSessionStorageProvider.overrideWith(
          (ref) => _TestAuthSessionStorage(rawSessionJson: _buildSessionJson()),
        ),
        templateGenerationControllerProvider.overrideWith(
          _IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          _IdleGenerationHistoryController.new,
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
          routerConfig: _testRouter(
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
      find.textContaining('Deletion is not available as a one-tap action'),
      findsOneWidget,
    );
  });

  test('support chat controller loads existing messages', () async {
    final supportRepository = _FakeSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWith((ref) => supportRepository),
        supportChatRealtimeClientProvider.overrideWith(
          (ref) => const _FakeSupportChatRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(supportChatControllerProvider.notifier).initialize();

    final state = container.read(supportChatControllerProvider);
    expect(state.conversation, isNotNull);
    expect(state.conversation?.assignedAdminDisplayName, 'PetMagic Support');
    expect(state.conversation?.messages.first.body, 'How can we help today?');
    expect(state.conversation?.userUnreadCount, 0);
  });

  test('support chat controller sends a new message', () async {
    final supportRepository = _FakeSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWith((ref) => supportRepository),
        supportChatRealtimeClientProvider.overrideWith(
          (ref) => const _FakeSupportChatRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(supportChatControllerProvider.notifier);
    await controller.initialize();
    await controller.sendMessage('I need billing help', localeTag: 'en');

    final state = container.read(supportChatControllerProvider);
    expect(supportRepository.lastSentBody, 'I need billing help');
    expect(
      state.conversation?.messages.any(
        (message) => message.body == 'I need billing help',
      ),
      isTrue,
    );
  });

  test(
    'support chat controller creates conversation on first message',
    () async {
      final supportRepository = _FakeSupportChatRepository(
        hasConversation: false,
      );
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const _FakeSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(supportChatControllerProvider.notifier);
      await controller.initialize();
      expect(
        container.read(supportChatControllerProvider).conversation,
        isNull,
      );

      await controller.sendMessage('Need help with tokens', localeTag: 'en');

      final state = container.read(supportChatControllerProvider);
      expect(supportRepository.openConversationCalls, 1);
      expect(
        supportRepository.lastOpenedInitialMessage,
        'Need help with tokens',
      );
      expect(state.conversation, isNotNull);
      expect(
        state.conversation?.messages.any(
          (message) => message.body == 'Need help with tokens',
        ),
        isTrue,
      );
    },
  );

  test(
    'support chat controller clears loading state on unexpected error',
    () async {
      final supportRepository = _ThrowingSupportChatRepository();
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const _FakeSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(supportChatControllerProvider.notifier).initialize();

      final state = container.read(supportChatControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.conversation, isNull);
      expect(state.errorMessage, 'support.unavailable');
    },
  );

  testWidgets(
    'support chat page shows retry fallback when initial load takes too long',
    (tester) async {
      final supportRepository = _DelayedSupportChatRepository();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportChatRepositoryProvider.overrideWith(
              (ref) => supportRepository,
            ),
            supportChatRealtimeClientProvider.overrideWith(
              (ref) => const _FakeSupportChatRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SupportChatPage(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));

      expect(find.text('Start the conversation'), findsOneWidget);
      expect(
        find.text(
          'Unable to reach support right now. Please try again in a moment.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets('support chat page renders support header and security card', (
    tester,
  ) async {
    final supportRepository = _FakeSupportChatRepository();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const _FakeSupportChatRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SupportChatPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Your conversation is protected. We use it only for support.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.text('PetMagic Support'), findsWidgets);
    expect(find.text('We usually reply within 24 hours'), findsWidgets);
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
  });

  testWidgets('support chat page shows welcome actions for empty chat', (
    tester,
  ) async {
    final supportRepository = _FakeSupportChatRepository(
      emptyConversation: true,
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const _FakeSupportChatRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SupportChatPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final text = AppLocalizations.of(
      tester.element(find.byType(SupportChatPage)),
    );

    expect(find.text(text.supportChatWelcomeBody), findsOneWidget);
    expect(find.text(text.supportHomeTopicGenerationIssue), findsOneWidget);
    expect(find.text(text.supportHomeTopicPaymentRefund), findsOneWidget);
    expect(find.text(text.supportHomeTopicTokensNotArrived), findsOneWidget);
  });

  testWidgets(
    'support chat attachment bubble does not overflow on narrow screens',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(320, 720);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      const longFileName =
          'ultra-super-mega-long-support-attachment-file-name-for-mobile-overflow-regression-check-2026-final-version.pdf';

      final supportRepository = _FakeSupportChatRepository();
      supportRepository._conversation = SupportChatConversation(
        conversationId: 'conversation-overflow-1',
        initiatorUserId: 'user-1',
        userEmail: 'pet@example.com',
        userDisplayName: 'Pet Parent',
        assignedAdminId: 'admin-1',
        assignedAdminDisplayName: 'PetMagic Support',
        status: 'Open',
        priority: 'Normal',
        source: 'Direct',
        userUnreadCount: 0,
        adminUnreadCount: 0,
        createdAtUtc: DateTime.utc(2026, 1, 1, 10),
        updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
        lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
        messages: [
          SupportChatMessage(
            messageId: 'message-replied',
            conversationId: 'conversation-overflow-1',
            senderUserId: 'admin-1',
            senderDisplayName: 'PetMagic Support',
            isFromAdmin: true,
            senderType: 'Admin',
            body: 'Please attach the file so we can investigate this issue.',
            isRead: true,
            attachments: const [],
            createdAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
          ),
          SupportChatMessage(
            messageId: 'message-attachment',
            conversationId: 'conversation-overflow-1',
            senderUserId: 'user-1',
            senderDisplayName: 'Pet Parent',
            isFromAdmin: false,
            senderType: 'User',
            body: '',
            replyToMessageId: 'message-replied',
            replyToPreview: 'Please attach the file so we can investigate.',
            isRead: false,
            attachments: const [
              SupportChatAttachment(
                fileUrl: 'https://example.com/files/attachment.pdf',
                type: 'file',
                mimeType: 'application/pdf',
                fileName: longFileName,
                sizeBytes: 245760,
              ),
            ],
            createdAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
          ),
        ],
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportChatRepositoryProvider.overrideWith(
              (ref) => supportRepository,
            ),
            supportChatRealtimeClientProvider.overrideWith(
              (ref) => const _FakeSupportChatRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SupportChatPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.textContaining('Please attach the file'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test('app preferences controller persists theme and locale', () async {
    SharedPreferences.setMockInitialValues(const {});

    final firstContainer = ProviderContainer();
    addTearDown(firstContainer.dispose);

    firstContainer.read(appPreferencesControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final firstController = firstContainer.read(
      appPreferencesControllerProvider.notifier,
    );

    await firstController.updateThemeMode(ThemeMode.dark);
    await firstController.updateLocale(const Locale('en'));

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    secondContainer.read(appPreferencesControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final loadedState = secondContainer.read(appPreferencesControllerProvider);
    expect(loadedState.themeMode, ThemeMode.dark);
    expect(loadedState.locale, const Locale('en'));
  });

  test('app preferences controller migrates legacy en_US locale', () async {
    SharedPreferences.setMockInitialValues(const {
      'petmagic_mobile_locale': 'en_US',
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appPreferencesControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(appPreferencesControllerProvider);
    expect(state.locale, const Locale('en'));
  });
}
