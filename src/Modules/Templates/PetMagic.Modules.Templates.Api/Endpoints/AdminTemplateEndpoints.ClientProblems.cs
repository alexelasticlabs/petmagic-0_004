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
            detail: GetAdminTemplateProblemDetail(error.Code, statusCode),
            statusCode: statusCode);
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
                or "templates.template_of_the_day_date_occupied"
                or "templates.template_of_the_day_auto_mode_disabled" => StatusCodes.Status409Conflict,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "templates.media_storage_failed"
                or "templates.media_metadata_failed"
                or "templates.generated_media_import_failed"
                or "templates.ai_provider_unavailable"
                or "templates.ai_provider_failed"
                or "templates.ai_provider_timed_out"
                or "GENERATION_QUEUE_OVERLOADED"
                or "GENERATION_WAIT_TOO_LONG" => StatusCodes.Status503ServiceUnavailable,
            "templates.watermark_not_ready" => StatusCodes.Status202Accepted,
            _ => StatusCodes.Status400BadRequest,
        };
    }

    private static string GetAdminTemplateProblemDetail(string errorCode, int statusCode)
    {
        return errorCode switch
        {
            "templates.invalid_subject" => "Authentication failed.",
            "templates.not_found" => "Template was not found.",
            "GENERATION_JOB_NOT_FOUND" => "Generation was not found.",
            "templates.invalid_status" => "Template state does not allow this action.",
            "templates.type_mismatch" => "Template type does not support this action.",
            "templates.preview_required" => "Template preview is required before this action can be completed.",
            "templates.image_model_required" => "Image model must be configured before this action can be completed.",
            "templates.reference_motion_required" => "Reference motion asset is required before this action can be completed.",
            "templates.reference_duration_required" => "Reference motion duration must be available before this action can be completed.",
            "templates.character_orientation_required" => "Character orientation must be available before this action can be completed.",
            "templates.invalid_image_model"
                or "templates.invalid_preprocessing_model"
                or "templates.invalid_kling_model" => "Selected model configuration is invalid.",
            "templates.invalid_media_upload" => "Uploaded media is invalid.",
            "templates.media_storage_failed" => "Media storage is temporarily unavailable.",
            "templates.media_metadata_failed" => "Media metadata could not be read right now.",
            "templates.generated_media_import_failed" => "Generated media could not be imported right now.",
            "templates.generated_media_too_large" => "Generated media exceeds the maximum allowed size.",
            "templates.update_conflict" => "Template was changed while saving. Reload and try again.",
            "templates.watermark_disabled" => "Watermarking is disabled.",
            "templates.watermark_already_removed" => "Watermark has already been removed.",
            "templates.watermark_not_ready" => "Generation media is still being prepared.",
            "templates.template_of_the_day_invalid_date_range" => "Template of the Day date range is invalid.",
            "templates.template_of_the_day_date_occupied" => "Template of the Day already has an active manual assignment for this date range.",
            "templates.template_of_the_day_template_unavailable" => "Template of the Day requires an active template with a valid preview asset.",
            "templates.template_of_the_day_auto_mode_disabled" => "Template of the Day auto-pick is disabled.",
            "ACTIVE_GENERATION_LIMIT_REACHED" => "Too many active generations are already running. Try again after one completes.",
            "GENERATION_QUEUE_OVERLOADED" or "GENERATION_WAIT_TOO_LONG" => "Generation queue is busy. Please try again later.",
            "templates.ai_provider_unavailable"
                or "templates.ai_provider_failed"
                or "templates.ai_provider_timed_out" => "AI provider is temporarily unavailable.",
            _ when statusCode == StatusCodes.Status404NotFound => "Requested template resource was not found.",
            _ when statusCode == StatusCodes.Status409Conflict => "Template request conflicts with the current resource state.",
            _ when statusCode == StatusCodes.Status429TooManyRequests => "Too many template requests are already running. Please try again later.",
            _ when statusCode == StatusCodes.Status503ServiceUnavailable => "Template administration is temporarily unavailable.",
            _ => "Template request could not be completed.",
        };
    }
}
