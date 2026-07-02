import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external stripe checkout schedules verification on app resume', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final lifecycleBody = _methodBody(
      pageSource,
      '_handlePremiumPageLifecycleChange',
    );

    expect(pageSource, contains('final openedForCheckout ='));
    expect(pageSource, contains('controller.markCheckoutOpened('));
    expect(pageSource, contains('_shouldReloadOnResume = true;'));
    expect(
      lifecycleBody,
      contains(
        'if (appState == AppLifecycleState.resumed && _shouldReloadOnResume)',
      ),
    );
    expect(
      lifecycleBody,
      contains('if (!ref.read(appLaunchControllerProvider).isAuthenticated) {'),
    );
    expect(
      lifecycleBody,
      contains('if (!ref.read(networkStatusControllerProvider).hasInternet) {'),
    );
    expect(
      lifecycleBody,
      contains('unawaited(controller.verifyCheckoutStatus());'),
    );
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:void|Future<[^>]+>)\s+' +
        methodName +
        r'\s*\([^)]*\)\s*(?:async\s*)?\{',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = source.indexOf('{', methodMatch.start);
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
