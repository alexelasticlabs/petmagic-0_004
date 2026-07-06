import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile success flows normalize wrapped success keys', () {
    final passwordResetSource = File(
      'lib/features/profile/presentation/password_reset_page.dart',
    ).readAsStringSync();
    final passwordChangeSource = File(
      'lib/features/profile/presentation/password_change_page.dart',
    ).readAsStringSync();
    final profilePageSource = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    expect(
      passwordResetSource,
      contains('normalizeProfileSuccessKey(nextState.successMessage)'),
    );
    expect(
      passwordChangeSource,
      contains('normalizeProfileSuccessKey(nextState.successMessage)'),
    );
    expect(profilePageSource, contains('mapProfileSuccessMessage('));
    expect(
      passwordResetSource,
      isNot(
        contains("nextState.successMessage == 'auth.password_reset_success'"),
      ),
    );
    expect(
      passwordChangeSource,
      isNot(
        contains("nextState.successMessage == 'auth.password_reset_success'"),
      ),
    );
    expect(
      profilePageSource,
      isNot(contains("next.successMessage == 'logout'")),
    );
  });

  test(
    'profile logout unregisters push token before clearing auth session',
    () {
      final source = File(
        'lib/features/profile/presentation/profile_controller.dart',
      ).readAsStringSync();
      final logoutBody = _methodBody(source, 'logout');
      final cleanupBody = _methodBody(
        source,
        '_unregisterPushTokenBeforeLogout',
      );

      final cleanupIndex = logoutBody.indexOf(
        'await _unregisterPushTokenBeforeLogout();',
      );
      final repositoryLogoutIndex = logoutBody.indexOf(
        'await repository.logout();',
      );

      expect(cleanupIndex, isNonNegative);
      expect(repositoryLogoutIndex, isNonNegative);
      expect(cleanupIndex, lessThan(repositoryLogoutIndex));
      expect(cleanupBody, contains('PushTokenRegistrar('));
      expect(cleanupBody, contains('templateGenerationRepositoryProvider'));
      expect(cleanupBody, contains('supportChatRepositoryProvider'));
      expect(cleanupBody, contains('walletRepositoryProvider'));
      expect(cleanupBody, contains('registrar.unregisterToken('));
      expect(cleanupBody, contains('token: token,'));
      expect(cleanupBody, contains('canContinue: () => ref.mounted'));
      expect(cleanupBody, contains('final cachedToken ='));
      expect(
        cleanupBody.indexOf('if (!ref.mounted)'),
        greaterThan(cleanupBody.indexOf('registrar.readRegisteredToken()')),
      );
      expect(
        cleanupBody.indexOf('await _readFirebaseToken()'),
        greaterThan(cleanupBody.indexOf('if (!ref.mounted)')),
      );
      expect(cleanupBody, isNot(contains("'token'")));
      expect(cleanupBody, isNot(contains('context: {')));
    },
  );

  test(
    'profile account deletion unregisters push token before deleting account',
    () {
      final source = File(
        'lib/features/profile/presentation/profile_controller.dart',
      ).readAsStringSync();
      final deleteAccountBody = _methodBody(source, 'deleteAccount');

      final cleanupIndex = deleteAccountBody.indexOf(
        'await _unregisterPushTokenBeforeLogout();',
      );
      final deleteAccountIndex = deleteAccountBody.indexOf(
        'await repository.deleteCurrentAccount(',
      );

      expect(cleanupIndex, isNonNegative);
      expect(deleteAccountIndex, isNonNegative);
      expect(cleanupIndex, lessThan(deleteAccountIndex));
    },
  );

  test('profile legal and verification errors use theme error color', () {
    final emailVerificationSource = File(
      'lib/features/profile/presentation/email_verification_page.dart',
    ).readAsStringSync();
    final legalGateSource = File(
      'lib/features/profile/presentation/legal_acceptance_gate_page.dart',
    ).readAsStringSync();

    expect(emailVerificationSource, contains('context.petMagicColors'));
    expect(legalGateSource, contains('context.petMagicColors'));
    expect(emailVerificationSource, contains('TextStyle(color: colors.error)'));
    expect(legalGateSource, contains('TextStyle(color: colors.error)'));
    expect(emailVerificationSource, isNot(contains('Colors.red')));
    expect(legalGateSource, isNot(contains('Colors.red')));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:void|Future<[^>]+>)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
