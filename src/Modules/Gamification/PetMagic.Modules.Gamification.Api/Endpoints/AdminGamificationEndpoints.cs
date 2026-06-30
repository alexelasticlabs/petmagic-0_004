using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Api.Endpoints;

public static class AdminGamificationEndpoints
{
    public static IEndpointRouteBuilder MapAdminGamificationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/gamification")
            .WithTags("Admin.Gamification")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/achievements", ListAchievementsAsync);
        group.MapGet("/challenges/current", ListCurrentChallengesAsync);
        group.MapGet("/users/{userId:guid}", GetUserOverviewAsync);
        group.MapDelete("/users/{userId:guid}/streak", ResetUserStreakAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async Task<Ok<AdminGamificationDashboardMetricsResponse>> GetDashboardMetricsAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminDashboardMetricsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>> ListAchievementsAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminAchievementsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>> ListCurrentChallengesAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminCurrentChallengesAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminUserGamificationOverviewResponse>> GetUserOverviewAsync(
        Guid userId,
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminUserOverviewAsync(userId, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> ResetUserStreakAsync(
        Guid userId,
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ResetAdminUserStreakAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.NoContent();
    }
}
