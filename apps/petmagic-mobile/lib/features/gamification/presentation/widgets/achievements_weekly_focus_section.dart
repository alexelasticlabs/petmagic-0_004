import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_text_mapper.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/challenge_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/streak_overview_card.dart';

class AchievementsWeeklyFocusSection extends StatelessWidget {
  const AchievementsWeeklyFocusSection({
    super.key,
    required this.streak,
    required this.challenges,
  });

  final StreakModel? streak;
  final List<WeeklyChallengeModel> challenges;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.gamificationWeekFocusTitle,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text.gamificationWeekFocusSubtitle,
          style: TextStyle(color: colors.textSoft, fontSize: 13, height: 1.35),
        ),
        if (streak != null) ...[
          const SizedBox(height: 12),
          StreakOverviewCard(streak: streak!),
        ],
        if (challenges.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...challenges.map(
            (challenge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChallengeCard(
                challenge: challenge,
                title: localizeChallengeTitle(text, challenge.titleKey),
                description: localizeChallengeDescription(
                  text,
                  challenge.descriptionKey,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
