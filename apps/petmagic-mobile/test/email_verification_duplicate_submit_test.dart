import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
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
}

Future<void> _pumpVerificationPage(
  WidgetTester tester,
  _DuplicateGuardProfileRepository repository, {
  bool startResendCooldown = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
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

  final _verifyCompleter = Completer<AuthSession>();
  final _resendCompleter = Completer<void>();

  @override
  Future<AuthSession> verifyEmailCode({
    required String email,
    required String code,
  }) {
    verifyCalls++;
    return _verifyCompleter.future;
  }

  @override
  Future<void> resendEmailVerificationCode({required String email}) {
    resendCalls++;
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
