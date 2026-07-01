using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateCategoryAdminService(
    TemplatesDbContext dbContext,
    ITemplateFeedRealtimeService templateFeedRealtimeService)
{
    public async Task<Result<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAdminCategoriesAsync(bool includeArchived, CancellationToken cancellationToken)
    {
        var categories = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(x => includeArchived || !x.IsArchived)
            .OrderBy(x => x.IsArchived)
            .ThenBy(x => x.Name)
            .ToArrayAsync(cancellationToken);

        if (categories.Length == 0)
        {
            return Result.Success<IReadOnlyList<AdminTemplateCategoryListItemResponse>>([]);
        }

        var categoryNames = categories
            .Select(category => NormalizeCategoryLookupKey(category.Name))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        var includesEmptyCategory = categoryNames.Contains(string.Empty, StringComparer.Ordinal);
        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .Where(template =>
                categoryNames.Contains(template.Category)
                || (includesEmptyCategory && (template.Category == null || template.Category == string.Empty)))
            .Select(template => new TemplateCategorySnapshot(
                NormalizeCategoryLookupKey(template.Category),
                template.TemplateType,
                template.Status,
                template.IsPremium,
                template.Tags))
            .ToArrayAsync(cancellationToken);
        var templatesByCategory = templates
            .GroupBy(template => template.Category, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => (IReadOnlyCollection<TemplateCategorySnapshot>)group.ToArray(), StringComparer.Ordinal);

        var response = categories
            .Select(category => MapAdminCategory(
                category,
                templatesByCategory.TryGetValue(NormalizeCategoryLookupKey(category.Name), out var categoryTemplates) ? categoryTemplates : []))
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateCategoryListItemResponse>>(response);
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> CreateCategoryAsync(CreateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        var categoryName = NormalizeCategoryName(command.Name);
        var normalizedName = NormalizeCategoryKey(categoryName);

        var exists = await dbContext.TemplateCategories
            .AsNoTracking()
            .AnyAsync(x => x.NormalizedName == normalizedName, cancellationToken);

        if (exists)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var category = new TemplateCategory
        {
            Id = Guid.NewGuid(),
            Name = categoryName,
            NormalizedName = normalizedName,
            IsArchived = false,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateCategories.Add(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminCategory(category, []));
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> UpdateCategoryAsync(UpdateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(command.CategoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryNotFound);
        }

        var categoryName = NormalizeCategoryName(command.Name);
        var normalizedName = NormalizeCategoryKey(categoryName);
        var duplicateExists = await dbContext.TemplateCategories
            .AsNoTracking()
            .AnyAsync(x => x.Id != category.Id && x.NormalizedName == normalizedName, cancellationToken);

        if (duplicateExists)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryAlreadyExists);
        }

        var previousName = category.Name;
        var updatedAtUtc = DateTime.UtcNow;

        category.Name = categoryName;
        category.NormalizedName = normalizedName;
        category.UpdatedAtUtc = updatedAtUtc;

        if (!string.Equals(previousName, categoryName, StringComparison.Ordinal))
        {
            var templates = await dbContext.TemplateItems
                .Where(x => x.Category == previousName)
                .ToArrayAsync(cancellationToken);

            foreach (var template in templates)
            {
                template.Category = categoryName;
                template.UpdatedAtUtc = updatedAtUtc;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);
        return Result.Success(await BuildAdminCategoryResponseAsync(category, cancellationToken));
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> ChangeCategoryArchiveStateAsync(ChangeTemplateCategoryArchiveStateCommand command, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(command.CategoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryNotFound);
        }

        if (category.IsArchived != command.IsArchived)
        {
            category.IsArchived = command.IsArchived;
            category.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
            await PublishFeedInvalidatedAsync(cancellationToken);
        }

        return Result.Success(await BuildAdminCategoryResponseAsync(category, cancellationToken));
    }

    public async Task<Result> DeleteCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(categoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure(TemplatesErrors.CategoryNotFound);
        }

        var hasTemplates = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Category == category.Name, cancellationToken);

        if (hasTemplates)
        {
            return Result.Failure(TemplatesErrors.CategoryHasTemplates);
        }

        dbContext.TemplateCategories.Remove(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);
        return Result.Success();
    }

    private Task<TemplateCategory?> FindCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateCategories
            .FirstOrDefaultAsync(x => x.Id == categoryId, cancellationToken);
    }

    private async Task<AdminTemplateCategoryListItemResponse> BuildAdminCategoryResponseAsync(TemplateCategory category, CancellationToken cancellationToken)
    {
        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.Category == category.Name)
            .Select(template => new TemplateCategorySnapshot(
                template.Category,
                template.TemplateType,
                template.Status,
                template.IsPremium,
                template.Tags))
            .ToArrayAsync(cancellationToken);

        return MapAdminCategory(category, templates);
    }

    private ValueTask PublishFeedInvalidatedAsync(CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(cancellationToken);
    }

    private static string NormalizeCategoryName(string rawCategoryName)
    {
        return rawCategoryName.Trim();
    }

    private static string NormalizeCategoryKey(string categoryName)
    {
        return categoryName.Trim().ToUpperInvariant();
    }

    private static string NormalizeCategoryLookupKey(string? categoryName)
    {
        return categoryName?.Trim() ?? string.Empty;
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return [.. tags
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private static string[] DeserializeTags(string? tags)
    {
        if (string.IsNullOrWhiteSpace(tags))
        {
            return [];
        }

        return NormalizeTags(tags.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static AdminTemplateCategoryListItemResponse MapAdminCategory(TemplateCategory category, IReadOnlyCollection<TemplateCategorySnapshot> templates)
    {
        var tags = templates
            .SelectMany(template => DeserializeTags(template.Tags))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(tag => tag, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new AdminTemplateCategoryListItemResponse(
            category.Id,
            category.Name ?? string.Empty,
            category.IsArchived,
            templates.Count,
            templates.Count(template => template.TemplateType == TemplateType.Video),
            templates.Count(template => template.TemplateType == TemplateType.Image),
            templates.Count(template => template.Status == TemplateStatus.Active),
            templates.Count(template => template.Status == TemplateStatus.Draft),
            templates.Count(template => template.Status == TemplateStatus.Archived),
            templates.Count(template => template.IsPremium),
            tags,
            category.CreatedAtUtc,
            category.UpdatedAtUtc);
    }

    private sealed record TemplateCategorySnapshot(
        string Category,
        TemplateType TemplateType,
        TemplateStatus Status,
        bool IsPremium,
        string? Tags);
}
