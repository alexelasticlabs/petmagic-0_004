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

    private static PublicTemplateCatalogMetadataResponse MapPublicCatalogMetadataItem(TemplateItem template)
    {
        var previewAsset = GetAsset(template, TemplateAssetKind.Preview);
        var previewUrl = previewAsset?.Url;
        var contentType = previewAsset?.ContentType?.Trim().ToLowerInvariant() ?? string.Empty;
        var isPreviewVideo = contentType.StartsWith("video/", StringComparison.Ordinal) || IsVideoAssetUrl(previewUrl);

        return new PublicTemplateCatalogMetadataResponse(
            template.Id,
            template.Title,
            template.Category,
            template.TemplateType.ToString(),
            isPreviewVideo ? null : previewUrl,
            previewUrl,
            template.TokenCost,
            DeserializeTags(template.Tags),
            template.Version,
            template.UpdatedAtUtc);
    }

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(asset.Url, asset.FileName, asset.ContentType, asset.FileSizeBytes, asset.DurationSeconds);
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
            template.Title,
            template.ShortDescription,
            template.Category,
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
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static AdminTemplateResponse MapAdminResponse(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
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
            template.UpdatedAtUtc,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static PublicTemplateListItemResponse MapPublicListItem(TemplateItem template)
    {
        return new PublicTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static PublicTemplateResponse MapPublicResponse(TemplateItem template)
    {
        return new PublicTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static TemplatePromoBadgeMode ParsePromoBadgeMode(string raw)
    {
        return Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out var mode)
            ? mode
            : TemplatePromoBadgeMode.Auto;
    }

    private static string? ResolveEffectivePromoBadge(TemplateItem template, DateTime utcNow)
    {
        if (template.PromoBadgeMode != TemplatePromoBadgeMode.Auto)
        {
            return template.PromoBadgeMode.ToString();
        }

        return TemplatePromoBadgeRules.ResolveAutoBadge(
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
}
