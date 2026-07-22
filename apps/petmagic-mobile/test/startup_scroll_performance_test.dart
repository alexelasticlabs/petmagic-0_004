import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup pages use lazy vertical scroll surfaces', () {
    for (final policy in const [
      _StartupScrollPolicy(
        path: 'lib/features/startup/presentation/guest_welcome_page.dart',
        expectedListViewCount: 1,
      ),
    ]) {
      final source = File(policy.path).readAsStringSync();
      final contentSource = File(
        'lib/features/startup/presentation/guest_welcome_content.part.dart',
      ).readAsStringSync();
      final featureSectionsSource = File(
        'lib/features/startup/presentation/guest_welcome_feature_sections.part.dart',
      ).readAsStringSync();

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
      expect(source, contains("part 'guest_welcome_content.part.dart';"));
      expect(source, isNot(contains('class _WelcomeHeroCard')));
      expect(contentSource, contains('class _WelcomeHeroCard'));
      expect(
        source,
        contains("part 'guest_welcome_feature_sections.part.dart';"),
      );
      expect(featureSectionsSource, contains('class _FeatureMiniCard'));
      expect(featureSectionsSource, contains('class _WelcomeCtaBlock'));
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
