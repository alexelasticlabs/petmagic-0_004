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
                x.CreatedAtUtc,
                x.SourceProvider,
                x.SourceProvider == "google_play" || x.SourceProvider == "app_store" ? null : x.SourceTransactionId,
                x.TokenKind,
                x.OperationKind,
                x.TokenBucketId,
                x.BucketDeltasJson,
                x.ExpiresAtUtc))
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
                    (x.pack.Code ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                    (x.pack.DisplayName ?? string.Empty).ToLower().Contains(normalizedSearch));
            }
        }

        var purchaseRows = await joined
            .OrderByDescending(x => x.order.CreatedAtUtc)
            .ThenByDescending(x => x.order.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new
            {
                x.order.Id,
                x.order.UserId,
                x.order.PackId,
                PackCode = x.pack.Code,
                PackDisplayName = x.pack.DisplayName,
                x.order.PaymentProvider,
                x.order.Status,
                x.order.PriceAmount,
                x.order.CurrencyCode,
                x.order.SparkToGrant,
                x.order.ExternalPaymentId,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc
            })
            .ToListAsync(cancellationToken);

        var items = purchaseRows
            .Select(x => new PurchaseHistoryItemResponse(
                x.Id,
                x.UserId,
                x.PackId,
                x.PackCode ?? string.Empty,
                x.PackDisplayName ?? string.Empty,
                x.PaymentProvider ?? string.Empty,
                x.Status ?? string.Empty,
                x.PriceAmount,
                x.CurrencyCode ?? string.Empty,
                x.SparkToGrant,
                null,
                x.CreatedAtUtc,
                x.ConfirmedAtUtc,
                x.PaymentProvider == "stripe"
                    && (x.Status == PurchaseOrderStatus.Succeeded
                        || x.Status == PurchaseOrderStatus.RefundPending)
                    && !string.IsNullOrWhiteSpace(x.ExternalPaymentId),
                "TokenPack",
                x.SparkToGrant,
                ResolvePurchaseRefundStatus(x.Status)))
            .ToList();

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
            || string.IsNullOrWhiteSpace(order.ExternalPaymentId))
        {
            return Result.Failure<PurchaseHistoryItemResponse>(EconomyErrors.PurchaseNotRefundable);
        }
        var externalPaymentId = order.ExternalPaymentId;

        if (string.Equals(order.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)
            || string.Equals(order.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal))
        {
            var refundedPack = await dbContext.CurrencyPacks
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);

            return Result.Success(ToPurchaseHistoryItem(order, refundedPack));
        }

        if (!string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
            && !string.Equals(order.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseHistoryItemResponse>(EconomyErrors.PurchaseNotRefundable);
        }

        var oldStatus = order.Status;
        var preparedRefund = string.Equals(order.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
            ? Result.Success(order)
            : await PreparePurchaseRefundInternalAsync(order, cancellationToken);
        if (preparedRefund.IsFailure)
        {
            return Result.Failure<PurchaseHistoryItemResponse>(preparedRefund.Error);
        }

        order = preparedRefund.Value;
        if (string.Equals(order.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal))
        {
            if (adminAuditLog is not null)
            {
                await adminAuditLog.WriteAsync(
                    new AdminAuditEntry(
                        "admin.payment.refund_manual_review_required",
                        "purchase_order",
                        order.Id.ToString("D"),
                        oldStatus,
                        order.Status,
                        $"Refund blocked before provider call. Wallet balance cannot revoke {order.SparkToGrant} tokens automatically.",
                        order.UserId),
                    cancellationToken);
            }

            var reviewPack = await dbContext.CurrencyPacks
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);

            return Result.Success(ToPurchaseHistoryItem(order, reviewPack));
        }

        var refundResult = await paymentGateway.RefundPaymentAsync(
            new PaymentRefundRequest(
                order.PaymentProvider,
                order.Id,
                externalPaymentId,
                order.PriceAmount,
                order.CurrencyCode,
                NormalizeRefundReason(command.Reason),
                ResolveStripeApiKey()),
            cancellationToken);

        if (refundResult.IsFailure)
        {
            if (adminAuditLog is not null)
            {
                await adminAuditLog.WriteAsync(
                    new AdminAuditEntry(
                        "admin.payment.refund_provider_failed",
                        "purchase_order",
                        order.Id.ToString("D"),
                        oldStatus,
                        order.Status,
                        $"Refund provider call failed after local token revoke reservation. Retry is required.",
                        order.UserId),
                    cancellationToken);
            }

            return Result.Failure<PurchaseHistoryItemResponse>(refundResult.Error);
        }

        var refundSettlement = await ApplyPurchaseRefundInternalAsync(
            order,
            refundResult.Value.ExternalRefundId,
            cancellationToken);
        if (refundSettlement.IsFailure)
        {
            return Result.Failure<PurchaseHistoryItemResponse>(refundSettlement.Error);
        }

        order = refundSettlement.Value;

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    "admin.payment.refunded",
                    "purchase_order",
                    order.Id.ToString("D"),
                    oldStatus,
                    order.Status,
                    $"Refunded {order.PriceAmount} {order.CurrencyCode}. Provider refund recorded. Revoked {order.SparkToGrant} tokens.",
                    order.UserId),
                cancellationToken);
        }

        var pack = await dbContext.CurrencyPacks
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);

        return Result.Success(ToPurchaseHistoryItem(order, pack));
    }

    public async Task<Result<AdminEconomyDashboardMetricsResponse>> GetAdminDashboardMetricsAsync(
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var currentWeekStart = StartOfUtcDay(now.AddDays(-6));
        var previousWeekStart = currentWeekStart.AddDays(-7);
        var nextDayStart = StartOfUtcDay(now).AddDays(1);

        var subscriptionSnapshots = await dbContext.UserSubscriptions
            .AsNoTracking()
            .Select(x => new UserSubscription
            {
                Status = x.Status,
                CurrentPeriodEndUtc = x.CurrentPeriodEndUtc,
                CancelAtPeriodEnd = x.CancelAtPeriodEnd
            })
            .ToListAsync(cancellationToken);
        var activeSubscriptions = subscriptionSnapshots.Count(IsActivePremiumSubscription);
        var renewalStops = subscriptionSnapshots.Count(x => x.CancelAtPeriodEnd && IsActivePremiumSubscription(x));
        var totalWalletCredits = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.Delta > 0)
            .SumAsync(x => (long?)x.Delta, cancellationToken) ?? 0L;
        var totalWalletDebits = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.Delta < 0)
            .SumAsync(x => (long?)(-x.Delta), cancellationToken) ?? 0L;

        var orders = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => (x.ConfirmedAtUtc ?? x.CreatedAtUtc) >= previousWeekStart
                        && (x.ConfirmedAtUtc ?? x.CreatedAtUtc) < nextDayStart)
            .Select(x => new
            {
                x.Status,
                x.PriceAmount,
                x.CurrencyCode,
                OccurredAtUtc = x.ConfirmedAtUtc ?? x.CreatedAtUtc
            })
            .Select(x => new DashboardPurchaseMetric(
                x.Status,
                x.PriceAmount,
                x.CurrencyCode,
                x.OccurredAtUtc))
            .ToListAsync(cancellationToken);

        var currentWeekOrders = orders
            .Where(x => x.OccurredAtUtc >= currentWeekStart)
            .ToList();
        var previousWeekOrders = orders
            .Where(x => x.OccurredAtUtc >= previousWeekStart && x.OccurredAtUtc < currentWeekStart)
            .ToList();
        var currentSucceeded = currentWeekOrders
            .Where(x => x.Status == PurchaseOrderStatus.Succeeded)
            .ToList();
        var previousSucceeded = previousWeekOrders
            .Where(x => x.Status == PurchaseOrderStatus.Succeeded)
            .ToList();
        var currencyCode = ResolveDashboardCurrency(currentSucceeded, previousSucceeded);
        var revenueSeries = Enumerable.Range(0, 7)
            .Select(offset =>
            {
                var date = DateOnly.FromDateTime(currentWeekStart.AddDays(offset));
                var amount = currentSucceeded
                    .Where(x => DateOnly.FromDateTime(x.OccurredAtUtc) == date
                                && NormalizeCurrencyCode(x.CurrencyCode) == currencyCode)
                    .Sum(x => x.PriceAmount);

                return new AdminEconomyDashboardRevenuePointResponse(date, amount);
            })
            .ToArray();

        return Result.Success(new AdminEconomyDashboardMetricsResponse(
            currentWeekOrders.Count,
            previousWeekOrders.Count,
            currentSucceeded.Count,
            previousSucceeded.Count,
            currentWeekOrders.Count(x => x.Status == PurchaseOrderStatus.Failed),
            previousWeekOrders.Count(x => x.Status == PurchaseOrderStatus.Failed),
            currentSucceeded
                .Where(x => NormalizeCurrencyCode(x.CurrencyCode) == currencyCode)
                .Sum(x => x.PriceAmount),
            previousSucceeded
                .Where(x => NormalizeCurrencyCode(x.CurrencyCode) == currencyCode)
                .Sum(x => x.PriceAmount),
            totalWalletCredits,
            totalWalletDebits,
            activeSubscriptions,
            renewalStops,
            currencyCode,
            revenueSeries));
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
        var normalizedStatus = NormalizeSubscriptionStatusFilter(status);
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
                    (x.subscription.PlanId ?? string.Empty).ToLower().Contains(normalizedSearch) ||
                    (x.plan != null && (x.plan.Name ?? string.Empty).ToLower().Contains(normalizedSearch)));
            }
        }

        var items = await joined
            .OrderByDescending(x => x.subscription.UpdatedAtUtc)
            .ThenByDescending(x => x.subscription.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new AdminUserSubscriptionResponse(
            x.subscription.Id,
            x.subscription.UserId,
            x.subscription.Provider ?? string.Empty,
            x.subscription.PurchaseChannel ?? string.Empty,
            x.subscription.Region ?? string.Empty,
            x.subscription.PlanId ?? string.Empty,
            x.plan != null ? x.plan.Name : null,
            x.subscription.Status ?? string.Empty,
            x.subscription.CurrentPeriodStartUtc,
            x.subscription.CurrentPeriodEndUtc,
            x.subscription.CancelAtPeriodEnd,
            x.subscription.MonthlyTokenLimit,
            x.subscription.MonthlyTokensGranted,
            x.subscription.LastTokenGrantAtUtc,
            x.subscription.CreatedAtUtc,
            x.subscription.UpdatedAtUtc,
            x.subscription.ProductId,
            !x.subscription.CancelAtPeriodEnd,
            x.subscription.CancelledAtUtc,
            x.subscription.ExpiredAtUtc,
            x.subscription.LastValidatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    private static string? NormalizeSubscriptionStatusFilter(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
        {
            return null;
        }

        return status.Trim().ToLowerInvariant() switch
        {
            "active" => "Active",
            "trialing" => "Trialing",
            "graceperiod" or "grace_period" or "grace-period" => "GracePeriod",
            "pastdue" or "past_due" or "past-due" => "PastDue",
            "canceled" => "Canceled",
            "expired" => "Expired",
            "refunded" => "Refunded",
            "revoked" => "Revoked",
            "pending" => "Pending",
            "processed" => "Processed",
            "failed" => "Failed",
            var normalized => normalized,
        };
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

    private static DateTime StartOfUtcDay(DateTime value)
    {
        return new DateTime(value.Year, value.Month, value.Day, 0, 0, 0, DateTimeKind.Utc);
    }

    private static string NormalizeCurrencyCode(string? value)
    {
        var normalized = string.IsNullOrWhiteSpace(value)
            ? "USD"
            : value.Trim().ToUpperInvariant();

        return normalized.Length == 3 ? normalized : "USD";
    }

    private static string ResolveDashboardCurrency(
        IReadOnlyList<DashboardPurchaseMetric> currentSucceeded,
        IReadOnlyList<DashboardPurchaseMetric> previousSucceeded)
    {
        return currentSucceeded
            .Concat(previousSucceeded)
            .GroupBy(x => NormalizeCurrencyCode(x.CurrencyCode))
            .OrderByDescending(group => group.Sum(x => x.PriceAmount))
            .ThenBy(group => group.Key)
            .Select(group => group.Key)
            .FirstOrDefault() ?? "USD";
    }

    private sealed record DashboardPurchaseMetric(
        string Status,
        decimal PriceAmount,
        string CurrencyCode,
        DateTime OccurredAtUtc);

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
            false,
            "TokenPack",
            order.SparkToGrant,
            ResolvePurchaseRefundStatus(order.Status));
    }

    private static string ResolvePurchaseRefundStatus(string? status)
    {
        return status switch
        {
            PurchaseOrderStatus.Refunded => "refunded",
            PurchaseOrderStatus.RefundPending => "pending_provider",
            PurchaseOrderStatus.RefundRequiresManualReview => "requires_manual_review",
            _ => "none"
        };
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

    public async Task<Result<OffsetPagedResponse<AdminRedeemCodeResponse>>> ListAdminRedeemCodesAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.ListAdminRedeemCodesAsync(query, cancellationToken);
    }

    public async Task<Result<AdminRedeemCodeMetricsResponse>> GetAdminRedeemCodeMetricsAsync(
        AdminRedeemCodeListQuery query,
        CancellationToken cancellationToken)
    {
        return await _adminRedeemCodeService.GetAdminRedeemCodeMetricsAsync(query, cancellationToken);
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
        var normalizedStatus = NormalizeSubscriptionStatusFilter(status);

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
