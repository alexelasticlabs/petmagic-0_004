import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment and generation controllers do not expose raw exceptions', () {
    final sources = [
      File(
        'lib/features/premium/presentation/premium_controller.dart',
      ).readAsStringSync(),
      File(
        'lib/features/premium/presentation/premium_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/wallet/presentation/wallet_controller.dart',
      ).readAsStringSync(),
      File(
        'lib/features/templates/presentation/generation_history_controller.dart',
      ).readAsStringSync(),
      File(
        'lib/features/templates/presentation/template_generation_controller.dart',
      ).readAsStringSync(),
    ];

    for (final source in sources) {
      expect(source, isNot(contains('error.toString()')));
      expect(source, isNot(contains('exception.toString()')));
    }

    expect(sources[0], contains('_premiumErrorMessage(error,'));
    expect(sources[1], isNot(contains('result.errorMessage?.trim()')));
    expect(sources[1], isNot(contains('message: failureMessage')));
    expect(sources[2], contains('_errorMessage(error)'));
    expect(sources[3], contains('_historyLoadErrorMessage(error)'));
    expect(sources[4], contains('_isSafeGenerationErrorKey(message)'));
  });
}
