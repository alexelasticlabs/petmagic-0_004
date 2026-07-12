import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/xp_progress_bar.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class GamificationHighlightsCard extends StatelessWidget {
  const GamificationHighlightsCard({
    super.key,
    this.summary,
    this.unlockedAchievementsCount,
    this.totalAchievementsCount,
    this.onOpenHub,
    this.onPetTap,
  });

  final GamificationSummaryModel? summary;
  final int? unlockedAchievementsCount;
  final int? totalAchievementsCount;
  final VoidCallback? onOpenHub;
  final VoidCallback? onPetTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final streak = summary?.streak;
    final topPet = summary?.topPets.isNotEmpty == true
        ? summary!.topPets.first
        : null;
    final achievementsValue =
        unlockedAchievementsCount != null && totalAchievementsCount != null
        ? '${unlockedAchievementsCount!}/${totalAchievementsCount!}'
        : '—';
    final weeklyGoalsValue = '${summary?.activeChallenges.length ?? 0}';

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
          PressableScale(
            key: const ValueKey('profile_gamification_hub'),
            onTap: onOpenHub,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: colors.surfaceStrong.withValues(alpha: 0.28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD86B), Color(0xFFFF934D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🏆', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.gamificationYourProgress,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          text.gamificationHubEntrySubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: colors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colors.textSoft,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  emoji: '🔥',
                  label: text.gamificationStreakTitle,
                  value: text.gamificationDayStreak(streak?.currentStreak ?? 0),
                  color: const Color(0xFFFF6D00),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  key: const ValueKey('profile_gamification_achievements_stat'),
                  emoji: '🏅',
                  label: text.gamificationAchievementsTitle,
                  value: achievementsValue,
                  color: const Color(0xFFFFD700),
                  onTap: onOpenHub,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  emoji: '🎯',
                  label: text.gamificationWeekFocusTitle,
                  value: weeklyGoalsValue,
                  color: const Color(0xFF53C3A6),
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
                            '${text.gamificationTopPet} · ${text.gamificationLevel(topPet.level)}',
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
                    Icon(Icons.chevron_right, size: 18, color: colors.textSoft),
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
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String emoji;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    final content = Container(
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: colors.textSoft)),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return PressableScale(onTap: onTap, child: content);
  }
}
