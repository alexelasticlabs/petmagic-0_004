import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';

void main() {
  testWidgets('email verification ignores duplicate verify taps in flight', (
    tester,
  ) async {
    final repository = _DuplicateGuardProfileRepository();
    await _pumpVerificationPage(tester, repository);

    final verifyButton = find.byType(FilledButton);
    await tester.tap(verifyButton);
    await tester.tap(verifyButton);

    expect(repository.verifyCalls, 1);

    repository.completeVerify();
    await tester.pump();
  });

  testWidgets('email verification ignores duplicate resend taps in flight', (
    tester,
  ) async {
    final repository = _DuplicateGuardProfileRepository();
    await _pumpVerificationPage(tester, repository);

    final resendButton = find.byType(OutlinedButton);
    await tester.tap(resendButton);
    await tester.tap(resendButton);

    expect(repository.resendCalls, 1);

    repository.completeResend();
    await tester.pump();
  });

  testWidgets('email verification disables resend while cooldown is active', (
    tester,
  ) async {
    final repository = _DuplicateGuardProfileRepository();
    await _pumpVerificationPage(tester, repository, startResendCooldown: true);

    expect(find.text('Send code again (60s)'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(repository.resendCalls, 0);

    await tester.pump(const Duration(seconds: 60));

    expect(find.text('Send code again'), findsOneWidget);
  });

  testWidgets(
    'email verification keeps verify and resend offline until reconnect',
    (tester) async {
      final repository = _DuplicateGuardProfileRepository();
      final networkController = _TestEmailVerificationNetworkStatusController(
        false,
      );
      await _pumpVerificationPage(
        tester,
        repository,
        networkStatusController: networkController,
      );

      final context = tester.element(find.byType(EmailVerificationPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.templateFlowNetworkError), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(repository.verifyCalls, 0);
      expect(repository.resendCalls, 0);

      networkController.setHasInternet(true);
      await tester.pump();

      expect(find.text(text.templateFlowNetworkError), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(repository.verifyCalls, 1);
      repository.completeVerify();
      await tester.pump();
    },
  );

  testWidgets(
    'email verification cancels active verify when network goes offline',
    (tester) async {
      final repository = _DuplicateGuardProfileRepository();
      final networkController = _TestEmailVerificationNetworkStatusController(
        true,
      );
      await _pumpVerificationPage(
        tester,
        repository,
        networkStatusController: networkController,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(repository.verifyCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await tester.pump();

      final context = tester.element(find.byType(EmailVerificationPage));
      final text = AppLocalizations.of(context);
      expect(repository.verifyCancelToken?.isCancelled, isTrue);
      expect(find.text(text.templateFlowNetworkError), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      repository.completeVerify();
      await tester.pump();

      expect(find.text(text.emailVerificationConfirmedMessage), findsNothing);
      expect(find.byType(EmailVerificationPage), findsOneWidget);
    },
  );

  testWidgets(
    'email verification cancels active resend when network goes offline',
    (tester) async {
      final repository = _DuplicateGuardProfileRepository();
      final networkController = _TestEmailVerificationNetworkStatusController(
        true,
      );
      await _pumpVerificationPage(
        tester,
        repository,
        networkStatusController: networkController,
      );

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(repository.resendCancelToken?.isCancelled, isFalse);

      networkController.setHasInternet(false);
      await tester.pump();

      final context = tester.element(find.byType(EmailVerificationPage));
      final text = AppLocalizations.of(context);
      expect(repository.resendCancelToken?.isCancelled, isTrue);
      expect(find.text(text.templateFlowNetworkError), findsOneWidget);
      expect(find.text('Send code again (60s)'), findsNothing);

      repository.completeResend();
      await tester.pump();

      expect(
        find.text(text.emailVerificationResentFallbackMessage),
        findsNothing,
      );
      expect(find.text('Send code again (60s)'), findsNothing);
    },
  );
}

Future<void> _pumpVerificationPage(
  WidgetTester tester,
  _DuplicateGuardProfileRepository repository, {
  bool startResendCooldown = false,
  NetworkStatusController? networkStatusController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        if (networkStatusController != null)
          networkStatusControllerProvider.overrideWith(
            () => networkStatusController,
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmailVerificationPage(
          email: 'pet@example.com',
          startResendCooldown: startResendCooldown,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _DuplicateGuardProfileRepository extends ProfileRepository {
  _DuplicateGuardProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  var verifyCalls = 0;
  var resendCalls = 0;
  CancelToken? verifyCancelToken;
  CancelToken? resendCancelToken;

  final _verifyCompleter = Completer<AuthSession>();
  final _resendCompleter = Completer<void>();

  @override
  Future<AuthSession> verifyEmailCode({
    required String email,
    required String code,
    CancelToken? cancelToken,
  }) {
    verifyCalls++;
    verifyCancelToken = cancelToken;
    return _verifyCompleter.future;
  }

  @override
  Future<void> resendEmailVerificationCode({
    required String email,
    CancelToken? cancelToken,
  }) {
    resendCalls++;
    resendCancelToken = cancelToken;
    return _resendCompleter.future;
  }

  void completeVerify() {
    if (!_verifyCompleter.isCompleted) {
      _verifyCompleter.complete(_authSession());
    }
  }

  void completeResend() {
    if (!_resendCompleter.isCompleted) {
      _resendCompleter.complete();
    }
  }
}

class _TestEmailVerificationNetworkStatusController
    extends NetworkStatusController {
  _TestEmailVerificationNetworkStatusController(this.initialHasInternet);

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

AuthSession _authSession() {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.utc(2030),
    user: const MobileUserProfile(
      userId: 'user-1',
      email: 'pet@example.com',
      displayName: null,
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: MobileLegalAcceptanceStatus(
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
      roles: ['User'],
      avatar: null,
    ),
  );
}
