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

    final profileSource =
        sources['lib/features/profile/presentation/profile_page.dart']!;
    expect(profileSource, contains('final accent = colors.gold;'));
    expect(
      profileSource,
      contains(
        'final premiumLabelColor = isLight ? colors.textStrong : colors.gold;',
      ),
    );
    expect(profileSource, isNot(contains('const accent = Color(0xFFFFC107)')));
    expect(profileSource, isNot(contains('color: Color(0xFFFFD666)')));
    expect(profileSource, contains('child: ProfileGlassCard('));
    expect(
      profileSource,
      contains('color: colors.accent.withValues(alpha: 0.12)'),
    );
    expect(
      profileSource,
      isNot(contains('const cardAccent = Color(0xFF00F2A6)')),
    );
    expect(profileSource, isNot(contains('const Color(0xFF0A7A4D)')));

    final walletSource = sources['wallet_page']!;
    expect(walletSource, contains('return ProfileGlassCard('));
    expect(walletSource, contains('PawSparkIcon(size: compact ? 36 : 40'));
    expect(walletSource, contains('final accent = colors.gold;'));
    expect(
      walletSource,
      contains(
        'final chipForeground = isDark ? colors.gold : colors.on(chipBg);',
      ),
    );
    expect(walletSource, contains('tone: colors.gold'));
    expect(
      walletSource,
      isNot(contains('const cardAccent = Color(0xFF00F2A6)')),
    );
    expect(walletSource, isNot(contains('const accent = Color(0xFFFFC107)')));
    expect(walletSource, isNot(contains('const Color(0xFF43606A)')));
    expect(walletSource, isNot(contains('const Color(0xFF32485A)')));
    expect(walletSource, isNot(contains('const Color(0xFFFFD666)')));

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
    expect(rewardsUpsellSource, contains('final accent = colors.gold;'));
    expect(rewardsUpsellSource, contains('color: colors.textSoft'));
    expect(
      rewardsUpsellSource,
      contains('color: isLight ? colors.textStrong : accent'),
    );
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFFD7B35D)')));
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFFEABA47)')));
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFF1E1608)')));
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFFEABF55)')));
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFF3B3324)')));
    expect(rewardsUpsellSource, isNot(contains('const Color(0xFFE3DFD2)')));
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

  test(
    'premium benefit copy matches the recurring PawSpark entitlement',
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

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        expect(
          source,
          contains('"premiumBenefitAiGenerationsTitle": "40 PawSpark"'),
        );
        expect(source, contains('"premiumBenefitAiGenerationsSubtitle"'));
        expect(source, isNot(contains('30 AI-генераций')));
        expect(source, isNot(contains('30 AI generations')));
        expect(source, isNot(contains('30 KI-Generationen')));
      }
    },
  );
}
