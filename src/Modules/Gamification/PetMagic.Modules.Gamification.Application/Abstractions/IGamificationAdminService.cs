using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Application.Abstractions;

public interface IGamificationAdminService
{
    Task<Result<AdminGamificationDashboardMetricsResponse>> GetAdminDashboardMetricsAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>> ListAdminAchievementsAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>> ListAdminCurrentChallengesAsync(CancellationToken cancellationToken);

    Task<Result<AdminUserGamificationOverviewResponse>> GetAdminUserOverviewAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> ResetAdminUserStreakAsync(Guid userId, CancellationToken cancellationToken);
}
