using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class EconomyTemplateGenerationBilling(IEconomyService economyService) : ITemplateGenerationBilling
{
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
            new CreditBalanceCommand(
                userId,
                tokenCost,
                WalletLedgerSource.GenerationRefund,
                CreateRefundReason(generationId),
                CreateRefundIdempotencyKey(generationId)),
            cancellationToken);

        return result.IsSuccess ? Result.Success() : Result.Failure(result.Error);
    }

    public async Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
    {
        if (creditCost <= 0)
        {
            var wallet = await economyService.GetWalletAsync(userId, isPremium: false, cancellationToken);
            return wallet.IsSuccess
                ? Result.Success(wallet.Value.Balance)
                : Result.Failure<int>(wallet.Error);
        }

        var result = await economyService.SpendAsync(
            new SpendBalanceCommand(
                userId,
                creditCost,
                $"template_watermark_unlock:{generationId:N}",
                WalletLedgerSource.WatermarkUnlock),
            cancellationToken);

        return result.IsSuccess
            ? Result.Success(result.Value.NewBalance)
            : Result.Failure<int>(result.Error);
    }

    private static string CreateReason(Guid generationId)
    {
        return $"template_generation:{generationId:N}";
    }

    private static string CreateRefundReason(Guid generationId)
    {
        return $"generation_refund:{generationId:N}";
    }

    private static string CreateRefundIdempotencyKey(Guid generationId)
    {
        return $"generation_refund:{generationId:N}";
    }
}
