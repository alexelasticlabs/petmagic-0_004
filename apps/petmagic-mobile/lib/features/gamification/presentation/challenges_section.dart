import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/challenge_card.dart';

class ChallengesSection extends ConsumerWidget {
  const ChallengesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final challengesAsync = ref.watch(weeklyChallengesProvider);

    return challengesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (challenges) {
        if (challenges.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Weekly Challenges',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textStrong,
              ),
            ),
            const SizedBox(height: 10),
            ...challenges.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChallengeCard(
                  challenge: c,
                  title: _resolveTitle(c.titleKey),
                  description: _resolveDescription(c.descriptionKey),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _resolveTitle(String key) {
    switch (key) {
      case 'gamificationChallengeGenerateImages':
        return 'Generate Images';
      case 'gamificationChallengeTryTemplates':
        return 'Try Different Templates';
      case 'gamificationChallengeShareCreations':
        return 'Share Creations';
      default:
        return key;
    }
  }

  static String _resolveDescription(String key) {
    switch (key) {
      case 'gamificationChallengeGenerateImagesDesc':
        return 'Generate images using any template';
      case 'gamificationChallengeTryTemplatesDesc':
        return 'Use different templates this week';
      case 'gamificationChallengeShareCreationsDesc':
        return 'Share your creations with friends';
      default:
        return key;
    }
  }
}
