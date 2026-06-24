using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Application.Abstractions;

public interface IGamificationService
{
    Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid userId,
        Guid petId,
        Guid templateId,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken);

    Task<PetProgressResponse?> GetPetProgressAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<IReadOnlyList<AchievementResponse>> GetAchievementsAsync(Guid userId, CancellationToken cancellationToken);

    Task<IReadOnlyList<AchievementResponse>> GetRecentAchievementsAsync(Guid userId, int count, CancellationToken cancellationToken);

    Task<StreakResponse?> GetStreakAsync(Guid userId, CancellationToken cancellationToken);

    Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken);

    Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken);

    Task<GamificationSummaryResponse> GetSummaryAsync(Guid userId, CancellationToken cancellationToken);
}

public sealed record GenerationProcessResult(
    int XpAwarded,
    int? NewLevel,
    string? NewEvolutionStage,
    bool DidLevelUp,
    IReadOnlyList<AchievementResponse> UnlockedAchievements,
    int TotalSparkReward);

public sealed record UseFreezeResult(bool Success, int FreezesRemaining);
