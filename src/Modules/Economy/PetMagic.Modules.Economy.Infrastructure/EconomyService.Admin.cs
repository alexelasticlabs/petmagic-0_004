using System.Data;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

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
        string? provider,
        string? search,
        Guid? userId,
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
        var normalizedSearch = string.IsNullOrWhiteSpace(search)
            ? null
            : search.Trim().ToLowerInvariant();

        var query = dbContext.PurchaseOrders
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(normalizedProvider))
        {
            query = query.Where(x => x.PaymentProvider == normalizedProvider);
        }

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        var joined = query.Join(
                dbContext.CurrencyPacks.AsNoTracking(),
                order => order.PackId,
                pack => pack.Id,
                (order, pack) => new { order, pack });

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            if (Guid.TryParse(normalizedSearch, out var parsedId))
            {
                joined = joined.Where(x => x.order.Id == parsedId || x.order.UserId == parsedId || x.order.PackId == parsedId);
            }
            else
            {
                joined = joined.Where(x =>
                    x.pack.Code.ToLower().Contains(normalizedSearch) ||
                    x.pack.DisplayName.ToLower().Contains(normalizedSearch));
            }
        }

        var items = await joined
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
                null,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc,
                x.order.PaymentProvider == "stripe"
                    && x.order.Status == PurchaseOrderStatus.Succeeded
                    && x.order.ExternalPaymentId != null
                    && x.order.ExternalPaymentId != string.Empty))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<PurchaseHistoryItemResponse>> RefundAdminPurchaseAsync(
        AdminRefundPurchaseCommand command,
        CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId, cancellationToken);
        if (order is null)
        {
            return Result.Failure<PurchaseHistoryItemResponse>(EconomyErrors.PurchaseNotFound);
        }

        if (!string.Equals(order.PaymentProvider, "stripe", StringComparison.OrdinalIgnoreCase)
            || !string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
            || string.IsNullOrWhiteSpace(order.ExternalPaymentId))
        {
            return Result.Failure<PurchaseHistoryItemResponse>(EconomyErrors.PurchaseNotRefundable);
        }

        var refundResult = await paymentGateway.RefundPaymentAsync(
            new PaymentRefundRequest(
                order.PaymentProvider,
                order.Id,
                order.ExternalPaymentId,
                order.PriceAmount,
                order.CurrencyCode,
                NormalizeRefundReason(command.Reason),
                ResolveStripeApiKey()),
            cancellationToken);

        if (refundResult.IsFailure)
        {
            return Result.Failure<PurchaseHistoryItemResponse>(refundResult.Error);
        }

        var oldStatus = order.Status;
        order.Status = PurchaseOrderStatus.Refunded;
        await dbContext.SaveChangesAsync(cancellationToken);

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    "admin.payment.refunded",
                    "purchase_order",
                    order.Id.ToString("D"),
                    oldStatus,
                    order.Status,
                    $"Refunded {order.PriceAmount} {order.CurrencyCode}. Provider refund: {refundResult.Value.ExternalRefundId}.",
                    order.UserId),
                cancellationToken);
        }

        var pack = await dbContext.CurrencyPacks
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);

        return Result.Success(ToPurchaseHistoryItem(order, pack));
    }

    public async Task<Result<OffsetPagedResponse<AdminUserSubscriptionResponse>>> GetAdminSubscriptionsAsync(
        int skip,
        int take,
        string? status,
        string? provider,
        string? search,
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
        var normalizedSearch = string.IsNullOrWhiteSpace(search)
            ? null
            : search.Trim().ToLowerInvariant();

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

        var joined = query
            .GroupJoin(
                dbContext.SubscriptionPlans.AsNoTracking(),
                subscription => subscription.PlanId,
                plan => plan.Id,
                (subscription, plans) => new { subscription, plans })
            .SelectMany(
                pair => pair.plans.DefaultIfEmpty(),
                (pair, plan) => new
                {
                    pair.subscription,
                    plan
                });

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            if (Guid.TryParse(normalizedSearch, out var parsedId))
            {
                joined = joined.Where(x => x.subscription.Id == parsedId || x.subscription.UserId == parsedId);
            }
            else
            {
                joined = joined.Where(x =>
                    x.subscription.PlanId.ToLower().Contains(normalizedSearch) ||
                    (x.plan != null && x.plan.Name.ToLower().Contains(normalizedSearch)));
            }
        }

        var items = await joined
            .Select(x => new AdminUserSubscriptionResponse(
                    x.subscription.Id,
                    x.subscription.UserId,
                    x.subscription.Provider,
                    x.subscription.PurchaseChannel,
                    x.subscription.Region,
                    x.subscription.PlanId,
                    x.plan != null ? x.plan.Name : null,
                    x.subscription.Status,
                    x.subscription.CurrentPeriodStartUtc,
                    x.subscription.CurrentPeriodEndUtc,
                    x.subscription.CancelAtPeriodEnd,
                    x.subscription.MonthlyTokenLimit,
                    x.subscription.MonthlyTokensGranted,
                    x.subscription.LastTokenGrantAtUtc,
                    x.subscription.CreatedAtUtc,
                    x.subscription.UpdatedAtUtc))
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.SubscriptionId)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    private static string? NormalizeRefundReason(string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            return null;
        }

        var trimmed = reason.Trim();
        return trimmed.Length <= 240 ? trimmed : trimmed[..240];
    }

    private static PurchaseHistoryItemResponse ToPurchaseHistoryItem(
        PurchaseOrder order,
        CurrencyPack? pack)
    {
        return new PurchaseHistoryItemResponse(
            order.Id,
            order.UserId,
            order.PackId,
            pack?.Code ?? string.Empty,
            pack?.DisplayName ?? string.Empty,
            order.PaymentProvider,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            null,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc,
            false);
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
