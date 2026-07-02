using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class LegalEndpoints
{
    private const int MaxLegalAcceptanceRequestBodyBytes = 8 * 1024;

    public static IEndpointRouteBuilder MapLegalEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/legal")
            .WithTags("Legal")
            .RequireRateLimiting("auth");

        group.MapGet("/current", GetCurrentAsync)
            .AllowAnonymous();

        group.MapPost("/accept", AcceptAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxLegalAcceptanceRequestBodyBytes))
            .RequireAuthorization();

        return endpoints;
    }

    private static Task<Results<Ok<LegalDocumentsResponse>, ProblemHttpResult>> GetCurrentAsync(
        [FromQuery(Name = "locale")] string? locale,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        return ExecuteGetCurrentAsync(locale, service, cancellationToken);
    }

    private static async Task<Results<Ok<LegalDocumentsResponse>, ProblemHttpResult>> ExecuteGetCurrentAsync(
        string? locale,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetCurrentLegalDocumentsAsync(locale, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status503ServiceUnavailable);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> AcceptAsync(
        HttpContext context,
        AcceptLegalDocumentsCommand command,
        IValidator<AcceptLegalDocumentsCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        if (!AuthEndpoints.TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.AcceptLegalDocumentsAsync(userId, command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }
}
