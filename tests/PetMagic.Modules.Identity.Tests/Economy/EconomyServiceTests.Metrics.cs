using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Tests.Host;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task GetAdminDashboardMetricsAsync_ShouldReturnBackendAggregatedPaymentMetrics()
    {
        await using var dbContext = CreateDbContext();

        var packId = AddStarterPack(dbContext);
        var now = DateTime.UtcNow;
        var todayStart = new DateTime(now.Year, now.Month, now.Day, 0, 0, 0, DateTimeKind.Utc);
        var currentDay = todayStart.AddHours(12);
        var previousPeriodDay = todayStart.AddDays(-8).AddHours(12);
        dbContext.PurchaseOrders.AddRange(
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Succeeded,
                PriceAmount = 10m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = currentDay.AddMinutes(-5),
                ConfirmedAtUtc = currentDay
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Failed,
                PriceAmount = 12m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = currentDay.AddMinutes(-4),
                ConfirmedAtUtc = currentDay
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Pending,
                PriceAmount = 8m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = currentDay.AddMinutes(-3)
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Succeeded,
                PriceAmount = 5m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = previousPeriodDay.AddMinutes(-5),
                ConfirmedAtUtc = previousPeriodDay
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Failed,
                PriceAmount = 6m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = previousPeriodDay.AddMinutes(-4),
                ConfirmedAtUtc = previousPeriodDay
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "stripe",
                Status = PurchaseOrderStatus.Succeeded,
                PriceAmount = 99m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = todayStart.AddDays(-20),
                ConfirmedAtUtc = todayStart.AddDays(-20).AddHours(12)
            });
        dbContext.UserSubscriptions.AddRange(
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "monthly",
                Status = "Active",
                CurrentPeriodStartUtc = now.AddDays(-4),
                CurrentPeriodEndUtc = now.AddDays(26),
                MonthlyTokenLimit = 500,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-4),
                UpdatedAtUtc = now
            },
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "monthly",
                Status = "active",
                CurrentPeriodStartUtc = now.AddDays(-2),
                CurrentPeriodEndUtc = now.AddDays(28),
                CancelAtPeriodEnd = true,
                MonthlyTokenLimit = 500,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-2),
                UpdatedAtUtc = now
            },
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "monthly",
                Status = "Canceled",
                CurrentPeriodStartUtc = now.AddDays(-10),
                CurrentPeriodEndUtc = now.AddDays(-1),
                CancelAtPeriodEnd = true,
                MonthlyTokenLimit = 500,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-10),
                UpdatedAtUtc = now
            });
        dbContext.WalletLedgerEntries.AddRange(
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Delta = 120,
                BalanceAfter = 120,
                Source = "pack_purchase",
                Reason = "purchase",
                CreatedAtUtc = currentDay.AddMinutes(-2)
            },
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Delta = 30,
                BalanceAfter = 30,
                Source = "admin_grant",
                Reason = "manual grant",
                CreatedAtUtc = currentDay.AddMinutes(-1)
            },
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Delta = -45,
                BalanceAfter = 75,
                Source = "generation_spend",
                Reason = "generation",
                CreatedAtUtc = currentDay
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminDashboardMetricsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(3, result.Value.PurchasesThisWeek);
        Assert.Equal(2, result.Value.PurchasesPreviousWeek);
        Assert.Equal(1, result.Value.SuccessfulPaymentsThisWeek);
        Assert.Equal(1, result.Value.SuccessfulPaymentsPreviousWeek);
        Assert.Equal(1, result.Value.FailedPaymentsThisWeek);
        Assert.Equal(1, result.Value.FailedPaymentsPreviousWeek);
        Assert.Equal(10m, result.Value.RevenueThisWeek);
        Assert.Equal(5m, result.Value.RevenuePreviousWeek);
        Assert.Equal(150, result.Value.TotalWalletCredits);
        Assert.Equal(45, result.Value.TotalWalletDebits);
        Assert.Equal(2, result.Value.ActiveSubscriptions);
        Assert.Equal(2, result.Value.RenewalStops);
        Assert.Equal("USD", result.Value.CurrencyCode);
        Assert.Equal(7, result.Value.RevenueSeries.Count);
        Assert.Equal(10m, result.Value.RevenueSeries.Sum(x => x.Amount));
    }

    [Fact]
    public async Task HandleStripeWebhookAsync_ShouldEmitFailureMetric_WhenSignatureIsInvalid()
    {
        using var recorder = new MeterMeasurementRecorder("PetMagic.Modules.Economy", "stripe_webhook_failures_total");
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.HandleStripeWebhookAsync(
            new StripeWebhookCommand("{}", "invalid-signature"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStripeSignature.Code, result.Error.Code);
        Assert.Contains(
            recorder.Measurements,
            measurement => measurement.InstrumentName == "stripe_webhook_failures_total"
                && measurement.Value == 1
                && Equals(measurement.Tags["error_code"], EconomyErrors.InvalidStripeSignature.Code)
                && Equals(measurement.Tags["stage"], "signature"));
    }
}
