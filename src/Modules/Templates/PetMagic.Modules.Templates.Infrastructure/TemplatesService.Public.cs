using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
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
                || ((template.PetPhotoRequirements ?? string.Empty).ToLower().Contains(normalizedSearchLower)));
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
            filtered = (await orderedQuery.ToArrayAsync(cancellationToken))
                .Where(template => normalizedTags.All(tag => DeserializeTags(template.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
                .Take(take + 1)
                .ToArray();
        }

        var pageItems = filtered.Take(take).ToArray();
        var hasMore = filtered.Length > take;
        var nextCursor = hasMore && pageItems.Length > 0
            ? FormatPublicFeedCursor(pageItems[^1])
            : null;

        return Result.Success(new PublicTemplatesFeedResponse(
            pageItems.Select(MapPublicListItem).ToArray(),
            nextCursor,
            hasMore,
            DateTime.UtcNow));
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.Status != TemplateStatus.Active)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(template));
    }
}

