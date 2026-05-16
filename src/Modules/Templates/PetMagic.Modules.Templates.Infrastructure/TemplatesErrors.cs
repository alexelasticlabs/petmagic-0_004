using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplatesErrors
{
    public static readonly Error NotFound = new("templates.not_found", "Template was not found.");
    public static readonly Error TypeMismatch = new("templates.type_mismatch", "Template type does not match the requested operation.");
    public static readonly Error InvalidStatus = new("templates.invalid_status", "Template status is invalid.");
    public static readonly Error MissingPreview = new("templates.preview_required", "Preview asset is required before activation.");
    public static readonly Error MissingReferenceMotion = new("templates.reference_motion_required", "Reference motion video is required before activation.");
    public static readonly Error MissingReferenceDuration = new("templates.reference_duration_required", "Reference video duration must be determined before activation.");
    public static readonly Error MissingCharacterOrientation = new("templates.character_orientation_required", "Character orientation must be calculated before activation.");
    public static readonly Error InvalidPreprocessingModel = new("templates.invalid_preprocessing_model", "Preprocessing model is not supported.");
    public static readonly Error InvalidKlingModel = new("templates.invalid_kling_model", "Kling model is not supported.");
    public static readonly Error InvalidMediaUpload = new("templates.invalid_media_upload", "Media upload is invalid.");
    public static readonly Error MediaStorageFailed = new("templates.media_storage_failed", "Media upload could not be stored.");
    public static readonly Error MediaMetadataFailed = new("templates.media_metadata_failed", "Media metadata could not be determined.");
}
