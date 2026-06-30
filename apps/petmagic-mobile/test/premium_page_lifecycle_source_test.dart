import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external stripe checkout schedules verification on app resume', () {
    final pageSource = File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsStringSync();

    expect(pageSource, contains('final openedForCheckout ='));
    expect(pageSource, contains('controller.markCheckoutOpened('));
    expect(pageSource, contains('_shouldReloadOnResume = true;'));
    expect(
      pageSource,
      contains(
        'if (appState == AppLifecycleState.resumed && _shouldReloadOnResume)',
      ),
    );
    expect(
      pageSource,
      contains('unawaited(controller.verifyCheckoutStatus());'),
    );
  });
}
