import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievement_card.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  static const routePath = '/profile/achievements';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final achievementsAsync = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: achievementsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          error: (error, _) => Center(
            child: Text(
              'Failed to load achievements',
              style: TextStyle(color: colors.textSoft),
            ),
          ),
          data: (achievements) {
            final unlocked =
                achievements.where((a) => a.isUnlocked).length;
            final total = achievements.length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _Header(
                      unlocked: unlocked,
                      total: total,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final achievement = achievements[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AchievementCard(
                            achievement: achievement,
                            title: _resolveTitle(achievement.titleKey),
                            description:
                                _resolveDescription(achievement.descriptionKey),
                          ),
                        );
                      },
                      childCount: achievements.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _resolveTitle(String key) {
    switch (key) {
      case 'achievementFirstMagic':
        return 'First Magic';
      case 'achievementApprentice10':
        return 'Apprentice';
      case 'achievementMagician100':
        return 'Magician';
      case 'achievementArchmage500':
        return 'Archmage';
      case 'achievementStreak3':
        return 'Getting Warmed Up';
      case 'achievementStreak7':
        return 'Week Warrior';
      case 'achievementStreak14':
        return 'Two Week Champion';
      case 'achievementStreak30':
        return 'Monthly Master';
      case 'achievementPackLeader':
        return 'Pack Leader';
      case 'achievementEvolutionBaby':
        return 'First Steps';
      case 'achievementEvolutionLegendary':
        return 'Legendary Guardian';
      case 'achievementTrendsetter':
        return 'Trendsetter';
      case 'achievementDailyRitual':
        return 'Daily Ritual';
      case 'achievementTemplateCollector':
        return 'Template Collector';
      case 'achievementNightOwl':
        return 'Night Owl';
      default:
        return key;
    }
  }

  static String _resolveDescription(String key) {
    switch (key) {
      case 'achievementFirstMagicDesc':
        return 'Create your first AI generation';
      case 'achievementApprentice10Desc':
        return 'Complete 10 generations';
      case 'achievementMagician100Desc':
        return 'Complete 100 generations';
      case 'achievementArchmage500Desc':
        return 'Complete 500 generations';
      case 'achievementStreak3Desc':
        return 'Maintain a 3-day streak';
      case 'achievementStreak7Desc':
        return 'Maintain a 7-day streak';
      case 'achievementStreak14Desc':
        return 'Maintain a 14-day streak';
      case 'achievementStreak30Desc':
        return 'Maintain a 30-day streak';
      case 'achievementPackLeaderDesc':
        return 'Have 5 pets';
      case 'achievementEvolutionBabyDesc':
        return 'Evolve a pet to Baby stage';
      case 'achievementEvolutionLegendaryDesc':
        return 'Evolve a pet to Legendary stage';
      case 'achievementTrendsetterDesc':
        return 'Use Template of the Day';
      case 'achievementDailyRitualDesc':
        return 'Generate 5 times in one day';
      case 'achievementTemplateCollectorDesc':
        return 'Use 20 different templates';
      case 'achievementNightOwlDesc':
        return 'Generate between 2 AM and 5 AM';
      default:
        return key;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final progress = total > 0 ? unlocked / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                backgroundColor: colors.surfaceStrong.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFFD700),
                ),
                strokeWidth: 4,
              ),
              Text(
                '$unlocked',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$unlocked / $total Unlocked',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                  color: colors.textStrong,
              ),
            ),
            Text(
              'Keep generating to unlock more!',
              style: TextStyle(
                fontSize: 12,
                  color: colors.textSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
