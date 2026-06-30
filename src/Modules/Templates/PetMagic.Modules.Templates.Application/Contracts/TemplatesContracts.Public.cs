using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

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
    string? ThumbnailUrl = null);

public sealed record PublicTemplateFeedItemResponse(
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
    string? ThumbnailUrl = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
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
    bool? PremiumOnly = null);

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
    string? Locale);

public sealed record PublicTemplatesFeedResponse(
    IReadOnlyList<PublicTemplateFeedItemResponse> Items,
    string? NextCursor,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record PublicRandomTemplateQuery(
    TemplateType? Type,
    string? Category,
    bool IncludePremium,
    string? Locale,
    string? Access = null,
    Guid? ExcludeTemplateId = null);

public sealed record PublicRandomTemplateResponse(
    PublicTemplateListItemResponse? Template);

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
    double? ReferenceVideoDurationSeconds,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    string? ThumbnailUrl = null);

public sealed record CompatibleGenerationTemplateResponse(
    Guid Id,
    string Title,
    string Type,
    string? ThumbnailUrl,
    bool IsPremium,
    bool IsRecommended,
    int TokenCost);

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
