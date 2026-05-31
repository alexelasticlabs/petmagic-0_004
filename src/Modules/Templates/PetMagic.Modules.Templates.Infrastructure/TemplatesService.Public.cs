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
        var normalizedCategory = query.Category?.Trim();

        var baseQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !query.Type.HasValue || x.TemplateType == query.Type.Value);

        if (!string.IsNullOrWhiteSpace(normalizedCategory))
        {
            var normalizedCategoryUpper = normalizedCategory.ToUpperInvariant();
            baseQuery = baseQuery.Where(template => (template.Category ?? string.Empty).ToUpper() == normalizedCategoryUpper);
        }

        var totalCount = await baseQuery.LongCountAsync(cancellationToken);
        var offset = (page - 1) * pageSize;

        var pageItems = await baseQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Id)
            .Skip(offset)
            .Take(pageSize)
            .Select(template => new
            {
                template.Id,
                template.Title,
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

        var hasMore = totalCount > offset + pageItems.Length;

        return Result.Success(new PublicTemplatesCatalogPageResponse(
            [.. pageItems.Select(item => MapPublicCatalogMetadataItem(
                item.Id,
                item.Title,
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
        var version = await GetCurrentCatalogVersionAsync(cancellationToken);
        DateTime? updatedAtUtc = null;

        if (version > 0)
        {
            updatedAtUtc = await dbContext.TemplateCatalogChanges
                .AsNoTracking()
                .Where(change => change.Version == version)
                .Select(change => (DateTime?)change.UpdatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }

        return Result.Success(new PublicTemplatesCatalogVersionResponse(version, updatedAtUtc));
    }

    public async Task<Result<PublicTemplatesCatalogChangesResponse>> GetPublicCatalogChangesAsync(long sinceVersion, CancellationToken cancellationToken)
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
                template.Title,
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
            [.. upserts.Values.OrderByDescending(item => item.UpdatedAtUtc).ThenByDescending(item => item.Id)],
            [.. deletedIds],
            false));
    }

    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => string.IsNullOrWhiteSpace(category) || string.Equals(x.Category, category.Trim(), StringComparison.OrdinalIgnoreCase))
            .Where(x => !premiumOnly.HasValue || !premiumOnly.Value || x.IsPremium)
            .OrderBy(x => x.IsPremium)
            .ThenBy(x => x.Title)
            .ToArrayAsync(cancellationToken);

        var filtered = items
            .Where(x => normalizedTags.Length == 0 || normalizedTags.All(tag => DeserializeTags(x.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
            .Select(MapPublicListItem)
            .ToArray();

        return Result.Success<IReadOnlyList<PublicTemplateListItemResponse>>(filtered);
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
        var normalizedCategory = query.Category?.Trim();
        var normalizedSearch = query.Search?.Trim();
        var normalizedTags = NormalizeTags(query.Tags);

        var filteredQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !query.Type.HasValue || x.TemplateType == query.Type.Value)
            .Where(x => !query.PremiumOnly.HasValue || !query.PremiumOnly.Value || x.IsPremium);

        if (!string.IsNullOrWhiteSpace(normalizedCategory))
        {
            var normalizedCategoryUpper = normalizedCategory.ToUpperInvariant();
            filteredQuery = filteredQuery.Where(template => (template.Category ?? string.Empty).ToUpper() == normalizedCategoryUpper);
        }

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
            filteredQuery = filteredQuery.Where(template =>
                template.UpdatedAtUtc < cursor.UpdatedAtUtc
                || (template.UpdatedAtUtc == cursor.UpdatedAtUtc && template.Id.CompareTo(cursor.TemplateId) < 0));
        }

        var orderedQuery = filteredQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Id);

        TemplateItem[] filtered;

        if (normalizedTags.Length == 0)
        {
            filtered = await orderedQuery
                .Take(take + 1)
                .ToArrayAsync(cancellationToken);
        }
        else
        {
            filtered = [.. (await orderedQuery.ToArrayAsync(cancellationToken))
                .Where(template => normalizedTags.All(tag => DeserializeTags(template.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
                .Take(take + 1)];
        }

        var pageItems = filtered.Take(take).ToArray();
        var hasMore = filtered.Length > take;
        var nextCursor = hasMore && pageItems.Length > 0
            ? FormatPublicFeedCursor(pageItems[^1])
            : null;

        return Result.Success(new PublicTemplatesFeedResponse(
            [.. pageItems.Select(MapPublicListItem)],
            nextCursor,
            hasMore,
            DateTime.UtcNow));
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.DeletedAtUtc is not null || template.Status != TemplateStatus.Active)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(template));
    }
}
