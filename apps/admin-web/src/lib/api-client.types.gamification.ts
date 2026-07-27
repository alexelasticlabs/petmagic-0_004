export type AdminGamificationDashboardMetrics = {
  totalUsersWithProgress: number;
  totalPetsTracked: number;
  totalAchievementDefinitions: number;
  totalAchievementsUnlocked: number;
  usersWithActiveStreak: number;
  currentWeekChallenges: number;
  currentWeekChallengeParticipants: number;
  currentWeekChallengeCompletions: number;
  generatedAtUtc: string;
};

export type AdminGamificationAchievementDefinition = {
  key: string;
  category: string;
  rarity: string;
  titleKey: string;
  descriptionKey: string;
  iconEmoji?: string | null;
  requirementType: string;
  requirementValue: number;
  rewardSpark: number;
  isSecret: boolean;
  sortOrder: number;
  unlockedUsersCount: number;
  version?: number;
};

export type AdminGamificationChallengeSummary = {
  id: string;
  weekStartDate: string;
  challengeType: string;
  targetValue: number;
  titleKey: string;
  descriptionKey: string;
  iconEmoji?: string | null;
  rewardSpark: number;
  sortOrder: number;
  participantCount: number;
  completedCount: number;
  definitionVersion?: number;
};

export type AdminGamificationStreak = {
  currentStreak: number;
  longestStreak: number;
  freezesAvailable: number;
  freezesPerWeek: number;
  lastActiveDate: string;
  activeDaysThisWeek: string[];
};

export type AdminGamificationPetProgress = {
  petId: string;
  xp: number;
  level: number;
  evolutionStage: string;
  totalGenerations: number;
  xpForNextLevel: number;
  xpForCurrentLevel: number;
  daysActive: number;
  favoriteTemplateId?: string | null;
  lastGenerationAtUtc?: string | null;
};

export type AdminGamificationAchievement = {
  key: string;
  category: string;
  rarity: string;
  titleKey: string;
  descriptionKey: string;
  iconEmoji?: string | null;
  requirementValue: number;
  currentProgress: number;
  rewardSpark: number;
  isSecret: boolean;
  isUnlocked: boolean;
  unlockedAtUtc?: string | null;
};

export type AdminGamificationChallenge = {
  id: string;
  challengeType: string;
  targetValue: number;
  currentValue: number;
  titleKey: string;
  descriptionKey: string;
  iconEmoji?: string | null;
  rewardSpark: number;
  isCompleted: boolean;
  rewardClaimed: boolean;
};

export type AdminUserGamificationHistoryItem = {
  eventId: string;
  kind: "achievement_reward" | "challenge_reward" | "streak_activity" | string;
  label: string;
  status: "credited" | "pending" | "no_reward" | "in_progress" | "recorded" | string;
  rewardSpark: number;
  occurredAtUtc: string;
  definitionVersion: number;
};

export type AdminUserGamificationOverview = {
  userId: string;
  streak?: AdminGamificationStreak | null;
  pets: AdminGamificationPetProgress[];
  achievements: AdminGamificationAchievement[];
  currentChallenges: AdminGamificationChallenge[];
  history?: AdminUserGamificationHistoryItem[];
};
