namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record MediaUploadCommand(
    string FileName,
    string ContentType,
    byte[] Content);

public sealed record TemplateAssetCommand(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds);

public sealed record CreateImageTemplateCommand(
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    TemplateAssetCommand? PreviewAsset,
    string? Status = null);

public sealed record UpdateImageTemplateCommand(
    Guid TemplateId,
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    TemplateAssetCommand? PreviewAsset,
    string? Status = null);

public sealed record CreateVideoTemplateCommand(
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    string MusicDescription,
    TemplateAssetCommand? PreviewAsset,
    TemplateAssetCommand? ReferenceMotionAsset,
    string PreprocessingModel,
    string PreprocessingPrompt,
    string KlingModel,
    string KlingPrompt,
    bool KeepOriginalSound,
    string? Status = null);

public sealed record UpdateVideoTemplateCommand(
    Guid TemplateId,
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    string MusicDescription,
    TemplateAssetCommand? PreviewAsset,
    TemplateAssetCommand? ReferenceMotionAsset,
    string PreprocessingModel,
    string PreprocessingPrompt,
    string KlingModel,
    string KlingPrompt,
    bool KeepOriginalSound,
    string? Status = null);

public sealed record ChangeTemplateStatusCommand(Guid TemplateId, string Status);

public sealed record StartTemplateGenerationCommand(
    Guid UserId,
    Guid TemplateId,
    TemplateAssetCommand SourceImageAsset);

public sealed record StoredMediaResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    string? LocalPath);

public sealed record TemplateAssetResponse(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds);

public sealed record AdminTemplateListItemResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string Status,
    string PromoBadgeMode,
    string? EffectivePromoBadge,
    bool IsPremium,
    int TokenCost,
    string[] Tags,
    TemplateAssetResponse? PreviewAsset,
    double? ReferenceVideoDurationSeconds,
    string? CharacterOrientation,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record AdminTemplateResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string Status,
    string PromoBadgeMode,
    string? EffectivePromoBadge,
    bool IsPremium,
    int TokenCost,
    string[] Tags,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    TemplateAssetResponse? ReferenceMotionAsset,
    double? ReferenceVideoDurationSeconds,
    string? CharacterOrientation,
    string? PreprocessingModel,
    string? PreprocessingPrompt,
    string? KlingModel,
    string? KlingPrompt,
    bool? KeepOriginalSound,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record PublicTemplateListItemResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string? EffectivePromoBadge,
    string[] Tags,
    bool IsPremium,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset,
    double? ReferenceVideoDurationSeconds);

public sealed record PublicTemplateResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string? EffectivePromoBadge,
    string[] Tags,
    bool IsPremium,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds);

public sealed record TemplateGenerationResponse(
    Guid GenerationId,
    Guid UserId,
    Guid TemplateId,
    string Status,
    int TokenCost,
    TemplateAssetResponse SourceImageAsset,
    string? NormalizedImageUrl,
    string? ReferenceMotionUrl,
    string? OutputUrl,
    string? FailureCode,
    string? FailureMessage,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc);
