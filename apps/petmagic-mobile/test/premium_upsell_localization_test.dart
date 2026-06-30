import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'profile_page_test_source.dart';
import 'wallet_page_test_source.dart';

void main() {
  test('premium upsell cards use shared localized copy', () async {
    final sources = <String, String>{
      'wallet_page': readWalletPageLibrarySource(),
      'lib/features/profile/presentation/profile_page.dart':
          readProfilePageLibrarySource(),
    };

    for (final source in sources.values) {
      expect(source, contains('premiumUpsellHeadline'));
      expect(source, contains('premiumUpsellSubtitle'));
      expect(source, contains('walletBalanceUnit'));
      expect(source, isNot(contains('Premium is better')));
      expect(source, isNot(contains('Premium выгоднее')));
      expect(source, isNot(contains("PawSpark';")));
      expect(source, isNot(contains("languageCode.toLowerCase() == 'ru'")));
    }

    final rewardsPageSource = await File(
      'lib/features/rewards/presentation/rewards_page.dart',
    ).readAsString();
    final rewardsReferralSource = await File(
      'lib/features/rewards/presentation/rewards_page_referral_cards.dart',
    ).readAsString();
    final rewardsUpsellSource = await File(
      'lib/features/rewards/presentation/rewards_page_premium_upsell.part.dart',
    ).readAsString();
    final rewardsSource =
        '$rewardsPageSource\n$rewardsReferralSource\n$rewardsUpsellSource';

    expect(
      rewardsPageSource,
      contains("part 'rewards_page_premium_upsell.part.dart';"),
    );
    expect(rewardsReferralSource, isNot(contains('_RewardsGoldShimmerButton')));
    expect(rewardsUpsellSource, contains('premiumUpsellHeadline'));
    expect(rewardsUpsellSource, contains('premiumUpsellSubtitle'));
    expect(rewardsSource, isNot(contains('Premium is better')));
    expect(rewardsSource, isNot(contains('Premium выгоднее')));
    expect(
      rewardsSource,
      isNot(contains("languageCode.toLowerCase() == 'ru'")),
    );
  });

  test(
    'premium upsell localization keys exist in every supported locale',
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
        'premiumUpsellHeadline',
        'premiumUpsellSubtitle',
        'premiumUpsellWeeklyCredits',
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
