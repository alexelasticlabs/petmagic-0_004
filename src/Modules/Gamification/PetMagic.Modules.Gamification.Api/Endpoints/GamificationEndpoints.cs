using System.Security.Claims;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Api.Endpoints;

public static class GamificationEndpoints
{
    public static IEndpointRouteBuilder MapGamificationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/gamification")
            .WithTags("Gamification")
            .RequireRateLimiting("economy")
            .RequireAuthorization(policy => policy
                .RequireAuthenticatedUser()
                .RequireAssertion(context =>
                    context.User.IsInRole("Admin")
                    || context.User.IsInRole("Moderator")
                    || !context.User.HasClaim(c => c.Type == "account_status")
                    || string.Equals(
                        context.User.FindFirst("account_status")?.Value,
                        "Active",
                        StringComparison.Ordinal)));

        group.MapGet("/summary", GetSummaryAsync)
            .RequireAuthorization();

        group.MapGet("/pets/{petId:guid}/progress", GetPetProgressAsync)
            .RequireAuthorization();

        group.MapGet("/achievements", GetAchievementsAsync)
            .RequireAuthorization();

        group.MapGet("/achievements/recent", GetRecentAchievementsAsync)
            .RequireAuthorization();

        group.MapGet("/streaks", GetStreakAsync)
            .RequireAuthorization();

        group.MapPost("/streaks/freeze", UseStreakFreezeAsync)
            .RequireAuthorization();

        group.MapGet("/challenges/current", GetCurrentChallengesAsync)
            .RequireAuthorization();

        return endpoints;
    }

    private static async Task<Results<Ok<GamificationSummaryResponse>, ProblemHttpResult>> GetSummaryAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetSummaryAsync(userId.Value, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<PetProgressResponse>, NotFound, ProblemHttpResult>> GetPetProgressAsync(
        HttpContext context,
        Guid petId,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetPetProgressAsync(userId.Value, petId, cancellationToken);
        return result is null ? TypedResults.NotFound() : TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<IReadOnlyList<AchievementResponse>>, ProblemHttpResult>> GetAchievementsAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetAchievementsAsync(userId.Value, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<IReadOnlyList<AchievementResponse>>, ProblemHttpResult>> GetRecentAchievementsAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetRecentAchievementsAsync(userId.Value, 10, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<StreakResponse>, NotFound, ProblemHttpResult>> GetStreakAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetStreakAsync(userId.Value, cancellationToken);
        return result is null ? TypedResults.NotFound() : TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<UseFreezeResult>, ProblemHttpResult>> UseStreakFreezeAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.UseStreakFreezeAsync(userId.Value, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<IReadOnlyList<ChallengeResponse>>, ProblemHttpResult>> GetCurrentChallengesAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return TypedResults.Problem(title: "gamification.invalid_subject", detail: "Invalid access token subject.", statusCode: 401);
        }

        var result = await service.GetCurrentChallengesAsync(userId.Value, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static Guid? TryGetUserId(HttpContext context)
    {
        var sub = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? context.User.FindFirst("sub")?.Value;
        return Guid.TryParse(sub, out var userId) ? userId : null;
    }
}
