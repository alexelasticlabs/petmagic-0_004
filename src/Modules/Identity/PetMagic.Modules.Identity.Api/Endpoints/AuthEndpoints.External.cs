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
using Microsoft.Extensions.Configuration;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static partial class AuthEndpoints
{

    private static async Task<IResult> ExternalChallengeAsync(
        string provider,
        string? redirectUri,
        string? mode,
        string? linkTicket,
        IConfiguration configuration,
        IAuthenticationSchemeProvider authenticationSchemes)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        string? normalizedRedirectUri = null;
        if (normalizedProvider is null)
        {
            return ToExternalAuthProblem("auth.external_invalid", StatusCodes.Status400BadRequest);
        }

        if (redirectUri is not null
            && !TryNormalizeMobileRedirectUri(redirectUri, configuration, out normalizedRedirectUri))
        {
            return ToExternalAuthProblem("auth.external_invalid", StatusCodes.Status400BadRequest);
        }

        if (await authenticationSchemes.GetSchemeAsync(normalizedProvider) is null)
        {
            return BuildExternalCallbackErrorResult(
                normalizedRedirectUri,
                "auth.external_not_configured",
                StatusCodes.Status404NotFound);
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
        [FromServices] IExternalLoginCompletionStore completionStore,
        [FromServices] IExternalAccountLinkStore linkStore,
        IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return ToExternalAuthProblem("auth.external_invalid", StatusCodes.Status400BadRequest);
        }

        var externalAuthResult = await httpContext.AuthenticateAsync(IdentityConstants.ExternalScheme);
        var clientRedirectUri = ReadMobileRedirectUri(externalAuthResult.Properties, configuration);
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
                    StatusCodes.Status401Unauthorized);
            }

            return BuildExternalCallbackErrorResult(
                clientRedirectUri,
                "auth.external_invalid",
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
                StatusCodes.Status400BadRequest);
        }

        if (string.Equals(flowMode, ExternalFlowModeLink, StringComparison.OrdinalIgnoreCase))
        {
            var linkedUserId = string.IsNullOrWhiteSpace(linkTicket)
                ? null
                : await linkStore.TryTakeAsync(linkTicket, cancellationToken);
            if (linkedUserId is null)
            {
                await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);
                return BuildExternalCallbackErrorResult(
                    clientRedirectUri,
                    ExternalTicketInvalidCode,
                    StatusCodes.Status401Unauthorized);
            }

            var linkedResult = await service.LinkExternalLoginAsync(linkedUserId.Value, command, cancellationToken);
            await httpContext.SignOutAsync(IdentityConstants.ExternalScheme);

            if (linkedResult.IsFailure)
            {
                return BuildExternalCallbackErrorResult(
                    clientRedirectUri,
                    linkedResult.Error.Code,
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
                StatusCodes.Status401Unauthorized);
        }

        if (clientRedirectUri is not null)
        {
            var ticket = await completionStore.CreateAsync(result.Value, cancellationToken);
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
            return ToExternalAuthProblem("auth.external_not_configured", StatusCodes.Status404NotFound);
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var verification = await verifier.VerifyIdTokenAsync(command.IdToken, cancellationToken);
        if (verification.IsFailure)
        {
            var statusCode = string.Equals(verification.Error.Code, "auth.external_not_configured", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status401Unauthorized;

            return ToExternalAuthProblem(verification.Error.Code, statusCode);
        }

        var result = await service.ExternalLoginAsync(verification.Value, cancellationToken);
        if (result.IsFailure)
        {
            return ToExternalAuthProblem(result.Error.Code, StatusCodes.Status401Unauthorized);
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
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

            return ToExternalAuthProblem(verification.Error.Code, statusCode);
        }

        var result = await service.ExternalLoginAsync(verification.Value, cancellationToken);
        if (result.IsFailure)
        {
            return ToExternalAuthProblem(result.Error.Code, StatusCodes.Status401Unauthorized);
        }

        WriteRefreshTokenCookie(context, result.Value.RefreshToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TokenPairResponse>, ValidationProblem, ProblemHttpResult>> ExchangeExternalLoginAsync(
        HttpContext context,
        ExternalLoginExchangeRequest request,
        [FromServices] IExternalLoginCompletionStore completionStore,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Ticket))
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(request.Ticket)] = [ExternalTicketInvalidCode]
            });
        }

        var session = await completionStore.TryTakeAsync(request.Ticket, cancellationToken);
        if (session is null)
        {
            return ToExternalAuthProblem(ExternalTicketInvalidCode, StatusCodes.Status401Unauthorized);
        }

        WriteRefreshTokenCookie(context, session.RefreshToken);
        return TypedResults.Ok(session);
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

    private static string? ReadMobileRedirectUri(
        AuthenticationProperties? properties,
        IConfiguration configuration)
    {
        if (properties?.Items.TryGetValue(ExternalRedirectUriProperty, out var redirectUri) == true &&
            redirectUri is not null &&
            TryNormalizeMobileRedirectUri(redirectUri, configuration, out var normalizedRedirectUri))
        {
            return normalizedRedirectUri;
        }

        return null;
    }

    internal static bool TryNormalizeMobileRedirectUri(
        string redirectUri,
        IConfiguration configuration,
        out string? normalizedRedirectUri)
    {
        normalizedRedirectUri = null;

        if (!Uri.TryCreate(redirectUri, UriKind.Absolute, out var parsedUri))
        {
            return false;
        }

        var allowedScheme = configuration[MobileRedirectSchemeConfigurationKey]?.Trim();
        if (string.IsNullOrWhiteSpace(allowedScheme))
        {
            allowedScheme = DefaultMobileRedirectScheme;
        }

        if (!Uri.CheckSchemeName(allowedScheme)
            || !string.Equals(parsedUri.Scheme, allowedScheme, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(parsedUri.Host, MobileRedirectHost, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(parsedUri.AbsolutePath, MobileRedirectPath, StringComparison.Ordinal) ||
            !parsedUri.IsDefaultPort ||
            !string.IsNullOrEmpty(parsedUri.UserInfo) ||
            !string.IsNullOrEmpty(parsedUri.Query) ||
            !string.IsNullOrEmpty(parsedUri.Fragment))
        {
            return false;
        }

        normalizedRedirectUri = parsedUri.GetLeftPart(UriPartial.Path);
        return true;
    }

    private static IResult BuildExternalCallbackErrorResult(
        string? clientRedirectUri,
        string errorCode,
        int statusCode)
    {
        if (clientRedirectUri is not null)
        {
            var redirectUrl = QueryHelpers.AddQueryString(clientRedirectUri, new Dictionary<string, string?>
            {
                ["error"] = errorCode
            });

            return Results.Redirect(redirectUrl);
        }

        return ToExternalAuthProblem(errorCode, statusCode);
    }

    private static ProblemHttpResult ToExternalAuthProblem(string errorCode, int statusCode)
    {
        return TypedResults.Problem(
            title: errorCode,
            statusCode: statusCode,
            extensions: IdentityClientProblems.BuildProblemExtensions(errorCode));
    }

    private sealed record ExternalLoginExchangeRequest(string Ticket);

    private sealed record GoogleMobileConfigResponse(string ServerClientId);

}
