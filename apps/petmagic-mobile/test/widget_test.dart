import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  testWidgets('shows welcome screen for first-time guest', (tester) async {
    await pumpTestApp(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(find.text(text.startupWelcomeTitle), findsOneWidget);
    expect(find.text(text.startupWelcomeContinueGuest), findsOneWidget);
  });

  testWidgets('compact welcome keeps primary actions in first viewport', (
    tester,
  ) async {
    await pumpTestApp(tester, surfaceSize: const Size(320, 568));

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    await pumpTestFrames(tester, count: 6);

    expect(tester.takeException(), isNull);
    _expectFullyVisible(
      tester,
      find.widgetWithText(FilledButton, text.profileSignInAction),
    );
    _expectFullyVisible(
      tester,
      find.widgetWithText(OutlinedButton, text.startupWelcomeContinueGuest),
    );
  });

  testWidgets('compact sign-in inline actions do not overflow', (tester) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      surfaceSize: const Size(375, 667),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact welcome remains scrollable at 200 percent text scale', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      surfaceSize: const Size(320, 568),
      textScaleFactor: 2.0,
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility control exposes its semantic action', (
    tester,
  ) async {
    await pumpTestApp(tester, sharedPrefs: const {onboardingSeenKey: true});

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    final text = AppLocalizations.of(
      tester.element(find.byType(AuthEntryPage)),
    );
    expect(find.byTooltip(text.authShowPassword), findsOneWidget);

    await tester.tap(find.byTooltip(text.authShowPassword));
    await tester.pump();

    expect(find.byTooltip(text.authHidePassword), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome primary actions expose accessible semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpTestApp(tester, surfaceSize: const Size(320, 568));

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    final signIn = tester.getSemantics(
      find.bySemanticsLabel(text.profileSignInAction),
    );
    final continueAsGuest = tester.getSemantics(
      find.bySemanticsLabel(text.startupWelcomeContinueGuest),
    );

    expect(signIn.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(signIn.getSemanticsData().label, contains(text.profileSignInAction));
    expect(
      continueAsGuest.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      continueAsGuest.getSemanticsData().label,
      contains(text.startupWelcomeContinueGuest),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
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
    await pumpTestApp(
      tester,
      appLaunchController: ThrowingGuestLaunchController.new,
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
    await pumpTestApp(tester, sharedPrefs: const {onboardingSeenKey: true});

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(find.text(text.startupWelcomeTitle), findsOneWidget);
    expect(find.text(text.startupWelcomeContinueGuest), findsOneWidget);
    expect(find.text('View onboarding'), findsNothing);
  });

  testWidgets('guest can open auth and registration pages', (tester) async {
    await pumpTestApp(tester, sharedPrefs: const {onboardingSeenKey: true});

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

  testWidgets('registration legal links open their documents', (tester) async {
    await pumpTestApp(tester, sharedPrefs: const {onboardingSeenKey: true});

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('auth_terms_link')));
    await pumpTestFrames(tester, count: 16);
    expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
    expect(find.text('Terms paragraph'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await pumpTestFrames(tester);

    await tester.tap(find.byKey(const ValueKey('auth_privacy_link')));
    await pumpTestFrames(tester);
    expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
    expect(find.text('Privacy paragraph'), findsOneWidget);
  });

  testWidgets('compact sign in keeps submit button visible without overflow', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      surfaceSize: const Size(320, 568),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    final text = AppLocalizations.of(
      tester.element(find.byType(AuthEntryPage)),
    );

    expect(tester.takeException(), isNull);
    _expectFullyVisible(
      tester,
      find.widgetWithText(FilledButton, text.profileSignInAction),
    );
  });

  testWidgets('sign in commits autofilled controller values before submit', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      profileRepository: profileRepository,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    tester.widget<TextField>(fields.at(0)).controller!.text =
        'autofill@example.com';
    tester.widget<TextField>(fields.at(1)).controller!.text =
        'AutofilledPassword123';

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(profileRepository.lastLoginEmail, 'autofill@example.com');
    expect(profileRepository.lastLoginPassword, 'AutofilledPassword123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration requires accepting terms', (tester) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      profileRepository: FakeProfileRepository(),
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

  testWidgets('sign up stays blocked when legal documents are unavailable', (
    tester,
  ) async {
    final profileRepository = UnavailableLegalDocumentsProfileRepository();

    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      profileRepository: profileRepository,
      surfaceSize: const Size(393, 852),
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

    final text = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    );
    expect(find.text(text.authLegalUnavailable), findsNothing);

    await tester.tap(find.byKey(const ValueKey('auth_terms_link')));
    await pumpTestFrames(tester, count: 16);
    expect(find.byType(ProfileSettingsDetailPage), findsOneWidget);
    expect(find.text(text.profileLegalLoading), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await pumpTestFrames(tester);

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

    expect(profileRepository.lastTermsOfUseAccepted, isNull);
    expect(profileRepository.lastTermsOfUseVersion, isNull);
    expect(profileRepository.lastPrivacyPolicyVersion, isNull);
    expect(find.text(text.authLegalUnavailable), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Verify email'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can open password reset and request a code', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
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
    final profileRepository = FakeProfileRepository();
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
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
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password123');
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
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
      profileRepository: FakeProfileRepository(),
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
    final profileRepository = FakeProfileRepository();

    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
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
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password123');
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

  testWidgets('registration blocks weak password before api call', (
    tester,
  ) async {
    final profileRepository = FakeProfileRepository();

    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
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

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(profileRepository.lastTermsOfUseAccepted, isNull);
  });

  testWidgets('shows validation error when passwords do not match', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      profileRepository: FakeProfileRepository(),
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

  testWidgets('continues with Google and opens discovery', (tester) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
      externalAuthRepository: FakeExternalAuthRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await tester.pump();
    await pumpTestFrames(tester);

    expect(find.text('What will your pet become?'), findsOneWidget);
  });

  testWidgets('shows localized message when external sign-in is cancelled', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      externalAuthRepository: FailingExternalAuthRepository(
        const AppException('auth.external_cancelled'),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await pumpTestFrames(tester);

    expect(find.text('Sign-in was cancelled.'), findsOneWidget);
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  test(
    'failed external sign-in does not block retrying regular auth',
    () async {
      SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWith(
            (ref) => FakeProfileRepository(),
          ),
          externalAuthRepositoryProvider.overrideWith(
            (ref) => ThrowingExternalAuthRepository(),
          ),
          authSessionStorageProvider.overrideWith(
            (ref) => TestAuthSessionStorage(),
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

  test('cancelled regular login clears saving state', () async {
    SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith(
          (ref) => CancelledLoginProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => FakeExternalAuthRepository(),
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appLaunchControllerProvider);
    final controller = container.read(profileControllerProvider.notifier);

    await controller.initialize();
    controller
      ..updateEmail('pet@example.com')
      ..updatePassword('Password123');
    await controller.login();

    final state = container.read(profileControllerProvider);
    expect(state.isSaving, isFalse);
    expect(state.isAuthenticated, isFalse);
  });

  test('cancelled external sign-in clears saving state', () async {
    SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith(
          (ref) => FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => CancelledExternalAuthRepository(),
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appLaunchControllerProvider);
    final controller = container.read(profileControllerProvider.notifier);

    await controller.initialize();
    await controller.authenticateWithProvider(ExternalAuthProvider.google);

    final state = container.read(profileControllerProvider);
    expect(state.isSaving, isFalse);
    expect(state.isAuthenticated, isFalse);
  });

  test('logout clears cached google session', () async {
    SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

    final profileRepository = FakeProfileRepository();
    final externalAuthRepository = TrackingExternalAuthRepository();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository,
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(),
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

  test('profile mutation is cancelled when app launch signs out', () async {
    SharedPreferences.setMockInitialValues(const {onboardingSeenKey: true});

    final profileRepository = DelayedProfileMutationRepository();
    final appLaunchController = MutableAuthenticatedWidgetAppLaunchController();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profileRepository),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => FakeExternalAuthRepository(),
        ),
        authSessionStorageProvider.overrideWith(
          (ref) => TestAuthSessionStorage(),
        ),
        appLaunchControllerProvider.overrideWith(() => appLaunchController),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(profileControllerProvider.notifier);
    controller
      ..updateEmail('pet@example.com')
      ..updatePassword('Password123');
    await controller.login();

    final mutation = controller.updateCurrentProfile(
      displayName: 'Signed Out Pet',
    );
    await Future<void>.delayed(Duration.zero);

    expect(profileRepository.updateProfileCalls, 1);
    expect(profileRepository.updateCancelToken?.isCancelled, isFalse);

    appLaunchController.markSignedOutForTest();
    await Future<void>.delayed(Duration.zero);

    expect(profileRepository.updateCancelToken?.isCancelled, isTrue);
    expect(container.read(profileControllerProvider).isAuthenticated, isFalse);
    expect(container.read(profileControllerProvider).isSaving, isFalse);

    profileRepository.completeUpdate();
    await mutation;

    expect(container.read(profileControllerProvider).isAuthenticated, isFalse);
  });

  testWidgets('opens discovery directly for authenticated user', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: {onboardingSeenKey: true, sessionKey: buildSessionJson()},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
    );

    expect(find.text('What will your pet become?'), findsOneWidget);
  });

  testWidgets('guest can continue from welcome into template browsing', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      repository: FakeTemplatesRepository(items: const [sampleTemplate]),
    );

    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('What will your pet become?'), findsOneWidget);
    expect(find.text('Search templates'), findsOneWidget);
  });

  testWidgets('welcome guest action resets after startup failure', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      sharedPrefs: const {onboardingSeenKey: true},
      appLaunchController: ThrowingGuestLaunchController.new,
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
}

void _expectFullyVisible(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);

  final rect = tester.getRect(finder);
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;

  expect(rect.top >= 0, isTrue, reason: 'Widget starts above the viewport');
  expect(rect.left >= 0, isTrue, reason: 'Widget starts left of the viewport');
  expect(
    rect.bottom <= logicalSize.height,
    isTrue,
    reason: 'Widget extends below the viewport',
  );
  expect(
    rect.right <= logicalSize.width,
    isTrue,
    reason: 'Widget extends beyond the viewport width',
  );
}

class MutableAuthenticatedWidgetAppLaunchController
    extends AppLaunchController {
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

  void markSignedOutForTest() {
    state = const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class DelayedProfileMutationRepository extends FakeProfileRepository {
  int updateProfileCalls = 0;
  RequestCancellation? updateCancelToken;
  final Completer<MobileUserProfile> _updateCompleter =
      Completer<MobileUserProfile>();

  @override
  Future<MobileUserProfile> updateProfile({
    required String? displayName,
    RequestCancellation? cancelToken,
  }) {
    updateProfileCalls++;
    updateCancelToken = cancelToken;
    return _updateCompleter.future;
  }

  void completeUpdate() {
    if (_updateCompleter.isCompleted) {
      return;
    }

    final profile = storedSession?.user;
    if (profile == null) {
      _updateCompleter.completeError(
        const AppException('Unauthorized', statusCode: 401),
      );
      return;
    }

    _updateCompleter.complete(profile);
  }
}
