using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface ITemplateGenerationBilling
{
    Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken);

    Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken);
}
