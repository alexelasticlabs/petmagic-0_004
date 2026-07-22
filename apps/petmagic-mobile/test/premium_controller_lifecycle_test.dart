import 'package:flutter_test/flutter_test.dart';

import 'premium_controller_test_source.dart';

void main() {
  test('premium lifecycle side effects are initialized outside build', () {
    final source = readPremiumControllerLibrarySource();
    final buildBody = _methodBody(source, 'build');
    final lifecycleBody = _methodBody(source, '_ensurePremiumLifecycleStarted');

    expect(buildBody, contains('_ensurePremiumLifecycleStarted();'));
    expect(buildBody, isNot(contains('_repository.purchaseUpdates.listen')));
    expect(buildBody, isNot(contains('_purchaseSubscription?.cancel()')));
    expect(source, contains('bool _premiumLifecycleStarted = false;'));
    expect(lifecycleBody, contains('if (!_premiumLifecycleStarted)'));
    expect(lifecycleBody, contains('_premiumLifecycleStarted = true;'));
    expect(lifecycleBody, contains('ref.onDispose'));
    expect(lifecycleBody, contains('premiumPurchaseUpdatesProvider'));
    expect(
      lifecycleBody,
      contains('ref.listen<AsyncValue<List<StorePurchaseDetails>>>'),
    );
    expect(lifecycleBody, contains('_handlePurchaseUpdates(purchases)'));
  });

  test('store purchase verification is cancelled with premium lifecycle', () {
    final source = readPremiumControllerLibrarySource();
    final verifyBody = _methodBody(source, '_verifyStorePurchase');

    expect(
      verifyBody,
      contains(
        'final verificationRequestCancellation =\n        _startCheckoutVerificationRequestCancellation();',
      ),
    );
    expect(
      verifyBody,
      contains('cancelToken: verificationRequestCancellation'),
    );
    expect(verifyBody, contains('verificationRequestCancellation.isCancelled'));
    expect(verifyBody, contains('on RequestCancelledException'));
    expect(
      verifyBody,
      contains(
        '_clearActiveCheckoutVerification(verificationRequestCancellation);',
      ),
    );
    expect(verifyBody, contains('} on RequestCancelledException {'));
    expect(verifyBody, contains('return;'));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:@override\s+)?(?:PremiumState|void|Future<[^>]+>)\s+' +
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
