import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';

GamificationSummaryModel mapGamificationSummaryDto(Map<String, dynamic> json) {
  return GamificationSummaryModel(
    streak: json['streak'] is Map<String, dynamic>
        ? _mapStreakDto(json['streak'] as Map<String, dynamic>)
        : null,
    recentAchievements:
        (json['recentAchievements'] as List<dynamic>?)
            ?.map((value) => mapAchievementDto(value as Map<String, dynamic>))
            .toList(growable: false) ??
        const [],
    activeChallenges:
        (json['activeChallenges'] as List<dynamic>?)
            ?.map(
              (value) => _mapWeeklyChallengeDto(value as Map<String, dynamic>),
            )
            .toList(growable: false) ??
        const [],
    topPets:
        (json['topPets'] as List<dynamic>?)
            ?.map((value) => _mapPetProgressDto(value as Map<String, dynamic>))
            .toList(growable: false) ??
        const [],
  );
}

AchievementModel mapAchievementDto(Map<String, dynamic> json) {
  return AchievementModel(
    key: json['key'] as String? ?? '',
    category: json['category'] as String? ?? 'special',
    rarity: json['rarity'] as String? ?? 'common',
    titleKey: json['titleKey'] as String? ?? '',
    descriptionKey: json['descriptionKey'] as String? ?? '',
    iconEmoji: json['iconEmoji'] as String?,
    requirementValue: (json['requirementValue'] as num?)?.toInt() ?? 0,
    currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
    rewardSpark: (json['rewardSpark'] as num?)?.toInt() ?? 0,
    isSecret: json['isSecret'] as bool? ?? false,
    isUnlocked: json['isUnlocked'] as bool? ?? false,
    unlockedAtUtc: json['unlockedAtUtc'] is String
        ? DateTime.tryParse(json['unlockedAtUtc'] as String)
        : null,
  );
}

PetProgressModel _mapPetProgressDto(Map<String, dynamic> json) {
  return PetProgressModel(
    petId: json['petId'] as String? ?? '',
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    evolutionStage: json['evolutionStage'] as String? ?? 'egg',
    totalGenerations: (json['totalGenerations'] as num?)?.toInt() ?? 0,
    xpForNextLevel: (json['xpForNextLevel'] as num?)?.toInt() ?? 0,
    xpForCurrentLevel: (json['xpForCurrentLevel'] as num?)?.toInt() ?? 0,
    daysActive: (json['daysActive'] as num?)?.toInt() ?? 0,
    favoriteTemplateId: json['favoriteTemplateId'] as String?,
    lastGenerationAtUtc: json['lastGenerationAtUtc'] is String
        ? DateTime.tryParse(json['lastGenerationAtUtc'] as String)
        : null,
  );
}

StreakModel _mapStreakDto(Map<String, dynamic> json) {
  return StreakModel(
    currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
    longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    freezesAvailable: (json['freezesAvailable'] as num?)?.toInt() ?? 0,
    freezesPerWeek: (json['freezesPerWeek'] as num?)?.toInt() ?? 1,
    lastActiveDate: json['lastActiveDate'] as String? ?? '',
    activeDaysThisWeek:
        (json['activeDaysThisWeek'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList(growable: false) ??
        const [],
  );
}

WeeklyChallengeModel _mapWeeklyChallengeDto(Map<String, dynamic> json) {
  return WeeklyChallengeModel(
    id: json['id'] as String? ?? '',
    challengeType: json['challengeType'] as String? ?? '',
    targetValue: (json['targetValue'] as num?)?.toInt() ?? 0,
    currentValue: (json['currentValue'] as num?)?.toInt() ?? 0,
    titleKey: json['titleKey'] as String? ?? '',
    descriptionKey: json['descriptionKey'] as String? ?? '',
    iconEmoji: json['iconEmoji'] as String?,
    rewardSpark: (json['rewardSpark'] as num?)?.toInt() ?? 0,
    isCompleted: json['isCompleted'] as bool? ?? false,
    rewardClaimed: json['rewardClaimed'] as bool? ?? false,
  );
}
