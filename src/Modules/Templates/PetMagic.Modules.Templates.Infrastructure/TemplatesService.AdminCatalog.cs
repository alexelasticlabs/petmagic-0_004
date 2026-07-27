using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAdminCategoriesAsync(bool includeArchived, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.ListAdminCategoriesAsync(includeArchived, cancellationToken);
    }

    public async Task<Result<AdminTemplateCategoryDiagnosticsResponse>> GetAdminCategoryDiagnosticsAsync(CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.GetAdminCategoryDiagnosticsAsync(cancellationToken);
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> CreateCategoryAsync(CreateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.CreateCategoryAsync(command, cancellationToken);
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> UpdateCategoryAsync(UpdateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.UpdateCategoryAsync(command, cancellationToken);
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> ChangeCategoryArchiveStateAsync(ChangeTemplateCategoryArchiveStateCommand command, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.ChangeCategoryArchiveStateAsync(command, cancellationToken);
    }

    public async Task<Result> DeleteCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.DeleteCategoryAsync(categoryId, cancellationToken);
    }

    public async Task<Result<AdminTemplateCatalogPageResponse>> ListAdminAsync(
        AdminTemplateCatalogQuery query,
        CancellationToken cancellationToken)
    {
        var templateType = ParseTemplateType(query.Type);
        var templateStatus = ParseTemplateStatus(query.Status);
        var normalizedSearch = NormalizeCatalogFilter(query.Search);
        var normalizedCategory = NormalizeCatalogFilter(query.Category);
        var normalizedAccess = NormalizeCatalogFilter(query.Access);
        var normalizedVisibility = NormalizeCatalogFilter(query.Visibility);
        var normalizedReadiness = NormalizeCatalogFilter(query.Readiness);
        var normalizedSort = NormalizeCatalogFilter(query.Sort);
        var normalizedStatus = NormalizeCatalogFilter(query.Status);
        var normalizedSkip = Math.Max(0, query.Skip ?? 0);
        var normalizedTake = NormalizeTake(query.Take, 24, 100);
        var excludeArchived = normalizedStatus == "not_archived";

        var catalogQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null)
            .Where(x => !templateType.HasValue || x.TemplateType == templateType.Value)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            catalogQuery = catalogQuery.Where(x =>
                (x.Title ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.ShortDescription ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.Category ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                (x.Tags ?? string.Empty).ToLower().Contains(normalizedSearch));
        }

        if (!string.IsNullOrWhiteSpace(normalizedCategory) && normalizedCategory != "all")
        {
            catalogQuery = catalogQuery.Where(x => (x.Category ?? string.Empty).ToLower() == normalizedCategory);
        }

        if (normalizedAccess == "premium")
        {
            catalogQuery = catalogQuery.Where(x => x.IsPremium);
        }
        else if (normalizedAccess == "free")
        {
            catalogQuery = catalogQuery.Where(x => !x.IsPremium);
        }

        if (normalizedVisibility == "qa_only")
        {
            catalogQuery = catalogQuery.Where(x => x.IsQaOnly);
        }
        else if (normalizedVisibility == "public")
        {
            catalogQuery = catalogQuery.Where(x => !x.IsQaOnly);
        }

        if (normalizedReadiness == "ready")
        {
            catalogQuery = catalogQuery.Where(x =>
                x.Assets.Any(asset => asset.AssetKind == TemplateAssetKind.Preview));
        }
        else if (normalizedReadiness == "missing_preview")
        {
            catalogQuery = catalogQuery.Where(x =>
                !x.Assets.Any(asset => asset.AssetKind == TemplateAssetKind.Preview));
        }

        var summaryData = await catalogQuery
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalTemplates = group.Count(),
                ImageTemplates = group.Count(x => x.TemplateType == TemplateType.Image),
                VideoTemplates = group.Count(x => x.TemplateType == TemplateType.Video),
                ActiveTemplates = group.Count(x => x.Status == TemplateStatus.Active),
                DraftTemplates = group.Count(x => x.Status == TemplateStatus.Draft),
                ArchivedTemplates = group.Count(x => x.Status == TemplateStatus.Archived),
                PremiumTemplates = group.Count(x => x.IsPremium),
                QaOnlyTemplates = group.Count(x => x.IsQaOnly),
                MissingPreviewTemplates = group.Count(x =>
                    !x.Assets.Any(asset => asset.AssetKind == TemplateAssetKind.Preview))
            })
            .SingleOrDefaultAsync(cancellationToken);

        var summary = summaryData is null
            ? new AdminTemplateCatalogSummaryResponse(0, 0, 0, 0, 0, 0, 0, 0, 0)
            : new AdminTemplateCatalogSummaryResponse(
                summaryData.TotalTemplates,
                summaryData.ImageTemplates,
                summaryData.VideoTemplates,
                summaryData.ActiveTemplates,
                summaryData.DraftTemplates,
                summaryData.ArchivedTemplates,
                summaryData.PremiumTemplates,
                summaryData.QaOnlyTemplates,
                summaryData.MissingPreviewTemplates);

        var itemsQuery = catalogQuery
            .Where(x => !templateStatus.HasValue || x.Status == templateStatus.Value)
            .Where(x => !excludeArchived || x.Status != TemplateStatus.Archived)
            .Include(x => x.Assets)
            .AsQueryable();

        itemsQuery = normalizedSort switch
        {
            "title" => itemsQuery.OrderBy(x => x.Title).ThenByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.Id),
            "tokens" => itemsQuery.OrderByDescending(x => x.TokenCost).ThenByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.Id),
            _ => itemsQuery.OrderByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.CreatedAtUtc).ThenByDescending(x => x.Id)
        };

        var totalCount = await itemsQuery.CountAsync(cancellationToken);
        var items = await itemsQuery
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        var hasMore = items.Count > normalizedTake;
        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        return Result.Success(new AdminTemplateCatalogPageResponse(
            [.. items.Select(MapAdminListItem)],
            normalizedSkip,
            normalizedTake,
            totalCount,
            hasMore,
            summary));
    }

    public async Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        return template is null || template.DeletedAtUtc is not null
            ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapAdminResponse(template));
    }

    private static TemplateType? ParseTemplateType(string? raw)
    {
        return Enum.TryParse<TemplateType>(raw, true, out var value) ? value : null;
    }

    private static TemplateStatus? ParseTemplateStatus(string? raw)
    {
        if (string.Equals(raw?.Trim(), "not_archived", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return Enum.TryParse<TemplateStatus>(raw, true, out var value) ? value : null;
    }

    private static string? NormalizeCatalogFilter(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim().ToLowerInvariant();
        return normalized.Length > 120 ? normalized[..120] : normalized;
    }

    private static int NormalizeTake(int? take, int fallback, int max)
    {
        if (!take.HasValue || take.Value <= 0)
        {
            return fallback;
        }

        return Math.Min(take.Value, max);
    }

    public async Task<Result<AdminTemplateStatisticsResponse>> GetAdminStatisticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminStatisticsAsync(templateId, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateTrendPointResponse>>> GetAdminTrendAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminTrendAsync(templateId, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateRecentGenerationResponse>>> GetAdminRecentGenerationsAsync(Guid templateId, int take, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminRecentGenerationsAsync(templateId, take, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> GetAdminTestHistoryAsync(Guid templateId, int take, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminTestHistoryAsync(templateId, take, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>> GetAdminFailureBreakdownAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminFailureBreakdownAsync(templateId, cancellationToken);
    }

    public async Task<Result<AdminTemplateEventAnalyticsResponse>> GetAdminEventAnalyticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminEventAnalyticsAsync(templateId, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFeedbackItemResponse>>> GetAdminFeedbackAsync(Guid templateId, AdminTemplateFeedbackQuery query, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminFeedbackAsync(templateId, query, cancellationToken);
    }

    public async Task<Result<AdminTemplatesAnalyticsOverviewResponse>> GetAdminTemplatesAnalyticsAsync(AdminTemplatesAnalyticsQuery query, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.GetAdminTemplatesAnalyticsAsync(query, cancellationToken);
    }

    public async Task<Result> RecordAnalyticsEventAsync(RecordTemplateAnalyticsEventCommand command, CancellationToken cancellationToken)
    {
        return await _templateAdminAnalyticsService.RecordAnalyticsEventAsync(command, cancellationToken);
    }
}
