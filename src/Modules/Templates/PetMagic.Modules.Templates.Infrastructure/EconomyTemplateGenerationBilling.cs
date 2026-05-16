using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class EconomyTemplateGenerationBilling(IEconomyService economyService) : ITemplateGenerationBilling
{
    private const string GenerationRefundSource = "generation_refund";

    public async Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
    {
        if (tokenCost <= 0)
        {
            return Result.Success();
        }

        var result = await economyService.SpendAsync(
            new SpendBalanceCommand(userId, tokenCost, CreateReason(generationId)),
            cancellationToken);

        return result.IsSuccess ? Result.Success() : Result.Failure(result.Error);
    }

    public async Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
    {
        if (tokenCost <= 0)
        {
            return Result.Success();
        }

        var result = await economyService.CreditAsync(
            new CreditBalanceCommand(userId, tokenCost, GenerationRefundSource, CreateReason(generationId)),
            cancellationToken);

        return result.IsSuccess ? Result.Success() : Result.Failure(result.Error);
    }

    private static string CreateReason(Guid generationId)
    {
        return $"template_generation:{generationId:N}";
    }
}
