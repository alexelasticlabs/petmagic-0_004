import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/streak_calendar.dart';

class StreakSection extends ConsumerWidget {
  const StreakSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final streakAsync = ref.watch(dailyStreakProvider);

    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (streak) {
        if (streak == null) return const SizedBox.shrink();

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
              Row(
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: streak.currentStreak > 0 ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.currentStreak}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: streak.currentStreak > 0
                              ? const Color(0xFFFF6D00)
                              : colors.textSoft,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Daily Streak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSoft,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (streak.longestStreak > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Best',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSoft,
                          ),
                        ),
                        Text(
                          '${streak.longestStreak}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              StreakCalendar(
                activeDays: streak.activeDaysThisWeek,
                currentStreak: streak.currentStreak,
              ),
              if (streak.freezesAvailable > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('❄️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${streak.freezesAvailable} freeze${streak.freezesAvailable > 1 ? 's' : ''} available',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
