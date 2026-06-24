namespace PetMagic.Modules.Gamification.Application.Contracts;

public sealed record PetProgressResponse(
    Guid PetId,
    int Xp,
    int Level,
    string EvolutionStage,
    int TotalGenerations,
    int XpForNextLevel,
    int XpForCurrentLevel,
    int DaysActive,
    Guid? FavoriteTemplateId,
    DateTime? LastGenerationAtUtc);

public sealed record AchievementResponse(
    string Key,
    string Category,
    string Rarity,
    string TitleKey,
    string DescriptionKey,
    string? IconEmoji,
    int RequirementValue,
    int CurrentProgress,
    int RewardSpark,
    bool IsSecret,
    bool IsUnlocked,
    DateTime? UnlockedAtUtc);

public sealed record StreakResponse(
    int CurrentStreak,
    int LongestStreak,
    int FreezesAvailable,
    int FreezesPerWeek,
    DateOnly LastActiveDate,
    IReadOnlyList<DateOnly> ActiveDaysThisWeek);

public sealed record ChallengeResponse(
    Guid Id,
    string ChallengeType,
    int TargetValue,
    int CurrentValue,
    string TitleKey,
    string DescriptionKey,
    string? IconEmoji,
    int RewardSpark,
    bool IsCompleted,
    bool RewardClaimed);

public sealed record GamificationSummaryResponse(
    StreakResponse? Streak,
    IReadOnlyList<AchievementResponse> RecentAchievements,
    IReadOnlyList<ChallengeResponse> ActiveChallenges,
    IReadOnlyList<PetProgressResponse> TopPets);
