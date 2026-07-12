import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive subscriptions do not show an auto-renewal state', () {
    final source = File(
      'lib/features/premium/presentation/'
      'subscription_management_sections.part.dart',
    ).readAsStringSync();
    final autoRenewalStart = source.indexOf(
      'label: text.subscriptionAutoRenewLabel',
    );
    final surroundingSource = source.substring(
      source.lastIndexOf('if (summary.isPremium)', autoRenewalStart),
      autoRenewalStart,
    );

    expect(autoRenewalStart, greaterThanOrEqualTo(0));
    expect(surroundingSource, contains('if (summary.isPremium)'));
  });
}
