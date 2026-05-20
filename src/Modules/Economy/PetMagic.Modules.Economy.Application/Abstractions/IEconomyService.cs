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

    Task<Result<RedeemCodeAppliedResponse>> ApplyRedeemCodeAsync(ApplyRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(CancellationToken cancellationToken);

    Task<Result<PremiumStatusResponse>> GetPremiumStatusAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PaymentMethodResponse>>> ListPaymentMethodsAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<PaymentMethodSetupResponse>> CreatePaymentMethodSetupAsync(CreatePaymentMethodSetupCommand command, CancellationToken cancellationToken);

    Task<Result> RemovePaymentMethodAsync(RemovePaymentMethodCommand command, CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetWalletLedgerAsync(Guid userId, int skip, int take, CancellationToken cancellationToken);

    Task<Result<PurchaseCheckoutResponse>> CreatePackPurchaseAsync(CreatePackPurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<PremiumCheckoutResponse>> CreatePremiumCheckoutAsync(CreatePremiumCheckoutCommand command, CancellationToken cancellationToken);

    Task<Result<BillingPortalSessionResponse>> CreatePremiumBillingPortalAsync(CreatePremiumBillingPortalCommand command, CancellationToken cancellationToken);

    Task<Result<PremiumStoreVerificationResponse>> VerifyPremiumStorePurchaseAsync(VerifyPremiumStorePurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetPurchaseHistoryAsync(Guid userId, int skip, int take, CancellationToken cancellationToken);

    Task<Result<PurchaseOrderResponse>> ConfirmPackPurchaseAsync(ConfirmPackPurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<PurchaseOrderResponse>> GetPurchaseAsync(Guid userId, Guid orderId, CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetAdminWalletLedgerAsync(int skip, int take, string? source, Guid? userId, CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetAdminPurchaseHistoryAsync(int skip, int take, string? status, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminCurrencyPackResponse>>> ListAdminCurrencyPacksAsync(CancellationToken cancellationToken);

    Task<Result<AdminCurrencyPackResponse>> UpdateCurrencyPackAsync(UpdateCurrencyPackCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> CreateRedeemCodeAsync(CreateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> UpdateRedeemCodeAsync(UpdateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken);
}
