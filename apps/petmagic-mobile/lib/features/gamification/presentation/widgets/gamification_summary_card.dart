import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/xp_progress_bar.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class GamificationHighlightsCard extends StatelessWidget {
  const GamificationHighlightsCard({
    super.key,
    this.summary,
    this.onStreakTap,
    this.onAchievementsTap,
    this.onPetTap,
  });

  final GamificationSummaryModel? summary;
  final VoidCallback? onStreakTap;
  final VoidCallback? onAchievementsTap;
  final VoidCallback? onPetTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final streak = summary?.streak;
    final topPet = summary?.topPets.isNotEmpty == true
        ? summary!.topPets.first
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1.1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.surfaceStrong.withValues(alpha: 0.97),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
                    color: colors.textStrong,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: onStreakTap,
                  child: _MiniStat(
                    emoji: '🔥',
                    label: 'Streak',
                    value: streak != null ? '${streak.currentStreak} days' : '0 days',
                    color: const Color(0xFFFF6D00),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  onTap: onAchievementsTap,
                  child: _MiniStat(
                    emoji: '🏆',
                    label: 'Achievements',
                    value: summary != null
                        ? '${summary!.recentAchievements.where((a) => a.isUnlocked).length}'
                        : '0',
                    color: const Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
          if (topPet != null) ...[
            const SizedBox(height: 10),
            PressableScale(
              onTap: onPetTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colors.surfaceStrong.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    EvolutionBadge(
                      evolutionStage: topPet.evolutionStage,
                      level: topPet.level,
                      size: 36,
                      showGlow: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Pet — Level ${topPet.level}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textStrong,
                            ),
                          ),
                          const SizedBox(height: 4),
                          XpProgressBar(
                            currentXp: topPet.xp,
                            xpForCurrentLevel: topPet.xpForCurrentLevel,
                            xpForNextLevel: topPet.xpForNextLevel,
                            level: topPet.level,
                            evolutionStage: topPet.evolutionStage,
                            height: 6,
                            showLabels: false,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.textSoft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  final String emoji;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.surfaceStrong.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
                    color: colors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}
