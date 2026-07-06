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
      contains('unawaited(_resumePremiumCheckoutSyncIfOnline());'),
    );
    expect(pageSource, contains('unawaited(_loadPremiumIfOnline());'));
    expect(
      pageSource,
      contains(
        'ref.listen<NetworkStatusState>(networkStatusControllerProvider, (',
      ),
    );
    expect(
      pageSource,
      contains('unawaited(_loadPremiumIfOnline(refresh: true));'),
    );
    expect(
      pageSource,
      contains('unawaited(_resumePremiumCheckoutSyncIfOnline());'),
    );
  });

  test('paywall feedback submit is best-effort and does not block close', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final feedbackBody = _methodBody(pageSource, '_maybeAskPaywallFeedback');

    expect(feedbackBody, contains('try {'));
    expect(feedbackBody, contains('submitFeedback('));
    expect(feedbackBody, contains('} catch (error, stackTrace) {'));
    expect(feedbackBody, contains("feature: 'Premium.PaywallFeedback'"));
    expect(feedbackBody, contains("operation: 'submit'"));
    expect(feedbackBody, contains("'category': result.category"));
    expect(feedbackBody, isNot(contains("'message': result.message")));
    expect(feedbackBody, isNot(contains("'feedback': result.message")));
  });

  test('paywall feedback removes legacy raw-scope cooldown key', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final feedbackBody = _methodBody(pageSource, '_maybeAskPaywallFeedback');
    final legacyCleanupIndex = feedbackBody.indexOf(
      'await preferences.remove(legacyLastShownKey);',
    );
    final cooldownReturnIndex = feedbackBody.indexOf(
      'now.difference(lastShown) < _paywallFeedbackCooldown',
    );

    expect(feedbackBody, contains('legacyLastShownKey != lastShownKey'));
    expect(legacyCleanupIndex, isNonNegative);
    expect(cooldownReturnIndex, isNonNegative);
    expect(legacyCleanupIndex, lessThan(cooldownReturnIndex));
  });

  test('paywall feedback sheet disposes its text controller after close', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();
    final sheetBody = _methodBody(pageSource, '_showPaywallFeedbackSheet');

    expect(sheetBody, contains('final controller = TextEditingController();'));
    expect(sheetBody, contains('controller: controller,'));
    expect(sheetBody, contains(').whenComplete(controller.dispose);'));
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
