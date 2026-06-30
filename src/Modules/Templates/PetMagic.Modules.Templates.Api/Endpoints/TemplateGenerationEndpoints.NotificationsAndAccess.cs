using System.Security.Claims;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private static async Task<Results<NoContent, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext context,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await pushTokenService.RegisterAsync(
            new RegisterTemplatePushTokenCommand(
                userId!.Value,
                request.Token,
                request.Platform,
                request.DeviceId,
                request.AppVersion,
                request.Locale),
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext context,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        await pushTokenService.UnregisterAsync(
            new UnregisterTemplatePushTokenCommand(userId!.Value, request.Token),
            cancellationToken);

        return TypedResults.NoContent();
    }

    private static bool IsOneOf(string value, params string[] allowedValues)
    {
        return allowedValues.Any(allowed => string.Equals(allowed, value, StringComparison.OrdinalIgnoreCase));
    }

    private static int ResolveFailureStatusCode(Error error)
    {
        return error.Code switch
        {
            "templates.not_found" => StatusCodes.Status404NotFound,
            "GENERATION_JOB_NOT_FOUND" => StatusCodes.Status404NotFound,
            "templates.invalid_status" => StatusCodes.Status409Conflict,
            "templates.type_mismatch" => StatusCodes.Status400BadRequest,
            "templates.generation_result_input_unavailable" => StatusCodes.Status409Conflict,
            "templates.generation_result_input_unsupported" => StatusCodes.Status400BadRequest,
            "templates.image_model_required" => StatusCodes.Status409Conflict,
            "templates.invalid_image_model" => StatusCodes.Status400BadRequest,
            "templates.reference_motion_required" => StatusCodes.Status409Conflict,
            "templates.character_orientation_required" => StatusCodes.Status409Conflict,
            "templates.premium_required" => StatusCodes.Status403Forbidden,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            "templates.watermark_not_ready" => StatusCodes.Status202Accepted,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "GENERATION_QUEUE_OVERLOADED" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static bool IsNotFoundError(Error error)
    {
        return string.Equals(error.Code, "templates.not_found", StringComparison.Ordinal)
            || string.Equals(error.Code, "GENERATION_JOB_NOT_FOUND", StringComparison.Ordinal);
    }

    private static bool TryGetPremiumClaim(ClaimsPrincipal principal, out bool isPremium)
    {
        var premiumRaw = principal.FindFirstValue("premium");
        if (string.IsNullOrWhiteSpace(premiumRaw))
        {
            isPremium = false;
            return false;
        }

        isPremium = string.Equals(premiumRaw, "true", StringComparison.OrdinalIgnoreCase);
        return true;
    }

    private static bool IsPrivilegedTemplateUser(ClaimsPrincipal principal)
    {
        return principal.IsInRole("Admin") || principal.IsInRole("Moderator");
    }

    private static async Task<int> ResolveActiveGenerationLimitAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (IsPrivilegedTemplateUser(context.User))
        {
            return PrivilegedActiveGenerationLimit;
        }

        return await HasPremiumTemplateAccessAsync(context, userId, cancellationToken)
            ? PremiumActiveGenerationLimit
            : FreeActiveGenerationLimit;
    }

    private static async Task<bool> HasPremiumTemplateAccessAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (IsPrivilegedTemplateUser(context.User))
        {
            return true;
        }

        var hasPremiumClaim = TryGetPremiumClaim(context.User, out var claimPremiumValue);
        if (hasPremiumClaim && claimPremiumValue)
        {
            return true;
        }

        var identityService = context.RequestServices.GetService<IIdentityService>();
        if (identityService is null)
        {
            return hasPremiumClaim && claimPremiumValue;
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        return profile.IsSuccess && profile.Value.IsPremium;
    }

    private static string? NormalizeIdempotencyKey(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static (Guid? UserId, Error? Error) TryGetSubject(HttpContext context)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return (null, new Error(InvalidSubjectCode, InvalidSubjectMessage));
        }

        return (userId, null);
    }

    private sealed record RegisterPushTokenRequest(string Token, string Platform, string? DeviceId, string? AppVersion, string? Locale);

    private sealed record UnregisterPushTokenRequest(string Token);
}
