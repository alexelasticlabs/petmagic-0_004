import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page_state.dart';

void main() {
  group('applyAchievementFilter', () {
    test('keeps only unlocked achievements for unlocked filter', () {
      final filtered = applyAchievementFilter(
        _achievements,
        AchievementFilter.unlocked,
      );

      expect(filtered.map((item) => item.key), ['first_magic']);
    });

    test('hides untouched secret achievements from in-progress filter', () {
      final filtered = applyAchievementFilter(
        _achievements,
        AchievementFilter.inProgress,
      );

      expect(filtered.map((item) => item.key), ['apprentice_10']);
    });

    test('keeps secret achievements for secret filter', () {
      final filtered = applyAchievementFilter(
        _achievements,
        AchievementFilter.secret,
      );

      expect(filtered.map((item) => item.key), ['secret_streak']);
    });
  });

  test(
    'findNextAchievement picks the locked item with the strongest visible progress',
    () {
      final nextAchievement = findNextAchievement(_achievements);

      expect(nextAchievement?.key, 'apprentice_10');
    },
  );
}

const _achievements = [
  AchievementModel(
    key: 'first_magic',
    category: 'generation',
    rarity: 'common',
    titleKey: 'achievementFirstMagic',
    descriptionKey: 'achievementFirstMagicDesc',
    requirementValue: 1,
    currentProgress: 1,
    rewardSpark: 10,
    isSecret: false,
    isUnlocked: true,
    iconEmoji: '✨',
  ),
  AchievementModel(
    key: 'apprentice_10',
    category: 'generation',
    rarity: 'common',
    titleKey: 'achievementApprentice10',
    descriptionKey: 'achievementApprentice10Desc',
    requirementValue: 10,
    currentProgress: 3,
    rewardSpark: 15,
    isSecret: false,
    isUnlocked: false,
    iconEmoji: '🎯',
  ),
  AchievementModel(
    key: 'secret_streak',
    category: 'streak',
    rarity: 'rare',
    titleKey: 'achievementStreak7',
    descriptionKey: 'achievementStreak7Desc',
    requirementValue: 7,
    currentProgress: 0,
    rewardSpark: 25,
    isSecret: true,
    isUnlocked: false,
    iconEmoji: '🔥',
  ),
];
