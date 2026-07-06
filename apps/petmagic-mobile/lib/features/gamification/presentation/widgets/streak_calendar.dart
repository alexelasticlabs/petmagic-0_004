import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class StreakCounter extends StatelessWidget {
  const StreakCounter({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final streakColor = colors.gold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🔥', style: TextStyle(fontSize: currentStreak > 0 ? 28 : 22)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currentStreak',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: currentStreak > 0 ? streakColor : colors.textSoft,
                height: 1,
              ),
            ),
            Text(
              text.gamificationDayStreak,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.activeDays,
    required this.currentStreak,
  });

  final List<String> activeDays;
  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final streakColor = colors.gold;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weekdayFormatter = DateFormat.E(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        final dateStr = date.toIso8601String().split('T').first;
        final isActive = activeDays.contains(dateStr);
        final isToday = date == today;
        final dayLabel = weekdayFormatter.format(date);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSoft,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? streakColor
                    : colors.surfaceStrong.withValues(alpha: 0.3),
                border: isToday
                    ? Border.all(color: streakColor, width: 2)
                    : null,
              ),
              alignment: Alignment.center,
              child: isActive
                  ? const Text('🔥', style: TextStyle(fontSize: 14))
                  : Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSoft,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}
