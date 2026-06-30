using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.WebUtilities;

using PetMagic.Modules.Identity.Api.Authentication;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static partial class AuthEndpoints
{

    private static async Task<Results<Accepted, ValidationProblem, ProblemHttpResult>> RegisterAsync(
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
            if (string.Equals(result.Error.Code, UserAlreadyExistsCode, StringComparison.Ordinal))
            {
                return TypedResults.Accepted((string?)null);
            }

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> LoginAsync(
        HttpContext context,
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
            var statusCode = string.Equals(result.Error.Code, EmailNotConfirmedCode, StringComparison.Ordinal)
                ? StatusCodes.Status403Forbidden
                : StatusCodes.Status401Unauthorized;

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted, ValidationProblem, ProblemHttpResult>> RequestEmailConfirmationAsync(
        RequestEmailConfirmationCommand command,
        IValidator<RequestEmailConfirmationCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RequestEmailConfirmationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static async Task<Results<Accepted, ValidationProblem, ProblemHttpResult>> ResendEmailVerificationCodeAsync(
        ResendEmailVerificationCodeCommand command,
        IValidator<ResendEmailVerificationCodeCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ResendEmailVerificationCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> ConfirmEmailAsync(
        ConfirmEmailCommand command,
        IValidator<ConfirmEmailCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ConfirmEmailAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> VerifyEmailCodeAsync(
        HttpContext context,
        VerifyEmailCodeCommand command,
        IValidator<VerifyEmailCodeCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.VerifyEmailCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted, ValidationProblem, ProblemHttpResult>> RequestPasswordResetAsync(
        RequestPasswordResetCommand command,
        IValidator<RequestPasswordResetCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RequestPasswordResetAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> ConfirmPasswordResetAsync(
        ConfirmPasswordResetCommand command,
        IValidator<ConfirmPasswordResetCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ConfirmPasswordResetAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> VerifyPasswordResetCodeAsync(
        VerifyPasswordResetCodeCommand command,
        IValidator<VerifyPasswordResetCodeCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.VerifyPasswordResetCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> ResetPasswordAsync(
        ResetPasswordCommand command,
        IValidator<ResetPasswordCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ResetPasswordAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Accepted, ProblemHttpResult>> RequestCurrentPasswordChangeCodeAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.RequestCurrentPasswordChangeCodeAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "users.not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: statusCode);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> ConfirmCurrentPasswordChangeAsync(
        HttpContext context,
        ConfirmCurrentPasswordChangeCommand command,
        IValidator<ConfirmCurrentPasswordChangeCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var resolvedCommand = command with
        {
            RefreshToken = ResolveRefreshToken(context, command.RefreshToken)
        };

        var validation = await validator.ValidateAsync(resolvedCommand, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ConfirmCurrentPasswordChangeAsync(userId, resolvedCommand, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "auth.invalid_refresh", StringComparison.Ordinal)
                ? StatusCodes.Status401Unauthorized
                : string.Equals(result.Error.Code, "users.not_found", StringComparison.Ordinal)
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> RefreshAsync(
        HttpContext context,
        RefreshTokenCommand? request,
        IValidator<RefreshTokenCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var resolvedRefreshToken = ResolveRefreshToken(context, request?.RefreshToken);
        var command = new RefreshTokenCommand(resolvedRefreshToken ?? string.Empty);
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

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> LogoutAsync(
        HttpContext context,
        RefreshTokenCommand? request,
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

        var resolvedRefreshToken = ResolveRefreshToken(context, request?.RefreshToken);
        var logoutCommand = new LogoutCommand(userId, resolvedRefreshToken ?? string.Empty);
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

        DeleteRefreshTokenCookie(context);
        return TypedResults.NoContent();
    }

}
