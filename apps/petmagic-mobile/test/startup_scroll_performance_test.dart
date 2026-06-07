import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup pages use lazy vertical scroll surfaces', () {
    for (final policy in const [
      _StartupScrollPolicy(
        path: 'lib/features/startup/presentation/guest_welcome_page.dart',
        expectedListViewCount: 1,
      ),
      _StartupScrollPolicy(
        path: 'lib/features/startup/presentation/onboarding_page.dart',
        expectedListViewCount: 1,
      ),
    ]) {
      final source = File(policy.path).readAsStringSync();

      expect(
        'ListView('.allMatches(source).length,
        greaterThanOrEqualTo(policy.expectedListViewCount),
        reason: '${policy.path} should keep vertical startup content lazy.',
      );
      expect(
        source,
        isNot(contains('SingleChildScrollView(')),
        reason:
            '${policy.path} must not eagerly build the startup scroll tree.',
      );
      expect(
        source,
        isNot(contains('return LayoutBuilder(')),
        reason:
            '${policy.path} should not wrap vertical startup scroll in LayoutBuilder.',
      );
    }
  });
}

class _StartupScrollPolicy {
  const _StartupScrollPolicy({
    required this.path,
    required this.expectedListViewCount,
  });

  final String path;
  final int expectedListViewCount;
}
