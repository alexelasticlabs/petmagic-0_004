enum EvolutionStage {
  egg,
  baby,
  teen,
  adult,
  legendary;

  static EvolutionStage fromString(String value) {
    return EvolutionStage.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EvolutionStage.egg,
    );
  }

  String get displayName => name;
}

enum AchievementCategory {
  generation,
  streak,
  collection,
  social,
  special;

  static AchievementCategory fromString(String value) {
    return AchievementCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AchievementCategory.special,
    );
  }
}

enum AchievementRarity {
  common,
  rare,
  epic,
  legendary,
  secret;

  static AchievementRarity fromString(String value) {
    return AchievementRarity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AchievementRarity.common,
    );
  }
}

class XpCalculator {
  XpCalculator._();

  static const int maxLevel = 10;

  static const List<int> levelThresholds = [
    0, // Level 1
    50, // Level 2
    150, // Level 3
    350, // Level 4
    700, // Level 5
    1200, // Level 6
    2000, // Level 7
    3200, // Level 8
    5000, // Level 9
    8000, // Level 10
  ];

  static int getLevel(int xp) {
    for (var i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  static int getXpForNextLevel(int currentLevel) {
    if (currentLevel >= maxLevel) return levelThresholds.last;
    return levelThresholds[currentLevel];
  }

  static int getXpForCurrentLevel(int currentLevel) {
    if (currentLevel <= 0) return 0;
    return levelThresholds[(currentLevel - 1).clamp(
      0,
      levelThresholds.length - 1,
    )];
  }

  static EvolutionStage getEvolutionStage(int level) {
    if (level <= 2) return EvolutionStage.egg;
    if (level <= 4) return EvolutionStage.baby;
    if (level <= 6) return EvolutionStage.teen;
    if (level <= 8) return EvolutionStage.adult;
    return EvolutionStage.legendary;
  }
}
