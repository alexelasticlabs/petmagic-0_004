using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IEconomyService
{
    Task<Result<WalletStateResponse>> GetWalletAsync(Guid userId, bool isPremium, CancellationToken cancellationToken);

    Task<Result<WalletOperationResponse>> ClaimWeeklyGrantAsync(ClaimWeeklyGrantCommand command, CancellationToken cancellationToken);

    Task<Result<WalletOperationResponse>> ClaimAdRewardAsync(ClaimAdRewardCommand command, CancellationToken cancellationToken);

    Task<Result<WalletOperationResponse>> SpendAsync(SpendBalanceCommand command, CancellationToken cancellationToken);

    Task<Result<WalletOperationResponse>> CreditAsync(CreditBalanceCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken);

    Task<Result<PurchaseCheckoutResponse>> CreatePackPurchaseAsync(CreatePackPurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<PurchaseOrderResponse>> ConfirmPackPurchaseAsync(ConfirmPackPurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<PurchaseOrderResponse>> GetPurchaseAsync(Guid userId, Guid orderId, CancellationToken cancellationToken);

    Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken);
}
