using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private const string InternalWalletMutationProvider = "internal";

    private sealed record WalletMutationResult(WalletOperationResponse Response, Guid LedgerEntryId);

    private async Task<Result<WalletMutationResult>> ApplyWalletMutationAsync(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        CancellationToken cancellationToken,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
    {
        if (wallet.UserId == Guid.Empty)
        {
            return Result.Failure<WalletMutationResult>(EconomyErrors.InvalidSubject);
        }

        var normalizedReason = NormalizeWalletMutationReason(reason);
        if (normalizedReason is null)
        {
            return Result.Failure<WalletMutationResult>(EconomyErrors.InvalidWalletReason);
        }

        var normalizedSourceProvider = NormalizeWalletMutationOptionalValue(sourceProvider);
        var normalizedSourceTransactionId = NormalizeWalletMutationOptionalValue(sourceTransactionId);

        var existingMutation = await TryResolveExistingWalletMutationAsync(
            wallet.UserId,
            source,
            normalizedReason,
            normalizedSourceProvider,
            normalizedSourceTransactionId,
            clearChangeTracker: false,
            cancellationToken);
        if (existingMutation is not null)
        {
            return Result.Success(existingMutation);
        }

        if (delta < 0 && wallet.Balance + delta < 0)
        {
            return Result.Failure<WalletMutationResult>(EconomyErrors.InsufficientBalance);
        }

        var mutation = await ApplyWalletDeltaAsync(
            wallet,
            delta,
            source,
            normalizedReason,
            now,
            cancellationToken,
            normalizedSourceProvider,
            normalizedSourceTransactionId);

        return Result.Success(mutation);
    }

    private async Task<WalletMutationResult?> TryResolveExistingWalletMutationAsync(
        Guid userId,
        string source,
        string reason,
        string? sourceProvider,
        string? sourceTransactionId,
        bool clearChangeTracker,
        CancellationToken cancellationToken)
    {
        if (clearChangeTracker)
        {
            dbContext.ChangeTracker.Clear();
        }

        WalletLedgerEntry? existingEntry = null;
        if (!string.IsNullOrWhiteSpace(sourceProvider) && !string.IsNullOrWhiteSpace(sourceTransactionId))
        {
            existingEntry = await dbContext.WalletLedgerEntries
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.SourceProvider == sourceProvider
                        && x.SourceTransactionId == sourceTransactionId,
                    cancellationToken);

            if (existingEntry is not null && existingEntry.UserId != userId)
            {
                return null;
            }
        }

        if (existingEntry is null && IsWalletSourceReasonIdempotent(source))
        {
            existingEntry = await dbContext.WalletLedgerEntries
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == userId
                        && x.Source == source
                        && x.Reason == reason,
                    cancellationToken);
        }

        if (existingEntry is null)
        {
            return null;
        }

        var wallet = await dbContext.Wallets
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        var response = new WalletOperationResponse(
            userId,
            0,
            wallet?.Balance ?? existingEntry.BalanceAfter,
            source,
            existingEntry.CreatedAtUtc,
            wallet?.LastWeeklyGrantAtUtc?.AddDays(7),
            Math.Max(0, options.Value.AdRewardDailyLimit - (wallet?.AdRewardsClaimedInWindow ?? 0)));

        return new WalletMutationResult(response, existingEntry.Id);
    }

    private static bool IsWalletSourceReasonIdempotent(string source)
    {
        return source is WalletLedgerSource.GenerationSpend
            or WalletLedgerSource.GenerationRefund
            or WalletLedgerSource.WatermarkUnlock
            or WalletLedgerSource.PackPurchase
            or WalletLedgerSource.PurchaseRefund
            or WalletLedgerSource.PremiumSubscriptionGrant
            or WalletLedgerSource.PremiumSubscriptionWeeklyGrant
            or WalletLedgerSource.ReferralBonus;
    }

    private static string? NormalizeWalletMutationReason(string reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            return null;
        }

        var normalized = reason.Trim();
        return normalized.Length <= 120 ? normalized : null;
    }

    private static string? NormalizeWalletMutationOptionalValue(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private async Task<WalletMutationResult> ApplyWalletDeltaAsync(
        Wallet wallet,
        int delta,
        string source,
        string reason,
        DateTime now,
        CancellationToken cancellationToken,
        string? sourceProvider = null,
        string? sourceTransactionId = null)
    {
        var ledgerEntryId = Guid.NewGuid();
        var tokenKind = ResolveWalletTokenKind(source, delta);
        var operationKind = ResolveWalletOperationKind(source, delta);
        Guid? tokenBucketId = null;
        DateTime? expiresAtUtc = ResolveTokenBucketExpiryUtc(source, tokenKind, now);
        IReadOnlyList<WalletBucketDelta> bucketDeltas;

        if (delta > 0)
        {
            tokenBucketId = Guid.NewGuid();
            bucketDeltas =
            [
                new WalletBucketDelta(tokenBucketId.Value, tokenKind, delta)
            ];
        }
        else if (delta < 0)
        {
            bucketDeltas = await ConsumeWalletBucketsAsync(wallet, -delta, source, now, cancellationToken);
        }
        else
        {
            bucketDeltas = [];
        }

        wallet.Balance += delta;
        wallet.UpdatedAtUtc = now;

        var ledgerEntry = new WalletLedgerEntry
        {
            Id = ledgerEntryId,
            UserId = wallet.UserId,
            Delta = delta,
            BalanceAfter = wallet.Balance,
            Source = source,
            Reason = reason,
            TokenKind = tokenKind,
            OperationKind = operationKind,
            TokenBucketId = tokenBucketId,
            BucketDeltasJson = bucketDeltas.Count == 0 ? null : JsonSerializer.Serialize(bucketDeltas),
            ExpiresAtUtc = expiresAtUtc,
            SourceProvider = string.IsNullOrWhiteSpace(sourceProvider) ? null : sourceProvider.Trim(),
            SourceTransactionId = string.IsNullOrWhiteSpace(sourceTransactionId) ? null : sourceTransactionId.Trim(),
            CreatedAtUtc = now
        };
        dbContext.WalletLedgerEntries.Add(ledgerEntry);

        if (delta > 0 && tokenBucketId.HasValue)
        {
            dbContext.WalletTokenBuckets.Add(new WalletTokenBucket
            {
                Id = tokenBucketId.Value,
                UserId = wallet.UserId,
                Kind = tokenKind,
                InitialAmount = delta,
                RemainingAmount = delta,
                SourceLedgerEntryId = ledgerEntryId,
                Source = source,
                Reason = reason,
                ExpiresAtUtc = expiresAtUtc,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
        }

        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);
        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        var response = new WalletOperationResponse(
                wallet.UserId,
                delta,
                wallet.Balance,
                source,
                now,
                nextWeeklyGrantAtUtc,
                adRewardsRemainingToday);

        return new WalletMutationResult(response, ledgerEntryId);
    }

    private async Task<IReadOnlyList<WalletBucketDelta>> ConsumeWalletBucketsAsync(
        Wallet wallet,
        int amount,
        string source,
        DateTime now,
        CancellationToken cancellationToken)
    {
        await EnsureLegacyBucketProjectionAsync(wallet, now, cancellationToken);

        var persistedBuckets = await dbContext.WalletTokenBuckets
            .Where(x => x.UserId == wallet.UserId && x.RemainingAmount > 0)
            .ToListAsync(cancellationToken);
        var buckets = persistedBuckets
            .Concat(dbContext.WalletTokenBuckets.Local
                .Where(x => x.UserId == wallet.UserId
                    && x.RemainingAmount > 0
                    && persistedBuckets.All(persisted => persisted.Id != x.Id)))
            .ToList();

        var orderedBuckets = buckets
            .OrderBy(x => ResolveSpendPriority(x.Kind, source))
            .ThenBy(x => x.ExpiresAtUtc ?? DateTime.MaxValue)
            .ThenBy(x => x.CreatedAtUtc)
            .ThenBy(x => x.Id)
            .ToList();

        var remaining = amount;
        var deltas = new List<WalletBucketDelta>();
        foreach (var bucket in orderedBuckets)
        {
            if (remaining <= 0)
            {
                break;
            }

            var consumed = Math.Min(bucket.RemainingAmount, remaining);
            bucket.RemainingAmount -= consumed;
            bucket.UpdatedAtUtc = now;
            remaining -= consumed;
            deltas.Add(new WalletBucketDelta(bucket.Id, bucket.Kind, -consumed));
        }

        if (remaining > 0)
        {
            throw new InvalidOperationException("Wallet bucket projection is lower than wallet balance.");
        }

        return deltas;
    }

    private async Task EnsureLegacyBucketProjectionAsync(
        Wallet wallet,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var bucketTotal = await dbContext.WalletTokenBuckets
            .Where(x => x.UserId == wallet.UserId)
            .SumAsync(x => (int?)x.RemainingAmount, cancellationToken) ?? 0;
        if (bucketTotal >= wallet.Balance)
        {
            return;
        }

        var missing = wallet.Balance - bucketTotal;
        dbContext.WalletTokenBuckets.Add(new WalletTokenBucket
        {
            Id = Guid.NewGuid(),
            UserId = wallet.UserId,
            Kind = WalletTokenKind.Legacy,
            InitialAmount = missing,
            RemainingAmount = missing,
            Source = "legacy_projection",
            Reason = "legacy balance projection",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
    }

    private static string ResolveWalletTokenKind(string source, int delta)
    {
        if (delta < 0)
        {
            return WalletTokenKind.MixedSpend;
        }

        return source switch
        {
            WalletLedgerSource.PackPurchase => WalletTokenKind.Purchased,
            WalletLedgerSource.PremiumSubscriptionGrant or WalletLedgerSource.PremiumSubscriptionWeeklyGrant => WalletTokenKind.SubscriptionAllowance,
            WalletLedgerSource.ReferralBonus => WalletTokenKind.Referral,
            WalletLedgerSource.RedeemCode => WalletTokenKind.Promo,
            WalletLedgerSource.AdminGrant or WalletLedgerSource.AdminDebit => WalletTokenKind.AdminAdjustment,
            WalletLedgerSource.GenerationRefund or WalletLedgerSource.PurchaseRefund => WalletTokenKind.RefundAdjustment,
            WalletLedgerSource.WeeklyGrant or WalletLedgerSource.AdReward => WalletTokenKind.Bonus,
            _ => WalletTokenKind.Bonus
        };
    }

    private static string ResolveWalletOperationKind(string source, int delta)
    {
        if (source == WalletLedgerSource.PurchaseRefund)
        {
            return "refund";
        }

        if (source is WalletLedgerSource.GenerationSpend or WalletLedgerSource.WatermarkUnlock)
        {
            return "spend";
        }

        if (source is WalletLedgerSource.AdminGrant or WalletLedgerSource.AdminDebit)
        {
            return "adjustment";
        }

        return delta >= 0 ? "credit" : "debit";
    }

    private static DateTime? ResolveTokenBucketExpiryUtc(string source, string tokenKind, DateTime now)
    {
        return tokenKind is WalletTokenKind.Promo or WalletTokenKind.Bonus
            ? null
            : null;
    }

    private static int ResolveSpendPriority(string kind, string source)
    {
        if (source == WalletLedgerSource.PurchaseRefund)
        {
            return kind switch
            {
                WalletTokenKind.Purchased => 10,
                WalletTokenKind.Legacy => 20,
                _ => 80
            };
        }

        return kind switch
        {
            WalletTokenKind.Promo => 10,
            WalletTokenKind.Referral => 20,
            WalletTokenKind.SubscriptionAllowance => 30,
            WalletTokenKind.Bonus => 40,
            WalletTokenKind.AdminAdjustment => 50,
            WalletTokenKind.RefundAdjustment => 60,
            WalletTokenKind.Legacy => 70,
            WalletTokenKind.Purchased => 80,
            _ => 90
        };
    }

    private sealed record WalletBucketDelta(Guid BucketId, string Kind, int Delta);

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
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "purchase_confirm",
            ct => ConfirmPurchaseInternalOnceAsync(order, ct),
            cancellationToken);
    }

    private async Task<Result<PurchaseOrder>> ConfirmPurchaseInternalOnceAsync(PurchaseOrder order, CancellationToken cancellationToken)
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
            await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
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

            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                order.SparkToGrant,
                WalletLedgerSource.PackPurchase,
                $"purchase:{order.Id:D}",
                now,
                cancellationToken,
                order.PaymentProvider,
                order.ExternalPaymentId);
            if (walletMutation.IsFailure)
            {
                return Result.Failure<PurchaseOrder>(walletMutation.Error);
            }

            await SettlePendingReferralBonusAsync(order.UserId, $"purchase:{order.Id:D}", now, cancellationToken);

            wallet.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        else
        {
            wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                order.SparkToGrant,
                WalletLedgerSource.PackPurchase,
                $"purchase:{order.Id:D}",
                now,
                cancellationToken,
                order.PaymentProvider,
                order.ExternalPaymentId);
            if (walletMutation.IsFailure)
            {
                return Result.Failure<PurchaseOrder>(walletMutation.Error);
            }

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

    private async Task<Result<PurchaseOrder>> PreparePurchaseRefundInternalAsync(
        PurchaseOrder order,
        CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "purchase_refund_prepare",
            ct => PreparePurchaseRefundInternalOnceAsync(order, ct),
            cancellationToken);
    }

    private async Task<Result<PurchaseOrder>> PreparePurchaseRefundInternalOnceAsync(
        PurchaseOrder order,
        CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational()
            && (string.Equals(order.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
                || string.Equals(order.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)
                || string.Equals(order.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)))
        {
            return Result.Success(order);
        }

        var now = DateTime.UtcNow;
        var refundReason = $"purchase_refund:{order.Id:D}";
        var reservationTransactionId = BuildPurchaseRefundReservationTransactionId(order.Id);

        if (dbContext.Database.IsRelational())
        {
            await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
            var claimedRows = await dbContext.PurchaseOrders
                .Where(x => x.Id == order.Id && x.Status == PurchaseOrderStatus.Succeeded)
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(x => x.Status, PurchaseOrderStatus.RefundPending),
                    cancellationToken);

            if (claimedRows == 0)
            {
                var existingOrder = await dbContext.PurchaseOrders
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == order.Id, cancellationToken);

                if (existingOrder is not null
                    && (string.Equals(existingOrder.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
                        || string.Equals(existingOrder.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)
                        || string.Equals(existingOrder.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)))
                {
                    if (transaction is not null)
                    {
                        await transaction.CommitAsync(cancellationToken);
                    }

                    return Result.Success(existingOrder);
                }

                return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseNotRefundable);
            }

            dbContext.ChangeTracker.Clear();
            order = await dbContext.PurchaseOrders.FirstAsync(x => x.Id == order.Id, cancellationToken);
            var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                -order.SparkToGrant,
                WalletLedgerSource.PurchaseRefund,
                refundReason,
                now,
                cancellationToken,
                InternalWalletMutationProvider,
                reservationTransactionId);
            if (walletMutation.IsFailure)
            {
                order.Status = PurchaseOrderStatus.RefundRequiresManualReview;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return Result.Success(order);
            }

            wallet.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(order);
        }

        if (!string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return string.Equals(order.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
                || string.Equals(order.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)
                || string.Equals(order.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)
                ? Result.Success(order)
                : Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseNotRefundable);
        }

        order.Status = PurchaseOrderStatus.RefundPending;
        var localWallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        var localWalletMutation = await ApplyWalletMutationAsync(
            localWallet,
            -order.SparkToGrant,
            WalletLedgerSource.PurchaseRefund,
            refundReason,
            now,
            cancellationToken,
            InternalWalletMutationProvider,
            reservationTransactionId);
        if (localWalletMutation.IsFailure)
        {
            order.Status = PurchaseOrderStatus.RefundRequiresManualReview;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(order);
        }

        localWallet.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(order);
    }

    private async Task<Result<PurchaseOrder>> ApplyPurchaseRefundInternalAsync(
        PurchaseOrder order,
        string externalRefundId,
        CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "purchase_refund_apply",
            ct => ApplyPurchaseRefundInternalOnceAsync(order, externalRefundId, ct),
            cancellationToken);
    }

    private async Task<Result<PurchaseOrder>> ApplyPurchaseRefundInternalOnceAsync(
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
            && (string.Equals(order.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)
                || string.Equals(order.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)))
        {
            return Result.Success(order);
        }

        var now = DateTime.UtcNow;
        if (dbContext.Database.IsRelational())
        {
            await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
            var claimedRows = await dbContext.PurchaseOrders
                .Where(x => x.Id == order.Id
                    && (x.Status == PurchaseOrderStatus.Succeeded
                        || x.Status == PurchaseOrderStatus.RefundPending))
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(x => x.Status, PurchaseOrderStatus.Refunded),
                    cancellationToken);

            if (claimedRows == 0)
            {
                var existingOrder = await dbContext.PurchaseOrders
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x => x.Id == order.Id, cancellationToken);

                if (existingOrder is not null
                    && (string.Equals(existingOrder.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)
                        || string.Equals(existingOrder.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)))
                {
                    if (transaction is not null)
                    {
                        await transaction.CommitAsync(cancellationToken);
                    }

                    return Result.Success(existingOrder);
                }

                return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseNotRefundable);
            }

            dbContext.ChangeTracker.Clear();
            order = await dbContext.PurchaseOrders.FirstAsync(x => x.Id == order.Id, cancellationToken);
            if (await HasPurchaseRefundLedgerAsync(order.UserId, order.Id, cancellationToken))
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return Result.Success(order);
            }

            var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);

            var walletMutation = await ApplyWalletMutationAsync(
                wallet,
                -order.SparkToGrant,
                WalletLedgerSource.PurchaseRefund,
                $"purchase_refund:{order.Id:D}",
                now,
                cancellationToken,
                order.PaymentProvider,
                normalizedExternalRefundId);
            if (walletMutation.IsFailure)
            {
                order.Status = PurchaseOrderStatus.RefundRequiresManualReview;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return Result.Success(order);
            }

            wallet.UpdatedAtUtc = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(order);
        }

        if (!string.Equals(order.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
            || !await HasPurchaseRefundLedgerAsync(order.UserId, order.Id, cancellationToken))
        {
            var localWallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
            var localWalletMutation = await ApplyWalletMutationAsync(
                localWallet,
                -order.SparkToGrant,
                WalletLedgerSource.PurchaseRefund,
                $"purchase_refund:{order.Id:D}",
                now,
                cancellationToken,
                order.PaymentProvider,
                normalizedExternalRefundId);
            if (localWalletMutation.IsFailure)
            {
                order.Status = PurchaseOrderStatus.RefundRequiresManualReview;
                await dbContext.SaveChangesAsync(cancellationToken);
                return Result.Success(order);
            }

            localWallet.UpdatedAtUtc = now;
        }

        order.Status = PurchaseOrderStatus.Refunded;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(order);
    }

    private async Task<bool> HasPurchaseRefundLedgerAsync(Guid userId, Guid orderId, CancellationToken cancellationToken)
    {
        var reason = $"purchase_refund:{orderId:D}";
        return await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == userId
                    && x.Source == WalletLedgerSource.PurchaseRefund
                    && x.Reason == reason,
                cancellationToken);
    }

    private static string BuildPurchaseRefundReservationTransactionId(Guid orderId)
    {
        return $"refund-reservation:{orderId:D}";
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
            null,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc);
    }
}
