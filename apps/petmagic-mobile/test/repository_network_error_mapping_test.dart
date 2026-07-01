import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile repository maps connectivity failures to retryable copy', () {
    final source = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();
    final body = _methodBody(source, '_mapDioException');

    expect(body, contains('NetworkErrorMapper.isConnectivityIssue(error)'));
    expect(body, contains("'templates.network_unavailable'"));
    expect(body, contains('includeCause: false'));
  });

  test(
    'profile repository session-expired fallback avoids human detail text',
    () {
      final source = File(
        'lib/features/profile/data/profile_repository.dart',
      ).readAsStringSync();
      final body = _methodBody(source, '_mapDioException');

      expect(body, contains("title == 'users.not_found'"));
      expect(body, isNot(contains("detail == 'User not found.'")));
      expect(body, contains("'auth.session_expired'"));
    },
  );

  test(
    'premium repository maps connectivity and server failures explicitly',
    () {
      final source = File(
        'lib/features/premium/data/premium_repository.dart',
      ).readAsStringSync();
      final body = _methodBody(source, '_mapDioException');

      expect(body, contains('NetworkErrorMapper.isConnectivityIssue(error)'));
      expect(body, contains("'templates.network_unavailable'"));
      expect(body, contains('NetworkErrorMapper.isServerError(error)'));
      expect(body, contains("'premium.store_unavailable'"));
      expect(body, contains('includeCause: false'));
    },
  );

  test('support repository treats all connectivity issues as unavailable', () {
    final source = File(
      'lib/features/support/data/support_chat_repository.dart',
    ).readAsStringSync();
    final body = _methodBody(source, '_mapDioException');

    expect(body, contains('NetworkErrorMapper.isConnectivityIssue(error)'));
    expect(body, contains("'support.unavailable'"));
    expect(body, isNot(contains('NetworkErrorMapper.isConnectionUnavailable')));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'AppException\s+' + methodName + r'\s*\(',
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
