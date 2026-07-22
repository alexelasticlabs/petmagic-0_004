import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';
import 'package:petmagic_mobile/shared/gamification/xp_progress_bar.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

/// Profile-owned composition of gamification highlights.
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
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 22,
                      color: Color(0xFF4A2B00),
                    ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columnCount = constraints.maxWidth < 300 ? 2 : 3;
              final itemWidth =
                  (constraints.maxWidth - (columnCount - 1) * gap) /
                  columnCount;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      label: text.gamificationStreakTitle,
                      value: text.gamificationDayStreak(
                        streak?.currentStreak ?? 0,
                      ),
                      color: const Color(0xFFFF6D00),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MiniStat(
                      key: const ValueKey(
                        'profile_gamification_achievements_stat',
                      ),
                      icon: Icons.workspace_premium_rounded,
                      label: text.gamificationAchievementsTitle,
                      value: achievementsValue,
                      color: const Color(0xFFFFD700),
                      onTap: onOpenHub,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MiniStat(
                      icon: Icons.track_changes_rounded,
                      label: text.gamificationWeekFocusTitle,
                      value: weeklyGoalsValue,
                      color: const Color(0xFF53C3A6),
                    ),
                  ),
                ],
              );
            },
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
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
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
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.15,
              color: colors.textSoft,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return PressableScale(onTap: onTap, child: content);
  }
}
