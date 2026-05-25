using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationService
{
    Task<Result<TemplateGenerationResponse>> StartAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(Guid templateId, TemplateAssetCommand sourceImageAsset, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationUnreadCountResponse>> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> MarkReadAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result> RecordFeedbackAsync(RecordTemplateGenerationFeedbackCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken);
}

public interface ITemplatePushTokenService
{
    Task<Result> RegisterAsync(RegisterTemplatePushTokenCommand command, CancellationToken cancellationToken);

    Task<Result> UnregisterAsync(UnregisterTemplatePushTokenCommand command, CancellationToken cancellationToken);
}
