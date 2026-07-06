using System.Security.Claims;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;

namespace PetMagic.Modules.Gamification.Api.Endpoints;

public static class GamificationEndpoints
{
    private const string InvalidSubjectCode = "gamification.invalid_subject";
    private const string PetProgressNotFoundCode = "gamification.pet_progress_not_found";
    private const string StreakNotFoundCode = "gamification.streak_not_found";
    private const int MaxGamificationMutationRequestBodyBytes = 8 * 1024;

    public static IEndpointRouteBuilder MapGamificationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/gamification")
            .WithTags("Gamification")
            .RequireRateLimiting("economy")
            .AddEndpointFilter(ApplyPrivateGamificationResponseHeadersAsync)
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
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxGamificationMutationRequestBodyBytes));

        group.MapGet("/challenges/current", GetCurrentChallengesAsync)
            .RequireAuthorization();

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateGamificationResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }

    private static async Task<Results<Ok<GamificationSummaryResponse>, ProblemHttpResult>> GetSummaryAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return InvalidSubjectProblem();
        }

        var result = await service.GetSummaryAsync(userId.Value, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<PetProgressResponse>, ProblemHttpResult>> GetPetProgressAsync(
        HttpContext context,
        Guid petId,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return InvalidSubjectProblem();
        }

        var result = await service.GetPetProgressAsync(userId.Value, petId, cancellationToken);
        return result is null ? NotFoundProblem(PetProgressNotFoundCode) : TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<IReadOnlyList<AchievementResponse>>, ProblemHttpResult>> GetAchievementsAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return InvalidSubjectProblem();
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
            return InvalidSubjectProblem();
        }

        var result = await service.GetRecentAchievementsAsync(userId.Value, 10, cancellationToken);
        return TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<StreakResponse>, ProblemHttpResult>> GetStreakAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return InvalidSubjectProblem();
        }

        var result = await service.GetStreakAsync(userId.Value, cancellationToken);
        return result is null ? NotFoundProblem(StreakNotFoundCode) : TypedResults.Ok(result);
    }

    private static async Task<Results<Ok<UseFreezeResult>, ProblemHttpResult>> UseStreakFreezeAsync(
        HttpContext context,
        IGamificationService service,
        CancellationToken cancellationToken)
    {
        var userId = TryGetUserId(context);
        if (userId is null)
        {
            return InvalidSubjectProblem();
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
            return InvalidSubjectProblem();
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

    private static ProblemHttpResult InvalidSubjectProblem()
    {
        return TypedResults.Problem(
            title: InvalidSubjectCode,
            statusCode: StatusCodes.Status401Unauthorized,
            extensions: BuildProblemExtensions(InvalidSubjectCode));
    }

    private static ProblemHttpResult NotFoundProblem(string errorCode)
    {
        return TypedResults.Problem(
            title: errorCode,
            statusCode: StatusCodes.Status404NotFound,
            extensions: BuildProblemExtensions(errorCode));
    }

    private static Dictionary<string, object?> BuildProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
