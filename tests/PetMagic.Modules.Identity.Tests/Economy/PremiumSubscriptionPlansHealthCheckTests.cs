using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class PremiumSubscriptionPlansHealthCheckTests
{
    [Fact]
    public async Task CheckHealthAsync_ShouldBeHealthy_WhenAllCatalogPlansAreConfiguredAndActive()
    {
        await using var dbContext = CreateDbContext();
        dbContext.SubscriptionPlans.AddRange(
            CreatePlan("monthly", isActive: true),
            CreatePlan("yearly", isActive: true));
        await dbContext.SaveChangesAsync();

        var healthCheck = new PremiumSubscriptionPlansHealthCheck(dbContext);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Healthy, result.Status);
    }

    [Fact]
    public async Task CheckHealthAsync_ShouldBeUnhealthy_WhenCatalogPlansAreMissingOrInactive()
    {
        await using var dbContext = CreateDbContext();
        dbContext.SubscriptionPlans.Add(CreatePlan("monthly", isActive: false));
        await dbContext.SaveChangesAsync();

        var logger = new CapturingLogger<PremiumSubscriptionPlansHealthCheck>();
        var healthCheck = new PremiumSubscriptionPlansHealthCheck(dbContext, logger);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Unhealthy, result.Status);
        Assert.Equal(["yearly"], Assert.IsType<string[]>(result.Data["missingPlanCodes"]));
        Assert.Equal(["monthly"], Assert.IsType<string[]>(result.Data["inactivePlanCodes"]));
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Premium subscription plan health check found configuration drift.", entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CheckHealthAsync_ShouldLogError_WhenVerificationThrows()
    {
        var logger = new CapturingLogger<PremiumSubscriptionPlansHealthCheck>();
        var dbContext = CreateDbContext();
        await dbContext.DisposeAsync();
        var healthCheck = new PremiumSubscriptionPlansHealthCheck(dbContext, logger);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Unhealthy, result.Status);
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Error);
        Assert.Contains("Premium subscription plan health check failed while querying SubscriptionPlans.", entry.Message, StringComparison.Ordinal);
    }

    private static EconomyDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"premium-subscription-health-{Guid.NewGuid():N}")
            .Options;

        return new EconomyDbContext(options);
    }

    private static SubscriptionPlan CreatePlan(string id, bool isActive)
    {
        return new SubscriptionPlan
        {
            Id = id,
            Name = $"Plan {id}",
            BillingPeriod = id == "yearly" ? "yearly" : "monthly",
            PriceAmount = id == "yearly" ? 99.99m : 14.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = id == "yearly" ? 1000 : 500,
            IsRecommended = id == "yearly",
            IsActive = isActive,
            AppleProductId = $"com.petmagic.app.premium.{id}",
            GoogleProductId = $"com.petmagic.app.premium.{id}",
            DisplayOrder = id == "yearly" ? 2 : 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception));
        }
    }

    private sealed record CapturedLogEntry(LogLevel LogLevel, string Message, Exception? Exception);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
