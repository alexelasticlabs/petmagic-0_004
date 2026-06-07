import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'email verification flow does not retain registration password',
    () async {
      final authEntry = await File(
        'lib/features/profile/presentation/auth_entry_page.dart',
      ).readAsString();
      final router = await File(
        'lib/app/router/app_router.dart',
      ).readAsString();
      final verificationPage = await File(
        'lib/features/profile/presentation/email_verification_page.dart',
      ).readAsString();

      expect(authEntry, isNot(contains('initialPassword')));
      expect(
        authEntry,
        isNot(contains("extra: <String, dynamic>{'initialPassword'")),
      );
      expect(router, isNot(contains('initialPassword')));
      expect(verificationPage, isNot(contains('initialPassword')));
      expect(verificationPage, isNot(contains('repository.login(')));
    },
  );

  test(
    'email verification maps errors without raw exception strings',
    () async {
      final verificationPage = await File(
        'lib/features/profile/presentation/email_verification_page.dart',
      ).readAsString();

      expect(verificationPage, isNot(contains('error.toString()')));
      expect(verificationPage, contains('mapProfileFeedbackMessage'));
    },
  );

  test('auth submit operations are guarded against duplicate starts', () async {
    final controller = await File(
      'lib/features/profile/presentation/profile_controller.dart',
    ).readAsString();

    for (final methodName in const [
      'login',
      'register',
      'authenticateWithProvider',
    ]) {
      final body = _methodBody(controller, methodName);
      expect(
        body,
        contains('if (state.isSaving) {\n      return;\n    }'),
        reason: '$methodName must ignore duplicate in-flight auth submits.',
      );
    }
  });

  test('profile presentation state does not retain auth tokens', () async {
    final controller = await File(
      'lib/features/profile/presentation/profile_controller.dart',
    ).readAsString();

    final stateClass = _classBody(controller, 'ProfileState');

    expect(stateClass, isNot(contains('AuthSession')));
    expect(stateClass, isNot(contains('accessToken')));
    expect(stateClass, isNot(contains('refreshToken')));
    expect(stateClass, contains('bool get isAuthenticated => profile != null'));
    expect(controller, isNot(contains('accessToken: session.accessToken')));
    expect(controller, isNot(contains('refreshToken: session.refreshToken')));
  });
}

String _methodBody(String source, String methodName) {
  final methodIndex = source.indexOf(RegExp('\\b$methodName\\b'));
  if (methodIndex < 0) {
    fail('Method $methodName was not found.');
  }

  final asyncBodyIndex = source.indexOf('async {', methodIndex);
  final openBraceIndex = asyncBodyIndex < 0
      ? source.indexOf('{', methodIndex)
      : source.indexOf('{', asyncBodyIndex);
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

String _classBody(String source, String className) {
  final classIndex = source.indexOf(RegExp('\\bclass\\s+$className\\b'));
  if (classIndex < 0) {
    fail('Class $className was not found.');
  }

  final openBraceIndex = source.indexOf('{', classIndex);
  if (openBraceIndex < 0) {
    fail('Class $className has no body.');
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

  fail('Class $className body did not close.');
}
