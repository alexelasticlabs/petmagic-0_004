import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/gamification/application/achievements_page_state.dart';

class AchievementsFilterBar extends StatelessWidget {
  const AchievementsFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AchievementFilter selected;
  final ValueChanged<AchievementFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AchievementsFilterChip(
            chipKey: const Key('achievement_filter_all'),
            label: text.gamificationFilterAll,
            selected: selected == AchievementFilter.all,
            onTap: () => onChanged(AchievementFilter.all),
          ),
          _AchievementsFilterChip(
            chipKey: const Key('achievement_filter_unlocked'),
            label: text.gamificationFilterUnlocked,
            selected: selected == AchievementFilter.unlocked,
            onTap: () => onChanged(AchievementFilter.unlocked),
          ),
          _AchievementsFilterChip(
            chipKey: const Key('achievement_filter_in_progress'),
            label: text.gamificationFilterInProgress,
            selected: selected == AchievementFilter.inProgress,
            onTap: () => onChanged(AchievementFilter.inProgress),
          ),
          _AchievementsFilterChip(
            chipKey: const Key('achievement_filter_secret'),
            label: text.gamificationFilterSecret,
            selected: selected == AchievementFilter.secret,
            onTap: () => onChanged(AchievementFilter.secret),
          ),
        ],
      ),
    );
  }
}

class _AchievementsFilterChip extends StatelessWidget {
  const _AchievementsFilterChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: chipKey,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.accent.withValues(alpha: 0.18),
        backgroundColor: colors.surfaceStrong.withValues(alpha: 0.46),
        labelStyle: TextStyle(
          color: selected ? colors.textStrong : colors.textSoft,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: selected ? colors.accent : colors.border),
        ),
      ),
    );
  }
}
