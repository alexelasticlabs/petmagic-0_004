using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Templates.Infrastructure;

/// <summary>Shared projection for published discovery and saved admin previews.</summary>
internal sealed class TemplateDiscoveryResolver(TemplatesDbContext dbContext)
{
    internal async Task<PublicTemplatesDiscoveryResponse> ResolveAsync(
        DiscoveryDocument document, long revision, string? locale, CancellationToken cancellationToken,
        int sectionLimit = 24, int itemsPerSection = 12, bool includeQaOnly = false)
    {
        var sections = document.Sections.Where(section => section.IsEnabled).Take(Math.Clamp(sectionLimit, 1, 24)).ToArray();
        var categoryIds = sections.Select(section => section.CategoryId).ToArray();
        var categories = await dbContext.TemplateCategories.AsNoTracking()
            .Where(category => categoryIds.Contains(category.Id) && !category.IsArchived)
            .ToDictionaryAsync(category => category.Id, cancellationToken);
        var visible = new TemplateVisibilityPolicy().ApplyPublic(dbContext.TemplateItems.AsNoTracking(),
                new TemplateVisibilityContext(IncludeQaOnly: includeQaOnly, Locale: locale))
            .Where(template => template.Assets.Any(asset =>
                (asset.AssetKind == TemplateAssetKind.Preview || asset.AssetKind == TemplateAssetKind.Thumbnail ||
                 asset.AssetKind == TemplateAssetKind.FeedLoopLow || asset.AssetKind == TemplateAssetKind.AnimatedPreview)
                && asset.Url != ""));
        IQueryable<Guid>? candidates = null;
        foreach (var section in sections)
        {
            if (!categories.TryGetValue(section.CategoryId, out var category)) continue;
            var pins = section.TemplateIds.Concat(section.HeroTemplateId is { } hero ? [hero] : Array.Empty<Guid>()).ToArray();
            var categoryName = category.Name;
            var categoryQuery = visible.Where(template => template.Category == categoryName);
            var manual = categoryQuery.Where(template => pins.Contains(template.Id)).Select(template => template.Id);
            var selected = section.SelectionMode == "Manual" ? manual : manual.Concat(categoryQuery
                .OrderByDescending(template => template.PublishedAtUtc ?? template.CreatedAtUtc)
                .ThenByDescending(template => template.Id).Take(section.ItemLimit).Select(template => template.Id));
            candidates = candidates is null ? selected : candidates.Concat(selected);
        }
        var candidateIds = candidates is null ? [] : await candidates.Distinct().ToArrayAsync(cancellationToken);
        // Bounded by 24 sections and 12 pins + 12 automatic candidates, independent of catalog size.
        var templates = await visible.Where(template => candidateIds.Contains(template.Id))
            .Include(template => template.Assets).AsSingleQuery().ToArrayAsync(cancellationToken);
        var output = new List<PublicTemplatesDiscoverySectionResponse>();
        foreach (var section in sections)
        {
            if (!categories.TryGetValue(section.CategoryId, out var category)) continue;
            var rows = templates.Where(template => template.Category == category.Name)
                .OrderByDescending(template => template.PublishedAtUtc ?? template.CreatedAtUtc)
                .ThenByDescending(template => template.Id).ToArray();
            var orderedIds = (section.HeroTemplateId is { } hero ? new[] { hero } : [])
                .Concat(section.SelectionMode == "Latest" ? [] : section.TemplateIds)
                .Concat(section.SelectionMode == "Manual" ? [] : rows.Select(template => template.Id)).Distinct();
            var byId = rows.ToDictionary(template => template.Id);
            var items = orderedIds.Where(byId.ContainsKey).Take(Math.Min(section.ItemLimit, Math.Clamp(itemsPerSection, 1, 12)))
                .Select(id => TemplatesService.MapDiscoveryFeedItem(byId[id], locale)).ToArray();
            if (items.Length == 0) continue;
            var copy = TemplateDiscoveryDocument.ResolveCopy(section.Copy, locale);
            output.Add(new(category.Name.Trim(), items, section.Id, category.Id,
                string.IsNullOrWhiteSpace(copy.Title) ? category.Name : copy.Title, copy.Subtitle,
                section.ShowInCarousel, section.ShowAsRail));
        }
        var pageCopy = TemplateDiscoveryDocument.ResolveCopy(document.Copy, locale);
        return new(output, DateTime.UtcNow, revision,
            new(pageCopy.Title, pageCopy.Subtitle, document.SearchEnabled, document.CarouselEnabled,
                document.AutoplayEnabled, document.AutoplayIntervalMs), SchemaVersion: 2);
    }
}
