using System.Data;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<OffsetPagedResponse<WalletLedgerItemResponse>>> GetAdminWalletLedgerAsync(
        int skip,
        int take,
        string? source,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedSource = string.IsNullOrWhiteSpace(source)
            ? null
            : source.Trim().ToLowerInvariant();

        var query = dbContext.WalletLedgerEntries
            .AsNoTracking()
            .AsQueryable();

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        if (!string.IsNullOrWhiteSpace(normalizedSource))
        {
            query = query.Where(x => x.Source == normalizedSource);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new WalletLedgerItemResponse(
                x.Id,
                x.UserId,
                x.Delta,
                x.BalanceAfter,
                x.Source,
                x.Reason,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetAdminPurchaseHistoryAsync(
        int skip,
        int take,
        string? status,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();

        var query = dbContext.PurchaseOrders
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        var items = await query
            .Join(
                dbContext.CurrencyPacks.AsNoTracking(),
                order => order.PackId,
                pack => pack.Id,
                (order, pack) => new { order, pack })
            .OrderByDescending(x => x.order.CreatedAtUtc)
            .ThenByDescending(x => x.order.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new PurchaseHistoryItemResponse(
                x.order.Id,
                x.order.UserId,
                x.order.PackId,
                x.pack.Code,
                x.pack.DisplayName,
                x.order.PaymentProvider,
                x.order.Status,
                x.order.PriceAmount,
                x.order.CurrencyCode,
                x.order.SparkToGrant,
                x.order.ExternalPaymentId,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<OffsetPagedResponse<AdminUserSubscriptionResponse>>> GetAdminSubscriptionsAsync(
        int skip,
        int take,
        string? status,
        string? provider,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();
        var normalizedProvider = string.IsNullOrWhiteSpace(provider)
            ? null
            : provider.Trim().ToLowerInvariant();

        var query = dbContext.UserSubscriptions
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(normalizedProvider))
        {
            query = query.Where(x => x.Provider == normalizedProvider);
        }

        var items = await query
            .GroupJoin(
                dbContext.SubscriptionPlans.AsNoTracking(),
                subscription => subscription.PlanId,
                plan => plan.Id,
                (subscription, plans) => new { subscription, plans })
            .SelectMany(
                pair => pair.plans.DefaultIfEmpty(),
                (pair, plan) => new AdminUserSubscriptionResponse(
                    pair.subscription.Id,
                    pair.subscription.UserId,
                    pair.subscription.Provider,
                    pair.subscription.PurchaseChannel,
                    pair.subscription.Region,
                    pair.subscription.PlanId,
                    plan != null ? plan.Name : null,
                    pair.subscription.Status,
                    pair.subscription.CurrentPeriodStartUtc,
                    pair.subscription.CurrentPeriodEndUtc,
                    pair.subscription.CancelAtPeriodEnd,
                    pair.subscription.MonthlyTokenLimit,
                    pair.subscription.MonthlyTokensGranted,
                    pair.subscription.LastTokenGrantAtUtc,
                    pair.subscription.CreatedAtUtc,
                    pair.subscription.UpdatedAtUtc))
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.SubscriptionId)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<IReadOnlyList<AdminCurrencyPackResponse>>> ListAdminCurrencyPacksAsync(CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.ListAdminCurrencyPacksAsync(cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminSubscriptionPlanResponse>>> ListAdminSubscriptionPlansAsync(CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.ListAdminSubscriptionPlansAsync(cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>> ListAdminPaymentProviderConfigurationsAsync(CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.ListAdminPaymentProviderConfigurationsAsync(cancellationToken);
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> CreatePaymentProviderConfigurationAsync(
        CreatePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.CreatePaymentProviderConfigurationAsync(command, cancellationToken);
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> ClonePaymentProviderConfigurationAsync(
        ClonePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.ClonePaymentProviderConfigurationAsync(command, cancellationToken);
    }

    public async Task<Result> DeletePaymentProviderConfigurationAsync(
        DeletePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.DeletePaymentProviderConfigurationAsync(command, cancellationToken);
    }

    public async Task<Result<AdminPaymentProviderConfigurationMatchResponse>> TestPaymentProviderConfigurationMatchAsync(
        TestPaymentProviderConfigurationMatchQuery query,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.TestPaymentProviderConfigurationMatchAsync(query, cancellationToken);
    }

    public async Task<Result<AdminCurrencyPackResponse>> UpdateCurrencyPackAsync(
        UpdateCurrencyPackCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.UpdateCurrencyPackAsync(command, cancellationToken);
    }

    public async Task<Result<AdminSubscriptionPlanResponse>> UpdateSubscriptionPlanAsync(
        UpdateSubscriptionPlanCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.UpdateSubscriptionPlanAsync(command, cancellationToken);
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> UpdatePaymentProviderConfigurationAsync(
        UpdatePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminConfigurationService.UpdatePaymentProviderConfigurationAsync(command, cancellationToken);
    }

    public async Task<Result<IReadOnlyList<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.ListAdminRedeemCodesAsync(cancellationToken);
    }

    public async Task<Result<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>> GetAdminRedeemCodeActivationsAsync(
        Guid redeemCodeId,
        int skip,
        int take,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.GetAdminRedeemCodeActivationsAsync(
            redeemCodeId,
            skip,
            take,
            userId,
            cancellationToken);
    }

    public async Task<Result<OffsetPagedResponse<AdminSubscriptionEventResponse>>> GetAdminSubscriptionEventsAsync(
        int skip,
        int take,
        string? provider,
        string? status,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedProvider = string.IsNullOrWhiteSpace(provider)
            ? null
            : provider.Trim().ToLowerInvariant();
        var normalizedStatus = string.IsNullOrWhiteSpace(status)
            ? null
            : status.Trim().ToLowerInvariant();

        var query = dbContext.SubscriptionEventLogs
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedProvider))
        {
            query = query.Where(x => x.Provider == normalizedProvider);
        }

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new AdminSubscriptionEventResponse(
                x.Id,
                x.UserId,
                x.UserSubscriptionId,
                x.Provider,
                x.EventType,
                x.Status,
                x.ExternalEventId,
                x.ExternalSubscriptionId,
                x.CreatedAtUtc,
                x.ProcessedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<AdminRedeemCodeResponse>> CreateRedeemCodeAsync(
        CreateRedeemCodeCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.CreateRedeemCodeAsync(command, cancellationToken);
    }

    public async Task<Result<AdminRedeemCodeResponse>> UpdateRedeemCodeAsync(
        UpdateRedeemCodeCommand command,
        CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.UpdateRedeemCodeAsync(command, cancellationToken);
    }
}
