using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class AuthEndpoints
{
    private const string InvalidSubjectCode = "auth.invalid_subject";
    private const string RefreshTokenOwnershipViolationCode = "auth.refresh_token_not_owned";

    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/auth")
            .WithTags("Auth")
            .RequireRateLimiting("auth");

        group.MapPost("/register", RegisterAsync)
            .AllowAnonymous();

        group.MapPost("/login", LoginAsync)
            .AllowAnonymous();

        group.MapPost("/refresh", RefreshAsync)
            .AllowAnonymous();

        group.MapPost("/logout", LogoutAsync)
            .RequireAuthorization();

        group.MapGet("/me", MeAsync)
            .RequireAuthorization();

        group.MapGet("/external/{provider}", ExternalChallengeAsync)
            .AllowAnonymous();

        group.MapGet("/external/callback", ExternalCallbackAsync)
            .AllowAnonymous();

        return endpoints;
    }

    private static async Task<Results<Created<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> RegisterAsync(
        RegisterUserCommand command,
        IValidator<RegisterUserCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RegisterAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Created($"/api/admin/users/{result.Value.UserId}", result.Value);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> LoginAsync(
        LoginCommand command,
        IValidator<LoginCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.LoginAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> RefreshAsync(
        RefreshTokenCommand command,
        IValidator<RefreshTokenCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RefreshAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> LogoutAsync(
        HttpContext context,
        RefreshTokenCommand command,
        IValidator<LogoutCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return TypedResults.Problem(
                title: InvalidSubjectCode,
                detail: "Invalid access token subject.",
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var logoutCommand = new LogoutCommand(userId, command.RefreshToken);
        var validation = await validator.ValidateAsync(logoutCommand, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.LogoutAsync(logoutCommand, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, RefreshTokenOwnershipViolationCode, StringComparison.Ordinal)
                ? StatusCodes.Status403Forbidden
                : StatusCodes.Status401Unauthorized;

            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

    private static IResult ExternalChallengeAsync(string provider)
    {
        if (!string.Equals(provider, "Google", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(provider, "Apple", StringComparison.OrdinalIgnoreCase))
        {
            return Results.BadRequest(new { message = "Unsupported provider." });
        }

        var redirectUri = $"/api/auth/external/callback?provider={provider}";
        return Results.Challenge(
            new AuthenticationProperties { RedirectUri = redirectUri },
            authenticationSchemes: [provider]);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ProblemHttpResult>> ExternalCallbackAsync(
        string provider,
        HttpContext httpContext,
        IValidator<ExternalLoginCallbackCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var externalAuthResult = await httpContext.AuthenticateAsync(IdentityConstants.ExternalScheme);
        if (!externalAuthResult.Succeeded || externalAuthResult.Principal is null)
        {
            return TypedResults.Problem(
                title: "auth.external_invalid",
                detail: "External authentication failed.",
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var principal = externalAuthResult.Principal;
        var providerSubject = principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue("sub")
            ?? string.Empty;

        var command = new ExternalLoginCallbackCommand(
            provider,
            providerSubject,
            principal.FindFirstValue(ClaimTypes.Email) ?? principal.FindFirstValue("email"),
            principal.FindFirstValue(ClaimTypes.Name) ?? principal.FindFirstValue("name"));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.Problem(
                title: "auth.external_invalid",
                detail: "External principal payload is invalid.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var result = await service.ExternalLoginAsync(command, cancellationToken);
        await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ProblemHttpResult>> MeAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return TypedResults.Problem(title: "auth.invalid_subject", detail: "Invalid access token subject.", statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetCurrentUserAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }
}
