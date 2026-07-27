using System.Text.Json;

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
    private static readonly JsonSerializerOptions RealtimeJsonSerializerOptions = new(JsonSerializerDefaults.Web);

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

    public async Task<Result<AdminTemplateCategoryDiagnosticsResponse>> GetAdminCategoryDiagnosticsAsync(CancellationToken cancellationToken)
    {
        var categorySnapshots = await dbContext.TemplateCategories
            .AsNoTracking()
            .Select(category => new
            {
                category.Name,
                category.NormalizedName,
                category.IsArchived
            })
            .ToArrayAsync(cancellationToken);
        var categoryStatesByKey = categorySnapshots
            .Select(category => new
            {
                Key = NormalizeCategoryKey(
                    string.IsNullOrWhiteSpace(category.NormalizedName)
                        ? category.Name ?? string.Empty
                        : category.NormalizedName),
                category.IsArchived
            })
            .Where(category => !string.IsNullOrWhiteSpace(category.Key))
            .GroupBy(category => category.Key, StringComparer.Ordinal)
            .ToDictionary(
                group => group.Key,
                group => new TemplateCategoryDiagnosticState(
                    HasActiveCategory: group.Any(category => !category.IsArchived),
                    HasArchivedCategory: group.Any(category => category.IsArchived)),
                StringComparer.Ordinal);

        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            // TemplateVisibilityPolicy direct-check allowlist: admin diagnostics intentionally inspect active, non-deleted
            // rows to report noncanonical category data. This is not a public visibility filter.
            .Where(template => template.DeletedAtUtc == null && template.Status == TemplateStatus.Active)
            .Select(template => new
            {
                template.Id,
                template.Title,
                template.Category,
                template.TemplateType,
                template.Status,
                template.UpdatedAtUtc
            })
            .ToArrayAsync(cancellationToken);

        var items = templates
            .Select(template => new
            {
                Template = template,
                NormalizedCategory = NormalizeCategoryKey(template.Category ?? string.Empty),
                IssueKind = ResolveCategoryIssueKind(
                    NormalizeCategoryKey(template.Category ?? string.Empty),
                    categoryStatesByKey)
            })
            .Where(template => template.IssueKind is not null)
            .OrderBy(template => template.NormalizedCategory, StringComparer.Ordinal)
            .ThenBy(template => template.Template.Title, StringComparer.Ordinal)
            .ThenBy(template => template.Template.Id)
            .Select(template => new AdminTemplateCategoryDiagnosticItemResponse(
                template.Template.Id,
                template.IssueKind!,
                template.Template.Title ?? string.Empty,
                template.Template.Category ?? string.Empty,
                template.NormalizedCategory,
                template.Template.TemplateType.ToString(),
                template.Template.Status.ToString(),
                template.Template.UpdatedAtUtc))
            .ToArray();

        TemplateCategoryMetrics.RecordNoncanonicalCategoryTemplatesCount(items.Length);

        var percent = templates.Length == 0
            ? 0d
            : Math.Round(items.Length * 100d / templates.Length, 2, MidpointRounding.AwayFromZero);

        return Result.Success(new AdminTemplateCategoryDiagnosticsResponse(
            templates.Length,
            items.Length,
            percent,
            items,
            DateTime.UtcNow));
    }

    private static string? ResolveCategoryIssueKind(
        string normalizedCategory,
        IReadOnlyDictionary<string, TemplateCategoryDiagnosticState> categoryStatesByKey)
    {
        if (string.IsNullOrWhiteSpace(normalizedCategory))
        {
            return AdminTemplateCategoryDiagnosticIssueKinds.EmptyCategory;
        }

        if (!categoryStatesByKey.TryGetValue(normalizedCategory, out var categoryState))
        {
            return AdminTemplateCategoryDiagnosticIssueKinds.MissingCategory;
        }

        if (categoryState.HasActiveCategory)
        {
            return null;
        }

        return categoryState.HasArchivedCategory
            ? AdminTemplateCategoryDiagnosticIssueKinds.ArchivedCategory
            : AdminTemplateCategoryDiagnosticIssueKinds.MissingCategory;
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
        await PublishCategoryInvalidatedAsync(category.Name, "created", isCritical: false, cancellationToken);

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

        if (dbContext.Database.IsRelational())
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
            await ApplyCategoryRenameAsync(category, previousName, categoryName, normalizedName, updatedAtUtc, cancellationToken);
            StageCategoryInvalidated(categoryName, "renamed", isCritical: false, updatedAtUtc);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        else
        {
            await ApplyCategoryRenameAsync(category, previousName, categoryName, normalizedName, updatedAtUtc, cancellationToken);
            StageCategoryInvalidated(categoryName, "renamed", isCritical: false, updatedAtUtc);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

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
            await PublishCategoryInvalidatedAsync(
                category.Name,
                command.IsArchived ? "archived" : "unarchived",
                isCritical: command.IsArchived,
                cancellationToken);
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
        await PublishCategoryInvalidatedAsync(category.Name, "deleted", isCritical: true, cancellationToken);
        return Result.Success();
    }

    private Task<TemplateCategory?> FindCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateCategories
            .FirstOrDefaultAsync(x => x.Id == categoryId, cancellationToken);
    }

    private async Task ApplyCategoryRenameAsync(
        TemplateCategory category,
        string previousName,
        string categoryName,
        string normalizedName,
        DateTime updatedAtUtc,
        CancellationToken cancellationToken)
    {
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

    private ValueTask PublishCategoryInvalidatedAsync(
        string category,
        string reason,
        bool isCritical,
        CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(
            new TemplateFeedInvalidationPayload(
                TemplateFeedInvalidationScopes.Category,
                Category: category,
                IsCritical: isCritical,
                Reason: reason),
            cancellationToken);
    }

    private void StageCategoryInvalidated(
        string category,
        string reason,
        bool isCritical,
        DateTime createdAtUtc)
    {
        var payload = new TemplateFeedInvalidationPayload(
            TemplateFeedInvalidationScopes.Category,
            Category: category,
            IsCritical: isCritical,
            Reason: reason);

        dbContext.TemplateRealtimeEvents.Add(new TemplateRealtimeEventRecord
        {
            Id = Guid.NewGuid(),
            Topic = TemplateFeedRealtimeTopics.TemplatesFeedInvalidated,
            Data = JsonSerializer.Serialize(payload, RealtimeJsonSerializerOptions),
            CreatedAtUtc = createdAtUtc
        });
    }

    private static string NormalizeCategoryName(string rawCategoryName)
    {
        return CollapseWhitespace(rawCategoryName);
    }

    private static string NormalizeCategoryKey(string categoryName)
    {
        return CollapseWhitespace(categoryName).ToUpperInvariant();
    }

    private static string NormalizeCategoryLookupKey(string? categoryName)
    {
        return string.IsNullOrWhiteSpace(categoryName)
            ? string.Empty
            : CollapseWhitespace(categoryName);
    }

    private static string CollapseWhitespace(string value)
    {
        return string.Join(' ', value
            .Trim()
            .Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries));
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

    private sealed record TemplateCategoryDiagnosticState(
        bool HasActiveCategory,
        bool HasArchivedCategory);
}
