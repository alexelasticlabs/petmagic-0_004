import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('shows onboarding for first-time guest', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Create magic moments with your pet'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('shows short welcome for returning guest', (tester) async {
    await _pumpApp(tester, sharedPrefs: const {_onboardingSeenKey: true});

    expect(find.text('Welcome back to PetMagic'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.text('View onboarding'), findsNothing);
  });

  testWidgets('guest can open auth and registration pages', (tester) async {
    await _pumpApp(tester, sharedPrefs: const {_onboardingSeenKey: true});

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Google'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Apple'), findsOneWidget);

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
    expect(
      find.text('I agree to the Terms of Use and Privacy Policy'),
      findsOneWidget,
    );
    expect(
      find.text('I want to receive updates and offers from PetMagic'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Google'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Apple'), findsOneWidget);
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
  });

  testWidgets('registers a new user and opens templates', (tester) async {
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
    await tester.tap(
      find.text('I agree to the Terms of Use and Privacy Policy'),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Magic Studio'), findsOneWidget);
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
    await tester.tap(
      find.text('I agree to the Terms of Use and Privacy Policy'),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('I want to receive updates and offers from PetMagic'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.text('I want to receive updates and offers from PetMagic'),
    );
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
    await tester.tap(
      find.text('I agree to the Terms of Use and Privacy Policy'),
    );
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Google'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create Magic'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Google'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in was cancelled.'), findsOneWidget);
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
    addTearDown(container.dispose);

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

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
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
    await tester.pumpAndSettle();

    expect(find.text('Magic Studio'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Try template'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Try template'), findsOneWidget);
  });

  testWidgets('profile tab sends guest to auth flow', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
  });

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

    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('Pet Parent'), findsWidgets);
    expect(find.text('pet@example.com'), findsWidgets);
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('User ID'), findsNothing);
    expect(
      find.textContaining('Current legal documents are accepted'),
      findsOneWidget,
    );
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

    expect(find.text('Your conversation is secure'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.text('PetMagic Support'), findsWidgets);
    expect(find.text('Average response time: under 24 hours'), findsWidgets);
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

    expect(find.text('Welcome to PetMagic support'), findsOneWidget);
    expect(find.text('Issue with image generation'), findsOneWidget);
    expect(find.text('Payment problem'), findsOneWidget);
    expect(find.text('FAQ'), findsOneWidget);
  });

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

GoRouter _testRouter(Widget home) {
  return GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> sharedPrefs = const {},
  TemplatesRepository? repository,
  ProfileRepository? profileRepository,
  ExternalAuthRepository? externalAuthRepository,
}) async {
  final sharedPrefsWithoutSession = Map<String, Object>.from(sharedPrefs)
    ..remove(_sessionKey);
  SharedPreferences.setMockInitialValues(sharedPrefsWithoutSession);

  final authStorage = _TestAuthSessionStorage(
    rawSessionJson: sharedPrefs[_sessionKey] is String
        ? sharedPrefs[_sessionKey] as String
        : null,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionStorageProvider.overrideWith((ref) => authStorage),
        templatesRepositoryProvider.overrideWith(
          (ref) => repository ?? _FakeTemplatesRepository(),
        ),
        templateGenerationControllerProvider.overrideWith(
          _IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          _IdleGenerationHistoryController.new,
        ),
        walletControllerProvider.overrideWith(_IdleWalletController.new),
        profileRepositoryProvider.overrideWith(
          (ref) => profileRepository ?? _FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository ?? _FakeExternalAuthRepository(),
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
      ],
      child: const PetMagicApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

String _buildSessionJson() {
  return jsonEncode(
    AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: const MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: _sampleLegalAcceptance,
        roles: ['user'],
        avatar: null,
      ),
    ).toJson(),
  );
}

class _TestAuthSessionStorage extends AuthSessionStorage {
  _TestAuthSessionStorage({String? rawSessionJson})
    : _session = _deserialize(rawSessionJson);

  AuthSession? _session;

  static AuthSession? _deserialize(String? rawSessionJson) {
    if (rawSessionJson == null || rawSessionJson.isEmpty) {
      return null;
    }

    try {
      return AuthSession.fromJson(
        jsonDecode(rawSessionJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

const _sampleLegalAcceptance = MobileLegalAcceptanceStatus(
  termsOfUseAccepted: true,
  termsOfUseAcceptedVersion: '2026-05-20',
  termsOfUseAcceptedAtUtc: null,
  privacyPolicyAccepted: true,
  privacyPolicyAcceptedVersion: '2026-05-20',
  privacyPolicyAcceptedAtUtc: null,
  currentTermsOfUseVersion: '2026-05-20',
  currentPrivacyPolicyVersion: '2026-05-20',
  requiresAcceptance: false,
);

const _sampleLegalDocuments = MobileLegalDocuments(
  termsOfUse: MobileLegalDocument(
    kind: 'terms-of-use',
    title: 'Terms',
    version: '2026-05-20',
    publishedAtUtc: null,
    summary: 'Terms summary',
    sections: [
      MobileLegalDocumentSection(
        heading: 'General',
        paragraphs: ['Terms paragraph'],
      ),
    ],
  ),
  privacyPolicy: MobileLegalDocument(
    kind: 'privacy-policy',
    title: 'Privacy',
    version: '2026-05-20',
    publishedAtUtc: null,
    summary: 'Privacy summary',
    sections: [
      MobileLegalDocumentSection(
        heading: 'Privacy',
        paragraphs: ['Privacy paragraph'],
      ),
    ],
  ),
);

const _sessionKey = AuthSessionStorage.sessionKey;
const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

const _sampleTemplate = TemplateItem(
  templateId: 'template-1',
  templateType: TemplateType.image,
  title: 'Magic Studio',
  shortDescription: 'Turn your pet into a star.',
  petPhotoRequirements: ['One pet in the photo', 'Clear face'],
  category: 'Magic',
  tags: ['funny', 'sparkle'],
  isPremium: false,
  tokenCost: 12,
);

class _FakeTemplatesRepository implements TemplatesRepository {
  const _FakeTemplatesRepository({this.items = const []});

  final List<TemplateItem> items;

  @override
  Future<List<String>> fetchCategories() async => const ['Magic'];

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async =>
      null;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async =>
      TemplatesFeedPage(items: items, nextCursor: null, hasMore: false);
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  AuthSession? storedSession;
  String? passwordResetRequestedFor;
  String? passwordResetConfirmedFor;
  bool? lastTermsOfUseAccepted;
  bool? lastMarketingEmailsEnabled;

  MobileUserProfile get _profile => const MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: _sampleLegalAcceptance,
    roles: ['user'],
    avatar: null,
  );

  @override
  Future<AuthSession?> readSession() async => storedSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: _profile.userId,
        email: email,
        displayName: _profile.displayName,
        isPremium: _profile.isPremium,
        emailConfirmed: _profile.emailConfirmed,
        termsOfUseAccepted: _profile.termsOfUseAccepted,
        privacyPolicyAccepted: _profile.privacyPolicyAccepted,
        marketingEmailsEnabled: _profile.marketingEmailsEnabled,
        legalAcceptance: _profile.legalAcceptance,
        roles: _profile.roles,
        avatar: _profile.avatar,
      ),
    );
    storedSession = session;
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required String termsOfUseVersion,
    required String privacyPolicyVersion,
    required bool marketingEmailsEnabled,
    String? displayName,
  }) async {
    lastTermsOfUseAccepted = termsOfUseAccepted;
    lastMarketingEmailsEnabled = marketingEmailsEnabled;

    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: _profile.userId,
        email: email,
        displayName: displayName?.isEmpty ?? true
            ? _profile.displayName
            : displayName,
        isPremium: _profile.isPremium,
        emailConfirmed: _profile.emailConfirmed,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        marketingEmailsEnabled: marketingEmailsEnabled,
        legalAcceptance: const MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '2026-05-20',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '2026-05-20',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '2026-05-20',
          currentPrivacyPolicyVersion: '2026-05-20',
          requiresAcceptance: false,
        ),
        roles: _profile.roles,
        avatar: _profile.avatar,
      ),
    );
    storedSession = session;
    return session;
  }

  @override
  Future<MobileUserProfile> fetchProfile() async {
    final session = storedSession;
    if (session == null) {
      throw const AppException('Unauthorized', statusCode: 401);
    }

    return MobileUserProfile(
      userId: _profile.userId,
      email: session.user.email,
      displayName: session.user.displayName,
      isPremium: _profile.isPremium,
      emailConfirmed: _profile.emailConfirmed,
      termsOfUseAccepted: session.user.termsOfUseAccepted,
      privacyPolicyAccepted: session.user.privacyPolicyAccepted,
      marketingEmailsEnabled: session.user.marketingEmailsEnabled,
      legalAcceptance: session.user.legalAcceptance,
      roles: _profile.roles,
      avatar: _profile.avatar,
    );
  }

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
  }) async {
    return _sampleLegalDocuments;
  }

  @override
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
  }) async {
    final session = storedSession;
    if (session == null) {
      throw const AppException('Unauthorized', statusCode: 401);
    }

    final profile = MobileUserProfile(
      userId: session.user.userId,
      email: session.user.email,
      displayName: session.user.displayName,
      isPremium: session.user.isPremium,
      emailConfirmed: session.user.emailConfirmed,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: session.user.marketingEmailsEnabled,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: documents.termsOfUse.version,
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: documents.privacyPolicy.version,
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: documents.termsOfUse.version,
        currentPrivacyPolicyVersion: documents.privacyPolicy.version,
        requiresAcceptance: false,
      ),
      roles: session.user.roles,
      avatar: session.user.avatar,
    );

    storedSession = AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAtUtc: session.expiresAtUtc,
      user: profile,
    );

    return profile;
  }

  @override
  Future<void> logout() async {
    storedSession = null;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    passwordResetRequestedFor = email;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    passwordResetConfirmedFor = email;
  }
}

class _FakeExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    return AuthSession(
      accessToken: 'external-access-token',
      refreshToken: 'external-refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: 'external-user-1',
        email: provider == ExternalAuthProvider.google
            ? 'google@example.com'
            : 'apple@example.com',
        displayName: provider == ExternalAuthProvider.google
            ? 'Google Pet Parent'
            : 'Apple Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: _sampleLegalAcceptance,
        roles: const ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
}

class _TrackingExternalAuthRepository extends _FakeExternalAuthRepository {
  final List<ExternalAuthProvider> clearedProviders = [];

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    clearedProviders.add(provider);
  }
}

class _FailingExternalAuthRepository implements ExternalAuthRepository {
  const _FailingExternalAuthRepository(this.error);

  final AppException error;

  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    throw error;
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    throw error;
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw error;
  }
}

class _ThrowingExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    throw Exception('google sign-in failed unexpectedly');
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    throw Exception('external account link failed unexpectedly');
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw Exception('external account sign-out failed unexpectedly');
  }
}

class _FakeSupportChatRepository extends SupportChatRepository {
  _FakeSupportChatRepository({this.emptyConversation = false})
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final bool emptyConversation;
  String? lastSentBody;
  late SupportChatConversation _conversation = SupportChatConversation(
    conversationId: 'conversation-1',
    initiatorUserId: 'user-1',
    userEmail: 'pet@example.com',
    userDisplayName: 'Pet Parent',
    assignedAdminId: 'admin-1',
    assignedAdminDisplayName: 'PetMagic Support',
    status: 'Open',
    priority: 'Normal',
    userUnreadCount: 1,
    adminUnreadCount: 0,
    createdAtUtc: DateTime.utc(2026, 1, 1, 10),
    updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    messages: emptyConversation
        ? []
        : [
            SupportChatMessage(
              messageId: 'message-1',
              conversationId: 'conversation-1',
              senderUserId: 'admin-1',
              senderDisplayName: 'PetMagic Support',
              isFromAdmin: true,
              body: 'How can we help today?',
              isRead: false,
              createdAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
            ),
          ],
  );

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
  }) async {
    return _conversation;
  }

  @override
  Future<SupportChatConversation> getConversation() async {
    return _conversation;
  }

  @override
  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
  }) async {
    lastSentBody = body;
    final message = SupportChatMessage(
      messageId: 'message-2',
      conversationId: conversationId,
      senderUserId: 'user-1',
      senderDisplayName: 'Pet Parent',
      isFromAdmin: false,
      body: body,
      isRead: false,
      createdAtUtc: DateTime.utc(2026, 1, 1, 10, 10),
    );

    _conversation = _conversation.copyWith(
      adminUnreadCount: _conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: [..._conversation.messages, message],
    );

    return message;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    _conversation = _conversation.copyWith(
      userUnreadCount: 0,
      messages: _conversation.messages
          .map(
            (message) => message.isFromAdmin
                ? message.copyWith(
                    isRead: true,
                    readAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
                  )
                : message,
          )
          .toList(growable: false),
    );
  }
}

class _ThrowingSupportChatRepository extends SupportChatRepository {
  _ThrowingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
  }) async {
    throw Exception('unexpected support failure');
  }
}

class _DelayedSupportChatRepository extends SupportChatRepository {
  _DelayedSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
  }) async {
    return Completer<SupportChatConversation>().future;
  }
}

class _FakeSupportChatRealtimeClient implements SupportChatRealtimeClient {
  const _FakeSupportChatRealtimeClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<SupportChatRealtimeUpdate> get events => const Stream.empty();
}
