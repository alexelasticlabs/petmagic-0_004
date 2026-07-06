using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Api.Endpoints;

public static class AdminGamificationEndpoints
{
    private const int MaxAdminGamificationMutationRequestBodyBytes = 8 * 1024;

    public static IEndpointRouteBuilder MapAdminGamificationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/gamification")
            .WithTags("Admin.Gamification")
            .RequireAuthorization("AdminOnly")
            .AddEndpointFilter(ApplyPrivateAdminGamificationResponseHeadersAsync)
            .RequireRateLimiting("admin");

        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/achievements", ListAchievementsAsync);
        group.MapGet("/challenges/current", ListCurrentChallengesAsync);
        group.MapGet("/users/{userId:guid}", GetUserOverviewAsync);
        group.MapDelete("/users/{userId:guid}/streak", ResetUserStreakAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminGamificationMutationRequestBodyBytes));

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateAdminGamificationResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }

    private static async Task<Results<Ok<AdminGamificationDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminDashboardMetricsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminGamificationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>, ProblemHttpResult>> ListAchievementsAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminAchievementsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminGamificationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>, ProblemHttpResult>> ListCurrentChallengesAsync(
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminCurrentChallengesAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminGamificationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminUserGamificationOverviewResponse>, ProblemHttpResult>> GetUserOverviewAsync(
        Guid userId,
        IGamificationAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminUserOverviewAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminGamificationProblem(result.Error);
        }

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
            return ToAdminGamificationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static ProblemHttpResult ToAdminGamificationProblem(Error error)
    {
        var statusCode = string.Equals(error.Code, "gamification.streak_not_found", StringComparison.Ordinal)
            ? StatusCodes.Status404NotFound
            : StatusCodes.Status400BadRequest;

        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildAdminGamificationProblemExtensions(error.Code));
    }

    private static Dictionary<string, object?> BuildAdminGamificationProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
