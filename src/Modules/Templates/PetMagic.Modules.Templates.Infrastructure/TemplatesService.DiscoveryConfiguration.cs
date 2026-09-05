using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    internal static FeedTemplateCardDto MapDiscoveryFeedItem(TemplateItem template, string? locale)
    {
        var thumbnail = GetAsset(template, TemplateAssetKind.Thumbnail);
        var animated = GetAsset(template, TemplateAssetKind.AnimatedPreview);
        var low = GetAsset(template, TemplateAssetKind.FeedLoopLow);
        var medium = GetAsset(template, TemplateAssetKind.FeedLoopMedium);
        var preview = GetAsset(template, TemplateAssetKind.Preview);
        return MapPublicFeedItem(template.Id, template.TemplateType, template.Title, template.ShortDescription,
            template.LocalizedTextsJson, template.Category, template.Tags, template.IsPremium, template.TokenCost,
            template.Version, thumbnail?.Url, thumbnail?.ContentType, thumbnail?.FileSizeBytes, thumbnail?.DurationSeconds,
            animated?.Url, animated?.ContentType, animated?.FileSizeBytes, animated?.DurationSeconds,
            low?.Url, low?.ContentType, low?.FileSizeBytes, low?.DurationSeconds,
            medium?.Url, medium?.ContentType, medium?.FileSizeBytes, medium?.DurationSeconds,
            preview?.Url, preview?.ContentType, preview?.FileSizeBytes, preview?.DurationSeconds, locale);
    }
}
