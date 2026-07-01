using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface ITemplateAiProviderHealthService
{
    Task<Result> EnsureCanAcceptGenerationAsync(
        string mediaType,
        string tier,
        CancellationToken cancellationToken);
}
