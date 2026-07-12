import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only active subscriptions can open subscription management', () {
    final source = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'summary?.isPremium == true && summary?.canManageSubscription == true',
      ),
    );
    expect(source, contains('!summary.isPremium'));
  });
}
