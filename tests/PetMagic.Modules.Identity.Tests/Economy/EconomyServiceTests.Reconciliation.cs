using System.Reflection;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForStalePendingPurchase()
    {
        await using var dbContext = CreateDbContext();

        var packId = AddStarterPack(dbContext);
        var userId = Guid.NewGuid();
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "cs_stale_pending",
            CreatedAtUtc = DateTime.UtcNow.AddHours(-2)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.IncidentsCreated);
        Assert.Equal(1, result.Value.ManualReviewRequired);

        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("PurchaseSettlementFailed", incident.Type);
        Assert.Equal("Open", incident.Status);
        Assert.Equal(userId, incident.UserId);
    }

    [Fact]
    public async Task EconomyIncidentDetails_ShouldSanitizeDurableSecrets()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var statsType = typeof(EconomyService).GetNestedType(
            "ReconciliationStats",
            BindingFlags.NonPublic);
        Assert.NotNull(statsType);
        var stats = Activator.CreateInstance(
            statsType,
            BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public,
            binder: null,
            args: [DateTime.UtcNow],
            culture: null);
        Assert.NotNull(stats);
        var upsertMethod = typeof(EconomyService).GetMethod(
            "UpsertEconomyIncidentAsync",
            BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(upsertMethod);

        var task = (Task)upsertMethod.Invoke(
            service,
            [
                "WebhookProcessingFailed",
                "Warning",
                "privacy:test-incident-details",
                "Synthetic privacy regression incident.",
                stats,
                "Open",
                null,
                null,
                null,
                "google_play",
                "evt_safe",
                new
                {
                    safe = "visible",
                    purchaseToken = "gp-token-secret",
                    signedPayload = "app-store-secret",
                    api_secret = "sk_live_hidden",
                    rawReceipt = "receipt-secret"
                },
                false,
                "provider failed with token=gp-token-secret api_secret=sk_live_hidden",
                CancellationToken.None
            ])!;
        await task;

        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.NotNull(incident.DetailsJson);
        Assert.Contains("visible", incident.DetailsJson);
        Assert.DoesNotContain("gp-token-secret", incident.DetailsJson);
        Assert.DoesNotContain("app-store-secret", incident.DetailsJson);
        Assert.DoesNotContain("sk_live_hidden", incident.DetailsJson);
        Assert.DoesNotContain("receipt-secret", incident.DetailsJson);
        Assert.DoesNotContain("gp-token-secret", incident.LastError);
        Assert.DoesNotContain("sk_live_hidden", incident.LastError);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldRestoreMissingPurchaseLedger()
    {
        await using var dbContext = CreateDbContext();

        var packId = AddStarterPack(dbContext);
        var userId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "cs_missing_ledger",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-20),
            ConfirmedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.AutoFixesApplied);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        Assert.Equal(120, wallet.Balance);
        var ledger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal(WalletLedgerSource.PackPurchase, ledger.Source);
        Assert.Equal($"purchase:{orderId:D}", ledger.Reason);

        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("PurchasePaidButNotCredited", incident.Type);
        Assert.Equal("Resolved", incident.Status);
        Assert.True(incident.AutoFixApplied);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForGenerationSpendWithoutChargeMarker()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 30);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 30,
            status: "Queued",
            chargedAtUtc: null);

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationChargeMarkerMissing", incident.Type);
        Assert.Equal("Critical", incident.Severity);
        Assert.Equal(generationId.ToString("D"), incident.ExternalReferenceId);
        Assert.Equal(userId, incident.UserId);
    }

    [Fact]
    public async Task ApplyAdminEconomyIncidentActionAsync_ShouldRestoreGenerationChargeMarker()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var spend = AddGenerationSpendLedger(dbContext, userId, generationId, 25);
        var incidentId = Guid.NewGuid();
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "GenerationChargeMarkerMissing",
            Severity = "Critical",
            Status = "Open",
            DeduplicationKey = $"generation_billing:charge_marker_missing:{generationId:D}",
            UserId = userId,
            ExternalReferenceId = generationId.ToString("D"),
            Summary = "Generation has spend without marker.",
            DetectionCount = 1,
            RetryCount = 1,
            FirstDetectedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            LastDetectedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        });
        await dbContext.SaveChangesAsync();

        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 25,
            status: "Queued",
            chargedAtUtc: null);

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .ApplyAdminEconomyIncidentActionAsync(
                new AdminEconomyIncidentActionCommand(
                    incidentId,
                    "restore_generation_charge_marker",
                    "Spend exists and job is valid."),
                CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("Resolved", result.Value.Incident.Status);
        var restored = Assert.Single(generationBilling.RestoredChargeMarkers);
        Assert.Equal(generationId, restored.GenerationId);
        Assert.Equal(spend.CreatedAtUtc, restored.ChargedAtUtc);
        Assert.Single(await dbContext.EconomyIncidentAuditEntries.ToListAsync());
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForChargedGenerationWithoutSpend()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 40,
            status: "Processing",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-20));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationLedgerSpendMissing", incident.Type);
        Assert.Equal("Critical", incident.Severity);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForFailedChargedGenerationWithoutRefund()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 50);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 50,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-30),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-20));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationRefundMissing", incident.Type);
        Assert.Equal("Critical", incident.Severity);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForGenerationRefundWithoutSpend()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationRefundLedger(dbContext, userId, generationId, 45);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 45,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-25),
            refundedAtUtc: DateTime.UtcNow.AddMinutes(-10),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-15));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incidents = await dbContext.EconomyIncidents.ToListAsync();
        var incident = Assert.Single(incidents, x => x.Type == "GenerationRefundWithoutSpend");
        Assert.Equal("Critical", incident.Severity);
        Assert.Equal(generationId.ToString("D"), incident.ExternalReferenceId);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForGenerationRefundMarkerMissing()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 45);
        AddGenerationRefundLedger(dbContext, userId, generationId, 45);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 45,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-25),
            refundedAtUtc: null,
            completedAtUtc: DateTime.UtcNow.AddMinutes(-15));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationRefundMarkerMissing", incident.Type);
        Assert.Equal("Warning", incident.Severity);
        Assert.Equal(generationId.ToString("D"), incident.ExternalReferenceId);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForGenerationRefundLedgerMissing()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 45);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 45,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-25),
            refundedAtUtc: DateTime.UtcNow.AddMinutes(-10),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-15));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationRefundLedgerMissing", incident.Type);
        Assert.Equal("Critical", incident.Severity);
        Assert.Equal(generationId.ToString("D"), incident.ExternalReferenceId);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForDuplicateGenerationSpendLedger()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 30);
        AddGenerationSpendLedger(dbContext, userId, generationId, 30);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 30,
            status: "Completed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-20),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-10));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationDuplicateLedgerMutation", incident.Type);
        Assert.Equal("generation_billing:duplicate_spend:" + generationId.ToString("D"), incident.DeduplicationKey);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForDuplicateGenerationRefundLedger()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 30);
        AddGenerationRefundLedger(dbContext, userId, generationId, 30);
        AddGenerationRefundLedger(dbContext, userId, generationId, 30);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 30,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-25),
            refundedAtUtc: DateTime.UtcNow.AddMinutes(-10),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-15));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationDuplicateLedgerMutation", incident.Type);
        Assert.Equal("generation_billing:duplicate_refund:" + generationId.ToString("D"), incident.DeduplicationKey);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldCreateIncidentForStaleUnchargedGeneration()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 20,
            status: "Queued",
            createdAtUtc: DateTime.UtcNow.AddHours(-2),
            chargedAtUtc: null);

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("GenerationBillingPendingStale", incident.Type);
        Assert.Equal("Warning", incident.Severity);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldIgnoreCompletedChargedGenerationWithLedger()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 20);
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 20,
            status: "Completed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-20),
            completedAtUtc: DateTime.UtcNow.AddMinutes(-10));

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(await dbContext.EconomyIncidents.ToListAsync());
    }

    [Fact]
    public async Task ApplyAdminEconomyIncidentActionAsync_ShouldRefundGenerationSpendIdempotently()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        AddGenerationSpendLedger(dbContext, userId, generationId, 35);
        var incidentId = Guid.NewGuid();
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "GenerationRefundMissing",
            Severity = "Critical",
            Status = "Open",
            DeduplicationKey = $"generation_billing:refund_missing:{generationId:D}",
            UserId = userId,
            ExternalReferenceId = generationId.ToString("D"),
            Summary = "Generation refund missing.",
            DetectionCount = 1,
            RetryCount = 1,
            FirstDetectedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            LastDetectedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        });
        await dbContext.SaveChangesAsync();

        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 35,
            status: "Failed",
            chargedAtUtc: DateTime.UtcNow.AddMinutes(-20));
        var service = CreateService(dbContext, generationBillingReconciliation: generationBilling);

        var command = new AdminEconomyIncidentActionCommand(
            incidentId,
            "refund_generation_spend",
            "Generation cannot be recovered.");
        var first = await service.ApplyAdminEconomyIncidentActionAsync(command, CancellationToken.None);
        var second = await service.ApplyAdminEconomyIncidentActionAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Single(await dbContext.WalletLedgerEntries
            .Where(x => x.Source == WalletLedgerSource.GenerationRefund && x.Reason == $"generation_refund:{generationId:N}")
            .ToListAsync());
        Assert.Equal(2, generationBilling.RefundedMarkers.Count);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldIgnoreFreshGenerationCreatedBeforeSpend()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var generationBilling = new FakeGenerationBillingReconciliationService();
        generationBilling.Snapshots[generationId] = CreateGenerationSnapshot(
            generationId,
            userId,
            tokenCost: 20,
            status: "Queued",
            createdAtUtc: DateTime.UtcNow.AddMinutes(-1),
            chargedAtUtc: null);

        var result = await CreateService(
            dbContext,
            generationBillingReconciliation: generationBilling)
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(await dbContext.EconomyIncidents.ToListAsync());
    }

    [Fact]
    public async Task ResolveAdminEconomyIncidentAsync_ShouldCloseOpenIncident()
    {
        await using var dbContext = CreateDbContext();

        var incidentId = Guid.NewGuid();
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "ManualReviewRequired",
            Severity = "Warning",
            Status = "Open",
            DeduplicationKey = $"manual:{incidentId:D}",
            Summary = "Manual review required.",
            DetectionCount = 1,
            RetryCount = 1,
            FirstDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            LastDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            NextRetryAtUtc = DateTime.UtcNow.AddMinutes(25)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).ResolveAdminEconomyIncidentAsync(
            incidentId,
            "Checked by admin.",
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("Resolved", result.Value.Status);
        Assert.Equal("Checked by admin.", result.Value.ResolutionNote);

        var incident = await dbContext.EconomyIncidents.SingleAsync();
        Assert.Equal("Resolved", incident.Status);
        Assert.NotNull(incident.ResolvedAtUtc);
        Assert.Single(await dbContext.EconomyIncidentAuditEntries.ToListAsync());
    }

    [Fact]
    public async Task GetAdminEconomyIncidentAsync_ShouldReturnSafeWebhookSnapshot()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var subscriptionId = Guid.NewGuid();
        var incidentId = Guid.NewGuid();
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "WebhookProcessingFailed",
            Severity = "Warning",
            Status = "Open",
            DeduplicationKey = $"webhook:{incidentId:D}",
            UserId = userId,
            UserSubscriptionId = subscriptionId,
            Provider = "stripe",
            ExternalReferenceId = "evt_secret",
            Summary = "Webhook failed.",
            DetectionCount = 1,
            RetryCount = 1,
            FirstDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            LastDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        });
        dbContext.SubscriptionEventLogs.Add(new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscriptionId,
            Provider = "stripe",
            EventType = "invoice.payment_failed",
            Status = "Failed",
            ExternalEventId = "evt_secret",
            ExternalSubscriptionId = "sub_should_not_be_exposed",
            PayloadJson = """{"id":"evt_secret","api_secret":"sk_live_hidden","signedPayload":"private_payload","safe":"visible"}""",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-4),
            ProcessedAtUtc = null
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminEconomyIncidentAsync(incidentId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var snapshot = Assert.Single(result.Value.WebhookEvents);
        Assert.Contains("visible", snapshot.PayloadSnapshotJson);
        Assert.Contains("[redacted]", snapshot.PayloadSnapshotJson);
        Assert.DoesNotContain("sk_live_hidden", snapshot.PayloadSnapshotJson);
        Assert.DoesNotContain("private_payload", snapshot.PayloadSnapshotJson);
    }

    [Fact]
    public async Task ApplyAdminEconomyIncidentActionAsync_ShouldApplyManualBonusGrantAndWriteAudit()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var incidentId = Guid.NewGuid();
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "ManualReviewRequired",
            Severity = "Warning",
            Status = "Open",
            DeduplicationKey = $"manual:{incidentId:D}",
            UserId = userId,
            Summary = "Manual review required.",
            DetectionCount = 1,
            RetryCount = 1,
            FirstDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            LastDetectedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        });
        await dbContext.SaveChangesAsync();

        var auditLog = new RecordingAdminAuditLog();
        var result = await CreateService(dbContext, adminAuditLog: auditLog).ApplyAdminEconomyIncidentActionAsync(
            new AdminEconomyIncidentActionCommand(
                incidentId,
                "manual_bonus_grant",
                "Compensating missing settlement after support review.",
                Amount: 75),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("manual_bonus_grant", result.Value.Action);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        Assert.Equal(75, wallet.Balance);
        var ledger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal(WalletLedgerSource.AdminGrant, ledger.Source);
        Assert.Equal(75, ledger.Delta);
        Assert.Single(await dbContext.EconomyIncidentAuditEntries.ToListAsync());
        var auditEntry = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.economy.incident.manual_bonus_grant", auditEntry.Action);
    }

    private static WalletLedgerEntry AddGenerationSpendLedger(
        EconomyDbContext dbContext,
        Guid userId,
        Guid generationId,
        int amount)
    {
        var entry = new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = -amount,
            BalanceAfter = 100 - amount,
            Source = WalletLedgerSource.GenerationSpend,
            Reason = $"template_generation:{generationId:N}",
            TokenKind = "purchased",
            OperationKind = "debit",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        };
        dbContext.WalletLedgerEntries.Add(entry);
        dbContext.SaveChanges();
        return entry;
    }

    private static WalletLedgerEntry AddGenerationRefundLedger(
        EconomyDbContext dbContext,
        Guid userId,
        Guid generationId,
        int amount)
    {
        var entry = new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = amount,
            BalanceAfter = 100,
            Source = WalletLedgerSource.GenerationRefund,
            Reason = $"generation_refund:{generationId:N}",
            TokenKind = "purchased",
            OperationKind = "credit",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        };
        dbContext.WalletLedgerEntries.Add(entry);
        dbContext.SaveChanges();
        return entry;
    }

    private static GenerationBillingSnapshot CreateGenerationSnapshot(
        Guid generationId,
        Guid userId,
        int tokenCost,
        string status,
        DateTime? createdAtUtc = null,
        DateTime? chargedAtUtc = null,
        DateTime? refundedAtUtc = null,
        DateTime? completedAtUtc = null)
    {
        var created = createdAtUtc ?? DateTime.UtcNow.AddMinutes(-15);
        return new GenerationBillingSnapshot(
            generationId,
            userId,
            tokenCost,
            status,
            created,
            created,
            chargedAtUtc,
            refundedAtUtc,
            RefundAttemptCount: 0,
            RefundLastErrorCode: null,
            RefundLastAttemptedAtUtc: null,
            completedAtUtc,
            LastErrorCode: null,
            IdempotencyKey: $"idem-{generationId:N}",
            RequestHash: $"hash-{generationId:N}");
    }
}
