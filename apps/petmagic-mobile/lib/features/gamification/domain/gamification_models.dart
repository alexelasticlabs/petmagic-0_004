/// Domain progress for a pet participating in gamification.
class PetProgressModel {
  const PetProgressModel({
    required this.petId,
    required this.xp,
    required this.level,
    required this.evolutionStage,
    required this.totalGenerations,
    required this.xpForNextLevel,
    required this.xpForCurrentLevel,
    required this.daysActive,
    this.favoriteTemplateId,
    this.lastGenerationAtUtc,
  });

  final String petId;
  final int xp;
  final int level;
  final String evolutionStage;
  final int totalGenerations;
  final int xpForNextLevel;
  final int xpForCurrentLevel;
  final int daysActive;
  final String? favoriteTemplateId;
  final DateTime? lastGenerationAtUtc;

  double get xpProgress {
    final range = xpForNextLevel - xpForCurrentLevel;
    if (range <= 0) return 1;
    return ((xp - xpForCurrentLevel) / range).clamp(0.0, 1.0);
  }
}

class AchievementModel {
  const AchievementModel({
    required this.key,
    required this.category,
    required this.rarity,
    required this.titleKey,
    required this.descriptionKey,
    required this.requirementValue,
    required this.currentProgress,
    required this.rewardSpark,
    required this.isSecret,
    required this.isUnlocked,
    this.iconEmoji,
    this.unlockedAtUtc,
  });

  final String key;
  final String category;
  final String rarity;
  final String titleKey;
  final String descriptionKey;
  final String? iconEmoji;
  final int requirementValue;
  final int currentProgress;
  final int rewardSpark;
  final bool isSecret;
  final bool isUnlocked;
  final DateTime? unlockedAtUtc;

  double get progressPercent {
    if (requirementValue <= 0) return 0;
    return (currentProgress / requirementValue).clamp(0.0, 1.0);
  }
}

class StreakModel {
  const StreakModel({
    required this.currentStreak,
    required this.longestStreak,
    required this.freezesAvailable,
    required this.freezesPerWeek,
    required this.lastActiveDate,
    required this.activeDaysThisWeek,
  });

  final int currentStreak;
  final int longestStreak;
  final int freezesAvailable;
  final int freezesPerWeek;
  final String lastActiveDate;
  final List<String> activeDaysThisWeek;
}

class WeeklyChallengeModel {
  const WeeklyChallengeModel({
    required this.id,
    required this.challengeType,
    required this.targetValue,
    required this.currentValue,
    required this.titleKey,
    required this.descriptionKey,
    required this.rewardSpark,
    required this.isCompleted,
    required this.rewardClaimed,
    this.iconEmoji,
  });

  final String id;
  final String challengeType;
  final int targetValue;
  final int currentValue;
  final String titleKey;
  final String descriptionKey;
  final String? iconEmoji;
  final int rewardSpark;
  final bool isCompleted;
  final bool rewardClaimed;

  double get progressPercent {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
}

class GamificationSummaryModel {
  const GamificationSummaryModel({
    this.streak,
    this.recentAchievements = const [],
    this.activeChallenges = const [],
    this.topPets = const [],
  });

  final StreakModel? streak;
  final List<AchievementModel> recentAchievements;
  final List<WeeklyChallengeModel> activeChallenges;
  final List<PetProgressModel> topPets;
}
