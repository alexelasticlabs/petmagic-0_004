import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.title,
    required this.description,
    this.expanded = false,
    this.onTap,
  });

  final AchievementModel achievement;
  final String title;
  final String description;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isSecretLocked = achievement.isSecret && !achievement.isUnlocked;
    final rarityColor = _rarityColor(achievement.rarity);
    final progressLabel = text.gamificationAchievementProgress(
      achievement.currentProgress,
      achievement.requirementValue,
    );
    final statusLabel = achievement.isUnlocked
        ? text.gamificationStatusUnlocked
        : text.gamificationStatusInProgress;

    return PressableScale(
      onTap: onTap,
      enabled: onTap != null,
      haptic: PressableScaleHaptic.selection,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: achievement.isUnlocked
                ? rarityColor.withValues(alpha: 0.52)
                : colors.border,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(
                alpha: achievement.isUnlocked ? 0.14 : 0.04,
              ),
              blurRadius: expanded ? 24 : 14,
              offset: const Offset(0, 10),
            ),
          ],
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: achievement.isUnlocked
                        ? rarityColor.withValues(alpha: 0.15)
                        : colors.surfaceStrong.withValues(alpha: 0.34),
                  ),
                  alignment: Alignment.center,
                  child: isSecretLocked
                      ? Text(
                          text.gamificationAchievementSecret,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.textSoft,
                          ),
                        )
                      : Text(
                          achievement.iconEmoji ?? '🏆',
                          style: const TextStyle(fontSize: 20),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSecretLocked
                            ? text.gamificationAchievementSecret
                            : title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textStrong,
                        ),
                        maxLines: expanded ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSecretLocked
                            ? text.gamificationKeepGenerating
                            : description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: colors.textSoft,
                        ),
                        maxLines: expanded ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (achievement.rewardSpark > 0)
                      _MetaChip(
                        color: rarityColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PawSparkIcon(size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '+${achievement.rewardSpark}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (achievement.rewardSpark > 0) const SizedBox(height: 6),
                    Icon(
                      achievement.isUnlocked
                          ? Icons.check_circle_rounded
                          : expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: achievement.isUnlocked
                          ? rarityColor
                          : colors.textSoft,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetaChip(
                    color: achievement.isUnlocked
                        ? rarityColor
                        : colors.textMuted,
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  progressLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSoft,
                  ),
                ),
              ],
            ),
            if (!isSecretLocked) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progressPercent,
                  backgroundColor: colors.surfaceStrong.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
                  minHeight: expanded ? 8 : 6,
                ),
              ),
            ],
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.isUnlocked
                            ? text.gamificationAchievementUnlocked
                            : text.gamificationKeepGenerating,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textSoft,
                        ),
                      ),
                    ),
                    if (!achievement.isUnlocked)
                      Text(
                        '${(achievement.progressPercent * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: rarityColor,
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ),
      ),
    );
  }

  static Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'rare':
        return const Color(0xFF42A5F5);
      case 'epic':
        return const Color(0xFFAB47BC);
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'secret':
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: color),
          child: child,
        ),
      ),
    );
  }
}
