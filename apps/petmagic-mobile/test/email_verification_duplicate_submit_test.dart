import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
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
}

Future<void> _pumpVerificationPage(
  WidgetTester tester,
  _DuplicateGuardProfileRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmailVerificationPage(email: 'pet@example.com'),
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

  final _verifyCompleter = Completer<void>();
  final _resendCompleter = Completer<void>();

  @override
  Future<void> verifyEmailCode({required String email, required String code}) {
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
      _verifyCompleter.complete();
    }
  }

  void completeResend() {
    if (!_resendCompleter.isCompleted) {
      _resendCompleter.complete();
    }
  }
}
