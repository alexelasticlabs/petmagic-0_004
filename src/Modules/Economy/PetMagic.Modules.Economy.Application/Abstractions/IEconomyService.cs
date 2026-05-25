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

    Task<Result<RewardsSummaryResponse>> GetRewardsSummaryAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<ReferralCodeAppliedResponse>> ApplyReferralCodeAsync(ApplyReferralCodeCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken);

    Task<Result<WalletCheckoutConfigResponse>> GetWalletCheckoutConfigAsync(GetWalletCheckoutConfigQuery query, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(CancellationToken cancellationToken);

    Task<Result<PaywallConfigResponse>> GetPaywallConfigAsync(GetPaywallConfigQuery query, CancellationToken cancellationToken);

    Task<Result<PremiumStatusResponse>> GetPremiumStatusAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<SubscriptionSummaryResponse>> GetSubscriptionSummaryAsync(Guid userId, CancellationToken cancellationToken);

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

    Task<Result<OffsetPagedResponse<AdminUserSubscriptionResponse>>> GetAdminSubscriptionsAsync(int skip, int take, string? status, string? provider, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminCurrencyPackResponse>>> ListAdminCurrencyPacksAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminSubscriptionPlanResponse>>> ListAdminSubscriptionPlansAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>> ListAdminPaymentProviderConfigurationsAsync(CancellationToken cancellationToken);

    Task<Result<AdminPaymentProviderConfigurationResponse>> CreatePaymentProviderConfigurationAsync(CreatePaymentProviderConfigurationCommand command, CancellationToken cancellationToken);

    Task<Result<AdminPaymentProviderConfigurationResponse>> ClonePaymentProviderConfigurationAsync(ClonePaymentProviderConfigurationCommand command, CancellationToken cancellationToken);

    Task<Result> DeletePaymentProviderConfigurationAsync(DeletePaymentProviderConfigurationCommand command, CancellationToken cancellationToken);

    Task<Result<AdminPaymentProviderConfigurationMatchResponse>> TestPaymentProviderConfigurationMatchAsync(TestPaymentProviderConfigurationMatchQuery query, CancellationToken cancellationToken);

    Task<Result<AdminCurrencyPackResponse>> UpdateCurrencyPackAsync(UpdateCurrencyPackCommand command, CancellationToken cancellationToken);

    Task<Result<AdminSubscriptionPlanResponse>> UpdateSubscriptionPlanAsync(UpdateSubscriptionPlanCommand command, CancellationToken cancellationToken);

    Task<Result<AdminPaymentProviderConfigurationResponse>> UpdatePaymentProviderConfigurationAsync(UpdatePaymentProviderConfigurationCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>> GetAdminRedeemCodeActivationsAsync(
        Guid redeemCodeId,
        int skip,
        int take,
        Guid? userId,
        CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<AdminSubscriptionEventResponse>>> GetAdminSubscriptionEventsAsync(int skip, int take, string? provider, string? status, CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> CreateRedeemCodeAsync(CreateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> UpdateRedeemCodeAsync(UpdateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken);

    Task<Result<StoreWebhookResultResponse>> HandleAppStoreServerNotificationAsync(AppStoreServerNotificationCommand command, CancellationToken cancellationToken);

    Task<Result<StoreWebhookResultResponse>> HandleGooglePlayDeveloperNotificationAsync(GooglePlayDeveloperNotificationCommand command, CancellationToken cancellationToken);
}

public interface IStoreWebhookSecurityValidator
{
    Result ValidateAppStoreSignedPayload(string signedPayload);

    Task<Result> ValidateGooglePlayPushAsync(string? authorizationHeader, CancellationToken cancellationToken);
}
