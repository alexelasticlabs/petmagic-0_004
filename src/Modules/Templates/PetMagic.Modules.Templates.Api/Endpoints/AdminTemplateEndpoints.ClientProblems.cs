using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static ProblemHttpResult ToAdminTemplateProblem(Error error)
    {
        var statusCode = ResolveAdminTemplateProblemStatusCode(error.Code);
        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildAdminTemplateProblemExtensions(error.Code));
    }

    private static int ResolveAdminTemplateProblemStatusCode(string errorCode)
    {
        return errorCode switch
        {
            "templates.invalid_subject" => StatusCodes.Status401Unauthorized,
            "templates.not_found"
                or "GENERATION_JOB_NOT_FOUND"
                or "templates.template_of_the_day_template_unavailable" => StatusCodes.Status404NotFound,
            "templates.invalid_status"
                or "templates.preview_required"
                or "templates.image_model_required"
                or "templates.reference_motion_required"
                or "templates.reference_duration_required"
                or "templates.character_orientation_required"
                or "templates.update_conflict"
                or "templates.watermark_disabled"
                or "templates.watermark_already_removed"
                or "templates.generation_cancel_disabled"
                or "templates.generation_cancel_not_allowed"
                or "templates.generation_cancel_already_completed"
                or "templates.generation_cancel_provider_not_found"
                or "templates.generation_cancel_provider_unsupported"
                or "templates.generation_cancel_retry_exhausted"
                or "templates.generation_retry_not_allowed"
                or "templates.generation_refund_not_pending"
                or "templates.gamification_legacy_review_not_required"
                or "templates.template_of_the_day_date_occupied"
                or "templates.template_of_the_day_auto_mode_disabled" => StatusCodes.Status409Conflict,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "templates.media_storage_failed"
                or "templates.media_metadata_failed"
                or "templates.generated_media_import_failed"
                or "templates.ai_provider_unavailable"
                or "templates.ai_provider_failed"
                or "templates.ai_provider_transient"
                or "templates.ai_provider_timed_out"
                or "templates.generation_attempts_exceeded"
                or "PROVIDER_CAPACITY_UNAVAILABLE"
                or "GENERATION_QUEUE_OVERLOADED"
                or "GENERATION_WAIT_TOO_LONG" => StatusCodes.Status503ServiceUnavailable,
            "templates.watermark_not_ready" => StatusCodes.Status202Accepted,
            _ => StatusCodes.Status400BadRequest,
        };
    }

    private static Dictionary<string, object?> BuildAdminTemplateProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
