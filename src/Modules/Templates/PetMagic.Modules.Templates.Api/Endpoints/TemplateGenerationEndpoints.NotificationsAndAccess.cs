using System.Security.Claims;

using FluentValidation;

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
    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext context,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] IValidator<RegisterTemplatePushTokenCommand> validator,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var command = new RegisterTemplatePushTokenCommand(
            userId!.Value,
            request.Token,
            request.Platform,
            request.DeviceId,
            request.AppVersion,
            request.Locale);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await pushTokenService.RegisterAsync(command, cancellationToken);

        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext context,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] IValidator<UnregisterTemplatePushTokenCommand> validator,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var command = new UnregisterTemplatePushTokenCommand(userId!.Value, request.Token);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await pushTokenService.UnregisterAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static bool IsOneOf(string value, params string[] allowedValues)
    {
        return allowedValues.Any(allowed => string.Equals(allowed, value, StringComparison.OrdinalIgnoreCase));
    }

    private static ProblemHttpResult ToClientGenerationProblem(Error error)
    {
        return TypedResults.Problem(
            title: error.Code,
            detail: GetClientGenerationProblemDetail(error),
            statusCode: ResolveFailureStatusCode(error),
            extensions: BuildClientGenerationProblemExtensions(error));
    }

    private static Dictionary<string, object?> BuildClientGenerationProblemExtensions(Error error)
    {
        var extensions = new Dictionary<string, object?>
        {
            ["code"] = error.Code
        };

        if (error.Code != "GENERATION_WAIT_TOO_LONG" || error.Metadata is null)
        {
            return extensions;
        }

        CopyIfPresent(error.Metadata, extensions, "mediaType");
        CopyIfPresent(error.Metadata, extensions, "tier");
        CopyIfPresent(error.Metadata, extensions, "estimatedWaitSeconds");
        CopyIfPresent(error.Metadata, extensions, "maxAllowedWaitSeconds");
        CopyIfPresent(error.Metadata, extensions, "retryAfterSeconds");
        CopyIfPresent(error.Metadata, extensions, "canRetry");
        CopyIfPresent(error.Metadata, extensions, "canUpgradeForPriority");
        return extensions;
    }

    private static void CopyIfPresent(
        IReadOnlyDictionary<string, object?> source,
        Dictionary<string, object?> target,
        string key)
    {
        if (source.TryGetValue(key, out var value))
        {
            target[key] = value;
        }
    }

    private static int ResolveFailureStatusCode(Error error)
    {
        return error.Code switch
        {
            "templates.invalid_subject" => StatusCodes.Status401Unauthorized,
            "templates.not_found" => StatusCodes.Status404NotFound,
            "GENERATION_JOB_NOT_FOUND" => StatusCodes.Status404NotFound,
            "templates.invalid_status" => StatusCodes.Status409Conflict,
            "templates.type_mismatch" => StatusCodes.Status400BadRequest,
            "templates.generation_result_input_unavailable" => StatusCodes.Status409Conflict,
            "templates.generation_result_input_unsupported" => StatusCodes.Status400BadRequest,
            "templates.generate_similar_unsupported" => StatusCodes.Status409Conflict,
            "templates.image_model_required" => StatusCodes.Status409Conflict,
            "templates.invalid_image_model" => StatusCodes.Status400BadRequest,
            "templates.reference_motion_required" => StatusCodes.Status409Conflict,
            "templates.character_orientation_required" => StatusCodes.Status409Conflict,
            "templates.premium_required" => StatusCodes.Status403Forbidden,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            "templates.watermark_not_ready" => StatusCodes.Status202Accepted,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "GENERATION_QUEUE_OVERLOADED" => StatusCodes.Status503ServiceUnavailable,
            "GENERATION_WAIT_TOO_LONG" => StatusCodes.Status503ServiceUnavailable,
            "templates.generation_cancel_not_allowed" => StatusCodes.Status409Conflict,
            "templates.generation_cancel_disabled" => StatusCodes.Status403Forbidden,
            "pets.not_found" => StatusCodes.Status404NotFound,
            "pets.photo_not_found" => StatusCodes.Status404NotFound,
            "pets.photo_required" => StatusCodes.Status409Conflict,
            "templates.source_media_unavailable" => StatusCodes.Status409Conflict,
            "templates.invalid_feedback" => StatusCodes.Status400BadRequest,
            "feedback.not_found" => StatusCodes.Status404NotFound,
            "feedback.forbidden" => StatusCodes.Status403Forbidden,
            "feedback.rate_limited" => StatusCodes.Status429TooManyRequests,
            "feedback.refund_unavailable" => StatusCodes.Status409Conflict,
            "feedback.refund_already_issued" => StatusCodes.Status409Conflict,
            "feedback.invalid_status" => StatusCodes.Status400BadRequest,
            "feedback.invalid_priority" => StatusCodes.Status400BadRequest,
            "feedback.invalid_type" => StatusCodes.Status400BadRequest,
            "templates.push_token_invalid" => StatusCodes.Status400BadRequest,
            "templates.invalid_media_upload" => StatusCodes.Status400BadRequest,
            "templates.media_storage_failed" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static string GetClientGenerationProblemDetail(Error error)
    {
        return error.Code switch
        {
            "templates.invalid_subject" => "Authentication failed.",
            "templates.not_found" or "GENERATION_JOB_NOT_FOUND" => "Generation was not found.",
            "templates.invalid_status" => "Generation is not available for this action.",
            "templates.type_mismatch" => "Template type does not support this action.",
            "templates.generation_result_input_unavailable" => "Source generation result is no longer available.",
            "templates.generation_result_input_unsupported" => "Selected template cannot use this generation result.",
            "templates.generate_similar_unsupported" => "This generation cannot be used to create a similar result.",
            "templates.image_model_required"
                or "templates.invalid_image_model"
                or "templates.reference_motion_required"
                or "templates.character_orientation_required" => "Template is temporarily unavailable.",
            "templates.premium_required" => PremiumRequiredMessage,
            "economy.insufficient_balance" => "Not enough credits to complete this action.",
            "templates.watermark_not_ready" => "Generation media is still being prepared.",
            "ACTIVE_GENERATION_LIMIT_REACHED" => "Too many active generations are already running. Try again after one completes.",
            "GENERATION_QUEUE_OVERLOADED" or "GENERATION_WAIT_TOO_LONG" => "Generation queue is busy. Please try again later.",
            "templates.generation_cancel_not_allowed" => "Only queued generations can be cancelled.",
            "templates.generation_cancel_disabled" => "Generation cancellation is temporarily unavailable.",
            "pets.not_found" => "Associated pet was not found.",
            "pets.photo_not_found" => "Associated pet photo was not found.",
            "pets.photo_required" => "A pet photo is required to start this generation.",
            "templates.source_media_unavailable" => "Source media is no longer available.",
            "templates.invalid_feedback" => "Generation feedback is invalid.",
            "feedback.not_found" => "Generation feedback was not found.",
            "feedback.forbidden" => "Generation feedback does not belong to the current user.",
            "feedback.rate_limited" => "Too many feedback requests. Please try again later.",
            "feedback.refund_unavailable" => "Feedback refund is not available.",
            "feedback.refund_already_issued" => "Credits were already refunded for this generation feedback.",
            "feedback.invalid_status" => "Generation feedback status is invalid.",
            "feedback.invalid_priority" => "Generation feedback priority is invalid.",
            "feedback.invalid_type" => "Generation feedback type is invalid.",
            "templates.push_token_invalid" => "Push device token is invalid.",
            "templates.invalid_media_upload" => "Uploaded media is invalid.",
            "templates.media_storage_failed" => "Uploaded media could not be stored.",
            _ => "Template generation request could not be completed."
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

    private static async Task<string> ResolveQueueTierAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (IsPrivilegedTemplateUser(context.User))
        {
            return "privileged";
        }

        return await HasPremiumTemplateAccessAsync(context, userId, cancellationToken)
            ? "premium"
            : "free";
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
