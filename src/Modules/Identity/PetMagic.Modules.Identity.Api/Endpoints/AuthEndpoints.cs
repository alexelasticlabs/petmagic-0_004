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
    private const string InvalidSubjectCode = "auth.invalid_subject";
    private const string RefreshTokenOwnershipViolationCode = "auth.refresh_token_not_owned";
    private const string EmailNotConfirmedCode = "auth.email_not_confirmed";
    private const string UserAlreadyExistsCode = "auth.user_exists";
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
    private const string DefaultMobileRedirectScheme = "petmagic";
    internal const string MobileRedirectSchemeConfigurationKey = "ExternalAuth:MobileRedirectScheme";
    private const string MobileRedirectHost = "auth";
    private const string MobileRedirectPath = "/external";
    private const int MaxAuthJsonRequestBodyBytes = 32 * 1024;
    private const long MaxAvatarUploadRequestBodyBytes = 9L * 1024 * 1024;

    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/auth")
            .WithTags("Auth")
            .AddEndpointFilter(ApplySensitiveNoStoreHeadersAsync)
            .RequireRateLimiting("auth");

        group.MapPost("/register", RegisterAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-register")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/login", LoginAsync)
            .AllowAnonymous()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/email-confirmation/request", RequestEmailConfirmationAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-email-verification")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/email-confirmation/confirm", ConfirmEmailAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-email-verification")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/resend-email-verification-code", ResendEmailVerificationCodeAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-email-verification")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/verify-email-code", VerifyEmailCodeAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-email-verification")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/password-reset/request", RequestPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/password-reset/confirm", ConfirmPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/request-password-reset", RequestPasswordResetAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/verify-password-reset-code", VerifyPasswordResetCodeAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/reset-password", ResetPasswordAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/me/password-change/request", RequestCurrentPasswordChangeCodeAsync)
            .RequireAuthorization()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/me/password-change/confirm", ConfirmCurrentPasswordChangeAsync)
            .RequireAuthorization()
            .RequireRateLimiting("auth-password-reset")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/refresh", RefreshAsync)
            .AllowAnonymous()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/logout", LogoutAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapGet("/me", MeAsync)
            .RequireAuthorization();

        group.MapPut("/me/profile", UpdateMeProfileAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapDelete("/me", DeleteMeAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/me/legal-acceptance", AcceptCurrentLegalDocumentsAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapGet("/me/linked-accounts", GetLinkedAccountsAsync)
            .RequireAuthorization();

        group.MapPost("/me/linked-accounts/{provider}/prepare", PrepareLinkedAccountAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/me/linked-accounts/google/native", GoogleNativeLinkAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapDelete("/me/linked-accounts/{provider}", UnlinkLinkedAccountAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPut("/me/avatar", UpdateAvatarAsync)
            .RequireAuthorization()
            .DisableAntiforgery()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAvatarUploadRequestBodyBytes));

        group.MapDelete("/me/avatar", RemoveAvatarAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapGet("/external/{provider}", ExternalChallengeAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external");

        group.MapGet("/external/google/mobile-config", GetGoogleMobileConfigAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external");

        group.MapGet("/external/callback", ExternalCallbackAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external");

        group.MapPost("/external/exchange", ExchangeExternalLoginAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/external/google/native", GoogleNativeLoginAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/google", GoogleSocialLoginAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        group.MapPost("/apple", AppleSocialLoginAsync)
            .AllowAnonymous()
            .RequireRateLimiting("auth-external")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAuthJsonRequestBodyBytes));

        return endpoints;
    }

    private static async ValueTask<object?> ApplySensitiveNoStoreHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        ApplySensitiveNoStoreHeaders(context.HttpContext);

        return await next(context);
    }
}
