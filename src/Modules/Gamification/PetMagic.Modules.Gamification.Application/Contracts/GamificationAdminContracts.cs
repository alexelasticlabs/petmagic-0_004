namespace PetMagic.Modules.Gamification.Application.Contracts;

public sealed record AdminGamificationDashboardMetricsResponse(
    int TotalUsersWithProgress,
    int TotalPetsTracked,
    int TotalAchievementDefinitions,
    int TotalAchievementsUnlocked,
    int UsersWithActiveStreak,
    int CurrentWeekChallenges,
    int CurrentWeekChallengeParticipants,
    int CurrentWeekChallengeCompletions,
    DateTime GeneratedAtUtc);

public sealed record AdminGamificationAchievementDefinitionResponse(
    string Key,
    string Category,
    string Rarity,
    string TitleKey,
    string DescriptionKey,
    string? IconEmoji,
    string RequirementType,
    int RequirementValue,
    int RewardSpark,
    bool IsSecret,
    int SortOrder,
    int UnlockedUsersCount);

public sealed record AdminGamificationChallengeSummaryResponse(
    Guid Id,
    DateOnly WeekStartDate,
    string ChallengeType,
    int TargetValue,
    string TitleKey,
    string DescriptionKey,
    string? IconEmoji,
    int RewardSpark,
    int SortOrder,
    int ParticipantCount,
    int CompletedCount);

public sealed record AdminUserGamificationOverviewResponse(
    Guid UserId,
    StreakResponse? Streak,
    IReadOnlyList<PetProgressResponse> Pets,
    IReadOnlyList<AchievementResponse> Achievements,
    IReadOnlyList<ChallengeResponse> CurrentChallenges);
