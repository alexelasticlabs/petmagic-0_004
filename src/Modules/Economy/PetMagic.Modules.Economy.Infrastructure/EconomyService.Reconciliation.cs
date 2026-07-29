using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using Npgsql;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private const long EconomyReconciliationAdvisoryLockKey = 0x5065744D67_02;
    private static class EconomyIncidentType
    {
        public const string WebhookProcessingFailed = "WebhookProcessingFailed";
        public const string PurchaseSettlementFailed = "PurchaseSettlementFailed";
        public const string PurchasePaidButNotCredited = "PurchasePaidButNotCredited";
        public const string RefundRequiresManualReview = "RefundRequiresManualReview";
        public const string SubscriptionStateMismatch = "SubscriptionStateMismatch";
        public const string PremiumEntitlementMismatch = "PremiumEntitlementMismatch";
        public const string LedgerWalletMismatch = "LedgerWalletMismatch";
        public const string ProviderStateMismatch = "ProviderStateMismatch";
        public const string ManualReviewRequired = "ManualReviewRequired";
        public const string GenerationChargeMarkerMissing = "GenerationChargeMarkerMissing";
        public const string GenerationLedgerSpendMissing = "GenerationLedgerSpendMissing";
        public const string GenerationRefundMissing = "GenerationRefundMissing";
        public const string GenerationRefundMarkerMissing = "GenerationRefundMarkerMissing";
        public const string GenerationRefundLedgerMissing = "GenerationRefundLedgerMissing";
        public const string GenerationRefundWithoutSpend = "GenerationRefundWithoutSpend";
        public const string GenerationDuplicateLedgerMutation = "GenerationDuplicateLedgerMutation";
        public const string GenerationBillingPendingStale = "GenerationBillingPendingStale";
        public const string GenerationBillingJobMissing = "GenerationBillingJobMissing";
    }

    public async Task<Result<EconomyReconciliationRunResponse>> RunEconomyReconciliationAsync(
        CancellationToken cancellationToken)
    {
        var reconciliationLock = await TryAcquireEconomyReconciliationLockAsync(cancellationToken);
        if (!reconciliationLock.Acquired)
        {
            return Result.Failure<EconomyReconciliationRunResponse>(EconomyErrors.ReconciliationAlreadyRunning);
        }

        await using var lease = reconciliationLock.Lease;
        var startedAtUtc = DateTime.UtcNow;
        var stats = new ReconciliationStats(startedAtUtc);
        var stalePendingBeforeUtc = startedAtUtc.AddMinutes(-Math.Max(5, options.Value.EconomyReconciliationPendingOrderMinutes));
        var lookbackAfterUtc = startedAtUtc.AddDays(-Math.Max(1, options.Value.EconomyReconciliationLookbackDays));

        await ReconcilePurchaseOrdersAsync(stalePendingBeforeUtc, stats, cancellationToken);
        await ReconcileLedgerConsistencyAsync(stats, cancellationToken);
        await ReconcileGenerationBillingAsync(stalePendingBeforeUtc, lookbackAfterUtc, stats, cancellationToken);
        await ReconcilePendingAdminPremiumRevocationsAsync(stats, cancellationToken);
        await ReconcileSubscriptionsAsync(startedAtUtc, lookbackAfterUtc, stats, cancellationToken);
        await ReconcileWebhookEventsAsync(lookbackAfterUtc, stats, cancellationToken);

        return Result.Success(new EconomyReconciliationRunResponse(
            stats.StartedAtUtc,
            DateTime.UtcNow,
            stats.ChecksRun,
            stats.IncidentsCreated,
            stats.IncidentsUpdated,
            stats.IncidentsResolved,
            stats.AutoFixesApplied,
            stats.ManualReviewRequired));
    }

    private async Task ReconcilePendingAdminPremiumRevocationsAsync(
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        const int batchSize = 100;
        var operationIds = await dbContext.SubscriptionEventLogs
            .AsNoTracking()
            .Where(x => x.Provider == "stripe"
                && x.EventType == AdminPremiumRevokeEventType
                && x.ExternalEventId != null
                && x.ExternalEventId.StartsWith(AdminPremiumRevokeOperationPrefix)
                && (x.Status == AdminPremiumRevokePending
                    || x.Status == AdminPremiumRevokeGatewayFailed
                    || x.Status == AdminPremiumRevokeEconomyApplied))
            .OrderBy(x => x.CreatedAtUtc)
            .Select(x => x.Id)
            .Take(batchSize)
            .ToListAsync(cancellationToken);

        foreach (var operationId in operationIds)
        {
            cancellationToken.ThrowIfCancellationRequested();
            stats.ChecksRun++;
            dbContext.ChangeTracker.Clear();

            var operation = await dbContext.SubscriptionEventLogs
                .FirstOrDefaultAsync(x => x.Id == operationId, cancellationToken);
            if (operation?.UserSubscriptionId is not { } subscriptionId
                || !IsAdminPremiumRevokeOperation(operation, subscriptionId))
            {
                continue;
            }

            var subscription = await dbContext.UserSubscriptions
                .FirstOrDefaultAsync(x => x.Id == subscriptionId, cancellationToken);
            if (subscription is null || subscription.UserId != operation.UserId)
            {
                logger?.LogWarning(
                    "Skipping orphaned admin Premium revoke recovery. OperationIdHash={OperationIdHash}",
                    SafeLogValues.StableHash(operationId.ToString("D")));
                continue;
            }

            var recovery = await ResumeAdminPremiumRevokeAsync(
                subscription,
                operation,
                cancellationToken);
            if (recovery.IsSuccess)
            {
                stats.AutoFixesApplied++;
                continue;
            }

            logger?.LogWarning(
                "Admin Premium revoke recovery remains pending. OperationIdHash={OperationIdHash} ErrorCode={ErrorCode}",
                SafeLogValues.StableHash(operationId.ToString("D")),
                recovery.Error.Code);
        }
    }

    private async Task<(bool Acquired, IAsyncDisposable? Lease)> TryAcquireEconomyReconciliationLockAsync(
        CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational()
            || !string.Equals(
                dbContext.Database.ProviderName,
                "Npgsql.EntityFrameworkCore.PostgreSQL",
                StringComparison.Ordinal))
        {
            return (true, null);
        }

        NpgsqlConnection connection;
        if (_postgreSqlDataSource is not null)
        {
            connection = await _postgreSqlDataSource.OpenConnectionAsync(cancellationToken);
        }
        else
        {
            var connectionString = dbContext.Database.GetConnectionString();
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                return (true, null);
            }

            connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);
        }

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT pg_try_advisory_lock(@key)";
            command.Parameters.AddWithValue("key", EconomyReconciliationAdvisoryLockKey);
            var acquired = (bool?)await command.ExecuteScalarAsync(cancellationToken) == true;
            if (!acquired)
            {
                await connection.DisposeAsync();
                return (false, null);
            }

            return (true, new EconomyReconciliationLockLease(connection));
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    private sealed class EconomyReconciliationLockLease(NpgsqlConnection connection) : IAsyncDisposable
    {
        public async ValueTask DisposeAsync()
        {
            try
            {
                await using var command = connection.CreateCommand();
                command.CommandText = "SELECT pg_advisory_unlock(@key)";
                command.Parameters.AddWithValue("key", EconomyReconciliationAdvisoryLockKey);
                await command.ExecuteNonQueryAsync();
            }
            finally
            {
                await connection.DisposeAsync();
            }
        }
    }

    public async Task<Result<OffsetPagedResponse<AdminEconomyIncidentResponse>>> GetAdminEconomyIncidentsAsync(
        int skip,
        int take,
        string? status,
        string? type,
        string? category,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        var normalizedStatus = NormalizeIncidentStatusFilter(status);
        var normalizedType = string.IsNullOrWhiteSpace(type) ? null : type.Trim();
        var normalizedCategory = NormalizeIncidentCategoryFilter(category);

        var query = dbContext.EconomyIncidents
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(normalizedStatus))
        {
            query = query.Where(x => x.Status == normalizedStatus);
        }

        if (!string.IsNullOrWhiteSpace(normalizedType))
        {
            query = query.Where(x => x.Type == normalizedType);
        }

        if (!string.IsNullOrWhiteSpace(normalizedCategory))
        {
            query = ApplyIncidentCategoryFilter(query, normalizedCategory);
        }

        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
        }

        var incidents = await query
            .OrderBy(x => x.Status == "Resolved")
            .ThenByDescending(x => x.LastDetectedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);
        var items = incidents
            .Select(ToAdminEconomyIncidentResponse)
            .ToList();

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<AdminEconomyIncidentResponse>> ResolveAdminEconomyIncidentAsync(
        Guid incidentId,
        string? resolutionNote,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(resolutionNote))
        {
            return Result.Failure<AdminEconomyIncidentResponse>(EconomyErrors.EconomyIncidentActionReasonRequired);
        }

        var incident = await dbContext.EconomyIncidents
            .FirstOrDefaultAsync(x => x.Id == incidentId, cancellationToken);
        if (incident is null)
        {
            return Result.Failure<AdminEconomyIncidentResponse>(EconomyErrors.EconomyIncidentNotFound);
        }

        var oldStatus = incident.Status;
        incident.Status = "Resolved";
        incident.ResolvedAtUtc = DateTime.UtcNow;
        incident.ResolutionNote = NormalizeIncidentResolutionNote(resolutionNote);
        incident.NextRetryAtUtc = null;
        await AppendIncidentAuditAsync(
            incident,
            "resolve_incident",
            resolutionNote,
            oldStatus,
            incident.Status,
            new { incident.Type, incident.PurchaseOrderId, incident.UserSubscriptionId },
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.resolved", oldStatus, incident.Status, resolutionNote, cancellationToken);

        return Result.Success(ToAdminEconomyIncidentResponse(incident));
    }

    private async Task ReconcilePurchaseOrdersAsync(
        DateTime stalePendingBeforeUtc,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var orders = await dbContext.PurchaseOrders
            .Where(x => x.CreatedAtUtc <= stalePendingBeforeUtc
                || x.Status == PurchaseOrderStatus.Succeeded
                || x.Status == PurchaseOrderStatus.RefundPending
                || x.Status == PurchaseOrderStatus.RefundRequiresManualReview
                || x.Status == PurchaseOrderStatus.Failed)
            .OrderBy(x => x.CreatedAtUtc)
            .Take(500)
            .ToListAsync(cancellationToken);

        foreach (var order in orders)
        {
            stats.ChecksRun++;

            if (order.Status == PurchaseOrderStatus.Pending && order.CreatedAtUtc <= stalePendingBeforeUtc)
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.PurchaseSettlementFailed,
                    "Warning",
                    $"purchase:pending:{order.Id:D}",
                    $"Purchase order {order.Id:D} has been pending longer than the reconciliation threshold.",
                    stats,
                    userId: order.UserId,
                    purchaseOrderId: order.Id,
                    provider: order.PaymentProvider,
                    externalReferenceId: order.ExternalPaymentId,
                    details: new
                    {
                        order.Status,
                        order.CreatedAtUtc,
                        order.ExternalPaymentId,
                        order.PriceAmount,
                        order.CurrencyCode
                    },
                    cancellationToken: cancellationToken);
                continue;
            }

            if (order.Status == PurchaseOrderStatus.Succeeded)
            {
                await ReconcileSucceededOrderLedgerAsync(order, stats, cancellationToken);
                continue;
            }

            if (order.Status == PurchaseOrderStatus.RefundPending)
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.ManualReviewRequired,
                    "Warning",
                    $"purchase:refund_pending:{order.Id:D}",
                    $"Purchase order {order.Id:D} is waiting for provider refund settlement.",
                    stats,
                    userId: order.UserId,
                    purchaseOrderId: order.Id,
                    provider: order.PaymentProvider,
                    externalReferenceId: order.ExternalPaymentId,
                    details: new { order.Status, order.CreatedAtUtc, order.ConfirmedAtUtc },
                    cancellationToken: cancellationToken);
                continue;
            }

            if (order.Status == PurchaseOrderStatus.RefundRequiresManualReview)
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.RefundRequiresManualReview,
                    "Critical",
                    $"purchase:refund_review:{order.Id:D}",
                    $"Purchase order {order.Id:D} refund cannot be completed automatically.",
                    stats,
                    userId: order.UserId,
                    purchaseOrderId: order.Id,
                    provider: order.PaymentProvider,
                    externalReferenceId: order.ExternalPaymentId,
                    details: new
                    {
                        order.Status,
                        order.SparkToGrant,
                        reason = "Wallet cannot safely revoke purchased tokens automatically."
                    },
                    cancellationToken: cancellationToken);
                continue;
            }

            if (order.Status == PurchaseOrderStatus.Failed && !string.IsNullOrWhiteSpace(order.ExternalPaymentId))
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.ProviderStateMismatch,
                    "Warning",
                    $"purchase:failed_external:{order.Id:D}",
                    $"Purchase order {order.Id:D} is failed locally but has a provider payment reference.",
                    stats,
                    userId: order.UserId,
                    purchaseOrderId: order.Id,
                    provider: order.PaymentProvider,
                    externalReferenceId: order.ExternalPaymentId,
                    details: new { order.Status, order.ExternalPaymentId },
                    cancellationToken: cancellationToken);
            }
        }
    }

    private async Task ReconcileSucceededOrderLedgerAsync(
        PurchaseOrder order,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var result = await ExecuteWalletSerializableMutationWithRetryAsync(
            "reconcile_purchase_ledger",
            async ct =>
            {
                await ReconcileSucceededOrderLedgerOnceAsync(order, stats, ct);
                return Result.Success(true);
            },
            cancellationToken);

        if (result.IsFailure)
        {
            throw BuildSafeEconomyOperationException("reconcile_purchase_ledger", result.Error);
        }
    }

    private async Task ReconcileSucceededOrderLedgerOnceAsync(
        PurchaseOrder order,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var hasPackLedger = await HasPackPurchaseLedgerAsync(order, cancellationToken);
        if (hasPackLedger)
        {
            return;
        }

        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
        var now = DateTime.UtcNow;
        var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        var mutation = await ApplyWalletMutationAsync(
            wallet,
            order.SparkToGrant,
            WalletLedgerSource.PackPurchase,
            $"purchase:{order.Id:D}",
            now,
            cancellationToken,
            order.PaymentProvider,
            order.ExternalPaymentId);
        if (mutation.IsFailure)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.PurchasePaidButNotCredited,
                "Critical",
                $"purchase:missing_ledger:{order.Id:D}",
                $"Purchase order {order.Id:D} is settled locally but wallet credit is missing.",
                stats,
                userId: order.UserId,
                purchaseOrderId: order.Id,
                provider: order.PaymentProvider,
                externalReferenceId: order.ExternalPaymentId,
                details: new { order.Status, errorCode = mutation.Error.Code },
                lastError: mutation.Error.Code,
                cancellationToken: cancellationToken);
            return;
        }

        wallet.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        stats.AutoFixesApplied++;
        await UpsertEconomyIncidentAsync(
            EconomyIncidentType.PurchasePaidButNotCredited,
            "Warning",
            $"purchase:missing_ledger:{order.Id:D}",
            $"Purchase order {order.Id:D} wallet credit was restored automatically.",
            stats,
            status: "Resolved",
            userId: order.UserId,
            purchaseOrderId: order.Id,
            provider: order.PaymentProvider,
            externalReferenceId: order.ExternalPaymentId,
            autoFixApplied: true,
            details: new { order.Status, order.SparkToGrant },
            cancellationToken: cancellationToken);
    }

    private async Task ReconcileLedgerConsistencyAsync(
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var purchaseLedgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.Source == WalletLedgerSource.PackPurchase)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(500)
            .ToListAsync(cancellationToken);

        foreach (var entry in purchaseLedgerEntries)
        {
            stats.ChecksRun++;
            var orderId = TryParsePurchaseOrderIdFromReason(entry.Reason);
            if (!orderId.HasValue)
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.LedgerWalletMismatch,
                    "Warning",
                    $"ledger:pack_purchase:unlinked:{entry.Id:D}",
                    $"Pack purchase ledger entry {entry.Id:D} cannot be linked to a purchase order.",
                    stats,
                    userId: entry.UserId,
                    externalReferenceId: entry.SourceTransactionId,
                    details: new { entry.Source, entry.Reason, entry.Delta },
                    cancellationToken: cancellationToken);
                continue;
            }

            var order = await dbContext.PurchaseOrders.FirstOrDefaultAsync(x => x.Id == orderId.Value, cancellationToken);
            if (order is null)
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.LedgerWalletMismatch,
                    "Critical",
                    $"ledger:order_missing:{entry.Id:D}",
                    $"Pack purchase ledger entry {entry.Id:D} references a missing order.",
                    stats,
                    userId: entry.UserId,
                    externalReferenceId: entry.SourceTransactionId,
                    details: new { entry.Source, entry.Reason, entry.Delta },
                    cancellationToken: cancellationToken);
                continue;
            }

            if (order.Status == PurchaseOrderStatus.Pending)
            {
                order.Status = PurchaseOrderStatus.Succeeded;
                order.ConfirmedAtUtc ??= entry.CreatedAtUtc;
                await dbContext.SaveChangesAsync(cancellationToken);
                stats.AutoFixesApplied++;
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.PurchaseSettlementFailed,
                    "Warning",
                    $"purchase:ledger_business_mismatch:{order.Id:D}",
                    $"Purchase order {order.Id:D} was marked succeeded because wallet ledger already exists.",
                    stats,
                    status: "Resolved",
                    userId: order.UserId,
                    purchaseOrderId: order.Id,
                    provider: order.PaymentProvider,
                    externalReferenceId: order.ExternalPaymentId,
                    autoFixApplied: true,
                    details: new { entry.Id, entry.Delta, entry.CreatedAtUtc },
                    cancellationToken: cancellationToken);
            }
        }

        var walletProjections = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .GroupBy(x => x.UserId)
            .Select(x => new { UserId = x.Key, Balance = x.Sum(y => y.Delta) })
            .ToListAsync(cancellationToken);

        foreach (var projection in walletProjections)
        {
            stats.ChecksRun++;
            var walletBalance = await dbContext.Wallets
                .AsNoTracking()
                .Where(x => x.UserId == projection.UserId)
                .Select(x => (int?)x.Balance)
                .FirstOrDefaultAsync(cancellationToken);
            if (!walletBalance.HasValue || walletBalance.Value == projection.Balance)
            {
                continue;
            }

            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.LedgerWalletMismatch,
                "Critical",
                $"wallet:projection:{projection.UserId:D}",
                $"Wallet balance does not match ledger projection for user {projection.UserId:D}.",
                stats,
                userId: projection.UserId,
                details: new { walletBalance, ledgerProjection = projection.Balance },
                cancellationToken: cancellationToken);
        }
    }

    private async Task ReconcileGenerationBillingAsync(
        DateTime stalePendingBeforeUtc,
        DateTime lookbackAfterUtc,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        if (_generationBillingReconciliation is null)
        {
            return;
        }

        var spendEntries = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.Source == WalletLedgerSource.GenerationSpend
                && x.CreatedAtUtc >= lookbackAfterUtc)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(1000)
            .ToListAsync(cancellationToken);
        var refundEntries = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.Source == WalletLedgerSource.GenerationRefund
                && x.CreatedAtUtc >= lookbackAfterUtc)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(1000)
            .ToListAsync(cancellationToken);

        var snapshotResult = await _generationBillingReconciliation.ListGenerationBillingSnapshotsAsync(
            lookbackAfterUtc,
            1000,
            cancellationToken);
        if (snapshotResult.IsFailure)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationBillingPendingStale,
                "Critical",
                "generation_billing:templates_snapshot_unavailable",
                "Generation billing reconciliation could not read Templates billing snapshots.",
                stats,
                details: new { snapshotResult.Error.Code },
                lastError: snapshotResult.Error.Code,
                cancellationToken: cancellationToken);
            return;
        }

        var spendGroups = spendEntries
            .Select(x => new { Entry = x, GenerationId = TryParseGenerationSpendIdFromReason(x.Reason) })
            .Where(x => x.GenerationId.HasValue)
            .GroupBy(x => x.GenerationId!.Value)
            .ToDictionary(x => x.Key, x => x.Select(y => y.Entry).ToList());
        var refundGroups = refundEntries
            .Select(x => new { Entry = x, GenerationId = TryParseGenerationRefundIdFromReason(x.Reason) })
            .Where(x => x.GenerationId.HasValue)
            .GroupBy(x => x.GenerationId!.Value)
            .ToDictionary(x => x.Key, x => x.Select(y => y.Entry).ToList());
        var snapshots = snapshotResult.Value.ToDictionary(x => x.GenerationId);
        var generationIds = spendGroups.Keys
            .Concat(refundGroups.Keys)
            .Concat(snapshots.Keys)
            .Distinct()
            .Take(2000)
            .ToList();

        foreach (var generationId in generationIds)
        {
            stats.ChecksRun++;
            spendGroups.TryGetValue(generationId, out var spends);
            refundGroups.TryGetValue(generationId, out var refunds);
            if (!snapshots.TryGetValue(generationId, out var snapshot))
            {
                var snapshotLookup = await _generationBillingReconciliation.GetGenerationBillingSnapshotAsync(
                    generationId,
                    cancellationToken);
                if (snapshotLookup.IsSuccess)
                {
                    snapshot = snapshotLookup.Value;
                    snapshots[generationId] = snapshot;
                }
            }

            await ReconcileGenerationBillingStateAsync(
                generationId,
                snapshot,
                spends ?? [],
                refunds ?? [],
                stalePendingBeforeUtc,
                stats,
                cancellationToken);
        }
    }

    private async Task ReconcileGenerationBillingStateAsync(
        Guid generationId,
        GenerationBillingSnapshot? snapshot,
        IReadOnlyList<WalletLedgerEntry> spends,
        IReadOnlyList<WalletLedgerEntry> refunds,
        DateTime stalePendingBeforeUtc,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var primarySpend = spends.OrderBy(x => x.CreatedAtUtc).FirstOrDefault();
        var primaryRefund = refunds.OrderBy(x => x.CreatedAtUtc).FirstOrDefault();
        var userId = snapshot?.UserId ?? primarySpend?.UserId ?? primaryRefund?.UserId;
        var tokenCost = snapshot?.TokenCost ?? Math.Abs(primarySpend?.Delta ?? primaryRefund?.Delta ?? 0);
        if (tokenCost <= 0)
        {
            return;
        }

        if (snapshot is null && (spends.Count > 0 || refunds.Count > 0))
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationBillingJobMissing,
                "Critical",
                $"generation_billing:job_missing:{generationId:D}",
                $"Generation billing ledger references generation {generationId:D}, but the Templates job was not found.",
                stats,
                userId: userId,
                externalReferenceId: generationId.ToString("D"),
                details: new
                {
                    generationId,
                    spendEntryIds = spends.Select(x => x.Id),
                    refundEntryIds = refunds.Select(x => x.Id)
                },
                cancellationToken: cancellationToken);
            return;
        }

        if (spends.Count > 1)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationDuplicateLedgerMutation,
                "Critical",
                $"generation_billing:duplicate_spend:{generationId:D}",
                $"Generation {generationId:D} has multiple spend ledger entries.",
                stats,
                userId: userId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, entryIds = spends.Select(x => x.Id), deltas = spends.Select(x => x.Delta) },
                cancellationToken: cancellationToken);
        }

        if (refunds.Count > 1)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationDuplicateLedgerMutation,
                "Critical",
                $"generation_billing:duplicate_refund:{generationId:D}",
                $"Generation {generationId:D} has multiple refund ledger entries.",
                stats,
                userId: userId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, entryIds = refunds.Select(x => x.Id), deltas = refunds.Select(x => x.Delta) },
                cancellationToken: cancellationToken);
        }

        if (snapshot is null)
        {
            return;
        }

        if (primarySpend is not null && snapshot.ChargedAtUtc is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationChargeMarkerMissing,
                "Critical",
                $"generation_billing:charge_marker_missing:{generationId:D}",
                $"Generation {generationId:D} has a wallet spend but no Templates ChargedAtUtc marker.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new
                {
                    generationId,
                    snapshot.Status,
                    snapshot.TokenCost,
                    spendEntryId = primarySpend.Id,
                    spendCreatedAtUtc = primarySpend.CreatedAtUtc,
                    snapshot.UpdatedAtUtc
                },
                cancellationToken: cancellationToken);
        }

        if (snapshot.ChargedAtUtc is not null && primarySpend is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationLedgerSpendMissing,
                "Critical",
                $"generation_billing:spend_missing:{generationId:D}",
                $"Generation {generationId:D} is marked charged but no matching generation spend ledger entry was found.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, snapshot.Status, snapshot.TokenCost, snapshot.ChargedAtUtc },
                cancellationToken: cancellationToken);
        }

        if (IsTerminalFailedGenerationStatus(snapshot.Status)
            && snapshot.ChargedAtUtc is not null
            && snapshot.RefundedAtUtc is null
            && primaryRefund is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationRefundMissing,
                "Critical",
                $"generation_billing:refund_missing:{generationId:D}",
                $"Generation {generationId:D} failed or was cancelled after charge, but no refund ledger entry was found.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new
                {
                    generationId,
                    snapshot.Status,
                    snapshot.TokenCost,
                    snapshot.RefundAttemptCount,
                    snapshot.RefundLastErrorCode,
                    snapshot.RefundLastAttemptedAtUtc
                },
                lastError: snapshot.RefundLastErrorCode,
                cancellationToken: cancellationToken);
        }

        if (primaryRefund is not null && primarySpend is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationRefundWithoutSpend,
                "Critical",
                $"generation_billing:refund_without_spend:{generationId:D}",
                $"Generation {generationId:D} has a refund ledger entry but no matching spend ledger entry.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, refundEntryId = primaryRefund.Id, refundDelta = primaryRefund.Delta },
                cancellationToken: cancellationToken);
        }

        if (primaryRefund is not null && snapshot.RefundedAtUtc is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationRefundMarkerMissing,
                "Warning",
                $"generation_billing:refund_marker_missing:{generationId:D}",
                $"Generation {generationId:D} has a refund ledger entry but no Templates RefundedAtUtc marker.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, refundEntryId = primaryRefund.Id, refundCreatedAtUtc = primaryRefund.CreatedAtUtc },
                cancellationToken: cancellationToken);
        }

        if (snapshot.RefundedAtUtc is not null && primaryRefund is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationRefundLedgerMissing,
                "Critical",
                $"generation_billing:refund_ledger_missing:{generationId:D}",
                $"Generation {generationId:D} is marked refunded but no matching generation refund ledger entry was found.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, snapshot.Status, snapshot.TokenCost, snapshot.RefundedAtUtc },
                cancellationToken: cancellationToken);
        }

        if (snapshot.ChargedAtUtc is null
            && primarySpend is null
            && IsActiveGenerationStatus(snapshot.Status)
            && snapshot.CreatedAtUtc <= stalePendingBeforeUtc)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.GenerationBillingPendingStale,
                "Warning",
                $"generation_billing:pending_stale:{generationId:D}",
                $"Generation {generationId:D} is still active without a billing spend after the pending threshold.",
                stats,
                userId: snapshot.UserId,
                externalReferenceId: generationId.ToString("D"),
                details: new { generationId, snapshot.Status, snapshot.TokenCost, snapshot.CreatedAtUtc },
                cancellationToken: cancellationToken);
        }
    }

    private async Task ReconcileSubscriptionsAsync(
        DateTime now,
        DateTime lookbackAfterUtc,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var subscriptions = await dbContext.UserSubscriptions
            .Where(x => x.UpdatedAtUtc >= lookbackAfterUtc
                || x.CurrentPeriodEndUtc == null
                || x.CurrentPeriodEndUtc >= lookbackAfterUtc)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Take(500)
            .ToListAsync(cancellationToken);

        foreach (var subscription in subscriptions)
        {
            stats.ChecksRun++;
            var isActive = IsActivePremiumSubscription(subscription);
            if (isActive)
            {
                await ReconcilePremiumAllowanceAsync(subscription, stats, cancellationToken);
                await ReconcileIdentityPremiumFlagAsync(subscription, desiredPremium: true, stats, cancellationToken);
                continue;
            }

            if (IsPremiumLikeStatus(subscription.Status))
            {
                await UpsertEconomyIncidentAsync(
                    EconomyIncidentType.SubscriptionStateMismatch,
                    "Warning",
                    $"subscription:expired_state:{subscription.Id:D}",
                    $"Subscription {subscription.Id:D} has a premium-like status but is not currently entitled by Economy rules.",
                    stats,
                    userId: subscription.UserId,
                    userSubscriptionId: subscription.Id,
                    provider: subscription.Provider,
                    externalReferenceId: subscription.ExternalSubscriptionId,
                    details: new
                    {
                        subscription.Status,
                        subscription.CurrentPeriodEndUtc,
                        subscription.CancelAtPeriodEnd
                    },
                    cancellationToken: cancellationToken);
            }

            await ReconcileIdentityPremiumFlagAsync(subscription, desiredPremium: false, stats, cancellationToken);
        }
    }

    private async Task ReconcilePremiumAllowanceAsync(
        UserSubscription subscription,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var periodStartUtc = subscription.CurrentPeriodStartUtc ?? subscription.CreatedAtUtc;
        var hasAllowanceLedger = await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == subscription.UserId
                    && x.Source == WalletLedgerSource.PremiumSubscriptionGrant
                    && x.Reason == $"premium_allowance:{periodStartUtc:O}",
                cancellationToken);

        if (hasAllowanceLedger
            && subscription.LastTokenGrantAtUtc.HasValue
            && subscription.LastTokenGrantAtUtc.Value >= periodStartUtc)
        {
            return;
        }

        try
        {
            await GrantPremiumSubscriptionAllowanceIfDueAsync(subscription, subscription.Provider, cancellationToken);
            stats.AutoFixesApplied++;
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.SubscriptionStateMismatch,
                "Warning",
                $"subscription:allowance_missing:{subscription.Id:D}:{periodStartUtc:O}",
                $"Premium allowance for subscription {subscription.Id:D} was restored automatically.",
                stats,
                status: "Resolved",
                userId: subscription.UserId,
                userSubscriptionId: subscription.Id,
                provider: subscription.Provider,
                externalReferenceId: subscription.ExternalSubscriptionId,
                autoFixApplied: true,
                details: new { periodStartUtc, subscription.MonthlyTokenLimit },
                cancellationToken: cancellationToken);
        }
        catch (Exception ex)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.SubscriptionStateMismatch,
                "Critical",
                $"subscription:allowance_missing:{subscription.Id:D}:{periodStartUtc:O}",
                $"Premium allowance for subscription {subscription.Id:D} could not be restored automatically.",
                stats,
                userId: subscription.UserId,
                userSubscriptionId: subscription.Id,
                provider: subscription.Provider,
                externalReferenceId: subscription.ExternalSubscriptionId,
                details: new { periodStartUtc, subscription.MonthlyTokenLimit },
                lastError: ex.GetType().Name,
                cancellationToken: cancellationToken);
        }
    }

    private async Task ReconcileIdentityPremiumFlagAsync(
        UserSubscription subscription,
        bool desiredPremium,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var latestSubscription = await GetLatestUserSubscriptionAsync(subscription.UserId, cancellationToken);
        if (latestSubscription is not null && latestSubscription.Id != subscription.Id)
        {
            return;
        }

        desiredPremium = IsActivePremiumSubscription(latestSubscription);

        if (identityService is null)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.PremiumEntitlementMismatch,
                "Critical",
                $"premium_identity:unavailable:{subscription.UserId:D}",
                $"Identity premium flag cannot be reconciled for user {subscription.UserId:D}.",
                stats,
                userId: subscription.UserId,
                userSubscriptionId: subscription.Id,
                provider: subscription.Provider,
                externalReferenceId: subscription.ExternalSubscriptionId,
                lastError: EconomyErrors.PremiumBillingUnavailable.Code,
                cancellationToken: cancellationToken);
            return;
        }

        var profile = await identityService.GetCurrentUserAsync(subscription.UserId, cancellationToken);
        if (profile.IsFailure)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.PremiumEntitlementMismatch,
                "Critical",
                $"premium_identity:read:{subscription.UserId:D}",
                $"Identity premium flag could not be read for user {subscription.UserId:D}.",
                stats,
                userId: subscription.UserId,
                userSubscriptionId: subscription.Id,
                provider: subscription.Provider,
                externalReferenceId: subscription.ExternalSubscriptionId,
                lastError: profile.Error.Code,
                cancellationToken: cancellationToken);
            return;
        }

        if (profile.Value.IsPremium == desiredPremium)
        {
            return;
        }

        var update = await identityService.SetPremiumStatusAsync(
            new SetPremiumStatusCommand(subscription.UserId, desiredPremium),
            cancellationToken);
        if (update.IsFailure)
        {
            await UpsertEconomyIncidentAsync(
                EconomyIncidentType.PremiumEntitlementMismatch,
                "Critical",
                $"premium_identity:update:{subscription.UserId:D}",
                $"Identity premium flag could not be synchronized for user {subscription.UserId:D}.",
                stats,
                userId: subscription.UserId,
                userSubscriptionId: subscription.Id,
                provider: subscription.Provider,
                externalReferenceId: subscription.ExternalSubscriptionId,
                details: new { desiredPremium, identityPremium = profile.Value.IsPremium },
                lastError: update.Error.Code,
                cancellationToken: cancellationToken);
            return;
        }

        stats.AutoFixesApplied++;
        await UpsertEconomyIncidentAsync(
            EconomyIncidentType.PremiumEntitlementMismatch,
            "Warning",
            $"premium_identity:mismatch:{subscription.UserId:D}",
            $"Identity premium flag for user {subscription.UserId:D} was synchronized from Economy.",
            stats,
            status: "Resolved",
            userId: subscription.UserId,
            userSubscriptionId: subscription.Id,
            provider: subscription.Provider,
            externalReferenceId: subscription.ExternalSubscriptionId,
            autoFixApplied: true,
            details: new { desiredPremium, previousIdentityPremium = profile.Value.IsPremium },
            cancellationToken: cancellationToken);
    }

    private async Task ReconcileWebhookEventsAsync(
        DateTime lookbackAfterUtc,
        ReconciliationStats stats,
        CancellationToken cancellationToken)
    {
        var failedEvents = await dbContext.SubscriptionEventLogs
            .AsNoTracking()
            .Where(x => x.CreatedAtUtc >= lookbackAfterUtc
                && (x.Status == "Failed"
                    || x.EventType == "PremiumIdentitySyncFailed"
                    || x.EventType == "PremiumReconciliationIncident"))
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(200)
            .ToListAsync(cancellationToken);

        foreach (var eventLog in failedEvents)
        {
            stats.ChecksRun++;
            await UpsertEconomyIncidentAsync(
                eventLog.EventType == "PremiumIdentitySyncFailed" || eventLog.EventType == "PremiumReconciliationIncident"
                    ? EconomyIncidentType.PremiumEntitlementMismatch
                    : EconomyIncidentType.WebhookProcessingFailed,
                "Warning",
                $"subscription_event:failed:{eventLog.Id:D}",
                $"Subscription event {eventLog.Id:D} requires reconciliation review.",
                stats,
                userId: eventLog.UserId,
                userSubscriptionId: eventLog.UserSubscriptionId,
                provider: eventLog.Provider,
                externalReferenceId: eventLog.ExternalSubscriptionId ?? eventLog.ExternalEventId,
                details: new { eventLog.EventType, eventLog.Status, eventLog.ExternalEventId },
                cancellationToken: cancellationToken);
        }
    }

    private async Task UpsertEconomyIncidentAsync(
        string type,
        string severity,
        string deduplicationKey,
        string summary,
        ReconciliationStats stats,
        string status = "Open",
        Guid? userId = null,
        Guid? purchaseOrderId = null,
        Guid? userSubscriptionId = null,
        string? provider = null,
        string? externalReferenceId = null,
        object? details = null,
        bool autoFixApplied = false,
        string? lastError = null,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var incident = await dbContext.EconomyIncidents
            .FirstOrDefaultAsync(x => x.DeduplicationKey == deduplicationKey, cancellationToken);

        if (incident is null)
        {
            incident = new EconomyIncident
            {
                Id = Guid.NewGuid(),
                Type = type,
                Severity = severity,
                Status = status,
                DeduplicationKey = deduplicationKey,
                UserId = userId,
                PurchaseOrderId = purchaseOrderId,
                UserSubscriptionId = userSubscriptionId,
                Provider = provider,
                ExternalReferenceId = externalReferenceId,
                Summary = summary,
                DetailsJson = SerializeSafeIncidentDetails(details, maxChars: 32000),
                DetectionCount = 1,
                RetryCount = status == "Open" ? 1 : 0,
                FirstDetectedAtUtc = now,
                LastDetectedAtUtc = now,
                NextRetryAtUtc = status == "Open"
                    ? now.AddMinutes(Math.Max(5, options.Value.EconomyReconciliationRetryDelayMinutes))
                    : null,
                ResolvedAtUtc = status == "Resolved" ? now : null,
                AutoFixApplied = autoFixApplied,
                LastError = NormalizeIncidentError(lastError)
            };
            dbContext.EconomyIncidents.Add(incident);
            stats.IncidentsCreated++;
        }
        else
        {
            incident.Type = type;
            incident.Severity = severity;
            incident.Status = status;
            incident.UserId = userId ?? incident.UserId;
            incident.PurchaseOrderId = purchaseOrderId ?? incident.PurchaseOrderId;
            incident.UserSubscriptionId = userSubscriptionId ?? incident.UserSubscriptionId;
            incident.Provider = provider ?? incident.Provider;
            incident.ExternalReferenceId = externalReferenceId ?? incident.ExternalReferenceId;
            incident.Summary = summary;
            incident.DetailsJson = details is null
                ? incident.DetailsJson
                : SerializeSafeIncidentDetails(details, maxChars: 32000);
            incident.DetectionCount += 1;
            incident.RetryCount += status == "Open" ? 1 : 0;
            incident.LastDetectedAtUtc = now;
            incident.NextRetryAtUtc = status == "Open"
                ? now.AddMinutes(Math.Max(5, options.Value.EconomyReconciliationRetryDelayMinutes))
                : null;
            incident.ResolvedAtUtc = status == "Resolved" ? now : incident.ResolvedAtUtc;
            incident.AutoFixApplied = incident.AutoFixApplied || autoFixApplied;
            incident.LastError = NormalizeIncidentError(lastError) ?? incident.LastError;
            stats.IncidentsUpdated++;
        }

        if (status == "Resolved")
        {
            stats.IncidentsResolved++;
        }
        else
        {
            stats.ManualReviewRequired++;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<bool> HasPackPurchaseLedgerAsync(PurchaseOrder order, CancellationToken cancellationToken)
    {
        var reason = $"purchase:{order.Id:D}";
        return await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == order.UserId
                    && x.Source == WalletLedgerSource.PackPurchase
                    && (x.Reason == reason
                        || (!string.IsNullOrWhiteSpace(order.ExternalPaymentId)
                            && x.SourceProvider == order.PaymentProvider
                            && x.SourceTransactionId == order.ExternalPaymentId)),
                cancellationToken);
    }

    private static Guid? TryParsePurchaseOrderIdFromReason(string? reason)
    {
        const string prefix = "purchase:";
        if (string.IsNullOrWhiteSpace(reason) || !reason.StartsWith(prefix, StringComparison.Ordinal))
        {
            return null;
        }

        return Guid.TryParse(reason[prefix.Length..], out var orderId) ? orderId : null;
    }

    private static Guid? TryParseGenerationSpendIdFromReason(string? reason)
    {
        return TryParseGuidFromReason(reason, "template_generation:");
    }

    private static Guid? TryParseGenerationRefundIdFromReason(string? reason)
    {
        return TryParseGuidFromReason(reason, "generation_refund:");
    }

    private static Guid? TryParseGuidFromReason(string? reason, string prefix)
    {
        if (string.IsNullOrWhiteSpace(reason) || !reason.StartsWith(prefix, StringComparison.Ordinal))
        {
            return null;
        }

        return Guid.TryParse(reason[prefix.Length..], out var id) ? id : null;
    }

    private static bool IsTerminalFailedGenerationStatus(string status)
    {
        return string.Equals(status, "Failed", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Cancelled", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsActiveGenerationStatus(string status)
    {
        return string.Equals(status, "Queued", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Processing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Retrying", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "SubmittingToProvider", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "ProviderQueued", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "ProviderProcessing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "ImportingMedia", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsGenerationBillingIncidentType(string type)
    {
        return type is EconomyIncidentType.GenerationChargeMarkerMissing
            or EconomyIncidentType.GenerationLedgerSpendMissing
            or EconomyIncidentType.GenerationRefundMissing
            or EconomyIncidentType.GenerationRefundMarkerMissing
            or EconomyIncidentType.GenerationRefundLedgerMissing
            or EconomyIncidentType.GenerationRefundWithoutSpend
            or EconomyIncidentType.GenerationDuplicateLedgerMutation
            or EconomyIncidentType.GenerationBillingPendingStale
            or EconomyIncidentType.GenerationBillingJobMissing;
    }

    private static bool IsPremiumLikeStatus(string? status)
    {
        return string.Equals(status, "Active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Trialing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "GracePeriod", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "PastDue", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase);
    }

    private static string? NormalizeIncidentStatusFilter(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
        {
            return null;
        }

        return status.Trim().ToLowerInvariant() switch
        {
            "open" => "Open",
            "resolved" => "Resolved",
            "suppressed" => "Suppressed",
            _ => null
        };
    }

    private static string? NormalizeIncidentCategoryFilter(string? category)
    {
        if (string.IsNullOrWhiteSpace(category))
        {
            return null;
        }

        return category.Trim().ToLowerInvariant() switch
        {
            "pending" => "pending",
            "failed" => "failed",
            "disputed" => "disputed",
            "refund_pending" => "refund_pending",
            "settlement_failed" => "settlement_failed",
            "webhook_failed" => "webhook_failed",
            "reconciliation_required" => "reconciliation_required",
            "manual_review_required" => "manual_review_required",
            "resolved" => "resolved",
            _ => null
        };
    }

    private static IQueryable<EconomyIncident> ApplyIncidentCategoryFilter(
        IQueryable<EconomyIncident> query,
        string category)
    {
        return category switch
        {
            "pending" => query.Where(x => x.Status == "Open" && x.NextRetryAtUtc != null),
            "failed" => query.Where(x => x.LastError != null || x.Type == EconomyIncidentType.ProviderStateMismatch),
            "disputed" => query.Where(x => x.Type == EconomyIncidentType.ProviderStateMismatch || x.Type == EconomyIncidentType.LedgerWalletMismatch),
            "refund_pending" => query.Where(x => x.Type == EconomyIncidentType.RefundRequiresManualReview || x.Type == EconomyIncidentType.ManualReviewRequired),
            "settlement_failed" => query.Where(x => x.Type == EconomyIncidentType.PurchaseSettlementFailed || x.Type == EconomyIncidentType.PurchasePaidButNotCredited),
            "webhook_failed" => query.Where(x => x.Type == EconomyIncidentType.WebhookProcessingFailed),
            "reconciliation_required" => query.Where(x => x.Status == "Open" && x.Type != EconomyIncidentType.ManualReviewRequired),
            "manual_review_required" => query.Where(x => x.Type == EconomyIncidentType.ManualReviewRequired || x.Type == EconomyIncidentType.RefundRequiresManualReview),
            "resolved" => query.Where(x => x.Status == "Resolved"),
            _ => query
        };
    }

    private static string? NormalizeIncidentResolutionNote(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return null;
        }

        return SafeLogValues.SanitizeText(trimmed, 1000);
    }

    private static string? NormalizeIncidentError(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return null;
        }

        return SafeLogValues.SanitizeText(trimmed, 1000);
    }

    private static AdminEconomyIncidentResponse ToAdminEconomyIncidentResponse(EconomyIncident incident)
    {
        return new AdminEconomyIncidentResponse(
            incident.Id,
            incident.Type,
            ResolveIncidentCategory(incident),
            incident.Severity,
            incident.Status,
            incident.UserId,
            incident.PurchaseOrderId,
            incident.UserSubscriptionId,
            incident.Provider,
            incident.ExternalReferenceId,
            incident.Summary,
            incident.DetectionCount,
            incident.RetryCount,
            incident.AutoFixApplied,
            incident.FirstDetectedAtUtc,
            incident.LastDetectedAtUtc,
            incident.NextRetryAtUtc,
            incident.ResolvedAtUtc,
            incident.ResolutionNote,
            incident.LastError);
    }

    private static string ResolveIncidentCategory(EconomyIncident incident)
    {
        if (string.Equals(incident.Status, "Resolved", StringComparison.OrdinalIgnoreCase))
        {
            return "resolved";
        }

        return incident.Type switch
        {
            EconomyIncidentType.WebhookProcessingFailed => "webhook_failed",
            EconomyIncidentType.PurchaseSettlementFailed or EconomyIncidentType.PurchasePaidButNotCredited => "settlement_failed",
            EconomyIncidentType.RefundRequiresManualReview => "manual_review_required",
            EconomyIncidentType.SubscriptionStateMismatch or EconomyIncidentType.PremiumEntitlementMismatch => "reconciliation_required",
            EconomyIncidentType.LedgerWalletMismatch or EconomyIncidentType.ProviderStateMismatch => "disputed",
            EconomyIncidentType.ManualReviewRequired => "manual_review_required",
            _ when IsGenerationBillingIncidentType(incident.Type) => "reconciliation_required",
            _ => incident.NextRetryAtUtc.HasValue ? "pending" : "failed"
        };
    }

    private sealed class ReconciliationStats(DateTime startedAtUtc)
    {
        public DateTime StartedAtUtc { get; } = startedAtUtc;

        public int ChecksRun { get; set; }

        public int IncidentsCreated { get; set; }

        public int IncidentsUpdated { get; set; }

        public int IncidentsResolved { get; set; }

        public int AutoFixesApplied { get; set; }

        public int ManualReviewRequired { get; set; }
    }
}
