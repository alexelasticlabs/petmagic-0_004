using System.Net;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class GenerationOperationalAlertPostgresRaceTests
{
    private const string ConnectionStringEnvironmentVariable =
        "PETMAGIC_ALERT_RACE_POSTGRES_INTEGRATION_CONNECTION_STRING";

    [Fact]
    public async Task ConcurrentFirstFalRefresh_ShouldPersistSingleFixedSnapshot_OnPostgres()
    {
        var connectionString = Environment.GetEnvironmentVariable(ConnectionStringEnvironmentVariable);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await ResetAsync(connectionString);
        var runtimeSettings = new StaticRuntimeSettingsProvider(CreateRuntimeSettings());
        var services = new ServiceCollection();
        services.AddDbContext<TemplatesDbContext>(options => options.UseNpgsql(connectionString));
        services.AddSingleton<ITemplateGenerationRuntimeSettingsProvider>(runtimeSettings);
        services.AddScoped<GenerationOperationalAlertService>();

        await using var serviceProvider = services.BuildServiceProvider();
        using var httpClient = new HttpClient(new ConcurrentBillingHandler(expectedRequests: 2));
        var billingClient = new FalAccountBillingClient(
            new SharedHttpClientFactory(httpClient),
            CreateTemplatesOptions(),
            NullLogger<FalAccountBillingClient>.Instance);
        var monitor = new FalProviderHealthMonitor(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            billingClient,
            NullLogger<FalProviderHealthMonitor>.Instance);

        try
        {
            await Task.WhenAll(
                monitor.RefreshNowAsync(CancellationToken.None),
                monitor.RefreshNowAsync(CancellationToken.None));

            await using var verificationContext = CreateDbContext(connectionString);
            var snapshot = Assert.Single(await verificationContext.TemplateFalProviderHealthSnapshots
                .AsNoTracking()
                .ToArrayAsync());
            Assert.Equal(FalProviderHealthMonitor.SnapshotId, snapshot.Id);
            Assert.Equal(20m, snapshot.BalanceUsd);
            Assert.Equal("healthy", snapshot.Status);
            Assert.Equal(0, snapshot.ConsecutiveFailures);
        }
        finally
        {
            await ResetAsync(connectionString);
        }
    }

    [Fact]
    public async Task OutOfOrderFalRefresh_ShouldNotOverwriteNewerStartedCheck()
    {
        var runtimeSettings = new StaticRuntimeSettingsProvider(CreateRuntimeSettings());
        var services = new ServiceCollection();
        var databaseRoot = new InMemoryDatabaseRoot();
        var databaseName = $"fal-refresh-order-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options =>
            options.UseInMemoryDatabase(databaseName, databaseRoot));
        services.AddSingleton<ITemplateGenerationRuntimeSettingsProvider>(runtimeSettings);
        services.AddScoped<GenerationOperationalAlertService>();

        await using var serviceProvider = services.BuildServiceProvider();
        var handler = new OutOfOrderBillingHandler();
        using var httpClient = new HttpClient(handler);
        var billingClient = new FalAccountBillingClient(
            new SharedHttpClientFactory(httpClient),
            CreateTemplatesOptions(),
            NullLogger<FalAccountBillingClient>.Instance);
        var monitor = new FalProviderHealthMonitor(
            serviceProvider.GetRequiredService<IServiceScopeFactory>(),
            billingClient,
            NullLogger<FalProviderHealthMonitor>.Instance);

        var olderRefresh = monitor.RefreshNowAsync(CancellationToken.None);
        await handler.FirstRequestStarted.WaitAsync(TimeSpan.FromSeconds(5));
        await Task.Delay(20);
        await monitor.RefreshNowAsync(CancellationToken.None);
        handler.ReleaseFirstRequest();
        await olderRefresh;

        using var verificationScope = serviceProvider.CreateScope();
        var snapshot = Assert.Single(await verificationScope.ServiceProvider
            .GetRequiredService<TemplatesDbContext>()
            .TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .ToArrayAsync());
        Assert.Equal(30m, snapshot.BalanceUsd);
        Assert.Equal("healthy", snapshot.Status);
    }

    [Fact]
    public async Task ConcurrentAlertEvaluation_ShouldPersistOneRowPerStableCode_OnPostgres()
    {
        var connectionString = Environment.GetEnvironmentVariable(ConnectionStringEnvironmentVariable);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await ResetAsync(connectionString);
        var saveBarrier = new FirstTwoAddedEntitySaveBarrier<TemplateGenerationOperationalAlert>();
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseNpgsql(connectionString)
            .AddInterceptors(saveBarrier)
            .Options;
        var runtimeSettings = new StaticRuntimeSettingsProvider(CreateRuntimeSettings());

        await using var firstContext = new TemplatesDbContext(options);
        await using var secondContext = new TemplatesDbContext(options);
        var first = new GenerationOperationalAlertService(firstContext, runtimeSettings);
        var second = new GenerationOperationalAlertService(secondContext, runtimeSettings);

        try
        {
            await Task.WhenAll(
                first.EvaluateAsync(CancellationToken.None),
                second.EvaluateAsync(CancellationToken.None));

            await using var verificationContext = CreateDbContext(connectionString);
            var alerts = await verificationContext.TemplateGenerationOperationalAlerts
                .AsNoTracking()
                .ToArrayAsync();
            Assert.Equal(alerts.Length, alerts.Select(alert => alert.Code).Distinct(StringComparer.Ordinal).Count());
            Assert.Contains(alerts, alert => alert.Code == "fal_balance_unknown" && alert.ResolvedAtUtc is null);
            Assert.Contains(alerts, alert => alert.Code == "worker_capacity_insufficient" && alert.ResolvedAtUtc is null);
        }
        finally
        {
            await ResetAsync(connectionString);
        }
    }

    [Fact]
    public async Task ConcurrentAcknowledgement_ShouldBeIdempotentForSameAdminAndAlert_OnPostgres()
    {
        var connectionString = Environment.GetEnvironmentVariable(ConnectionStringEnvironmentVariable);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await ResetAsync(connectionString);
        var alertId = Guid.NewGuid();
        var adminUserId = Guid.NewGuid();
        await using (var seedContext = CreateDbContext(connectionString))
        {
            var now = DateTime.UtcNow;
            seedContext.TemplateGenerationOperationalAlerts.Add(new TemplateGenerationOperationalAlert
            {
                Id = alertId,
                Code = $"ack_race_{alertId:N}",
                Severity = "warning",
                Title = "Acknowledgement race test",
                Message = "Concurrent acknowledgement fixture.",
                ActivatedAtUtc = now,
                LastObservedAtUtc = now,
                UpdatedAtUtc = now
            });
            await seedContext.SaveChangesAsync();
        }

        var saveBarrier = new FirstTwoAddedEntitySaveBarrier<TemplateGenerationOperationalAlertAcknowledgement>();
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseNpgsql(connectionString)
            .AddInterceptors(saveBarrier)
            .Options;
        var runtimeSettings = new StaticRuntimeSettingsProvider(CreateRuntimeSettings());
        await using var firstContext = new TemplatesDbContext(options);
        await using var secondContext = new TemplatesDbContext(options);
        var first = CreateAdminService(firstContext, runtimeSettings);
        var second = CreateAdminService(secondContext, runtimeSettings);

        try
        {
            var results = await Task.WhenAll(
                first.AcknowledgeAlertAsync(alertId, adminUserId, CancellationToken.None),
                second.AcknowledgeAlertAsync(alertId, adminUserId, CancellationToken.None));

            Assert.All(results, result => Assert.True(result.IsSuccess));
            Assert.All(results, result => Assert.True(result.Value.IsAcknowledged));
            Assert.Equal(results[0].Value.AcknowledgedAtUtc, results[1].Value.AcknowledgedAtUtc);

            await using var verificationContext = CreateDbContext(connectionString);
            Assert.Equal(
                1,
                await verificationContext.TemplateGenerationOperationalAlertAcknowledgements
                    .CountAsync(acknowledgement =>
                        acknowledgement.AlertId == alertId
                        && acknowledgement.AdminUserId == adminUserId));
        }
        finally
        {
            await ResetAsync(connectionString);
        }
    }

    private static AdminGenerationControlService CreateAdminService(
        TemplatesDbContext dbContext,
        ITemplateGenerationRuntimeSettingsProvider runtimeSettings) => new(
            dbContext,
            runtimeSettings,
            providerMonitor: null!,
            alertService: null!,
            options: CreateTemplatesOptions(),
            adminAuditLog: null,
            logger: NullLogger<AdminGenerationControlService>.Instance);

    private static TemplatesDbContext CreateDbContext(string connectionString) => new(
        new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseNpgsql(connectionString)
            .Options);

    private static async Task ResetAsync(string connectionString)
    {
        await using var dbContext = CreateDbContext(connectionString);
        await dbContext.TemplateGenerationOperationalAlertAcknowledgements.ExecuteDeleteAsync();
        await dbContext.TemplateGenerationOperationalAlerts.ExecuteDeleteAsync();
        await dbContext.TemplateFalProviderHealthSnapshots.ExecuteDeleteAsync();
    }

    private static TemplateGenerationRuntimeSnapshot CreateRuntimeSettings() => new(
        Version: 1,
        GlobalMaxConcurrent: 8,
        ImageMaxConcurrent: 7,
        ImageProtectedConcurrent: 1,
        VideoGuaranteedConcurrent: 2,
        VideoMaxConcurrent: 4,
        VideoBorrowMaxConcurrent: 2,
        WorkerLoopsPerInstance: 2,
        FalConfiguredConcurrency: 10,
        FalReservedConcurrency: 2,
        FalBalanceLowThresholdUsd: 10,
        FalBalanceCriticalThresholdUsd: 5,
        NewClaimsPaused: false,
        DrainOperationId: null,
        UpdatedAtUtc: DateTime.UtcNow);

    private static TemplatesOptions CreateTemplatesOptions() => new()
    {
        PublicBaseUrl = "http://localhost:5000",
        LocalMediaRootPath = "wwwroot/templates-media",
        DefaultImagePrompt = "Create a themed pet portrait.",
        DefaultPreprocessingPrompt = "Keep the same pet.",
        DefaultKlingPrompt = "Funny dance.",
        AllowedImageModels = ["openai/gpt-image-2/edit"],
        AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
        AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
        SupportedLocalizationLocales = ["ru"],
        Fal = new FalAiOptions
        {
            ApiKey = "test-fal-generation-key",
            AdminApiKey = "test-fal-admin-key",
            ExpectedAccountUsername = "petmagic"
        }
    };

    private sealed class StaticRuntimeSettingsProvider(TemplateGenerationRuntimeSnapshot current)
        : ITemplateGenerationRuntimeSettingsProvider
    {
        public TemplateGenerationRuntimeSnapshot Current { get; } = current;

        public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class FirstTwoAddedEntitySaveBarrier<TEntity> : SaveChangesInterceptor
        where TEntity : class
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private int arrivals;

        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            var dbContext = eventData.Context;
            if (dbContext is null
                || !dbContext.ChangeTracker.Entries<TEntity>().Any(entry => entry.State == EntityState.Added))
            {
                return result;
            }

            var arrival = Interlocked.Increment(ref arrivals);
            if (arrival > 2)
            {
                return result;
            }

            if (arrival == 2)
            {
                release.TrySetResult();
            }

            await release.Task.WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
            return result;
        }
    }

    private sealed class ConcurrentBillingHandler(int expectedRequests) : HttpMessageHandler
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private int requests;

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref requests) >= expectedRequests)
            {
                release.TrySetResult();
            }

            await release.Task.WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"username":"petmagic","credits":{"current_balance":20.00,"currency":"USD"}}""")
            };
        }
    }

    private sealed class OutOfOrderBillingHandler : HttpMessageHandler
    {
        private readonly TaskCompletionSource firstRequestStarted = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource releaseFirstRequest = new(
            TaskCreationOptions.RunContinuationsAsynchronously);
        private int requestCount;

        public Task FirstRequestStarted => firstRequestStarted.Task;

        public void ReleaseFirstRequest() => releaseFirstRequest.TrySetResult();

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var requestNumber = Interlocked.Increment(ref requestCount);
            if (requestNumber == 1)
            {
                firstRequestStarted.TrySetResult();
                await releaseFirstRequest.Task.WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
            }

            var balance = requestNumber == 1 ? "10.00" : "30.00";
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    "{\"username\":\"petmagic\",\"credits\":{\"current_balance\":"
                    + balance
                    + ",\"currency\":\"USD\"}}")
            };
        }
    }

    private sealed class SharedHttpClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => httpClient;
    }
}
