using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateAdminService
{
    Task<Result<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAdminCategoriesAsync(bool includeArchived, CancellationToken cancellationToken);

    Task<Result<AdminTemplateCategoryDiagnosticsResponse>> GetAdminCategoryDiagnosticsAsync(CancellationToken cancellationToken);

    Task<Result<AdminTemplateCategoryListItemResponse>> CreateCategoryAsync(CreateTemplateCategoryCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateCategoryListItemResponse>> UpdateCategoryAsync(UpdateTemplateCategoryCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateCategoryListItemResponse>> ChangeCategoryArchiveStateAsync(ChangeTemplateCategoryArchiveStateCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteCategoryAsync(Guid categoryId, CancellationToken cancellationToken);

    Task<Result<AdminTemplateCatalogPageResponse>> ListAdminAsync(
        AdminTemplateCatalogQuery query,
        CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<AdminTemplateStatisticsResponse>> GetAdminStatisticsAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateTrendPointResponse>>> GetAdminTrendAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateRecentGenerationResponse>>> GetAdminRecentGenerationsAsync(Guid templateId, int take, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<TemplateGenerationResponse>>> GetAdminTestHistoryAsync(Guid templateId, int take, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>> GetAdminFailureBreakdownAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<AdminTemplateEventAnalyticsResponse>> GetAdminEventAnalyticsAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateFeedbackItemResponse>>> GetAdminFeedbackAsync(Guid templateId, AdminTemplateFeedbackQuery query, CancellationToken cancellationToken);

    Task<Result<AdminModerationQueuePageResponse>> GetAdminModerationQueueAsync(AdminModerationQueueQuery query, CancellationToken cancellationToken);

    Task<Result<AdminModerationQueueItemResponse>> DecideAdminModerationItemAsync(AdminModerationDecisionCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplatesAnalyticsOverviewResponse>> GetAdminTemplatesAnalyticsAsync(AdminTemplatesAnalyticsQuery query, CancellationToken cancellationToken);

    Task<Result<AdminTemplateGenerationDashboardMetricsResponse>> GetAdminGenerationDashboardMetricsAsync(CancellationToken cancellationToken);

    Task<Result<AdminTemplateGenerationListPageResponse>> ListAdminGenerationsAsync(AdminTemplateGenerationsQuery query, CancellationToken cancellationToken);

    Task<Result<AdminWatermarkSettingsResponse>> GetAdminWatermarkSettingsAsync(CancellationToken cancellationToken);

    Task<Result<AdminWatermarkSettingsResponse>> UpdateAdminWatermarkSettingsAsync(UpdateAdminWatermarkSettingsCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDayScheduleResponse>> ListAdminTemplateOfTheDayScheduleAsync(int? skip, int? take, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDaySettingsResponse>> GetAdminTemplateOfTheDaySettingsAsync(CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDaySettingsResponse>> UpdateAdminTemplateOfTheDaySettingsAsync(UpdateTemplateOfTheDaySettingsCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDayResponse?>> GetAdminCurrentTemplateOfTheDayAsync(DateOnly? date, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDayResponse>> CreateTemplateOfTheDayAsync(CreateTemplateOfTheDayCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDayResponse>> UpdateTemplateOfTheDayAsync(UpdateTemplateOfTheDayCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteTemplateOfTheDayAsync(Guid id, CancellationToken cancellationToken);

    Task<Result<AdminTemplateOfTheDayResponse>> AutoPickTemplateOfTheDayAsync(AutoPickTemplateOfTheDayCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> ChangeStatusAsync(ChangeTemplateStatusCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken);
}
