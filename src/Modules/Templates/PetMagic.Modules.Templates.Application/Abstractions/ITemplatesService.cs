using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplatesService
{
    Task<Result<IReadOnlyList<AdminTemplateListItemResponse>>> ListAdminAsync(TemplateType? type, TemplateStatus? status, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<AdminTemplateStatisticsResponse>> GetAdminStatisticsAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateTrendPointResponse>>> GetAdminTrendAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateRecentGenerationResponse>>> GetAdminRecentGenerationsAsync(Guid templateId, int take, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>> GetAdminFailureBreakdownAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<AdminTemplateEventAnalyticsResponse>> GetAdminEventAnalyticsAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result> RecordAnalyticsEventAsync(RecordTemplateAnalyticsEventCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken);

    Task<Result<AdminTemplateResponse>> ChangeStatusAsync(ChangeTemplateStatusCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken);

    Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken);
}
