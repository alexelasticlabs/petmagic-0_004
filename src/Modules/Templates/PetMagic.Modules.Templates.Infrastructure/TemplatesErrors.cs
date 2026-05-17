using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplatesErrors
{
    public static readonly Error NotFound = new("templates.not_found", "Template was not found.");
    public static readonly Error CategoryNotFound = new("templates.category_not_found", "Template category was not found.");
    public static readonly Error CategoryAlreadyExists = new("templates.category_already_exists", "Template category already exists.");
    public static readonly Error CategoryArchived = new("templates.category_archived", "Template category is archived and cannot be assigned to new templates.");
    public static readonly Error CategoryHasTemplates = new("templates.category_has_templates", "Template category cannot be deleted while templates still reference it.");
    public static readonly Error TypeMismatch = new("templates.type_mismatch", "Template type does not match the requested operation.");
    public static readonly Error InvalidStatus = new("templates.invalid_status", "Template status is invalid.");
    public static readonly Error MissingPreview = new("templates.preview_required", "Preview asset is required before activation.");
    public static readonly Error MissingImageModel = new("templates.image_model_required", "Image model is required before activation.");
    public static readonly Error MissingReferenceMotion = new("templates.reference_motion_required", "Reference motion video is required before activation.");
    public static readonly Error MissingReferenceDuration = new("templates.reference_duration_required", "Reference video duration must be determined before activation.");
    public static readonly Error MissingCharacterOrientation = new("templates.character_orientation_required", "Character orientation must be calculated before activation.");
    public static readonly Error InvalidImageModel = new("templates.invalid_image_model", "Image model is not supported.");
    public static readonly Error InvalidPreprocessingModel = new("templates.invalid_preprocessing_model", "Preprocessing model is not supported.");
    public static readonly Error InvalidKlingModel = new("templates.invalid_kling_model", "Kling model is not supported.");
    public static readonly Error InvalidMediaUpload = new("templates.invalid_media_upload", "Media upload is invalid.");
    public static readonly Error MediaStorageFailed = new("templates.media_storage_failed", "Media upload could not be stored.");
    public static readonly Error MediaMetadataFailed = new("templates.media_metadata_failed", "Media metadata could not be determined.");
    public static readonly Error AiProviderUnavailable = new("templates.ai_provider_unavailable", "AI provider is not configured.");
    public static readonly Error AiProviderFailed = new("templates.ai_provider_failed", "AI provider request failed.");
    public static readonly Error AiProviderTimedOut = new("templates.ai_provider_timed_out", "AI provider request timed out.");
    public static readonly Error GenerationAttemptsExceeded = new("templates.generation_attempts_exceeded", "Template generation exceeded the maximum number of attempts.");
    public static readonly Error GeneratedMediaImportFailed = new("templates.generated_media_import_failed", "Generated media could not be imported into storage.");
    public static readonly Error GeneratedMediaTooLarge = new("templates.generated_media_too_large", "Generated media exceeds the maximum allowed size.");
}
