using System.IO;
using System.Text.Json.Serialization;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

/// <summary>Template category metadata for public card/detail contracts.</summary>
public sealed record TemplateCategorySummaryDto(
    Guid? Id,
    string Slug,
    string Title);

/// <summary>Media variants intended for many cards rendered in feed-like surfaces.</summary>
/// <param name="ThumbnailUrl">Static image for immediate card rendering.</param>
/// <param name="AnimatedPreviewUrl">Cheap animated image or short loop for lightweight card motion.</param>
/// <param name="FeedLoopLowUrl">Low-bitrate muted video loop for feed playback.</param>
/// <param name="FeedLoopMediumUrl">Medium-bitrate muted video loop for future adaptive feed playback.</param>
/// <param name="MediaKind">Primary media kind for card rendering, for example image or video.</param>
/// <param name="AspectRatio">Known media aspect ratio when available.</param>
/// <param name="DurationMs">Known preview duration in milliseconds when available.</param>
/// <param name="SizeBytes">Known preview size in bytes when available.</param>
/// <param name="DominantColor">Optional placeholder color for fast card paint.</param>
/// <param name="BlurHash">Optional compact placeholder hash for fast card paint.</param>
/// <param name="MediaVersion">Version used for client and CDN cache invalidation.</param>
public sealed record FeedTemplateMediaDto(
    string? ThumbnailUrl,
    string? AnimatedPreviewUrl,
    string? FeedLoopLowUrl,
    string? FeedLoopMediumUrl,
    string MediaKind,
    double? AspectRatio = null,
    int? DurationMs = null,
    long? SizeBytes = null,
    string? DominantColor = null,
    string? BlurHash = null,
    long MediaVersion = 0);

/// <summary>Media variants intended for the template preview/detail screen.</summary>
/// <param name="ThumbnailUrl">Static image for immediate preview rendering.</param>
/// <param name="DetailPreviewUrl">High-quality preview used only after opening template detail.</param>
/// <param name="MediaKind">Primary detail media kind, for example image or video.</param>
/// <param name="AspectRatio">Known detail preview aspect ratio when available.</param>
/// <param name="DurationMs">Known detail preview duration in milliseconds when available.</param>
/// <param name="SizeBytes">Known detail preview size in bytes when available.</param>
/// <param name="DominantColor">Optional placeholder color for fast detail paint.</param>
/// <param name="BlurHash">Optional compact placeholder hash for fast detail paint.</param>
/// <param name="MediaVersion">Version used for client and CDN cache invalidation.</param>
public sealed record TemplateDetailMediaDto(
    string? ThumbnailUrl,
    string? DetailPreviewUrl,
    string MediaKind,
    double? AspectRatio = null,
    int? DurationMs = null,
    long? SizeBytes = null,
    string? DominantColor = null,
    string? BlurHash = null,
    long MediaVersion = 0);

public sealed record FeedTemplateCardDto(
    Guid Id,
    string Title,
    string ShortDescription,
    string Type,
    TemplateCategorySummaryDto Category,
    string[] Tags,
    bool IsPremium,
    string Access,
    int TokenCost,
    string? ThumbnailUrl,
    FeedTemplateMediaDto Media,
    string MediaKind,
    double? AspectRatio,
    int? DurationMs,
    long? SizeBytes,
    long Version,
    long MediaVersion)
{
    [JsonIgnore]
    public Guid TemplateId => Id;

    [JsonIgnore]
    public string TemplateType => Type;

    [JsonIgnore]
    public TemplateAssetResponse? PreviewAsset => string.IsNullOrWhiteSpace(Media.FeedLoopLowUrl)
        ? null
        : new TemplateAssetResponse(
            Media.FeedLoopLowUrl,
            string.Empty,
            MediaKind == "video" ? "video/mp4" : "image/jpeg",
            SizeBytes,
            DurationMs.HasValue ? DurationMs.Value / 1000d : null);

    [JsonIgnore]
    public IReadOnlyList<string>? PetPhotoRequirements => null;

    [JsonIgnore]
    public bool SupportsGenerationResultInput => false;

    [JsonIgnore]
    public string? RequiredInputMediaType => null;

    [JsonIgnore]
    public bool RecommendedAfterImageGeneration => false;

    [JsonIgnore]
    public bool SupportsGenerateSimilar => true;

    [JsonIgnore]
    public string DefaultVariationStrength => "medium";

    [JsonIgnore]
    public double? ReferenceVideoDurationSeconds => null;

    [JsonIgnore]
    public DateTime? UpdatedAtUtc => null;
}

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
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    string? ThumbnailUrl = null,
    long Version = 0,
    DateTime? UpdatedAtUtc = null);

public sealed record PublicTemplateCategoryResponse(
    string Name);

public sealed record PublicTemplatesCatalogQuery(
    int? Page,
    int? PageSize,
    TemplateType? Type,
    string? Category,
    string? Locale,
    string[]? Tags = null,
    bool? PremiumOnly = null,
    bool IncludeQaOnly = false);

public sealed record PublicTemplateCatalogMetadataResponse(
    Guid Id,
    string Title,
    string Category,
    string Type,
    string? ThumbnailUrl,
    string? PreviewUrl,
    int PriceTokens,
    bool IsPremium,
    string[] Tags,
    long Version,
    DateTime UpdatedAtUtc);

public sealed record PublicTemplatesCatalogPageResponse(
    IReadOnlyList<PublicTemplateCatalogMetadataResponse> Items,
    int Page,
    int PageSize,
    bool HasMore,
    long TotalCount,
    DateTime GeneratedAtUtc);

public sealed record PublicTemplatesCatalogVersionResponse(
    long Version,
    DateTime? UpdatedAtUtc);

public sealed record PublicTemplatesCatalogChangesResponse(
    long FromVersion,
    long ToVersion,
    IReadOnlyList<PublicTemplateCatalogMetadataResponse> Upserts,
    IReadOnlyList<Guid> DeletedIds,
    bool NeedsFullResync);

public sealed record PublicTemplatesFeedQuery(
    TemplateType? Type,
    string? Category,
    string[] Tags,
    bool? PremiumOnly,
    string? Search,
    int? Take,
    string? Cursor,
    string? Locale,
    bool IncludeQaOnly = false);

public sealed record PublicTemplatesFeedResponse(
    IReadOnlyList<FeedTemplateCardDto> Items,
    string? NextCursor,
    bool HasMore,
    DateTime GeneratedAtUtc);

public static class PublicTemplatesDiscoveryLimits
{
    public const int DefaultItemsPerSection = 6;
    public const int MaxItemsPerSection = 12;
    public const int DefaultSectionLimit = 12;
    public const int MaxSectionLimit = 24;
}

public sealed record PublicTemplatesDiscoveryQuery(
    int ItemsPerSection,
    int SectionLimit,
    string? Locale,
    bool IncludeQaOnly = false);

public sealed record PublicTemplatesDiscoverySectionResponse(
    string Category,
    IReadOnlyList<FeedTemplateCardDto> Items);

public sealed record PublicTemplatesDiscoveryResponse(
    IReadOnlyList<PublicTemplatesDiscoverySectionResponse> Sections,
    DateTime GeneratedAtUtc);

public sealed record PublicRandomTemplateQuery(
    TemplateType? Type,
    string? Category,
    bool IncludePremium,
    string? Locale,
    string? Access = null,
    Guid? ExcludeTemplateId = null,
    bool IncludeQaOnly = false);

public sealed record PublicRandomTemplateResponse(
    PublicTemplateListItemResponse? Template);

public sealed record TemplateDetailDto(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    TemplateCategorySummaryDto Category,
    string? EffectivePromoBadge,
    string[] Tags,
    bool IsPremium,
    int TokenCost,
    TemplateDetailMediaDto Media,
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    string? ThumbnailUrl = null,
    long Version = 0,
    DateTime? UpdatedAtUtc = null)
{
    [JsonIgnore]
    public TemplateAssetResponse? PreviewAsset => string.IsNullOrWhiteSpace(Media.DetailPreviewUrl)
        ? null
        : new TemplateAssetResponse(
            Media.DetailPreviewUrl,
            string.Empty,
            string.Empty,
            Media.SizeBytes,
            Media.DurationMs.HasValue ? Media.DurationMs.Value / 1000d : null);
}

public sealed record CompatibleGenerationTemplateResponse(
    Guid Id,
    string Title,
    string Type,
    string? ThumbnailUrl,
    bool IsPremium,
    bool IsRecommended,
    int TokenCost,
    long Version = 0);

public sealed record CompatibleGenerationTemplatesResponse(
    Guid ResultId,
    string InputMediaType,
    IReadOnlyList<CompatibleGenerationTemplateResponse> Templates);

public sealed record PublicTemplateOfTheDayResponse(
    PublicTemplateOfTheDayItemResponse? Template);

public sealed record PublicTemplateOfTheDayItemResponse(
    Guid TemplateId,
    string Title,
    string Subtitle,
    string BadgeText,
    string Type,
    string? ThumbnailUrl,
    string? PreviewMediaUrl,
    bool IsPremium,
    string RequiredPlan,
    DateOnly Date,
    string Source,
    string Category,
    IReadOnlyList<string> Tags,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset);
