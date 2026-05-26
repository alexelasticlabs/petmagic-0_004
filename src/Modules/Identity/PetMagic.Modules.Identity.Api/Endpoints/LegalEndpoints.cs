using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class LegalEndpoints
{
    public static IEndpointRouteBuilder MapLegalEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/legal")
            .WithTags("Legal")
            .RequireRateLimiting("auth");

        group.MapGet("/current", GetCurrentAsync)
            .AllowAnonymous();

        group.MapPost("/accept", AcceptAsync)
            .RequireAuthorization();

        return endpoints;
    }

    private static Task<Ok<LegalDocumentsResponse>> GetCurrentAsync(
        [AsParameters] GetLegalDocumentsRequest request,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        return ExecuteGetCurrentAsync(request.Locale, service, cancellationToken);
    }

    private static async Task<Ok<LegalDocumentsResponse>> ExecuteGetCurrentAsync(
        string? locale,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetCurrentLegalDocumentsAsync(locale, cancellationToken);
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

        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return TypedResults.Problem(title: "auth.invalid_subject", detail: "Invalid access token subject.", statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.AcceptLegalDocumentsAsync(userId, command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "users.not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private sealed record GetLegalDocumentsRequest(string? Locale);
}
