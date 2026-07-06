using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record MediaUploadCommand(
    string FileName,
    string ContentType,
    byte[]? Content,
    Stream? ContentStream,
    long? ContentLengthBytes,
    string? PreferredStorageKey = null)
{
    public MediaUploadCommand(string fileName, string contentType, byte[] content)
        : this(fileName, contentType, content, null, content.LongLength, null)
    {
    }

    public MediaUploadCommand(string fileName, string contentType, Stream contentStream, long? contentLengthBytes = null)
        : this(fileName, contentType, null, contentStream, contentLengthBytes, null)
    {
    }
}

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
    string ImageModel,
    string ImagePrompt,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false,
    TemplateAssetCommand? ThumbnailAsset = null,
    TemplateAssetCommand? AnimatedPreviewAsset = null,
    TemplateAssetCommand? FeedLoopLowAsset = null,
    TemplateAssetCommand? FeedLoopMediumAsset = null,
    TemplateAssetCommand? DetailPreviewAsset = null);

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
    string ImageModel,
    string ImagePrompt,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false,
    TemplateAssetCommand? ThumbnailAsset = null,
    TemplateAssetCommand? AnimatedPreviewAsset = null,
    TemplateAssetCommand? FeedLoopLowAsset = null,
    TemplateAssetCommand? FeedLoopMediumAsset = null,
    TemplateAssetCommand? DetailPreviewAsset = null,
    bool KeepPreviewAsset = false);

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
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false,
    TemplateAssetCommand? ThumbnailAsset = null,
    TemplateAssetCommand? AnimatedPreviewAsset = null,
    TemplateAssetCommand? FeedLoopLowAsset = null,
    TemplateAssetCommand? FeedLoopMediumAsset = null,
    TemplateAssetCommand? DetailPreviewAsset = null);

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
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false,
    TemplateAssetCommand? ThumbnailAsset = null,
    TemplateAssetCommand? AnimatedPreviewAsset = null,
    TemplateAssetCommand? FeedLoopLowAsset = null,
    TemplateAssetCommand? FeedLoopMediumAsset = null,
    TemplateAssetCommand? DetailPreviewAsset = null,
    bool KeepPreviewAsset = false,
    bool KeepReferenceMotionAsset = false);

public sealed record ChangeTemplateStatusCommand(Guid TemplateId, string Status);

public sealed record CreateTemplateCategoryCommand(
    string Name);

public sealed record UpdateTemplateCategoryCommand(
    Guid CategoryId,
    string Name);

public sealed record ChangeTemplateCategoryArchiveStateCommand(
    Guid CategoryId,
    bool IsArchived);

public sealed record CreateTemplateOfTheDayCommand(
    Guid TemplateId,
    DateOnly StartDate,
    DateOnly? EndDate,
    bool IsActive,
    bool IsManual,
    int Priority,
    string? TitleOverride,
    string? SubtitleOverride,
    string? BadgeTextOverride,
    Guid? CreatedByAdminId);

public sealed record UpdateTemplateOfTheDayCommand(
    Guid Id,
    Guid TemplateId,
    DateOnly StartDate,
    DateOnly? EndDate,
    bool IsActive,
    bool IsManual,
    int Priority,
    string? TitleOverride,
    string? SubtitleOverride,
    string? BadgeTextOverride);

public sealed record AutoPickTemplateOfTheDayCommand(
    DateOnly Date,
    string? AllowedTypes,
    int? ExcludeRecentDays,
    Guid? CreatedByAdminId,
    bool Force = false);

public sealed record UpdateTemplateOfTheDaySettingsCommand(
    bool AutoModeEnabled,
    string? AllowedTypes,
    int? ExcludeRecentDays,
    Guid? UpdatedByAdminId);
