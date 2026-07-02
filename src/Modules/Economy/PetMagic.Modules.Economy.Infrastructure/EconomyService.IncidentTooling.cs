using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private const int IncidentDetailLedgerLimit = 25;
    private const int IncidentDetailWebhookLimit = 10;
    private const int IncidentDetailAuditLimit = 50;

    public async Task<Result<AdminEconomyIncidentDetailResponse>> GetAdminEconomyIncidentAsync(
        Guid incidentId,
        CancellationToken cancellationToken)
    {
        var incident = await dbContext.EconomyIncidents
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == incidentId, cancellationToken);
        if (incident is null)
        {
            return Result.Failure<AdminEconomyIncidentDetailResponse>(EconomyErrors.EconomyIncidentNotFound);
        }

        return Result.Success(await BuildIncidentDetailAsync(incident, cancellationToken));
    }

    public async Task<Result<AdminEconomyIncidentResponse>> ReopenAdminEconomyIncidentAsync(
        Guid incidentId,
        string reason,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(reason))
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
        incident.Status = "Open";
        incident.ResolvedAtUtc = null;
        incident.ResolutionNote = null;
        incident.LastDetectedAtUtc = DateTime.UtcNow;
        incident.NextRetryAtUtc = DateTime.UtcNow.AddMinutes(Math.Max(5, options.Value.EconomyReconciliationRetryDelayMinutes));

        await AppendIncidentAuditAsync(
            incident,
            "reopen_incident",
            reason,
            oldStatus,
            incident.Status,
            new { incident.Type, incident.PurchaseOrderId, incident.UserSubscriptionId },
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.reopened", oldStatus, incident.Status, reason, cancellationToken);

        return Result.Success(ToAdminEconomyIncidentResponse(incident));
    }

    public async Task<Result<AdminEconomyIncidentActionResponse>> ApplyAdminEconomyIncidentActionAsync(
        AdminEconomyIncidentActionCommand command,
        CancellationToken cancellationToken)
    {
        var action = NormalizeIncidentAction(command.Action);
        if (string.IsNullOrWhiteSpace(command.Reason))
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.EconomyIncidentActionReasonRequired);
        }

        var incident = await dbContext.EconomyIncidents
            .FirstOrDefaultAsync(x => x.Id == command.IncidentId, cancellationToken);
        if (incident is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.EconomyIncidentNotFound);
        }

        return action switch
        {
            "retry_webhook_processing" => await RetryIncidentWebhookProcessingAsync(incident, command.Reason, cancellationToken),
            "retry_settlement" => await RetryIncidentSettlementAsync(incident, command.Reason, cancellationToken),
            "manual_settle" => await ManualSettleIncidentPurchaseAsync(incident, command.Reason, cancellationToken),
            "manual_revoke" => await ManualRevokeIncidentTokensAsync(incident, command, cancellationToken),
            "manual_refund_mark" => await ManualMarkIncidentRefundAsync(incident, command, cancellationToken),
            "manual_bonus_grant" => await ManualBonusGrantIncidentAsync(incident, command, cancellationToken),
            "manual_wallet_correction" => await ManualWalletCorrectionIncidentAsync(incident, command, cancellationToken),
            "restore_generation_charge_marker" => await RestoreGenerationChargeMarkerIncidentAsync(incident, command.Reason, cancellationToken),
            "refund_generation_spend" => await RefundGenerationSpendIncidentAsync(incident, command.Reason, cancellationToken),
            "resolve_incident" => await ResolveIncidentFromActionAsync(incident, command.Reason, cancellationToken),
            "reopen_incident" => await ReopenIncidentFromActionAsync(incident, command.Reason, cancellationToken),
            _ => Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.EconomyIncidentActionInvalid)
        };
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> RetryIncidentWebhookProcessingAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        var oldRetryCount = incident.RetryCount;
        var reconciliation = await RunEconomyReconciliationAsync(cancellationToken);
        if (reconciliation.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(reconciliation.Error);
        }

        await dbContext.Entry(incident).ReloadAsync(cancellationToken);
        incident.RetryCount = Math.Max(incident.RetryCount, oldRetryCount + 1);
        incident.NextRetryAtUtc = DateTime.UtcNow.AddMinutes(Math.Max(5, options.Value.EconomyReconciliationRetryDelayMinutes));
        await AppendIncidentAuditAsync(
            incident,
            "retry_webhook_processing",
            reason,
            incident.Status,
            incident.Status,
            reconciliation.Value,
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.retry_webhook_processing", incident.Status, incident.Status, reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "retry_webhook_processing",
            "Local webhook reconciliation retry completed."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> RetryIncidentSettlementAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        var reconciliation = await RunEconomyReconciliationAsync(cancellationToken);
        if (reconciliation.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(reconciliation.Error);
        }

        await dbContext.Entry(incident).ReloadAsync(cancellationToken);
        await AppendIncidentAuditAsync(
            incident,
            "retry_settlement",
            reason,
            incident.Status,
            incident.Status,
            reconciliation.Value,
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.retry_settlement", incident.Status, incident.Status, reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "retry_settlement",
            "Local settlement reconciliation retry completed."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ManualSettleIncidentPurchaseAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        if (!incident.PurchaseOrderId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PurchaseNotFound);
        }

        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == incident.PurchaseOrderId.Value, cancellationToken);
        if (order is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PurchaseNotFound);
        }

        var oldOrderStatus = order.Status;
        if (!string.Equals(order.Status, PurchaseOrderStatus.Pending, StringComparison.Ordinal)
            && !string.Equals(order.Status, PurchaseOrderStatus.Failed, StringComparison.Ordinal))
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PurchaseAlreadyProcessed);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Failed, StringComparison.Ordinal))
        {
            order.Status = PurchaseOrderStatus.Pending;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var settled = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (settled.IsFailure && !string.Equals(settled.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(settled.Error);
        }

        await dbContext.Entry(incident).ReloadAsync(cancellationToken);
        await ResolveIncidentWithAuditAsync(
            incident,
            "manual_settle",
            reason,
            new { oldOrderStatus, newOrderStatus = PurchaseOrderStatus.Succeeded, order.Id },
            cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.manual_settle", oldOrderStatus, PurchaseOrderStatus.Succeeded, reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "manual_settle",
            "Purchase was manually settled locally."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ManualRevokeIncidentTokensAsync(
        EconomyIncident incident,
        AdminEconomyIncidentActionCommand command,
        CancellationToken cancellationToken)
    {
        var amount = Math.Abs(command.Amount ?? 0);
        if (amount <= 0)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidAmount);
        }

        var userId = await ResolveIncidentUserIdAsync(incident, cancellationToken);
        if (!userId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidSubject);
        }

        var mutation = await ApplyManualWalletMutationAsync(
            incident,
            userId.Value,
            -amount,
            WalletLedgerSource.AdminDebit,
            "manual_revoke",
            command.Reason,
            cancellationToken);
        if (mutation.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(mutation.Error);
        }

        await ResolveIncidentWithAuditAsync(
            incident,
            "manual_revoke",
            command.Reason,
            new { userId, amount, mutation.Value.NewBalance },
            cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.manual_revoke", null, mutation.Value.NewBalance.ToString(), command.Reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "manual_revoke",
            "Tokens were manually revoked locally."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ManualMarkIncidentRefundAsync(
        EconomyIncident incident,
        AdminEconomyIncidentActionCommand command,
        CancellationToken cancellationToken)
    {
        if (!incident.PurchaseOrderId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PurchaseNotFound);
        }

        if (string.IsNullOrWhiteSpace(command.ExternalReferenceId))
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == incident.PurchaseOrderId.Value, cancellationToken);
        if (order is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.PurchaseNotFound);
        }

        var oldStatus = order.Status;
        order.Status = PurchaseOrderStatus.Refunded;
        await dbContext.SaveChangesAsync(cancellationToken);

        await ResolveIncidentWithAuditAsync(
            incident,
            "manual_refund_mark",
            command.Reason,
            new { oldStatus, newStatus = order.Status, externalRefundId = command.ExternalReferenceId },
            cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.manual_refund_mark", oldStatus, order.Status, command.Reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "manual_refund_mark",
            "Purchase was marked refunded locally after operator review."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ManualBonusGrantIncidentAsync(
        EconomyIncident incident,
        AdminEconomyIncidentActionCommand command,
        CancellationToken cancellationToken)
    {
        var amount = command.Amount ?? 0;
        if (amount <= 0)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidAmount);
        }

        var userId = await ResolveIncidentUserIdAsync(incident, cancellationToken);
        if (!userId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidSubject);
        }

        var mutation = await ApplyManualWalletMutationAsync(
            incident,
            userId.Value,
            amount,
            WalletLedgerSource.AdminGrant,
            "manual_bonus_grant",
            command.Reason,
            cancellationToken);
        if (mutation.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(mutation.Error);
        }

        await AppendIncidentAuditAsync(
            incident,
            "manual_bonus_grant",
            command.Reason,
            incident.Status,
            incident.Status,
            new { userId, amount, mutation.Value.NewBalance },
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.manual_bonus_grant", null, mutation.Value.NewBalance.ToString(), command.Reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "manual_bonus_grant",
            "Manual bonus grant was applied."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ManualWalletCorrectionIncidentAsync(
        EconomyIncident incident,
        AdminEconomyIncidentActionCommand command,
        CancellationToken cancellationToken)
    {
        var amount = command.Amount ?? 0;
        if (amount == 0)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidAmount);
        }

        var userId = await ResolveIncidentUserIdAsync(incident, cancellationToken);
        if (!userId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidSubject);
        }

        var source = amount > 0 ? WalletLedgerSource.AdminGrant : WalletLedgerSource.AdminDebit;
        var mutation = await ApplyManualWalletMutationAsync(
            incident,
            userId.Value,
            amount,
            source,
            "manual_wallet_correction",
            command.Reason,
            cancellationToken);
        if (mutation.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(mutation.Error);
        }

        await AppendIncidentAuditAsync(
            incident,
            "manual_wallet_correction",
            command.Reason,
            incident.Status,
            incident.Status,
            new { userId, amount, mutation.Value.NewBalance },
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.manual_wallet_correction", null, mutation.Value.NewBalance.ToString(), command.Reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "manual_wallet_correction",
            "Manual wallet correction was applied."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> RestoreGenerationChargeMarkerIncidentAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        if (_generationBillingReconciliation is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.GenerationBillingReconciliationUnavailable);
        }

        var generationId = ResolveIncidentGenerationId(incident);
        if (!generationId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidSubject);
        }

        var spend = await LoadPrimaryGenerationSpendLedgerAsync(generationId.Value, cancellationToken);
        if (spend is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.GenerationBillingLedgerNotFound);
        }

        var restore = await _generationBillingReconciliation.RestoreGenerationChargeMarkerAsync(
            generationId.Value,
            spend.CreatedAtUtc,
            reason,
            cancellationToken);
        if (restore.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(restore.Error);
        }

        await ResolveIncidentWithAuditAsync(
            incident,
            "restore_generation_charge_marker",
            reason,
            new
            {
                generationId,
                spendEntryId = spend.Id,
                chargedAtUtc = restore.Value.ChargedAtUtc,
                restore.Value.Status
            },
            cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.restore_generation_charge_marker", null, restore.Value.Status, reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "restore_generation_charge_marker",
            "Generation charge marker was restored from wallet ledger."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> RefundGenerationSpendIncidentAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        if (_generationBillingReconciliation is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.GenerationBillingReconciliationUnavailable);
        }

        var generationId = ResolveIncidentGenerationId(incident);
        if (!generationId.HasValue)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.InvalidSubject);
        }

        var spend = await LoadPrimaryGenerationSpendLedgerAsync(generationId.Value, cancellationToken);
        if (spend is null)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(EconomyErrors.GenerationBillingLedgerNotFound);
        }

        var refund = await CreditAsync(
            new CreditBalanceCommand(
                spend.UserId,
                Math.Abs(spend.Delta),
                WalletLedgerSource.GenerationRefund,
                BuildGenerationRefundReason(generationId.Value),
                BuildGenerationRefundReason(generationId.Value)),
            cancellationToken);
        if (refund.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(refund.Error);
        }

        var marker = await _generationBillingReconciliation.MarkGenerationRefundedAsync(
            generationId.Value,
            refund.Value.OccurredAtUtc,
            reason,
            cancellationToken);
        if (marker.IsFailure
            && !string.Equals(marker.Error.Code, "GENERATION_JOB_NOT_FOUND", StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(marker.Error);
        }

        await ResolveIncidentWithAuditAsync(
            incident,
            "refund_generation_spend",
            reason,
            new
            {
                generationId,
                spendEntryId = spend.Id,
                refund.Value.Delta,
                refund.Value.NewBalance,
                markerUpdated = marker.IsSuccess
            },
            cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.refund_generation_spend", null, refund.Value.NewBalance.ToString(), reason, cancellationToken);

        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "refund_generation_spend",
            "Generation spend was refunded idempotently."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ResolveIncidentFromActionAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        await ResolveIncidentWithAuditAsync(incident, "resolve_incident", reason, new { incident.Type }, cancellationToken);
        await WriteAdminAuditAsync(incident, "admin.economy.incident.resolved", "Open", "Resolved", reason, cancellationToken);
        return Result.Success(new AdminEconomyIncidentActionResponse(
            ToAdminEconomyIncidentResponse(incident),
            "resolve_incident",
            "Incident was resolved."));
    }

    private async Task<Result<AdminEconomyIncidentActionResponse>> ReopenIncidentFromActionAsync(
        EconomyIncident incident,
        string reason,
        CancellationToken cancellationToken)
    {
        var reopened = await ReopenAdminEconomyIncidentAsync(incident.Id, reason, cancellationToken);
        if (reopened.IsFailure)
        {
            return Result.Failure<AdminEconomyIncidentActionResponse>(reopened.Error);
        }

        return Result.Success(new AdminEconomyIncidentActionResponse(
            reopened.Value,
            "reopen_incident",
            "Incident was reopened."));
    }

    private async Task<Result<WalletOperationResponse>> ApplyManualWalletMutationAsync(
        EconomyIncident incident,
        Guid userId,
        int amount,
        string source,
        string action,
        string reason,
        CancellationToken cancellationToken)
    {
        return await ExecuteWalletSerializableMutationWithRetryAsync(
            "admin_manual_wallet_mutation",
            ct => ApplyManualWalletMutationOnceAsync(incident, userId, amount, source, action, reason, ct),
            cancellationToken);
    }

    private async Task<Result<WalletOperationResponse>> ApplyManualWalletMutationOnceAsync(
        EconomyIncident incident,
        Guid userId,
        int amount,
        string source,
        string action,
        string reason,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginWalletSerializableTransactionAsync(cancellationToken);
        var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
        var now = DateTime.UtcNow;
        var sourceTransactionId = $"incident:{incident.Id:D}:{action}";
        var mutation = await ApplyWalletMutationAsync(
            wallet,
            amount,
            source,
            $"{action}:{incident.Id:D}:{NormalizeIncidentReasonForLedger(reason)}",
            now,
            cancellationToken,
            InternalWalletMutationProvider,
            sourceTransactionId);
        if (mutation.IsFailure)
        {
            return Result.Failure<WalletOperationResponse>(mutation.Error);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return Result.Success(mutation.Value.Response);
    }

    private async Task ResolveIncidentWithAuditAsync(
        EconomyIncident incident,
        string action,
        string reason,
        object details,
        CancellationToken cancellationToken)
    {
        var oldStatus = incident.Status;
        incident.Status = "Resolved";
        incident.ResolvedAtUtc = DateTime.UtcNow;
        incident.ResolutionNote = NormalizeIncidentResolutionNote(reason);
        incident.LastDetectedAtUtc = DateTime.UtcNow;
        incident.NextRetryAtUtc = null;
        await AppendIncidentAuditAsync(incident, action, reason, oldStatus, incident.Status, details, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<Guid?> ResolveIncidentUserIdAsync(EconomyIncident incident, CancellationToken cancellationToken)
    {
        if (incident.UserId.HasValue)
        {
            return incident.UserId.Value;
        }

        if (incident.PurchaseOrderId.HasValue)
        {
            return await dbContext.PurchaseOrders
                .AsNoTracking()
                .Where(x => x.Id == incident.PurchaseOrderId.Value)
                .Select(x => (Guid?)x.UserId)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (incident.UserSubscriptionId.HasValue)
        {
            return await dbContext.UserSubscriptions
                .AsNoTracking()
                .Where(x => x.Id == incident.UserSubscriptionId.Value)
                .Select(x => (Guid?)x.UserId)
                .FirstOrDefaultAsync(cancellationToken);
        }

        return null;
    }

    private async Task<AdminEconomyIncidentDetailResponse> BuildIncidentDetailAsync(
        EconomyIncident incident,
        CancellationToken cancellationToken)
    {
        var userId = await ResolveIncidentUserIdAsync(incident, cancellationToken);
        var purchase = await LoadIncidentPurchaseAsync(incident, cancellationToken);
        var subscription = await LoadIncidentSubscriptionAsync(incident, cancellationToken);
        var generation = await LoadIncidentGenerationAsync(incident, cancellationToken);
        var wallet = userId.HasValue
            ? await dbContext.Wallets
                .AsNoTracking()
                .Where(x => x.UserId == userId.Value)
                .Select(x => new AdminEconomyIncidentWalletResponse(x.UserId, x.Balance, x.UpdatedAtUtc))
                .FirstOrDefaultAsync(cancellationToken)
            : null;
        var ledger = await LoadIncidentLedgerAsync(incident, userId, cancellationToken);
        var webhooks = await LoadIncidentWebhookSnapshotsAsync(incident, userId, cancellationToken);
        var audit = await dbContext.EconomyIncidentAuditEntries
            .AsNoTracking()
            .Where(x => x.IncidentId == incident.Id)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(IncidentDetailAuditLimit)
            .Select(x => new AdminEconomyIncidentAuditEntryResponse(
                x.Id,
                x.Action,
                x.Reason,
                x.OldStatus,
                x.NewStatus,
                x.DetailsJson,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return new AdminEconomyIncidentDetailResponse(
            ToAdminEconomyIncidentResponse(incident),
            purchase,
            subscription,
            wallet,
            generation,
            ledger,
            webhooks,
            audit);
    }

    private async Task<PurchaseHistoryItemResponse?> LoadIncidentPurchaseAsync(
        EconomyIncident incident,
        CancellationToken cancellationToken)
    {
        if (!incident.PurchaseOrderId.HasValue)
        {
            return null;
        }

        var row = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.Id == incident.PurchaseOrderId.Value)
            .GroupJoin(
                dbContext.CurrencyPacks.AsNoTracking(),
                order => order.PackId,
                pack => pack.Id,
                (order, packs) => new { order, packs })
            .SelectMany(
                x => x.packs.DefaultIfEmpty(),
                (x, pack) => new { x.order, pack })
            .FirstOrDefaultAsync(cancellationToken);

        return row is null ? null : ToPurchaseHistoryItem(row.order, row.pack);
    }

    private async Task<AdminUserSubscriptionResponse?> LoadIncidentSubscriptionAsync(
        EconomyIncident incident,
        CancellationToken cancellationToken)
    {
        if (!incident.UserSubscriptionId.HasValue)
        {
            return null;
        }

        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.Id == incident.UserSubscriptionId.Value)
            .GroupJoin(
                dbContext.SubscriptionPlans.AsNoTracking(),
                subscription => subscription.PlanId,
                plan => plan.Id,
                (subscription, plans) => new { subscription, plans })
            .SelectMany(
                x => x.plans.DefaultIfEmpty(),
                (x, plan) => new AdminUserSubscriptionResponse(
                    x.subscription.Id,
                    x.subscription.UserId,
                    x.subscription.Provider,
                    x.subscription.PurchaseChannel,
                    x.subscription.Region,
                    x.subscription.PlanId,
                    plan != null ? plan.Name : null,
                    x.subscription.Status,
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
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<AdminEconomyIncidentGenerationResponse?> LoadIncidentGenerationAsync(
        EconomyIncident incident,
        CancellationToken cancellationToken)
    {
        if (_generationBillingReconciliation is null)
        {
            return null;
        }

        var generationId = ResolveIncidentGenerationId(incident);
        if (!generationId.HasValue)
        {
            return null;
        }

        var snapshot = await _generationBillingReconciliation.GetGenerationBillingSnapshotAsync(
            generationId.Value,
            cancellationToken);
        if (snapshot.IsFailure)
        {
            return null;
        }

        return new AdminEconomyIncidentGenerationResponse(
            snapshot.Value.GenerationId,
            snapshot.Value.UserId,
            snapshot.Value.TokenCost,
            snapshot.Value.Status,
            snapshot.Value.CreatedAtUtc,
            snapshot.Value.UpdatedAtUtc,
            snapshot.Value.ChargedAtUtc,
            snapshot.Value.RefundedAtUtc,
            snapshot.Value.RefundAttemptCount,
            snapshot.Value.RefundLastErrorCode,
            snapshot.Value.RefundLastAttemptedAtUtc,
            snapshot.Value.CompletedAtUtc,
            snapshot.Value.LastErrorCode,
            snapshot.Value.IdempotencyKey,
            snapshot.Value.RequestHash);
    }

    private async Task<IReadOnlyList<WalletLedgerItemResponse>> LoadIncidentLedgerAsync(
        EconomyIncident incident,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var query = dbContext.WalletLedgerEntries.AsNoTracking().AsQueryable();
        var hasSelector = false;
        if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
            hasSelector = true;
        }

        if (incident.PurchaseOrderId.HasValue)
        {
            var purchaseReason = $"purchase:{incident.PurchaseOrderId.Value:D}";
            var refundReason = $"purchase_refund:{incident.PurchaseOrderId.Value:D}";
            query = query.Where(x => x.Reason == purchaseReason || x.Reason == refundReason || x.SourceTransactionId == incident.ExternalReferenceId);
            hasSelector = true;
        }
        else if (ResolveIncidentGenerationId(incident) is Guid generationId)
        {
            var spendReason = BuildGenerationSpendReason(generationId);
            var refundReason = BuildGenerationRefundReason(generationId);
            query = query.Where(x => x.Reason == spendReason || x.Reason == refundReason);
            hasSelector = true;
        }
        else if (!string.IsNullOrWhiteSpace(incident.ExternalReferenceId))
        {
            query = query.Where(x => x.SourceTransactionId == incident.ExternalReferenceId);
            hasSelector = true;
        }

        if (!hasSelector)
        {
            return [];
        }

        return await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(IncidentDetailLedgerLimit)
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
    }

    private async Task<IReadOnlyList<AdminEconomyIncidentWebhookSnapshotResponse>> LoadIncidentWebhookSnapshotsAsync(
        EconomyIncident incident,
        Guid? userId,
        CancellationToken cancellationToken)
    {
        var query = dbContext.SubscriptionEventLogs.AsNoTracking().AsQueryable();
        var hasSelector = false;
        if (incident.UserSubscriptionId.HasValue)
        {
            query = query.Where(x => x.UserSubscriptionId == incident.UserSubscriptionId.Value);
            hasSelector = true;
        }
        else if (userId.HasValue)
        {
            query = query.Where(x => x.UserId == userId.Value);
            hasSelector = true;
        }

        if (!string.IsNullOrWhiteSpace(incident.Provider))
        {
            query = query.Where(x => x.Provider == incident.Provider);
        }

        if (!string.IsNullOrWhiteSpace(incident.ExternalReferenceId))
        {
            query = query.Where(x => x.ExternalEventId == incident.ExternalReferenceId
                || x.ExternalSubscriptionId == incident.ExternalReferenceId);
            hasSelector = true;
        }

        if (!hasSelector)
        {
            return [];
        }

        var rows = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(IncidentDetailWebhookLimit)
            .ToListAsync(cancellationToken);

        return rows
            .Select(x => new AdminEconomyIncidentWebhookSnapshotResponse(
                x.Id,
                x.UserId,
                x.UserSubscriptionId,
                x.Provider,
                x.EventType,
                x.Status,
                x.ExternalEventId,
                SanitizeWebhookPayloadSnapshot(x.PayloadJson),
                x.CreatedAtUtc,
                x.ProcessedAtUtc))
            .ToList();
    }

    private async Task AppendIncidentAuditAsync(
        EconomyIncident incident,
        string action,
        string reason,
        string? oldStatus,
        string? newStatus,
        object? details,
        CancellationToken cancellationToken)
    {
        dbContext.EconomyIncidentAuditEntries.Add(new EconomyIncidentAuditEntry
        {
            Id = Guid.NewGuid(),
            IncidentId = incident.Id,
            Action = action,
            Reason = NormalizeIncidentResolutionNote(reason) ?? string.Empty,
            OldStatus = oldStatus,
            NewStatus = newStatus,
            DetailsJson = details is null ? null : Truncate(JsonSerializer.Serialize(details), 4000),
            CreatedAtUtc = DateTime.UtcNow
        });

        await Task.CompletedTask;
    }

    private async Task WriteAdminAuditAsync(
        EconomyIncident incident,
        string action,
        string? oldValue,
        string? newValue,
        string reason,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null)
        {
            return;
        }

        await adminAuditLog.WriteAsync(
            new AdminAuditEntry(
                action,
                "economy_incident",
                incident.Id.ToString("D"),
                oldValue,
                newValue,
                $"Reason: {NormalizeIncidentResolutionNote(reason)}",
                incident.UserId),
            cancellationToken);
    }

    private static string NormalizeIncidentAction(string action)
    {
        return action.Trim().ToLowerInvariant();
    }

    private static Guid? ResolveIncidentGenerationId(EconomyIncident incident)
    {
        return Guid.TryParse(incident.ExternalReferenceId, out var generationId)
            ? generationId
            : null;
    }

    private async Task<WalletLedgerEntry?> LoadPrimaryGenerationSpendLedgerAsync(
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var spendReason = BuildGenerationSpendReason(generationId);
        return await dbContext.WalletLedgerEntries
            .AsNoTracking()
            .Where(x => x.Source == WalletLedgerSource.GenerationSpend && x.Reason == spendReason)
            .OrderBy(x => x.CreatedAtUtc)
            .ThenBy(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private static string BuildGenerationSpendReason(Guid generationId)
    {
        return $"template_generation:{generationId:N}";
    }

    private static string BuildGenerationRefundReason(Guid generationId)
    {
        return $"generation_refund:{generationId:N}";
    }

    private static string NormalizeIncidentReasonForLedger(string reason)
    {
        var normalized = reason.Trim();
        return normalized.Length <= 120 ? normalized : normalized[..120];
    }

    private static string? SanitizeWebhookPayloadSnapshot(string? payloadJson)
    {
        if (string.IsNullOrWhiteSpace(payloadJson))
        {
            return null;
        }

        try
        {
            using var document = JsonDocument.Parse(payloadJson);
            var sanitized = SanitizeJsonElement(document.RootElement, depth: 0);
            return Truncate(JsonSerializer.Serialize(sanitized), 4000);
        }
        catch (JsonException)
        {
            return Truncate(payloadJson, 500);
        }
    }

    private static object? SanitizeJsonElement(JsonElement element, int depth)
    {
        if (depth > 4)
        {
            return "[truncated]";
        }

        return element.ValueKind switch
        {
            JsonValueKind.Object => element.EnumerateObject()
                .Take(40)
                .ToDictionary(
                    property => property.Name,
                    property => IsSensitivePayloadKey(property.Name)
                        ? "[redacted]"
                        : SanitizeJsonElement(property.Value, depth + 1)),
            JsonValueKind.Array => element.EnumerateArray()
                .Take(20)
                .Select(value => SanitizeJsonElement(value, depth + 1))
                .ToArray(),
            JsonValueKind.String => Truncate(element.GetString(), 240),
            JsonValueKind.Number => element.GetRawText(),
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            _ => null
        };
    }

    private static bool IsSensitivePayloadKey(string key)
    {
        var normalized = key.ToLowerInvariant();
        return normalized.Contains("secret", StringComparison.Ordinal)
            || normalized.Contains("token", StringComparison.Ordinal)
            || normalized.Contains("signature", StringComparison.Ordinal)
            || normalized.Contains("authorization", StringComparison.Ordinal)
            || normalized.Contains("credential", StringComparison.Ordinal)
            || normalized.Contains("password", StringComparison.Ordinal)
            || normalized.Contains("receipt", StringComparison.Ordinal)
            || normalized.Contains("signedpayload", StringComparison.Ordinal)
            || normalized.Contains("signedtransaction", StringComparison.Ordinal)
            || normalized.Contains("raw", StringComparison.Ordinal);
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength];
    }
}
