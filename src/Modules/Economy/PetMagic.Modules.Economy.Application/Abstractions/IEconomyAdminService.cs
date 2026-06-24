using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IEconomyAdminService
{
    Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetAdminWalletLedgerAsync(int skip, int take, string? source, Guid? userId, CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetAdminPurchaseHistoryAsync(
        int skip,
        int take,
        string? status,
        string? provider,
        string? search,
        Guid? userId,
        CancellationToken cancellationToken);

    Task<Result<PurchaseHistoryItemResponse>> RefundAdminPurchaseAsync(AdminRefundPurchaseCommand command, CancellationToken cancellationToken);

    Task<Result<AdminEconomyDashboardMetricsResponse>> GetAdminDashboardMetricsAsync(CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<AdminUserSubscriptionResponse>>> GetAdminSubscriptionsAsync(int skip, int take, string? status, string? provider, string? search, CancellationToken cancellationToken);

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

    Task<Result<OffsetPagedResponse<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeMetricsResponse>> GetAdminRedeemCodeMetricsAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>> GetAdminRedeemCodeActivationsAsync(
        Guid redeemCodeId,
        int skip,
        int take,
        Guid? userId,
        CancellationToken cancellationToken);

    Task<Result<OffsetPagedResponse<AdminSubscriptionEventResponse>>> GetAdminSubscriptionEventsAsync(int skip, int take, string? provider, string? status, CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> CreateRedeemCodeAsync(CreateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<AdminRedeemCodeResponse>> UpdateRedeemCodeAsync(UpdateRedeemCodeCommand command, CancellationToken cancellationToken);

    Task<Result<SubscriptionSummaryResponse>> AdminRevokePremiumSubscriptionAsync(AdminRevokePremiumSubscriptionCommand command, CancellationToken cancellationToken);
}
