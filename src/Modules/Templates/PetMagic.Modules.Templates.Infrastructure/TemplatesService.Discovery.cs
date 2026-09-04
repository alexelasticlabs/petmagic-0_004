using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<PublicTemplatesDiscoveryResponse>> ListPublicDiscoveryAsync(
        PublicTemplatesDiscoveryQuery query,
        CancellationToken cancellationToken)
    {
        var itemsPerSection = Math.Clamp(
            query.ItemsPerSection,
            1,
            PublicTemplatesDiscoveryLimits.MaxItemsPerSection);
        var sectionLimit = Math.Clamp(
            query.SectionLimit,
            1,
            PublicTemplatesDiscoveryLimits.MaxSectionLimit);
        var visibleTemplates = _visibilityPolicy.ApplyPublic(
            dbContext.TemplateItems.AsNoTracking(),
            new TemplateVisibilityContext(IncludeQaOnly: query.IncludeQaOnly, Locale: query.Locale));

        var categoryRows = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(category => !category.IsArchived)
            .Where(category => category.Name.Trim() != string.Empty)
            .Where(category => visibleTemplates.Any(template => template.Category == category.Name))
            .OrderBy(category => category.NormalizedName)
            .ThenBy(category => category.Name)
            .ThenBy(category => category.Id)
            .Take(sectionLimit)
            .Select(category => new
            {
                DatabaseName = category.Name,
                category.NormalizedName
            })
            .ToArrayAsync(cancellationToken);

        if (categoryRows.Length == 0)
        {
            return Result.Success(new PublicTemplatesDiscoveryResponse([], DateTime.UtcNow));
        }

        IQueryable<Guid>? selectedTemplateIdsQuery = null;
        foreach (var category in categoryRows)
        {
            var databaseCategoryName = category.DatabaseName;
            var categoryTemplateIds = visibleTemplates
                .Where(template => template.Category == databaseCategoryName)
                .OrderByDescending(template => template.PublishedAtUtc ?? template.CreatedAtUtc)
                .ThenByDescending(template => template.Id)
                .Take(itemsPerSection)
                .Select(template => template.Id);

            selectedTemplateIdsQuery = selectedTemplateIdsQuery is null
                ? categoryTemplateIds
                : selectedTemplateIdsQuery.Concat(categoryTemplateIds);
        }

        var selectedTemplateIds = await selectedTemplateIdsQuery!
            .ToArrayAsync(cancellationToken);
        if (selectedTemplateIds.Length == 0)
        {
            return Result.Success(new PublicTemplatesDiscoveryResponse([], DateTime.UtcNow));
        }

        var templateRows = await visibleTemplates
            .Where(template => selectedTemplateIds.Contains(template.Id))
            .Select(template => new
            {
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.Version,
                template.CreatedAtUtc,
                template.PublishedAtUtc,
                Thumbnail = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Thumbnail)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault(),
                AnimatedPreview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.AnimatedPreview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault(),
                FeedLoopLow = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.FeedLoopLow)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault(),
                FeedLoopMedium = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.FeedLoopMedium)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault(),
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault()
            })
            .ToArrayAsync(cancellationToken);

        var sections = categoryRows
            .Select(category =>
            {
                var items = templateRows
                    .Where(template => template.Category == category.DatabaseName)
                    .OrderByDescending(template => template.PublishedAtUtc ?? template.CreatedAtUtc)
                    .ThenByDescending(template => template.Id)
                    .Take(itemsPerSection)
                    .Select(template => MapPublicFeedItem(
                        template.Id,
                        template.TemplateType,
                        template.Title,
                        template.ShortDescription,
                        template.LocalizedTextsJson,
                        template.Category,
                        template.Tags,
                        template.IsPremium,
                        template.TokenCost,
                        template.Version,
                        template.Thumbnail?.Url,
                        template.Thumbnail?.ContentType,
                        template.Thumbnail?.FileSizeBytes,
                        template.Thumbnail?.DurationSeconds,
                        template.AnimatedPreview?.Url,
                        template.AnimatedPreview?.ContentType,
                        template.AnimatedPreview?.FileSizeBytes,
                        template.AnimatedPreview?.DurationSeconds,
                        template.FeedLoopLow?.Url,
                        template.FeedLoopLow?.ContentType,
                        template.FeedLoopLow?.FileSizeBytes,
                        template.FeedLoopLow?.DurationSeconds,
                        template.FeedLoopMedium?.Url,
                        template.FeedLoopMedium?.ContentType,
                        template.FeedLoopMedium?.FileSizeBytes,
                        template.FeedLoopMedium?.DurationSeconds,
                        template.Preview?.Url,
                        template.Preview?.ContentType,
                        template.Preview?.FileSizeBytes,
                        template.Preview?.DurationSeconds,
                        query.Locale))
                    .ToArray();

                return new PublicTemplatesDiscoverySectionResponse(
                    NormalizePublicCategoryName(category.DatabaseName),
                    items);
            })
            .Where(section => section.Items.Count > 0)
            .ToArray();

        return Result.Success(new PublicTemplatesDiscoveryResponse(sections, DateTime.UtcNow));
    }
}
