import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium checkout error mapper does not echo raw details', () {
    final premiumPage = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();

    final body = _functionBody(premiumPage, '_resolveCheckoutErrorMessage');

    expect(body, isNot(contains('return value;')));
    expect(body, contains('text.premiumCheckoutFailed'));
    expect(body, contains('text.premiumPurchaseCancelled'));
    expect(body, contains('text.premiumStoreUnavailable'));
    expect(body, contains('text.premiumStoreProductUnavailable'));
    expect(body, contains('text.templateFlowNetworkError'));
  });

  test('premium controller keeps network error key safe', () {
    final premiumController = File(
      'lib/features/premium/presentation/premium_controller.dart',
    ).readAsStringSync();

    final body = _functionBody(premiumController, '_isSafePremiumErrorKey');

    expect(body, contains("value == 'templates.network_unavailable'"));
  });
}

String _functionBody(String source, String functionName) {
  final start = source.indexOf(
    RegExp(r'(?:String|bool) ' + functionName + r'\('),
  );
  expect(start, isNonNegative, reason: '$functionName not found');

  final bodyStart = source.indexOf('{', start);
  expect(bodyStart, isNonNegative, reason: '$functionName body not found');

  var depth = 0;
  for (var index = bodyStart; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  fail('$functionName body did not close');
}
