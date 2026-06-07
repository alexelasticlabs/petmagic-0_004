import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet user-facing error mapper does not echo raw details', () {
    final walletPage = File(
      'lib/features/wallet/presentation/wallet_page.dart',
    ).readAsStringSync();

    final body = _functionBody(walletPage, '_friendlyError');

    expect(body, isNot(contains('return value;')));
    expect(body, contains('text.walletDataUnavailableFallback'));
    expect(body, contains('text.walletRedeemOfflineError'));
    expect(body, contains('text.walletPaymentUnavailableError'));

    expect(walletPage, isNot(contains('paymentResult.errorMessage?.trim()')));
    expect(walletPage, isNot(contains('result.errorMessage?.trim()')));
    expect(walletPage, isNot(contains('message: failureMessage')));
    expect(walletPage, contains('text.walletPaymentGatewayUnavailableError'));
  });
}

String _functionBody(String source, String functionName) {
  final start = source.indexOf('String $functionName(');
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
