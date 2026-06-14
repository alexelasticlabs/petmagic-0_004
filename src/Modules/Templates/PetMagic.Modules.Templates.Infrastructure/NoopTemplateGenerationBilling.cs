using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class NoopTemplateGenerationBilling : ITemplateGenerationBilling
{
    public Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success());
    }

    public Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success());
    }

    public Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(0));
    }
}
