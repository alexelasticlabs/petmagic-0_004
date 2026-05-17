using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationService
{
    Task<Result<TemplateGenerationResponse>> StartAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(Guid templateId, TemplateAssetCommand sourceImageAsset, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken);
}
