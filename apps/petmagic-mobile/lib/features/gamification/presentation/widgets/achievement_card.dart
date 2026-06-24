import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.title,
    required this.description,
  });

  final AchievementModel achievement;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isSecretLocked = achievement.isSecret && !achievement.isUnlocked;
    final rarityColor = _rarityColor(achievement.rarity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: achievement.isUnlocked
              ? rarityColor.withValues(alpha: 0.5)
              : colors.border,
          width: 1.1,
        ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: achievement.isUnlocked
                      ? rarityColor.withValues(alpha: 0.15)
                      : colors.surfaceStrong.withValues(alpha: 0.3),
                ),
                alignment: Alignment.center,
                child: isSecretLocked
                    ? Text(
                        '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textSoft,
                        ),
                      )
                    : Text(
                        achievement.iconEmoji ?? '🏆',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSecretLocked ? '???' : title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textStrong,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isSecretLocked)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (achievement.isUnlocked)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: rarityColor,
                ),
            ],
          ),
          if (!achievement.isUnlocked && !isSecretLocked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: achievement.progressPercent,
                backgroundColor: colors.surfaceStrong.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${achievement.currentProgress} / ${achievement.requirementValue}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                  color: colors.textSoft,
              ),
            ),
          ],
        ],
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
