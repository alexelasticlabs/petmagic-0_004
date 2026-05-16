using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationService
{
    Task<Result<TemplateGenerationResponse>> StartVideoAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);
}
