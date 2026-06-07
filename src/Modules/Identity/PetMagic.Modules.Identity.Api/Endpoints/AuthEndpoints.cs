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

public static class AuthEndpoints
{
    private const string InvalidSubjectCode = "auth.invalid_subject";
    private const string RefreshTokenOwnershipViolationCode = "auth.refresh_token_not_owned";
    private const string EmailNotConfirmedCode = "auth.email_not_confirmed";
    private const string RefreshTokenCookieName = "petmagic_refresh_token";
    private const string RefreshTokenCookiePath = "/api/auth";
    private const int RefreshTokenCookieLifetimeDays = 30;
    private const string ExternalRedirectUriProperty = "mobile_redirect_uri";
    private const string ExternalLinkTicketProperty = "external_link_ticket";
    private const string ExternalFlowModeProperty = "external_flow_mode";
    private const string ExternalTicketInvalidCode = "auth.external_ticket_invalid";
    private const string ExternalCancelledCode = "auth.external_cancelled";
    private const string ExternalFlowModeLink = "link";
    private const string ExternalTicketInvalidMessage = "External sign-in session is invalid or expired.";
    private const string ExternalCancelledMessage = "External sign-in was cancelled.";
    private const string UnsupportedRedirectUriMessage = "Unsupported redirect URI.";
    private const string MobileRedirectScheme = "petmagic";
    private const string MobileRedirectHost = "auth";
    private const string MobileRedirectPath = "/external";

    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/auth")
            .WithTags("Auth")
            .RequireRateLimiting("auth");

        group.MapPost("/register", RegisterAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-register");

        group.MapPost("/login", LoginAsync)
            .AllowAnonymous();

        group.MapPost("/email-confirmation/request", RequestEmailConfirmationAsync)
            .AllowAnonymous();

        group.MapPost("/email-confirmation/confirm", ConfirmEmailAsync)
            .AllowAnonymous();

        group.MapPost("/resend-email-verification-code", ResendEmailVerificationCodeAsync)
            .AllowAnonymous();

        group.MapPost("/verify-email-code", VerifyEmailCodeAsync)
            .AllowAnonymous();

        group.MapPost("/password-reset/request", RequestPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/password-reset/confirm", ConfirmPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/request-password-reset", RequestPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/verify-password-reset-code", VerifyPasswordResetCodeAsync)
            .AllowAnonymous();

        group.MapPost("/reset-password", ResetPasswordAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/me/password-change/request", RequestCurrentPasswordChangeCodeAsync)
            .RequireAuthorization()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/me/password-change/confirm", ConfirmCurrentPasswordChangeAsync)
            .RequireAuthorization()
            .RequireRateLimiting("auth-password-reset");

        group.MapPost("/refresh", RefreshAsync)
            .AllowAnonymous();

        group.MapPost("/logout", LogoutAsync)
            .RequireAuthorization();

        group.MapGet("/me", MeAsync)
            .RequireAuthorization();

        group.MapPut("/me/profile", UpdateMeProfileAsync)
            .RequireAuthorization();

        group.MapDelete("/me", DeleteMeAsync)
            .RequireAuthorization();

        group.MapPost("/me/legal-acceptance", AcceptCurrentLegalDocumentsAsync)
            .RequireAuthorization();

        group.MapGet("/me/linked-accounts", GetLinkedAccountsAsync)
            .RequireAuthorization();

        group.MapPost("/me/linked-accounts/{provider}/prepare", PrepareLinkedAccountAsync)
            .RequireAuthorization();

        group.MapDelete("/me/linked-accounts/{provider}", UnlinkLinkedAccountAsync)
            .RequireAuthorization();

        group.MapPut("/me/avatar", UpdateAvatarAsync)
            .RequireAuthorization()
            .DisableAntiforgery();

        group.MapDelete("/me/avatar", RemoveAvatarAsync)
            .RequireAuthorization();

        group.MapGet("/external/{provider}", ExternalChallengeAsync)
            .AllowAnonymous();

        group.MapGet("/external/google/mobile-config", GetGoogleMobileConfigAsync)
            .AllowAnonymous();

        group.MapGet("/external/callback", ExternalCallbackAsync)
            .AllowAnonymous();

        group.MapPost("/external/exchange", ExchangeExternalLoginAsync)
            .AllowAnonymous();

        group.MapPost("/external/google/native", GoogleNativeLoginAsync)
            .AllowAnonymous();

        group.MapPost("/google", GoogleSocialLoginAsync)
            .AllowAnonymous();

        group.MapPost("/apple", AppleSocialLoginAsync)
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

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> VerifyEmailCodeAsync(
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

        return TypedResults.NoContent();
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

    private static IResult ExternalChallengeAsync(string provider, string? redirectUri, string? mode, string? linkTicket)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        string? normalizedRedirectUri = null;
        if (normalizedProvider is null)
        {
            return Results.BadRequest(new { message = "Unsupported provider." });
        }

        if (redirectUri is not null && !TryNormalizeMobileRedirectUri(redirectUri, out normalizedRedirectUri))
        {
            return Results.BadRequest(new { message = UnsupportedRedirectUriMessage });
        }

        var callbackRedirectUri = $"/api/auth/external/callback?provider={normalizedProvider}";
        var properties = new AuthenticationProperties { RedirectUri = callbackRedirectUri };
        if (normalizedRedirectUri is not null)
        {
            properties.Items[ExternalRedirectUriProperty] = normalizedRedirectUri;
        }

        if (string.Equals(mode, ExternalFlowModeLink, StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrWhiteSpace(linkTicket))
        {
            properties.Items[ExternalFlowModeProperty] = ExternalFlowModeLink;
            properties.Items[ExternalLinkTicketProperty] = linkTicket;
        }

        return Results.Challenge(
            properties,
            authenticationSchemes: [normalizedProvider]);
    }

    private static async Task<IResult> ExternalCallbackAsync(
        string provider,
        HttpContext httpContext,
        IValidator<ExternalLoginCallbackCommand> validator,
        IIdentityService service,
        ExternalLoginCompletionStore completionStore,
        ExternalAccountLinkStore linkStore,
        CancellationToken cancellationToken)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return Results.BadRequest(new { message = "Unsupported provider." });
        }

        var externalAuthResult = await httpContext.AuthenticateAsync(IdentityConstants.ExternalScheme);
        var clientRedirectUri = ReadMobileRedirectUri(externalAuthResult.Properties);
        var flowMode = ReadAuthProperty(externalAuthResult.Properties, ExternalFlowModeProperty);
        var linkTicket = ReadAuthProperty(externalAuthResult.Properties, ExternalLinkTicketProperty);
        if (!externalAuthResult.Succeeded || externalAuthResult.Principal is null)
        {
            var providerError = httpContext.Request.Query["error"].ToString();
            if (string.Equals(providerError, "access_denied", StringComparison.OrdinalIgnoreCase))
            {
                return BuildExternalCallbackErrorResult(
                    clientRedirectUri,
                    ExternalCancelledCode,
                    ExternalCancelledMessage,
                    StatusCodes.Status401Unauthorized);
            }

            return BuildExternalCallbackErrorResult(
                clientRedirectUri,
                "auth.external_invalid",
                "External authentication failed.",
                StatusCodes.Status401Unauthorized);
        }

        var principal = externalAuthResult.Principal;
        var providerSubject = principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue("sub")
            ?? string.Empty;

        var command = new ExternalLoginCallbackCommand(
            normalizedProvider,
            providerSubject,
            principal.FindFirstValue(ClaimTypes.Email) ?? principal.FindFirstValue("email"),
            principal.FindFirstValue(ClaimTypes.Name) ?? principal.FindFirstValue("name"));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);
            return BuildExternalCallbackErrorResult(
                clientRedirectUri,
                "auth.external_invalid",
                "External principal payload is invalid.",
                StatusCodes.Status400BadRequest);
        }

        if (string.Equals(flowMode, ExternalFlowModeLink, StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(linkTicket) || !linkStore.TryTake(linkTicket, out var userId))
            {
                await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);
                return BuildExternalCallbackErrorResult(
                    clientRedirectUri,
                    ExternalTicketInvalidCode,
                    ExternalTicketInvalidMessage,
                    StatusCodes.Status401Unauthorized);
            }

            var linkedResult = await service.LinkExternalLoginAsync(userId, command, cancellationToken);
            await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);

            if (linkedResult.IsFailure)
            {
                return BuildExternalCallbackErrorResult(
                    clientRedirectUri,
                    linkedResult.Error.Code,
                    linkedResult.Error.Message,
                    StatusCodes.Status400BadRequest);
            }

            if (clientRedirectUri is not null)
            {
                var redirectUrl = QueryHelpers.AddQueryString(clientRedirectUri, new Dictionary<string, string?>
                {
                    ["mode"] = ExternalFlowModeLink,
                    ["provider"] = normalizedProvider,
                    ["linked"] = "1"
                });

                return Results.Redirect(redirectUrl);
            }

            return TypedResults.Ok(linkedResult.Value);
        }

        var result = await service.ExternalLoginAsync(command, cancellationToken);
        await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);

        if (result.IsFailure)
        {
            return BuildExternalCallbackErrorResult(
                clientRedirectUri,
                result.Error.Code,
                result.Error.Message,
                StatusCodes.Status401Unauthorized);
        }

        if (clientRedirectUri is not null)
        {
            var ticket = completionStore.Create(result.Value);
            var redirectUrl = QueryHelpers.AddQueryString(clientRedirectUri, new Dictionary<string, string?>
            {
                ["ticket"] = ticket,
                ["provider"] = normalizedProvider
            });

            return Results.Redirect(redirectUrl);
        }

        WriteRefreshTokenCookie(httpContext, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static Results<Ok<GoogleMobileConfigResponse>, ProblemHttpResult> GetGoogleMobileConfigAsync(
        IGoogleIdentityTokenVerifier verifier)
    {
        if (!verifier.IsConfigured || string.IsNullOrWhiteSpace(verifier.ClientId))
        {
            return TypedResults.Problem(
                title: "auth.external_not_configured",
                detail: "Google sign-in is not configured.",
                statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(new GoogleMobileConfigResponse(verifier.ClientId));
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> GoogleNativeLoginAsync(
        HttpContext context,
        GoogleNativeLoginCommand command,
        [FromServices] IValidator<GoogleNativeLoginCommand> validator,
        [FromServices] IGoogleIdentityTokenVerifier verifier,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var verification = await verifier.VerifyIdTokenAsync(command.IdToken, cancellationToken);
        if (verification.IsFailure)
        {
            var statusCode = string.Equals(verification.Error.Code, "auth.external_not_configured", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status401Unauthorized;

            return TypedResults.Problem(
                title: verification.Error.Code,
                detail: verification.Error.Message,
                statusCode: statusCode);
        }

        var result = await service.ExternalLoginAsync(verification.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status401Unauthorized);
        }

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> GoogleSocialLoginAsync(
        HttpContext context,
        GoogleSocialLoginCommand command,
        [FromServices] IValidator<GoogleSocialLoginCommand> validator,
        [FromServices] IGoogleIdentityTokenVerifier verifier,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        return await CompleteSocialLoginAsync(
            context,
            verifier.VerifyIdTokenAsync(command.IdToken, cancellationToken),
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> AppleSocialLoginAsync(
        HttpContext context,
        AppleSocialLoginCommand command,
        [FromServices] IValidator<AppleSocialLoginCommand> validator,
        [FromServices] IAppleIdentityTokenVerifier verifier,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        return await CompleteSocialLoginAsync(
            context,
            verifier.VerifyIdTokenAsync(command.IdentityToken, cancellationToken),
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> CompleteSocialLoginAsync(
        HttpContext context,
        Task<PetMagic.BuildingBlocks.Results.Result<ExternalLoginCallbackCommand>> verificationTask,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var verification = await verificationTask;
        if (verification.IsFailure)
        {
            var statusCode = string.Equals(verification.Error.Code, "auth.external_not_configured", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status401Unauthorized;

            return TypedResults.Problem(
                title: verification.Error.Code,
                detail: verification.Error.Message,
                statusCode: statusCode);
        }

        var result = await service.ExternalLoginAsync(verification.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status401Unauthorized);
        }

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult> ExchangeExternalLoginAsync(
        HttpContext context,
        ExternalLoginExchangeRequest request,
        ExternalLoginCompletionStore completionStore)
    {
        if (string.IsNullOrWhiteSpace(request.Ticket))
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(request.Ticket)] = ["Ticket is required."]
            });
        }

        if (!completionStore.TryTake(request.Ticket, out var session) || session is null)
        {
            return TypedResults.Problem(
                title: ExternalTicketInvalidCode,
                detail: ExternalTicketInvalidMessage,
                statusCode: StatusCodes.Status401Unauthorized);
        }

        WriteRefreshTokenCookie(context, session.RefreshToken);
        return TypedResults.Ok(session);
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

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> UpdateMeProfileAsync(
        HttpContext context,
        UpdateCurrentUserProfileCommand command,
        IValidator<UpdateCurrentUserProfileCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.UpdateCurrentUserProfileAsync(userId, command, cancellationToken);
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

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteMeAsync(
        HttpContext context,
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

        var result = await service.DeleteCurrentUserAsync(new DeleteCurrentUserCommand(userId), cancellationToken);
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

        DeleteRefreshTokenCookie(context);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> AcceptCurrentLegalDocumentsAsync(
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
            return TypedResults.Problem(
                title: InvalidSubjectCode,
                detail: "Invalid access token subject.",
                statusCode: StatusCodes.Status401Unauthorized);
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

    private static async Task<Results<Ok<IReadOnlyList<LinkedAccountResponse>>, ProblemHttpResult>> GetLinkedAccountsAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.GetLinkedAccountsAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static Results<Ok<ExternalLinkPreparationResponse>, ProblemHttpResult> PrepareLinkedAccountAsync(
        string provider,
        HttpContext context,
        ExternalAccountLinkStore linkStore)
    {
        if (NormalizeExternalProvider(provider) is null)
        {
            return TypedResults.Problem(
                title: "auth.external_invalid",
                detail: "Unsupported provider.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        return TypedResults.Ok(new ExternalLinkPreparationResponse(linkStore.Create(userId)));
    }

    private static async Task<Results<Ok<IReadOnlyList<LinkedAccountResponse>>, ProblemHttpResult>> UnlinkLinkedAccountAsync(
        string provider,
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return TypedResults.Problem(
                title: "auth.external_invalid",
                detail: "Unsupported provider.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.UnlinkExternalLoginAsync(userId, normalizedProvider, cancellationToken);
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

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> UpdateAvatarAsync(
        HttpContext context,
        IIdentityService service,
        [FromForm] IFormFile? file,
        CancellationToken cancellationToken)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return TypedResults.Problem(title: InvalidSubjectCode, detail: "Invalid access token subject.", statusCode: StatusCodes.Status401Unauthorized);
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Avatar file is required."]
            });
        }

        await using var stream = file.OpenReadStream();
        var result = await service.UpdateUserAvatarAsync(
            new UpdateUserAvatarCommand(
                userId,
                Path.GetFileName(file.FileName),
                file.ContentType ?? "application/octet-stream",
                stream,
                file.Length),
            cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ProblemHttpResult>> RemoveAvatarAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return TypedResults.Problem(title: InvalidSubjectCode, detail: "Invalid access token subject.", statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.RemoveUserAvatarAsync(new RemoveUserAvatarCommand(userId), cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static string? ResolveRefreshToken(HttpContext context, string? requestRefreshToken)
    {
        if (!string.IsNullOrWhiteSpace(requestRefreshToken))
        {
            return requestRefreshToken;
        }

        if (context.Request.Cookies.TryGetValue(RefreshTokenCookieName, out var refreshTokenFromCookie)
            && !string.IsNullOrWhiteSpace(refreshTokenFromCookie))
        {
            return refreshTokenFromCookie;
        }

        return null;
    }

    private static void WriteRefreshTokenCookie(HttpContext context, string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return;
        }

        context.Response.Cookies.Append(RefreshTokenCookieName, refreshToken, BuildRefreshCookieOptions(context));
    }

    private static void DeleteRefreshTokenCookie(HttpContext context)
    {
        context.Response.Cookies.Delete(RefreshTokenCookieName, BuildRefreshCookieDeletionOptions(context));
    }

    private static CookieOptions BuildRefreshCookieOptions(HttpContext context)
    {
        var secureCookie = context.Request.IsHttps;

        return new CookieOptions
        {
            HttpOnly = true,
            Secure = secureCookie,
            SameSite = secureCookie ? SameSiteMode.None : SameSiteMode.Lax,
            IsEssential = true,
            Path = RefreshTokenCookiePath,
            Expires = DateTimeOffset.UtcNow.AddDays(RefreshTokenCookieLifetimeDays)
        };
    }

    private static CookieOptions BuildRefreshCookieDeletionOptions(HttpContext context)
    {
        var secureCookie = context.Request.IsHttps;

        return new CookieOptions
        {
            HttpOnly = true,
            Secure = secureCookie,
            SameSite = secureCookie ? SameSiteMode.None : SameSiteMode.Lax,
            IsEssential = true,
            Path = RefreshTokenCookiePath
        };
    }

    private static string? NormalizeExternalProvider(string provider)
    {
        if (string.Equals(provider, "Google", StringComparison.OrdinalIgnoreCase))
        {
            return "Google";
        }

        if (string.Equals(provider, "Apple", StringComparison.OrdinalIgnoreCase))
        {
            return "Apple";
        }

        return null;
    }

    private static string? ReadAuthProperty(AuthenticationProperties? properties, string key)
    {
        if (properties?.Items.TryGetValue(key, out var value) == true && !string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        return null;
    }

    private static bool TryGetUserId(HttpContext context, out Guid userId, out ProblemHttpResult? problem)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out userId))
        {
            problem = TypedResults.Problem(
                title: InvalidSubjectCode,
                detail: "Invalid access token subject.",
                statusCode: StatusCodes.Status401Unauthorized);
            return false;
        }

        problem = null;
        return true;
    }

    private static string? ReadMobileRedirectUri(AuthenticationProperties? properties)
    {
        if (properties?.Items.TryGetValue(ExternalRedirectUriProperty, out var redirectUri) == true &&
            redirectUri is not null &&
            TryNormalizeMobileRedirectUri(redirectUri, out var normalizedRedirectUri))
        {
            return normalizedRedirectUri;
        }

        return null;
    }

    private static bool TryNormalizeMobileRedirectUri(string redirectUri, out string? normalizedRedirectUri)
    {
        normalizedRedirectUri = null;

        if (!Uri.TryCreate(redirectUri, UriKind.Absolute, out var parsedUri))
        {
            return false;
        }

        if (!string.Equals(parsedUri.Scheme, MobileRedirectScheme, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(parsedUri.Host, MobileRedirectHost, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(parsedUri.AbsolutePath, MobileRedirectPath, StringComparison.Ordinal))
        {
            return false;
        }

        normalizedRedirectUri = parsedUri.GetLeftPart(UriPartial.Path);
        return true;
    }

    private static IResult BuildExternalCallbackErrorResult(
        string? clientRedirectUri,
        string errorCode,
        string errorMessage,
        int statusCode)
    {
        if (clientRedirectUri is not null)
        {
            var redirectUrl = QueryHelpers.AddQueryString(clientRedirectUri, new Dictionary<string, string?>
            {
                ["error"] = errorCode,
                ["message"] = errorMessage
            });

            return Results.Redirect(redirectUrl);
        }

        return TypedResults.Problem(title: errorCode, detail: errorMessage, statusCode: statusCode);
    }

    private sealed record ExternalLoginExchangeRequest(string Ticket);

    private sealed record GoogleMobileConfigResponse(string ServerClientId);
}
