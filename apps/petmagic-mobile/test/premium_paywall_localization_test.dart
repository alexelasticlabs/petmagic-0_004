import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium paywall feedback copy comes from app localizations', () async {
    final source = await File(
      'lib/features/premium/presentation/premium_page.dart',
    ).readAsString();

    expect(source, contains('premiumPaywallFeedbackTitle'));
    expect(source, contains('premiumPaywallFeedbackCommentLabel'));
    expect(source, contains('premiumPaywallFeedbackThanksMessage'));
    expect(source, isNot(contains("What stopped you?")));
    expect(source, isNot(contains("Что остановило?")));
    expect(source, isNot(contains("Thanks for the feedback")));
  });

  test(
    'premium paywall feedback keys exist in every supported locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const requiredKeys = <String>[
        'premiumPaywallFeedbackTitle',
        'premiumPaywallFeedbackCommentLabel',
        'premiumPaywallFeedbackCommentHint',
        'premiumPaywallFeedbackSubmitAction',
        'premiumPaywallFeedbackThanksMessage',
        'premiumPaywallFeedbackOptionExpensive',
        'premiumPaywallFeedbackOptionLowValue',
        'premiumPaywallFeedbackOptionPaymentProblem',
        'premiumPaywallFeedbackOptionJustBrowsing',
        'premiumPaywallFeedbackOptionOther',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in requiredKeys) {
          expect(source, contains('"$key"'), reason: '$path is missing $key');
        }
      }
    },
  );
}
