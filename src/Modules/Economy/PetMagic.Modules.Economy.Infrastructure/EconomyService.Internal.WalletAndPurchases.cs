using System.Data;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private WalletOperationResponse ApplyWalletDelta(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
    {
        return ApplyWalletDelta(wallet, delta, source, reason, now, out _, sourceProvider, sourceTransactionId);
    }

    private WalletOperationResponse ApplyWalletDelta(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        out Guid ledgerEntryId,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
    {
        ledgerEntryId = Guid.NewGuid();
        wallet.Balance += delta;
        wallet.UpdatedAtUtc = now;

        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = ledgerEntryId,
            UserId = wallet.UserId,
            Delta = delta,
            BalanceAfter = wallet.Balance,
            Source = source,
            Reason = reason,
            SourceProvider = string.IsNullOrWhiteSpace(sourceProvider) ? null : sourceProvider.Trim(),
            SourceTransactionId = string.IsNullOrWhiteSpace(sourceTransactionId) ? null : sourceTransactionId.Trim(),
            CreatedAtUtc = now
        });

        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);
        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletOperationResponse(
            wallet.UserId,
            delta,
            wallet.Balance,
            source,
            now,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday);
    }

    private WalletStateResponse ToWalletState(
        Wallet wallet,
        bool isPremium,
        DateTime? nextPremiumWeeklyGrantAtUtc = null)
    {
        var nextWeeklyGrantAtUtc = nextPremiumWeeklyGrantAtUtc ?? wallet.LastWeeklyGrantAtUtc?.AddDays(7);

        if (wallet.AdRewardWindowStartedAtUtc is null || wallet.AdRewardWindowStartedAtUtc.Value.Date != DateTime.UtcNow.Date)
        {
            return new WalletStateResponse(
                wallet.UserId,
                wallet.Balance,
                nextWeeklyGrantAtUtc,
                options.Value.AdRewardDailyLimit,
                isPremium,
                wallet.UpdatedAtUtc);
        }

        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletStateResponse(
            wallet.UserId,
            wallet.Balance,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday,
            isPremium,
            wallet.UpdatedAtUtc);
    }

    private async Task<Result<PurchaseOrder>> ConfirmPurchaseInternalAsync(PurchaseOrder order, CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational()
            && (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
                || !string.Equals(order.Status, PurchaseOrderStatus.Pending, StringComparison.Ordinal)))
        {
            LogPaymentFailed(order, EconomyErrors.PurchaseAlreadyProcessed, "purchase.confirm");
            return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
        }

        var now = DateTime.UtcNow;
        Wallet wallet;
        if (dbContext.Database.IsRelational())
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
            var claimedRows = await dbContext.PurchaseOrders
                .Where(x => x.Id == order.Id && x.Status == PurchaseOrderStatus.Pending)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(x => x.Status, PurchaseOrderStatus.Succeeded)
                        .SetProperty(x => x.ConfirmedAtUtc, now)
                        .SetProperty(x => x.ExternalPaymentId, order.ExternalPaymentId),
                    cancellationToken);

            if (claimedRows == 0)
            {
                var existingOrder = await dbContext.PurchaseOrders
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == order.Id, cancellationToken);

                if (existingOrder is not null
                    && string.Equals(existingOrder.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
                {
                    LogPaymentFailed(existingOrder, EconomyErrors.PurchaseAlreadyProcessed, "purchase.confirm");
                    return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
                }

                LogPaymentFailed(order, EconomyErrors.PurchaseAlreadyProcessed, "purchase.confirm");
                return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
            }

            dbContext.ChangeTracker.Clear();
            order = await dbContext.PurchaseOrders.FirstAsync(x => x.Id == order.Id, cancellationToken);
            wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            ApplyWalletDelta(
                wallet,
                order.SparkToGrant,
                WalletLedgerSource.PackPurchase,
                $"purchase:{order.Id:D}",
                now,
                order.PaymentProvider,
                order.ExternalPaymentId);
            await SettlePendingReferralBonusAsync(order.UserId, $"purchase:{order.Id:D}", now, cancellationToken);

            wallet.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        else
        {
            wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            ApplyWalletDelta(
                wallet,
                order.SparkToGrant,
                WalletLedgerSource.PackPurchase,
                $"purchase:{order.Id:D}",
                now,
                order.PaymentProvider,
                order.ExternalPaymentId);
            await SettlePendingReferralBonusAsync(order.UserId, $"purchase:{order.Id:D}", now, cancellationToken);

            order.Status = PurchaseOrderStatus.Succeeded;
            order.ConfirmedAtUtc = now;
            wallet.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await _pushNotificationSender.NotifyWalletUpdateAsync(
            order.UserId,
            new WalletPushNotification(
                Status: "succeeded",
                OrderId: order.Id,
                SparkDelta: order.SparkToGrant),
            cancellationToken);
        LogPaymentSucceeded(order, "purchase.confirm");
        return Result.Success(order);
    }

    private async Task<Result<PurchaseOrder>> ApplyPurchaseRefundInternalAsync(
        PurchaseOrder order,
        string externalRefundId,
        CancellationToken cancellationToken)
    {
        var normalizedExternalRefundId = externalRefundId.Trim();
        if (string.IsNullOrWhiteSpace(normalizedExternalRefundId))
        {
            return Result.Failure<PurchaseOrder>(EconomyErrors.PaymentGatewayFailed);
        }

        if (!dbContext.Database.IsRelational()
            && string.Equals(order.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal))
        {
            return Result.Success(order);
        }

        var now = DateTime.UtcNow;
        if (dbContext.Database.IsRelational())
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
            var claimedRows = await dbContext.PurchaseOrders
                .Where(x => x.Id == order.Id && x.Status == PurchaseOrderStatus.Succeeded)
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(x => x.Status, PurchaseOrderStatus.Refunded),
                    cancellationToken);

            if (claimedRows == 0)
            {
                var existingOrder = await dbContext.PurchaseOrders
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == order.Id, cancellationToken);

                if (existingOrder is not null
                    && string.Equals(existingOrder.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal))
                {
                    await transaction.CommitAsync(cancellationToken);
                    return Result.Success(existingOrder);
                }

                return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseNotRefundable);
            }

            dbContext.ChangeTracker.Clear();
            order = await dbContext.PurchaseOrders.FirstAsync(x => x.Id == order.Id, cancellationToken);
            var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            // Refunds must revoke the previously granted balance even if that drives
            // the wallet below zero; otherwise a user can keep spent tokens after a refund.
            ApplyWalletDelta(
                wallet,
                -order.SparkToGrant,
                WalletLedgerSource.PurchaseRefund,
                $"purchase_refund:{order.Id:D}",
                now,
                order.PaymentProvider,
                normalizedExternalRefundId);
            wallet.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Result.Success(order);
        }

        var localWallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        ApplyWalletDelta(
            localWallet,
            -order.SparkToGrant,
            WalletLedgerSource.PurchaseRefund,
            $"purchase_refund:{order.Id:D}",
            now,
            order.PaymentProvider,
            normalizedExternalRefundId);
        order.Status = PurchaseOrderStatus.Refunded;
        localWallet.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(order);
    }

    private async Task<Result<PurchaseOrder>> ConfirmStorePurchaseInternalAsync(
        PurchaseOrder order,
        string externalPaymentId,
        CancellationToken cancellationToken)
    {
        var normalizedExternalPaymentId = externalPaymentId.Trim();
        if (string.IsNullOrWhiteSpace(normalizedExternalPaymentId))
        {
            return Result.Failure<PurchaseOrder>(EconomyErrors.StorePurchaseInvalid);
        }

        var existingOrder = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(
                x => x.PaymentProvider == order.PaymentProvider
                    && x.ExternalPaymentId == normalizedExternalPaymentId,
                cancellationToken);

        if (existingOrder is not null && existingOrder.Id != order.Id)
        {
            if (existingOrder.UserId != order.UserId)
            {
                return Result.Failure<PurchaseOrder>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(existingOrder);
        }

        order.ExternalPaymentId = normalizedExternalPaymentId;
        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(order);
        }

        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure
            && string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
        {
            return Result.Success(order);
        }

        return confirmResult;
    }

    private async Task<PurchaseOrder?> ResolveOrderAsync(Guid? orderId, string? externalPaymentId, CancellationToken cancellationToken)
    {
        if (orderId.HasValue)
        {
            var byId = await dbContext.PurchaseOrders.FirstOrDefaultAsync(x => x.Id == orderId.Value, cancellationToken);
            if (byId is not null)
            {
                return byId;
            }
        }

        if (!string.IsNullOrWhiteSpace(externalPaymentId))
        {
            return await dbContext.PurchaseOrders.FirstOrDefaultAsync(
                x => x.PaymentProvider == "stripe" && x.ExternalPaymentId == externalPaymentId,
                cancellationToken);
        }

        return null;
    }

    private static PurchaseCheckoutResponse ToPurchaseCheckoutResponse(PurchaseOrder order)
    {
        return new PurchaseCheckoutResponse(
            order.Id,
            order.UserId,
            order.PaymentProvider,
            order.ExternalPaymentId ?? string.Empty,
            order.CheckoutUrl ?? string.Empty,
            null,
            null,
            null,
            null,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.CreatedAtUtc);
    }

    private static PurchaseOrderResponse ToPurchaseOrderResponse(PurchaseOrder order)
    {
        return new PurchaseOrderResponse(
            order.Id,
            order.UserId,
            order.PackId,
            order.PaymentProvider,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            IsStoreProvider(order.PaymentProvider) ? null : order.ExternalPaymentId,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc);
    }

    private static bool IsStoreProvider(string provider)
    {
        return string.Equals(provider, "google_play", StringComparison.OrdinalIgnoreCase)
            || string.Equals(provider, "app_store", StringComparison.OrdinalIgnoreCase);
    }
}
