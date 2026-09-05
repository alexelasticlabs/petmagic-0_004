using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateDiscoveryAdminService
{
    private async Task<DiscoveryDocument> CreateInitialDocumentAsync(CancellationToken cancellationToken)
    {
        var visible = new TemplateVisibilityPolicy().ApplyPublic(dbContext.TemplateItems.AsNoTracking(), new TemplateVisibilityContext());
        var categories = await dbContext.TemplateCategories.AsNoTracking().Where(category => !category.IsArchived)
            .Where(category => visible.Any(template => template.Category == category.Name))
            .OrderBy(category => category.NormalizedName).Take(12).ToArrayAsync(cancellationToken);
        return new(1, new Dictionary<string, DiscoveryCopy>
        { ["en"] = new("Create magic", "Find your pet's next adventure"), ["ru"] = new("Создай магию", "Найди новое приключение для питомца") },
            true, true, true, 7000, categories.Select(category => new DiscoverySection(
                Guid.NewGuid(), category.Id, true, true, true, null, "Latest", 6, [],
                new Dictionary<string, DiscoveryCopy> { ["en"] = new(category.Name, "") })).ToArray());
    }

    private async Task<List<DiscoveryValidationIssue>> ValidateDocumentAsync(DiscoveryDocument document, CancellationToken cancellationToken)
    {
        var issues = TemplateDiscoveryDocument.ShapeIssues(document);
        if (issues.Count > 0) return issues;
        void Add(string path, string code, string message) => issues.Add(new(path, code, message));
        if (!document.Copy.TryGetValue("en", out var fallback) || string.IsNullOrWhiteSpace(fallback.Title))
            Add("copy.en.title", "missing_fallback", "An English page title is required as the fallback.");
        if (!document.Sections.Any(section => section.IsEnabled &&
            (section.ShowAsRail || (document.CarouselEnabled && section.ShowInCarousel))))
            Add("sections", "empty_page", "Enable at least one visible section.");
        var categoryIds = document.Sections.Select(section => section.CategoryId).ToArray();
        var categories = await dbContext.TemplateCategories.AsNoTracking().Where(category => categoryIds.Contains(category.Id))
            .ToDictionaryAsync(category => category.Id, cancellationToken);
        var pinnedIds = document.Sections.SelectMany(section => section.TemplateIds
            .Concat(section.HeroTemplateId is { } hero ? [hero] : Array.Empty<Guid>())).Distinct().ToArray();
        var templates = await new TemplateVisibilityPolicy().ApplyPublic(dbContext.TemplateItems.AsNoTracking(), new TemplateVisibilityContext())
            .Where(template => pinnedIds.Contains(template.Id))
            .Select(template => new
            {
                template.Id,
                template.Category,
                HasPreview = template.Assets.Any(asset => asset.Url != "" &&
                    (asset.AssetKind == TemplateAssetKind.Preview || asset.AssetKind == TemplateAssetKind.Thumbnail ||
                     asset.AssetKind == TemplateAssetKind.FeedLoopLow || asset.AssetKind == TemplateAssetKind.AnimatedPreview))
            })
            .ToDictionaryAsync(template => template.Id, cancellationToken);
        for (var index = 0; index < document.Sections.Count; index++)
        {
            var section = document.Sections[index];
            if (!section.IsEnabled) continue;
            var path = $"sections[{index}]";
            if (!categories.TryGetValue(section.CategoryId, out var category) || category.IsArchived)
            { Add(path + ".categoryId", "category_unavailable", "The category is missing or archived."); continue; }
            if (section.SelectionMode == "Latest" && section.TemplateIds.Count > 0)
                Add(path + ".templateIds", "unexpected_pins", "Latest mode cannot contain pinned templates.");
            var ids = section.TemplateIds.Concat(section.HeroTemplateId is { } hero ? [hero] : Array.Empty<Guid>()).Distinct().ToArray();
            if (ids.Length > section.ItemLimit)
                Add(path + ".itemLimit", "hidden_pins", "Increase the item limit or remove pinned templates; the cover also occupies a slot.");
            if (section.SelectionMode == "Manual" && ids.Length == 0)
                Add(path + ".templateIds", "empty_section", "Choose at least one template for a manual section.");
            foreach (var id in ids)
            {
                if (!templates.TryGetValue(id, out var template) || !template.HasPreview || template.Category != category.Name)
                    Add(path + ".templateIds", "template_unavailable", $"Template {id} must be public, active, have a preview and belong to this category.");
            }
            if (section.Copy.Any(pair => !string.IsNullOrWhiteSpace(pair.Value.Title)) &&
                (!section.Copy.TryGetValue("en", out var sectionFallback) || string.IsNullOrWhiteSpace(sectionFallback.Title)))
                Add(path + ".copy.en.title", "missing_fallback", "Provide an English fallback for the custom section title.");
        }
        // Resolve once with production visibility to also validate automatic sections without N+1 queries.
        var preview = await new TemplateDiscoveryResolver(dbContext).ResolveAsync(document, 0, "en", cancellationToken);
        var resolved = preview.Sections.Select(section => section.SectionId).ToHashSet();
        for (var index = 0; index < document.Sections.Count; index++)
            if (document.Sections[index].IsEnabled && !resolved.Contains(document.Sections[index].Id))
                Add($"sections[{index}]", "empty_section", "This section has no publicly available templates.");
        return issues;
    }
}
