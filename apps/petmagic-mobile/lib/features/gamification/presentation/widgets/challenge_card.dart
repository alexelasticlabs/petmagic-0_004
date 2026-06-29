import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.title,
    required this.description,
  });

  final WeeklyChallengeModel challenge;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final progressLabel = text.gamificationAchievementProgress(
      challenge.currentValue,
      challenge.targetValue,
    );
    final statusText = challenge.isCompleted
        ? text.gamificationChallengeComplete
        : text.gamificationStatusInProgress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: challenge.isCompleted
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
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
        children: [
          Row(
            children: [
              if (challenge.iconEmoji != null)
                Text(
                  challenge.iconEmoji!,
                  style: const TextStyle(fontSize: 20),
                ),
              if (challenge.iconEmoji != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (challenge.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: colors.textSoft),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.progressPercent,
                    backgroundColor: colors.surfaceStrong.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      challenge.isCompleted
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF6D00),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                progressLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const PawSparkIcon(size: 14),
              const SizedBox(width: 4),
              Text(
                '+${challenge.rewardSpark}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textStrong,
                ),
              ),
              const Spacer(),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: challenge.isCompleted
                      ? const Color(0xFF4CAF50)
                      : colors.textSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
