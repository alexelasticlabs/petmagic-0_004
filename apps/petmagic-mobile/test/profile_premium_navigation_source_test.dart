import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only active subscriptions can open subscription management', () {
    final source = [
      'lib/features/profile/presentation/profile_page.dart',
      'lib/features/profile/presentation/profile_page_view.part.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(
      source,
      contains(
        'summary?.isPremium == true && summary?.canManageSubscription == true',
      ),
    );
    expect(source, contains('!summary.isPremium'));
  });
}
