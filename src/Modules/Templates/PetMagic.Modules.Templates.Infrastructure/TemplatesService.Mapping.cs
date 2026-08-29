using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private static bool IsVideoAssetUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        var normalized = url.Trim().ToLowerInvariant();
        return normalized.EndsWith(".mp4", StringComparison.Ordinal)
            || normalized.EndsWith(".webm", StringComparison.Ordinal)
            || normalized.EndsWith(".mov", StringComparison.Ordinal)
            || normalized.EndsWith(".m4v", StringComparison.Ordinal);
    }

    private static string? ResolvePublicThumbnailUrl(string? previewUrl, string? previewContentType)
    {
        if (string.IsNullOrWhiteSpace(previewUrl))
        {
            return null;
        }

        var contentType = previewContentType?.Trim().ToLowerInvariant() ?? string.Empty;
        return contentType.StartsWith("video/", StringComparison.Ordinal) || IsVideoAssetUrl(previewUrl)
            ? null
            : previewUrl;
    }

    private static PublicTemplateCatalogMetadataResponse MapPublicCatalogMetadataItem(TemplateItem template, string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(
            template.Title,
            template.ShortDescription,
            template.LocalizedTextsJson,
            locale,
            musicDescription: template.MusicDescription);
        var previewAsset = GetAsset(template, TemplateAssetKind.Preview);
        return MapPublicCatalogMetadataItem(
            template.Id,
            localizedTexts.Title,
            template.Category,
            template.TemplateType,
            previewAsset?.Url,
            previewAsset?.ContentType,
            template.TokenCost,
            template.IsPremium,
            template.Tags,
            template.Version,
            template.UpdatedAtUtc);
    }

    private static PublicTemplateCatalogMetadataResponse MapPublicCatalogMetadataItem(
        Guid templateId,
        string title,
        string category,
        TemplateType templateType,
        string? previewUrl,
        string? previewContentType,
        int tokenCost,
        bool isPremium,
        string tags,
        long version,
        DateTime updatedAtUtc)
    {
        var contentType = previewContentType?.Trim().ToLowerInvariant() ?? string.Empty;
        var isPreviewVideo = contentType.StartsWith("video/", StringComparison.Ordinal) || IsVideoAssetUrl(previewUrl);

        return new PublicTemplateCatalogMetadataResponse(
            templateId,
            title,
            category,
            templateType.ToString(),
            isPreviewVideo ? null : previewUrl,
            previewUrl,
            tokenCost,
            isPremium,
            DeserializeTags(tags),
            version,
            updatedAtUtc);
    }

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(
                asset.Url,
                asset.FileName ?? string.Empty,
                asset.ContentType ?? string.Empty,
                asset.FileSizeBytes,
                asset.DurationSeconds);
    }

    private static AdminTemplateListItemResponse MapAdminListItem(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        // Calculate estimated USD cost based on template models.
        decimal? estimatedCostUsd = null;
        if (template.TemplateType == TemplateType.Image)
        {
            estimatedCostUsd = FalModelPricing.TryGetImageGenerationCostUsd(template.ImageModel);
        }
        else if (template.TemplateType == TemplateType.Video)
        {
            estimatedCostUsd = FalModelPricing.TryCalculateEstimatedGenerationCostUsd(
                template.PreprocessingModel,
                template.KlingModel,
                template.ReferenceVideoDurationSeconds);
        }

        return new AdminTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title ?? string.Empty,
            template.ShortDescription ?? string.Empty,
            template.Category ?? string.Empty,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            estimatedCostUsd,
            DeserializeRequirements(template.PetPhotoRequirements),
            template.SupportsGenerationResultInput,
            template.RequiredInputMediaType?.ToString(),
            template.RecommendedAfterImageGeneration,
            template.SupportsGenerateSimilar,
            template.DefaultVariationStrength ?? "medium",
            template.IsQaOnly);
    }

    private static AdminTemplateResponse MapAdminResponse(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title ?? string.Empty,
            template.ShortDescription ?? string.Empty,
            template.Category ?? string.Empty,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            GetAsset(template, TemplateAssetKind.Thumbnail),
            GetAsset(template, TemplateAssetKind.AnimatedPreview),
            GetAsset(template, TemplateAssetKind.FeedLoopLow),
            GetAsset(template, TemplateAssetKind.FeedLoopMedium),
            GetAsset(template, TemplateAssetKind.DetailPreview),
            template.MusicDescription,
            GetAsset(template, TemplateAssetKind.ReferenceMotion),
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.ImageModel,
            template.ImagePrompt,
            template.PreprocessingModel,
            template.PreprocessingPrompt,
            template.KlingModel,
            template.KlingPrompt,
            template.KeepOriginalSound,
            template.TemplateType == TemplateType.Image
                ? FalModelPricing.TryGetImageGenerationCostUsd(template.ImageModel)
                : FalModelPricing.TryCalculateEstimatedGenerationCostUsd(
                    template.PreprocessingModel,
                    template.KlingModel,
                    template.ReferenceVideoDurationSeconds),
            template.CreatedAtUtc,
            template.PublishedAtUtc,
            template.UpdatedAtUtc,
            DeserializeRequirements(template.PetPhotoRequirements),
            template.SupportsGenerationResultInput,
            template.RequiredInputMediaType?.ToString(),
            template.RecommendedAfterImageGeneration,
            template.SupportsGenerateSimilar,
            template.DefaultVariationStrength ?? "medium",
            template.IsQaOnly);
    }

    private static PublicTemplateListItemResponse MapPublicListItem(TemplateItem template, string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(
            template.Title,
            template.ShortDescription,
            template.LocalizedTextsJson,
            locale,
            musicDescription: template.MusicDescription);
        var previewAsset = GetAsset(template, TemplateAssetKind.Preview);

        return new PublicTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            localizedTexts.Title,
            localizedTexts.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            previewAsset,
            localizedTexts.MusicDescription ?? template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            localizedTexts.PetPhotoRequirements ?? DeserializeRequirements(template.PetPhotoRequirements),
            template.SupportsGenerationResultInput,
            template.RequiredInputMediaType?.ToString(),
            template.RecommendedAfterImageGeneration,
            template.SupportsGenerateSimilar,
            template.DefaultVariationStrength,
            ResolvePublicThumbnailUrl(
                previewAsset?.Url,
                previewAsset?.ContentType));
    }

    private static PublicTemplateListItemResponse MapPublicListItem(
        Guid templateId,
        TemplateType templateType,
        string title,
        string shortDescription,
        string? localizedTextsJson,
        string category,
        string tags,
        bool isPremium,
        int tokenCost,
        TemplatePromoBadgeMode promoBadgeMode,
        TemplateStatus status,
        string? musicDescription,
        double? referenceVideoDurationSeconds,
        string? petPhotoRequirements,
        bool supportsGenerationResultInput,
        TemplateType? requiredInputMediaType,
        bool recommendedAfterImageGeneration,
        bool supportsGenerateSimilar,
        string? defaultVariationStrength,
        long version,
        DateTime createdAtUtc,
        DateTime updatedAtUtc,
        string? previewUrl,
        string? previewFileName,
        string? previewContentType,
        long? previewFileSizeBytes,
        double? previewDurationSeconds,
        string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(
            title,
            shortDescription,
            localizedTextsJson,
            locale,
            musicDescription: musicDescription);
        var previewAsset = string.IsNullOrWhiteSpace(previewUrl)
            ? null
            : new TemplateAssetResponse(
                previewUrl,
                previewFileName ?? string.Empty,
                previewContentType ?? string.Empty,
                previewFileSizeBytes,
                previewDurationSeconds);

        return new PublicTemplateListItemResponse(
            templateId,
            templateType.ToString(),
            localizedTexts.Title,
            localizedTexts.ShortDescription,
            category,
            ResolveEffectivePromoBadge(
                promoBadgeMode,
                createdAtUtc,
                updatedAtUtc,
                status,
                isPremium,
                tokenCost,
                [
                    title,
                    shortDescription,
                    category,
                    tags,
                    musicDescription
                ],
                DateTime.UtcNow),
            DeserializeTags(tags),
            isPremium,
            tokenCost,
            previewAsset,
            localizedTexts.MusicDescription ?? musicDescription,
            referenceVideoDurationSeconds,
            localizedTexts.PetPhotoRequirements ?? DeserializeRequirements(petPhotoRequirements),
            supportsGenerationResultInput,
            requiredInputMediaType?.ToString(),
            recommendedAfterImageGeneration,
            supportsGenerateSimilar,
            NormalizePublicVariationStrength(defaultVariationStrength),
            ThumbnailUrl: ResolvePublicThumbnailUrl(previewUrl, previewContentType));
    }

    private static FeedTemplateCardDto MapPublicFeedItem(
        Guid templateId,
        TemplateType templateType,
        string title,
        string shortDescription,
        string? localizedTextsJson,
        string category,
        string tags,
        bool isPremium,
        int tokenCost,
        long version,
        string? thumbnailUrl,
        string? thumbnailContentType,
        long? thumbnailFileSizeBytes,
        double? thumbnailDurationSeconds,
        string? animatedPreviewUrl,
        string? animatedPreviewContentType,
        long? animatedPreviewFileSizeBytes,
        double? animatedPreviewDurationSeconds,
        string? feedLoopLowUrl,
        string? feedLoopLowContentType,
        long? feedLoopLowFileSizeBytes,
        double? feedLoopLowDurationSeconds,
        string? feedLoopMediumUrl,
        string? feedLoopMediumContentType,
        long? feedLoopMediumFileSizeBytes,
        double? feedLoopMediumDurationSeconds,
        string? previewUrl,
        string? previewContentType,
        long? previewFileSizeBytes,
        double? previewDurationSeconds,
        string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(title, shortDescription, localizedTextsJson, locale);
        var resolvedThumbnailUrl = thumbnailUrl ?? ResolvePublicThumbnailUrl(previewUrl, previewContentType);
        var resolvedFeedLoopLowUrl = feedLoopLowUrl;
        if (string.IsNullOrWhiteSpace(resolvedFeedLoopLowUrl) && ResolveTemplateMediaKind(previewContentType) == "video")
        {
            resolvedFeedLoopLowUrl = previewUrl;
        }

        var primaryContentType = feedLoopLowContentType
            ?? animatedPreviewContentType
            ?? feedLoopMediumContentType
            ?? thumbnailContentType
            ?? previewContentType;
        var primaryDurationSeconds = feedLoopLowDurationSeconds
            ?? animatedPreviewDurationSeconds
            ?? feedLoopMediumDurationSeconds
            ?? thumbnailDurationSeconds
            ?? previewDurationSeconds;
        var primarySizeBytes = feedLoopLowFileSizeBytes
            ?? animatedPreviewFileSizeBytes
            ?? feedLoopMediumFileSizeBytes
            ?? thumbnailFileSizeBytes
            ?? previewFileSizeBytes;
        var mediaKind = ResolveTemplateMediaKind(primaryContentType);

        return new FeedTemplateCardDto(
            templateId,
            localizedTexts.Title,
            localizedTexts.ShortDescription,
            templateType.ToString(),
            new TemplateCategorySummaryDto(null, ResolveCategorySlug(category), category),
            DeserializeTags(tags),
            isPremium,
            isPremium ? "premium" : "free",
            tokenCost,
            resolvedThumbnailUrl,
            new FeedTemplateMediaDto(
                resolvedThumbnailUrl,
                animatedPreviewUrl,
                resolvedFeedLoopLowUrl,
                feedLoopMediumUrl,
                mediaKind,
                DurationMs: ToDurationMs(primaryDurationSeconds),
                SizeBytes: primarySizeBytes,
                MediaVersion: version),
            mediaKind,
            null,
            ToDurationMs(primaryDurationSeconds),
            primarySizeBytes,
            version,
            version);
    }

    private static TemplateDetailDto MapTemplateDetail(TemplateItem template, string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(
            template.Title,
            template.ShortDescription,
            template.LocalizedTextsJson,
            locale,
            musicDescription: template.MusicDescription);
        var previewAsset = GetAsset(template, TemplateAssetKind.Preview);
        var thumbnailAsset = GetAsset(template, TemplateAssetKind.Thumbnail);
        var detailPreviewAsset = GetAsset(template, TemplateAssetKind.DetailPreview) ?? previewAsset;
        var mediaKind = ResolveTemplateMediaKind(detailPreviewAsset?.ContentType ?? thumbnailAsset?.ContentType ?? previewAsset?.ContentType);

        return new TemplateDetailDto(
            template.Id,
            template.TemplateType.ToString(),
            localizedTexts.Title,
            localizedTexts.ShortDescription,
            new TemplateCategorySummaryDto(null, ResolveCategorySlug(template.Category), template.Category),
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            new TemplateDetailMediaDto(
                thumbnailAsset?.Url ?? ResolvePublicThumbnailUrl(previewAsset?.Url, previewAsset?.ContentType),
                detailPreviewAsset?.Url,
                mediaKind,
                DurationMs: ToDurationMs(detailPreviewAsset?.DurationSeconds ?? previewAsset?.DurationSeconds),
                SizeBytes: detailPreviewAsset?.FileSizeBytes ?? previewAsset?.FileSizeBytes,
                MediaVersion: template.Version),
            localizedTexts.MusicDescription ?? template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            localizedTexts.PetPhotoRequirements ?? DeserializeRequirements(template.PetPhotoRequirements),
            template.SupportsGenerationResultInput,
            template.RequiredInputMediaType?.ToString(),
            template.RecommendedAfterImageGeneration,
            template.SupportsGenerateSimilar,
            template.DefaultVariationStrength,
            thumbnailAsset?.Url ?? ResolvePublicThumbnailUrl(previewAsset?.Url, previewAsset?.ContentType),
            template.Version,
            template.UpdatedAtUtc);
    }

    private static TemplateDetailDto MapTemplateDetail(
        Guid templateId,
        TemplateType templateType,
        string title,
        string shortDescription,
        string? localizedTextsJson,
        string? petPhotoRequirements,
        string category,
        string tags,
        bool isPremium,
        int tokenCost,
        TemplatePromoBadgeMode promoBadgeMode,
        TemplateStatus status,
        string? musicDescription,
        double? referenceVideoDurationSeconds,
        bool supportsGenerationResultInput,
        TemplateType? requiredInputMediaType,
        bool recommendedAfterImageGeneration,
        bool supportsGenerateSimilar,
        string? defaultVariationStrength,
        long version,
        DateTime createdAtUtc,
        DateTime updatedAtUtc,
        string? previewUrl,
        string? previewFileName,
        string? previewContentType,
        long? previewFileSizeBytes,
        double? previewDurationSeconds,
        string? thumbnailUrl,
        string? thumbnailContentType,
        string? detailPreviewUrl,
        string? detailPreviewContentType,
        long? detailPreviewFileSizeBytes,
        double? detailPreviewDurationSeconds,
        string? locale)
    {
        var localizedTexts = TemplateLocalizationTranslator.Resolve(
            title,
            shortDescription,
            localizedTextsJson,
            locale,
            musicDescription: musicDescription);
        var previewAsset = string.IsNullOrWhiteSpace(previewUrl)
            ? null
            : new TemplateAssetResponse(
                previewUrl,
                previewFileName ?? string.Empty,
                previewContentType ?? string.Empty,
                previewFileSizeBytes,
                previewDurationSeconds);
        var resolvedDetailPreviewUrl = string.IsNullOrWhiteSpace(detailPreviewUrl) ? previewUrl : detailPreviewUrl;
        var resolvedDetailContentType = string.IsNullOrWhiteSpace(detailPreviewContentType) ? previewContentType : detailPreviewContentType;
        var mediaKind = ResolveTemplateMediaKind(resolvedDetailContentType ?? thumbnailContentType ?? previewContentType);

        return new TemplateDetailDto(
            templateId,
            templateType.ToString(),
            localizedTexts.Title,
            localizedTexts.ShortDescription,
            new TemplateCategorySummaryDto(null, ResolveCategorySlug(category), category),
            ResolveEffectivePromoBadge(
                promoBadgeMode,
                createdAtUtc,
                updatedAtUtc,
                status,
                isPremium,
                tokenCost,
                [
                    title,
                    shortDescription,
                    category,
                    tags,
                    musicDescription
                ],
                DateTime.UtcNow),
            DeserializeTags(tags),
            isPremium,
            tokenCost,
            new TemplateDetailMediaDto(
                thumbnailUrl ?? ResolvePublicThumbnailUrl(previewAsset?.Url, previewAsset?.ContentType),
                resolvedDetailPreviewUrl,
                mediaKind,
                DurationMs: ToDurationMs(detailPreviewDurationSeconds ?? previewDurationSeconds),
                SizeBytes: detailPreviewFileSizeBytes ?? previewFileSizeBytes,
                MediaVersion: version),
            localizedTexts.MusicDescription ?? musicDescription,
            referenceVideoDurationSeconds,
            localizedTexts.PetPhotoRequirements ?? DeserializeRequirements(petPhotoRequirements),
            supportsGenerationResultInput,
            requiredInputMediaType?.ToString(),
            recommendedAfterImageGeneration,
            supportsGenerateSimilar,
            NormalizePublicVariationStrength(defaultVariationStrength),
            thumbnailUrl ?? ResolvePublicThumbnailUrl(previewAsset?.Url, previewAsset?.ContentType),
            version,
            updatedAtUtc);
    }

    private static string NormalizePublicVariationStrength(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? "medium" : value;
    }

    private static int? ToDurationMs(double? durationSeconds)
    {
        return durationSeconds is null
            ? null
            : (int)Math.Round(durationSeconds.Value * 1000d, MidpointRounding.AwayFromZero);
    }

    private static string ResolveTemplateMediaKind(string? contentType)
    {
        return contentType?.StartsWith("video/", StringComparison.OrdinalIgnoreCase) == true
            ? "video"
            : "image";
    }

    private static string ResolveCategorySlug(string? category)
    {
        var normalized = (category ?? string.Empty).Trim().ToLowerInvariant();
        if (normalized.Length == 0)
        {
            return string.Empty;
        }

        return string.Join(
            "-",
            normalized
                .Split([' ', '_', '/', '\\'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(part => part.Length > 0));
    }

    private static TemplatePromoBadgeMode ParsePromoBadgeMode(string raw)
    {
        return Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out var mode)
            ? mode
            : TemplatePromoBadgeMode.Auto;
    }

    private static string? ResolveEffectivePromoBadge(TemplateItem template, DateTime utcNow)
    {
        return ResolveEffectivePromoBadge(
            template.PromoBadgeMode,
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            template.Status,
            template.IsPremium,
            template.TokenCost,
            [
                template.Title,
                template.ShortDescription,
                template.Category,
                template.Tags,
                template.MusicDescription,
                template.ImagePrompt,
                template.KlingPrompt
            ],
            utcNow);
    }

    private static string? ResolveEffectivePromoBadge(
        TemplatePromoBadgeMode promoBadgeMode,
        DateTime createdAtUtc,
        DateTime updatedAtUtc,
        TemplateStatus status,
        bool isPremium,
        int tokenCost,
        IReadOnlyList<string?> signals,
        DateTime utcNow)
    {
        if (promoBadgeMode != TemplatePromoBadgeMode.Auto)
        {
            return promoBadgeMode.ToString();
        }

        return TemplatePromoBadgeRules.ResolveAutoBadge(
            createdAtUtc,
            updatedAtUtc,
            status,
            isPremium,
            tokenCost,
            signals,
            utcNow);
    }
}
