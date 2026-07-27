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
    int UnlockedUsersCount,
    int Version = 1);

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
    int CompletedCount,
    int DefinitionVersion = 1);

public sealed record AdminUserGamificationHistoryItemResponse(
    string EventId,
    string Kind,
    string Label,
    string Status,
    int RewardSpark,
    DateTime OccurredAtUtc,
    int DefinitionVersion);

public sealed record AdminUserGamificationOverviewResponse(
    Guid UserId,
    StreakResponse? Streak,
    IReadOnlyList<PetProgressResponse> Pets,
    IReadOnlyList<AchievementResponse> Achievements,
    IReadOnlyList<ChallengeResponse> CurrentChallenges)
{
    public IReadOnlyList<AdminUserGamificationHistoryItemResponse> History { get; init; } = [];
}

public sealed record AdminResetUserStreakCommand(
    Guid AdminUserId,
    Guid UserId,
    string Reason);
