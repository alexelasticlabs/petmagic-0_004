import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API logging error context uses endpoint path without query', () {
    final source = File(
      'lib/core/network/api_logging_interceptor.dart',
    ).readAsStringSync();

    expect(source, contains("'path': _requestPath(err.requestOptions),"));
    expect(source, isNot(contains("'path': err.requestOptions.path,")));
    expect(source, contains('return stripQuery(options.path);'));
    expect(source, contains('return stripQuery(options.uri.path);'));
  });

  test('API logging skips expected cancellation noise', () {
    final source = File(
      'lib/core/network/api_logging_interceptor.dart',
    ).readAsStringSync();
    final onErrorBody = _methodBody(source, 'onError');

    expect(onErrorBody, contains('CancelToken.isCancel(err)'));
    expect(
      onErrorBody.indexOf('CancelToken.isCancel(err)'),
      lessThan(onErrorBody.indexOf('AppLogger.error')),
    );
    expect(onErrorBody, contains('handler.next(err);\n      return;'));
  });

  test('validation fields logging filters sensitive field names', () {
    final source = File(
      'lib/core/network/api_logging_interceptor.dart',
    ).readAsStringSync();

    expect(source, contains('_isSensitiveFieldName'));
    expect(source, contains("'password'"));
    expect(source, contains("'token'"));
    expect(source, contains("'jwt'"));
    expect(source, contains("'secret'"));
    expect(source, contains("'credential'"));
    expect(source, contains("'authorization'"));
    expect(source, contains("'email'"));
    expect(source, contains("'phone'"));
    expect(source, contains("'receipt'"));
    expect(source, contains("'cookie'"));
    expect(source, contains("'signature'"));
    expect(source, contains("normalized == 'code'"));
    expect(source, contains("normalized.endsWith('code')"));
    expect(source, contains("normalized.contains('session')"));
    expect(source, contains("normalized.contains('ticket')"));
    expect(source, contains("normalized.contains('otp')"));
    expect(source, contains('.where((key) => !_isSensitiveFieldName(key))'));
  });

  test(
    'API logging does not persist raw problem detail from server payloads',
    () {
      final source = File(
        'lib/core/network/api_logging_interceptor.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("'problem_detail'")));
      expect(
        source,
        isNot(contains("_problemString(response?.data, 'detail')")),
      );
    },
  );

  test(
    'API logging uses RequestIdentity secure default unless random is injected',
    () {
      final source = File(
        'lib/core/network/api_logging_interceptor.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('ApiLoggingInterceptor({Random? random}) : _random = random;'),
      );
      expect(source, contains('final Random? _random;'));
      expect(
        source,
        contains('RequestIdentity.createRequestId(random: _random)'),
      );
      expect(
        source,
        contains('RequestIdentity.createCorrelationId(random: _random)'),
      );
      expect(source, isNot(contains('random ?? Random()')));
    },
  );
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
