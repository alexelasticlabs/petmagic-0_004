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
    public async Task<Result<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAdminCategoriesAsync(bool includeArchived, CancellationToken cancellationToken)
    {
        return await _templateCategoryAdminService.ListAdminCategoriesAsync(includeArchived, cancellationToken);
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

    public async Task<Result<IReadOnlyList<AdminTemplateListItemResponse>>> ListAdminAsync(TemplateType? type, TemplateStatus? status, CancellationToken cancellationToken)
    {
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => !status.HasValue || x.Status == status.Value)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateListItemResponse>>(items.Select(MapAdminListItem).ToArray());
    }

    public async Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        return template is null
            ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapAdminResponse(template));
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

