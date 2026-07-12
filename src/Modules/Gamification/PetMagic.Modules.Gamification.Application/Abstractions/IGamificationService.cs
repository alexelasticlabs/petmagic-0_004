using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Application.Abstractions;

public interface IGamificationService
{
    Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid generationId,
        Guid userId,
        Guid petId,
        Guid templateId,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken);

    Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid generationId,
        Guid userId,
        Guid petId,
        Guid templateId,
        DateTime completedAtUtc,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken) => ProcessGenerationCompletedAsync(
            generationId,
            userId,
            petId,
            templateId,
            isTemplateOfTheDay,
            isPremium,
            cancellationToken);

    Task<PetProgressResponse?> GetPetProgressAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<IReadOnlyList<AchievementResponse>> GetAchievementsAsync(Guid userId, CancellationToken cancellationToken);

    Task<IReadOnlyList<AchievementResponse>> GetRecentAchievementsAsync(Guid userId, int count, CancellationToken cancellationToken);

    Task<StreakResponse?> GetStreakAsync(Guid userId, CancellationToken cancellationToken);

    Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken);

    Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken);

    Task<GamificationSummaryResponse> GetSummaryAsync(Guid userId, CancellationToken cancellationToken);

    Task RecordCreationSharedAsync(Guid generationId, Guid userId, CancellationToken cancellationToken);

    Task RecordCreationSharedAsync(
        Guid generationId,
        Guid userId,
        DateTime sharedAtUtc,
        CancellationToken cancellationToken) => RecordCreationSharedAsync(
            generationId,
            userId,
            cancellationToken);
}

public sealed record GenerationProcessResult(
    int XpAwarded,
    int? NewLevel,
    string? NewEvolutionStage,
    bool DidLevelUp,
    IReadOnlyList<AchievementResponse> UnlockedAchievements,
    int TotalSparkReward);

public sealed record UseFreezeResult(bool Success, int FreezesRemaining);
