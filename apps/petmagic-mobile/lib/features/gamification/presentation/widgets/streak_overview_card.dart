import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/streak_calendar.dart';

class StreakOverviewCard extends StatelessWidget {
  const StreakOverviewCard({super.key, required this.streak});

  final StreakModel streak;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8A50).withValues(alpha: 0.28),
          width: 1.1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF8A50).withValues(alpha: 0.16),
            colors.surfaceStrong.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8A50).withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.gamificationStreakTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      text.gamificationHubSubtitle,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _StreakStatPill(
                label: text.gamificationBest,
                value: '${streak.longestStreak}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${streak.currentStreak}',
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.gamificationStreakDays(streak.currentStreak),
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreakCalendar(
            activeDays: streak.activeDaysThisWeek,
            currentStreak: streak.currentStreak,
          ),
          if (streak.freezesAvailable > 0) ...[
            const SizedBox(height: 12),
            Text(
              streak.freezesAvailable == 1
                  ? text.gamificationFreezeAvailable(streak.freezesAvailable)
                  : text.gamificationFreezesAvailable(streak.freezesAvailable),
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakStatPill extends StatelessWidget {
  const _StreakStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.surface.withValues(alpha: 0.72),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
