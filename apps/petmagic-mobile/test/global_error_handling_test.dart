import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main wires global error handlers through safe AppLogger paths', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('FlutterError.onError'));
    expect(source, contains('PlatformDispatcher.instance.onError'));
    expect(source, contains('runZonedGuarded<Future<void>>'));
    expect(source, contains('ErrorWidget.builder = _buildSafeErrorWidget'));
    expect(source, contains("operation: 'flutter_error'"));
    expect(source, contains("operation: 'platform_dispatcher_error'"));
    expect(source, contains("operation: 'zoned_guarded_error'"));
    expect(source, contains("operation: 'error_widget'"));
    expect(source, contains("message: 'Unhandled Flutter framework error'"));
    expect(source, contains('if (kDebugMode)'));
    expect(source, contains('return const _ProductionErrorFallback();'));
    expect(source, isNot(contains('print(')));
    expect(source, isNot(contains('debugPrint(')));

    final installBody = _methodBody(source, '_installGlobalErrorHandlers');
    expect(installBody, isNot(contains('details.exceptionAsString()')));
  });

  test('main does not block first frame on Firebase initialization', () {
    final source = File('lib/main.dart').readAsStringSync();
    final mainBody = _methodBody(source, 'main');

    expect(mainBody, contains('unawaited(_configureFirebaseMessagingAsync())'));
    expect(mainBody, contains('runApp('));
    expect(mainBody, contains('overrides: mobileProviderOverrides'));
    expect(mainBody, contains('child: const PetMagicApp()'));
    expect(mainBody, isNot(contains('await _initializeFirebase()')));
    expect(
      mainBody.indexOf('unawaited(_configureFirebaseMessagingAsync())'),
      lessThan(mainBody.indexOf('runApp(')),
    );
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
