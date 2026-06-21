using System.Security.Cryptography;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<PublicTemplatesCatalogPageResponse>> ListPublicCatalogAsync(PublicTemplatesCatalogQuery query, CancellationToken cancellationToken)
    {
        var page = NormalizePublicCatalogPage(query.Page);
        var pageSize = NormalizePublicCatalogPageSize(query.PageSize);
        var normalizedCategory = NormalizePublicCategoryFilter(query.Category);
        var normalizedTags = NormalizePublicTagFilters(query.Tags);

        var baseQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !query.Type.HasValue || x.TemplateType == query.Type.Value)
            .Where(x => !query.PremiumOnly.HasValue || !query.PremiumOnly.Value || x.IsPremium);

        baseQuery = await ApplyPublicCategoryFilterAsync(baseQuery, normalizedCategory, cancellationToken);

        baseQuery = ApplyTemplateTagFilter(baseQuery, normalizedTags);

        var totalCount = await baseQuery.LongCountAsync(cancellationToken);
        var offset = ((long)page - 1) * pageSize;
        if (offset > int.MaxValue)
        {
            return Result.Success(new PublicTemplatesCatalogPageResponse(
                [],
                page,
                pageSize,
                false,
                totalCount,
                DateTime.UtcNow));
        }

        var filtered = await baseQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Version)
            .ThenByDescending(template => template.Id)
            .Skip((int)offset)
            .Take(pageSize + 1)
            .Select(template => new
            {
                template.Id,
                template.Title,
                template.LocalizedTextsJson,
                LocalizedTitle = TemplateLocalizationTranslator.Resolve(template.Title, string.Empty, template.LocalizedTextsJson, query.Locale).Title,
                template.Category,
                template.TemplateType,
                template.TokenCost,
                template.IsPremium,
                template.Tags,
                template.Version,
                template.UpdatedAtUtc,
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType
                    })
                    .FirstOrDefault()
            })
            .ToArrayAsync(cancellationToken);

        var pageItems = filtered.Take(pageSize).ToArray();
        var hasMore = filtered.Length > pageSize;

        return Result.Success(new PublicTemplatesCatalogPageResponse(
                [.. pageItems.Select(item => MapPublicCatalogMetadataItem(
                item.Id,
                item.LocalizedTitle,
                item.Category,
                item.TemplateType,
                item.Preview?.Url,
                item.Preview?.ContentType,
                item.TokenCost,
                item.IsPremium,
                item.Tags,
                item.Version,
                item.UpdatedAtUtc))],
            page,
            pageSize,
            hasMore,
            totalCount,
            DateTime.UtcNow));
    }

    public async Task<Result<PublicTemplatesCatalogVersionResponse>> GetPublicCatalogVersionAsync(CancellationToken cancellationToken)
    {
        var snapshot = await GetCurrentCatalogVersionSnapshotAsync(cancellationToken);

        return Result.Success(new PublicTemplatesCatalogVersionResponse(snapshot.Version, snapshot.UpdatedAtUtc));
    }

    public async Task<Result<PublicTemplatesCatalogChangesResponse>> GetPublicCatalogChangesAsync(long sinceVersion, string? locale, CancellationToken cancellationToken)
    {
        var normalizedSinceVersion = Math.Max(0L, sinceVersion);
        var toVersion = await GetCurrentCatalogVersionAsync(cancellationToken);

        if (normalizedSinceVersion >= toVersion)
        {
            return Result.Success(new PublicTemplatesCatalogChangesResponse(
                normalizedSinceVersion,
                toVersion,
                [],
                [],
                false));
        }

        var changes = await dbContext.TemplateCatalogChanges
            .AsNoTracking()
            .Where(change => change.Version > normalizedSinceVersion)
            .OrderBy(change => change.Version)
            .Take(PublicCatalogMaxDeltaChanges + 1)
            .ToArrayAsync(cancellationToken);

        if (changes.Length == 0)
        {
            return Result.Success(new PublicTemplatesCatalogChangesResponse(
                normalizedSinceVersion,
                toVersion,
                [],
                [],
                true));
        }

        var firstAvailableVersion = changes[0].Version;
        if (firstAvailableVersion > normalizedSinceVersion + 1)
        {
            return Result.Success(new PublicTemplatesCatalogChangesResponse(
                normalizedSinceVersion,
                toVersion,
                [],
                [],
                true));
        }

        if (changes.Length > PublicCatalogMaxDeltaChanges)
        {
            return Result.Success(new PublicTemplatesCatalogChangesResponse(
                normalizedSinceVersion,
                toVersion,
                [],
                [],
                true));
        }

        var changedTemplateIds = changes.Select(change => change.TemplateId).Distinct().ToArray();
        var changedTemplates = await dbContext.TemplateItems
            .AsNoTracking()
            .Where(template => changedTemplateIds.Contains(template.Id))
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Select(template => new
            {
                template.Id,
                template.Title,
                template.LocalizedTextsJson,
                LocalizedTitle = TemplateLocalizationTranslator.Resolve(template.Title, string.Empty, template.LocalizedTextsJson, locale).Title,
                template.Category,
                template.TemplateType,
                template.TokenCost,
                template.IsPremium,
                template.Tags,
                template.Version,
                template.UpdatedAtUtc,
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.ContentType
                    })
                    .FirstOrDefault()
            })
            .ToDictionaryAsync(template => template.Id, cancellationToken);

        var deletedIds = new HashSet<Guid>();
        var upserts = new Dictionary<Guid, PublicTemplateCatalogMetadataResponse>();

        foreach (var change in changes)
        {
            if (change.ChangeType == TemplateCatalogChangeType.Delete)
            {
                upserts.Remove(change.TemplateId);
                deletedIds.Add(change.TemplateId);
                continue;
            }

            if (!changedTemplates.TryGetValue(change.TemplateId, out var template))
            {
                upserts.Remove(change.TemplateId);
                deletedIds.Add(change.TemplateId);
                continue;
            }

            deletedIds.Remove(change.TemplateId);
            upserts[change.TemplateId] = MapPublicCatalogMetadataItem(
                template.Id,
                template.LocalizedTitle,
                template.Category,
                template.TemplateType,
                template.Preview?.Url,
                template.Preview?.ContentType,
                template.TokenCost,
                template.IsPremium,
                template.Tags,
                template.Version,
                template.UpdatedAtUtc);
        }

        return Result.Success(new PublicTemplatesCatalogChangesResponse(
            normalizedSinceVersion,
            toVersion,
            [.. upserts.Values
                .OrderByDescending(item => item.UpdatedAtUtc)
                .ThenByDescending(item => item.Version)
                .ThenByDescending(item => item.Id)],
            [.. deletedIds],
            false));
    }

    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, string? locale, CancellationToken cancellationToken)
    {
        var normalizedCategory = NormalizePublicCategoryFilter(category);
        var normalizedTags = NormalizePublicTagFilters(tags ?? []);
        var query = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => !premiumOnly.HasValue || !premiumOnly.Value || x.IsPremium);

        query = await ApplyPublicCategoryFilterAsync(query, normalizedCategory, cancellationToken);

        query = ApplyTemplateTagFilter(query, normalizedTags);

        var items = await query
            .OrderBy(x => x.IsPremium)
            .ThenBy(x => x.Title)
            .ThenBy(x => x.Id)
            .Take(PublicLegacyListMaxTake)
            .Select(template => new
            {
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.PetPhotoRequirements,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.PromoBadgeMode,
                template.Status,
                template.MusicDescription,
                template.ReferenceVideoDurationSeconds,
                template.SupportsGenerationResultInput,
                template.RequiredInputMediaType,
                template.RecommendedAfterImageGeneration,
                template.SupportsGenerateSimilar,
                template.DefaultVariationStrength,
                template.CreatedAtUtc,
                template.UpdatedAtUtc,
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.FileName,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault()
            })
            .ToArrayAsync(cancellationToken);

        var publicItems = items
            .Select(template => MapPublicListItem(
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.PetPhotoRequirements,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.PromoBadgeMode,
                template.Status,
                template.MusicDescription,
                template.ReferenceVideoDurationSeconds,
                template.SupportsGenerationResultInput,
                template.RequiredInputMediaType,
                template.RecommendedAfterImageGeneration,
                template.SupportsGenerateSimilar,
                template.DefaultVariationStrength,
                template.CreatedAtUtc,
                template.UpdatedAtUtc,
                template.Preview?.Url,
                template.Preview?.FileName,
                template.Preview?.ContentType,
                template.Preview?.FileSizeBytes,
                template.Preview?.DurationSeconds,
                locale))
            .ToArray();

        return Result.Success<IReadOnlyList<PublicTemplateListItemResponse>>(publicItems);
    }

    public async Task<Result<IReadOnlyList<PublicTemplateCategoryResponse>>> ListPublicCategoriesAsync(CancellationToken cancellationToken)
    {
        var categories = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(x => !x.IsArchived)
            .OrderBy(x => x.Name)
            .Select(x => new PublicTemplateCategoryResponse(x.Name))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<PublicTemplateCategoryResponse>>(categories);
    }

    public async Task<Result<PublicTemplatesFeedResponse>> ListPublicFeedAsync(PublicTemplatesFeedQuery query, CancellationToken cancellationToken)
    {
        var take = NormalizePublicFeedTake(query.Take);
        var cursor = TryParsePublicFeedCursor(query.Cursor);
        var normalizedCategory = NormalizePublicCategoryFilter(query.Category);
        var normalizedSearch = NormalizePublicSearchFilter(query.Search);
        var normalizedTags = NormalizePublicTagFilters(query.Tags);

        var filteredQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !query.Type.HasValue || x.TemplateType == query.Type.Value)
            .Where(x => !query.PremiumOnly.HasValue || !query.PremiumOnly.Value || x.IsPremium);

        filteredQuery = await ApplyPublicCategoryFilterAsync(filteredQuery, normalizedCategory, cancellationToken);

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            var normalizedSearchLower = normalizedSearch.ToLowerInvariant();
            filteredQuery = filteredQuery.Where(template =>
                (template.Title ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.ShortDescription ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.Category ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.Tags ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.PetPhotoRequirements ?? string.Empty).ToLower().Contains(normalizedSearchLower));
        }

        if (cursor is not null)
        {
            filteredQuery = cursor.Version.HasValue
                ? filteredQuery.Where(template =>
                    template.UpdatedAtUtc < cursor.UpdatedAtUtc
                    || (template.UpdatedAtUtc == cursor.UpdatedAtUtc && template.Version < cursor.Version.Value)
                    || (template.UpdatedAtUtc == cursor.UpdatedAtUtc
                        && template.Version == cursor.Version.Value
                        && template.Id.CompareTo(cursor.TemplateId) < 0))
                : filteredQuery.Where(template => template.UpdatedAtUtc < cursor.UpdatedAtUtc);
        }

        var orderedQuery = filteredQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Version)
            .ThenByDescending(template => template.Id);

        var filtered = await ApplyTemplateTagFilter(orderedQuery, normalizedTags)
            .Take(take + 1)
            .Select(template => new
            {
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.PetPhotoRequirements,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.Version,
                template.PromoBadgeMode,
                template.Status,
                template.MusicDescription,
                template.ReferenceVideoDurationSeconds,
                template.SupportsGenerationResultInput,
                template.RequiredInputMediaType,
                template.RecommendedAfterImageGeneration,
                template.SupportsGenerateSimilar,
                template.DefaultVariationStrength,
                template.CreatedAtUtc,
                template.UpdatedAtUtc,
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.FileName,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault()
            })
            .ToArrayAsync(cancellationToken);

        var pageItems = filtered.Take(take).ToArray();
        var hasMore = filtered.Length > take;
        var nextCursor = hasMore && pageItems.Length > 0
            ? FormatPublicFeedCursor(pageItems[^1].UpdatedAtUtc, pageItems[^1].Version, pageItems[^1].Id)
            : null;

        return Result.Success(new PublicTemplatesFeedResponse(
            [.. pageItems.Select(template => MapPublicFeedItem(
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.PetPhotoRequirements,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.PromoBadgeMode,
                template.Status,
                template.MusicDescription,
                template.ReferenceVideoDurationSeconds,
                template.SupportsGenerationResultInput,
                template.RequiredInputMediaType,
                template.RecommendedAfterImageGeneration,
                template.SupportsGenerateSimilar,
                template.DefaultVariationStrength,
                template.Version,
                template.CreatedAtUtc,
                template.UpdatedAtUtc,
                template.Preview?.Url,
                template.Preview?.FileName,
                template.Preview?.ContentType,
                template.Preview?.FileSizeBytes,
                template.Preview?.DurationSeconds,
                query.Locale))],
            nextCursor,
            hasMore,
            DateTime.UtcNow));
    }

    public async Task<Result<PublicRandomTemplateResponse>> GetPublicRandomTemplateAsync(
        PublicRandomTemplateQuery query,
        CancellationToken cancellationToken)
    {
        var normalizedCategory = NormalizePublicCategoryFilter(query.Category);
        var normalizedAccess = NormalizePublicRandomAccess(query.Access);

        var filteredQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Where(template => !query.Type.HasValue || template.TemplateType == query.Type.Value)
            .Where(template => !query.ExcludeTemplateId.HasValue || template.Id != query.ExcludeTemplateId.Value)
            .Where(template => template.Assets.Any(asset =>
                asset.AssetKind == TemplateAssetKind.Preview
                && asset.Url != null
                && asset.Url.Trim() != string.Empty));

        filteredQuery = normalizedAccess switch
        {
            "premium" => filteredQuery.Where(template => template.IsPremium),
            "free" => filteredQuery.Where(template => !template.IsPremium),
            _ => filteredQuery.Where(template => query.IncludePremium || !template.IsPremium)
        };

        filteredQuery = await ApplyPublicCategoryFilterAsync(filteredQuery, normalizedCategory, cancellationToken);

        var totalCount = await filteredQuery.CountAsync(cancellationToken);
        if (totalCount <= 0)
        {
            return Result.Success(new PublicRandomTemplateResponse(null));
        }

        var offset = RandomNumberGenerator.GetInt32(totalCount);
        var item = await filteredQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Id)
            .Skip(offset)
            .Take(1)
            .Select(template => new
            {
                template.Id,
                template.TemplateType,
                template.Title,
                template.ShortDescription,
                template.LocalizedTextsJson,
                template.PetPhotoRequirements,
                template.Category,
                template.Tags,
                template.IsPremium,
                template.TokenCost,
                template.PromoBadgeMode,
                template.Status,
                template.MusicDescription,
                template.ReferenceVideoDurationSeconds,
                template.SupportsGenerationResultInput,
                template.RequiredInputMediaType,
                template.RecommendedAfterImageGeneration,
                template.SupportsGenerateSimilar,
                template.DefaultVariationStrength,
                template.CreatedAtUtc,
                template.UpdatedAtUtc,
                Preview = template.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.FileName,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault()
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (item is null)
        {
            return Result.Success(new PublicRandomTemplateResponse(null));
        }

        return Result.Success(new PublicRandomTemplateResponse(
            MapPublicListItem(
                item.Id,
                item.TemplateType,
                item.Title,
                item.ShortDescription,
                item.LocalizedTextsJson,
                item.PetPhotoRequirements,
                item.Category,
                item.Tags,
                item.IsPremium,
                item.TokenCost,
                item.PromoBadgeMode,
                item.Status,
                item.MusicDescription,
                item.ReferenceVideoDurationSeconds,
                item.SupportsGenerationResultInput,
                item.RequiredInputMediaType,
                item.RecommendedAfterImageGeneration,
                item.SupportsGenerateSimilar,
                item.DefaultVariationStrength,
                item.CreatedAtUtc,
                item.UpdatedAtUtc,
                item.Preview?.Url,
                item.Preview?.FileName,
                item.Preview?.ContentType,
                item.Preview?.FileSizeBytes,
                item.Preview?.DurationSeconds,
                query.Locale)));
    }

    private static IQueryable<TemplateItem> ApplyTemplateTagFilter(IQueryable<TemplateItem> query, string[] normalizedTags)
    {
        foreach (var tag in normalizedTags)
        {
            var tagNeedle = "," + tag.ToLowerInvariant() + ",";
            query = query.Where(template => ("," + (template.Tags ?? string.Empty).ToLower() + ",").Contains(tagNeedle));
        }

        return query;
    }

    private async Task<IQueryable<TemplateItem>> ApplyPublicCategoryFilterAsync(
        IQueryable<TemplateItem> query,
        string? normalizedCategory,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(normalizedCategory))
        {
            return query;
        }

        var categoryKey = NormalizeCategoryKey(normalizedCategory);
        var canonicalCategory = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(category => category.NormalizedName == categoryKey)
            .Select(category => category.Name)
            .FirstOrDefaultAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(canonicalCategory))
        {
            return query.Where(template => template.Category == canonicalCategory);
        }

        return query.Where(template => (template.Category ?? string.Empty).ToUpper() == categoryKey);
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, string? locale, CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.Id == templateId)
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Select(x => new
            {
                x.Id,
                x.TemplateType,
                x.Title,
                x.ShortDescription,
                x.LocalizedTextsJson,
                x.PetPhotoRequirements,
                x.Category,
                x.Tags,
                x.IsPremium,
                x.TokenCost,
                x.PromoBadgeMode,
                x.Status,
                x.MusicDescription,
                x.ReferenceVideoDurationSeconds,
                x.SupportsGenerationResultInput,
                x.RequiredInputMediaType,
                x.RecommendedAfterImageGeneration,
                x.SupportsGenerateSimilar,
                x.DefaultVariationStrength,
                x.CreatedAtUtc,
                x.UpdatedAtUtc,
                Preview = x.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => new
                    {
                        asset.Url,
                        asset.FileName,
                        asset.ContentType,
                        asset.FileSizeBytes,
                        asset.DurationSeconds
                    })
                    .FirstOrDefault()
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (template is null)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(
            template.Id,
            template.TemplateType,
            template.Title,
            template.ShortDescription,
            template.LocalizedTextsJson,
            template.PetPhotoRequirements,
            template.Category,
            template.Tags,
            template.IsPremium,
            template.TokenCost,
            template.PromoBadgeMode,
            template.Status,
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            template.SupportsGenerationResultInput,
            template.RequiredInputMediaType,
            template.RecommendedAfterImageGeneration,
            template.SupportsGenerateSimilar,
            template.DefaultVariationStrength,
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            template.Preview?.Url,
            template.Preview?.FileName,
            template.Preview?.ContentType,
            template.Preview?.FileSizeBytes,
            template.Preview?.DurationSeconds,
            locale));
    }
}
