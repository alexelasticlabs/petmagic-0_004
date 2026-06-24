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

  factory PetProgressModel.fromJson(Map<String, dynamic> json) {
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

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
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

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      freezesAvailable: (json['freezesAvailable'] as num?)?.toInt() ?? 0,
      freezesPerWeek: (json['freezesPerWeek'] as num?)?.toInt() ?? 1,
      lastActiveDate: json['lastActiveDate'] as String? ?? '',
      activeDaysThisWeek: (json['activeDaysThisWeek'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
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

  factory WeeklyChallengeModel.fromJson(Map<String, dynamic> json) {
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

  factory GamificationSummaryModel.fromJson(Map<String, dynamic> json) {
    return GamificationSummaryModel(
      streak: json['streak'] is Map<String, dynamic>
          ? StreakModel.fromJson(json['streak'] as Map<String, dynamic>)
          : null,
      recentAchievements: (json['recentAchievements'] as List<dynamic>?)
              ?.map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activeChallenges: (json['activeChallenges'] as List<dynamic>?)
              ?.map((e) => WeeklyChallengeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      topPets: (json['topPets'] as List<dynamic>?)
              ?.map((e) => PetProgressModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
