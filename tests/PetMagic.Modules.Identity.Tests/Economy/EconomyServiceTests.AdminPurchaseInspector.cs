using System.Text.Json;

using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task GetAdminPurchaseAsync_ShouldReturnSafeRefundTimelineCapabilitiesAndIncidentLinks()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        var incidentId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter pack",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            IsActive = true
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Refunded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 100,
            ExternalPaymentId = "provider-secret-must-not-leak",
            CreatedAtUtc = now.AddHours(-2),
            ConfirmedAtUtc = now.AddHours(-1)
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = -100,
            BalanceAfter = 20,
            Source = WalletLedgerSource.PurchaseRefund,
            Reason = $"purchase_refund:{orderId:D}",
            TokenKind = "paid",
            OperationKind = "debit",
            SourceProvider = "stripe",
            SourceTransactionId = "refund-secret-must-not-leak",
            CreatedAtUtc = now.AddMinutes(-30)
        });
        dbContext.EconomyIncidents.Add(new EconomyIncident
        {
            Id = incidentId,
            Type = "RefundSettlementMismatch",
            Severity = "Warning",
            Status = "Resolved",
            DeduplicationKey = $"purchase:{orderId:D}",
            PurchaseOrderId = orderId,
            Summary = "Safe summary",
            DetailsJson = "{\"providerPayload\":\"must-not-leak\"}",
            LastError = "provider-secret-error",
            FirstDetectedAtUtc = now.AddMinutes(-20),
            LastDetectedAtUtc = now.AddMinutes(-10),
            ResolvedAtUtc = now.AddMinutes(-5)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminPurchaseAsync(orderId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("settled", result.Value.SettlementState);
        Assert.Equal("refunded", result.Value.RefundStatus);
        Assert.False(result.Value.Capabilities.CanRefund);
        Assert.Contains(result.Value.Timeline, item => item.EventType == "refund_requested");
        Assert.Contains(result.Value.Timeline, item => item.EventType == "refund_settled");
        Assert.Equal(incidentId, Assert.Single(result.Value.Incidents).IncidentId);

        var json = JsonSerializer.Serialize(result.Value, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.DoesNotContain("provider-secret-must-not-leak", json, StringComparison.Ordinal);
        Assert.DoesNotContain("refund-secret-must-not-leak", json, StringComparison.Ordinal);
        Assert.DoesNotContain("providerPayload", json, StringComparison.Ordinal);
        Assert.DoesNotContain("provider-secret-error", json, StringComparison.Ordinal);
    }

    [Fact]
    public async Task GetAdminPurchaseAsync_ShouldComputeRetryCapabilityForPendingStripeRefund()
    {
        await using var dbContext = CreateDbContext();
        var packId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "plus",
            DisplayName = "Plus pack",
            CurrencyCode = "USD",
            PriceAmount = 9.99m,
            GrantedSpark = 250,
            IsActive = true
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = Guid.NewGuid(),
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.RefundPending,
            PriceAmount = 9.99m,
            CurrencyCode = "USD",
            SparkToGrant = 250,
            ExternalPaymentId = "pi_test",
            CreatedAtUtc = DateTime.UtcNow.AddHours(-1),
            ConfirmedAtUtc = DateTime.UtcNow.AddMinutes(-50)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminPurchaseAsync(orderId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("pending_provider", result.Value.SettlementState);
        Assert.True(result.Value.Capabilities.CanRefund);
        Assert.True(result.Value.Capabilities.CanRetryRefund);
        Assert.False(result.Value.Capabilities.RequiresManualReview);
    }

    [Theory]
    [InlineData("stripe", PurchaseOrderStatus.Succeeded, null, false, false, false)]
    [InlineData("paypal", PurchaseOrderStatus.Succeeded, "provider-id", false, false, false)]
    [InlineData("stripe", PurchaseOrderStatus.RefundRequiresManualReview, "provider-id", false, false, true)]
    [InlineData("stripe", PurchaseOrderStatus.Failed, "provider-id", false, false, false)]
    public async Task GetAdminPurchaseAsync_ShouldNotExposeUnsafeCapabilities(
        string provider,
        string status,
        string? externalPaymentId,
        bool canRefund,
        bool canRetryRefund,
        bool requiresManualReview)
    {
        await using var dbContext = CreateDbContext();
        var packId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = $"pack-{orderId:N}",
            DisplayName = "Capability pack",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            IsActive = true
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = Guid.NewGuid(),
            PackId = packId,
            PaymentProvider = provider,
            Status = status,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 100,
            ExternalPaymentId = externalPaymentId,
            CreatedAtUtc = DateTime.UtcNow.AddHours(-1),
            ConfirmedAtUtc = DateTime.UtcNow.AddMinutes(-50)
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminPurchaseAsync(orderId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(canRefund, result.Value.Capabilities.CanRefund);
        Assert.Equal(canRetryRefund, result.Value.Capabilities.CanRetryRefund);
        Assert.Equal(requiresManualReview, result.Value.Capabilities.RequiresManualReview);
    }

    [Fact]
    public async Task GetAdminPurchaseAsync_ShouldReturnNotFoundForUnknownOrder()
    {
        await using var dbContext = CreateDbContext();

        var result = await CreateService(dbContext)
            .GetAdminPurchaseAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PurchaseNotFound.Code, result.Error.Code);
    }
}
