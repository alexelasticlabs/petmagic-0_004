import 'package:flutter/material.dart';
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🔥',
          style: TextStyle(fontSize: currentStreak > 0 ? 28 : 22),
        ),
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
                color: currentStreak > 0
                    ? const Color(0xFFFF6D00)
                    : colors.textSoft,
                height: 1,
              ),
            ),
            Text(
              'day streak',
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        final dateStr = date.toIso8601String().split('T').first;
        final isActive = activeDays.contains(dateStr);
        final isToday = date == today;
        final dayLabel = _dayLabel(date.weekday);

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
                    ? const Color(0xFFFF6D00)
                    : colors.surfaceStrong.withValues(alpha: 0.3),
                border: isToday
                    ? Border.all(
                        color: const Color(0xFFFF6D00),
                        width: 2,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: isActive
                  ? const Text(
                      '🔥',
                      style: TextStyle(fontSize: 14),
                    )
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

  static String _dayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      case 7:
        return 'S';
      default:
        return '';
    }
  }
}
