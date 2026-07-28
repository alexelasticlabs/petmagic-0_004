using System.Net;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalProviderHealthServiceTests
{
    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenConcurrencyLimitIsUnknown()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext, CreateOptions(falProviderConcurrencyLimit: 0), billingJson: null);

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.NotNull(result.Error.Metadata);
        Assert.Equal("concurrency_unknown", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenBalanceIsCritical()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreateOptions(falProviderConcurrencyLimit: 10, criticalBalanceUsd: 25),
            """{"credits":{"current_balance":12.50}}""");

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.NotNull(result.Error.Metadata);
        Assert.Equal("balance_critical", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldPass_WhenBalanceAndCapacityAreHealthy()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreateOptions(falProviderConcurrencyLimit: 10, criticalBalanceUsd: 25),
            """{"credits":{"current_balance":250.00}}""");

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldCountSubmittingReservations_WithoutProviderRequestIds()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateOptions(falProviderConcurrencyLimit: 9, criticalBalanceUsd: 5);
        var now = DateTime.UtcNow;
        dbContext.TemplateGenerationJobs.AddRange(Enumerable.Range(0, 8).Select(_ =>
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                Status = PetMagic.Modules.Templates.Domain.Enums.TemplateGenerationStatus.SubmittingToProvider,
                ProviderCompletedAtUtc = null,
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now
            }));
        await dbContext.SaveChangesAsync();
        var service = CreateService(
            dbContext,
            options,
            """{"credits":{"current_balance":250.00}}""");

        var result = await service.EnsureCanAcceptGenerationAsync("video", "premium", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("concurrency_exhausted", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldRejectPersistedBalance_WhenLastSuccessIsStale()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateOptions(falProviderConcurrencyLimit: 10, criticalBalanceUsd: 5);
        var now = DateTime.UtcNow;
        dbContext.TemplateFalProviderHealthSnapshots.Add(new TemplateFalProviderHealthSnapshot
        {
            Id = Guid.NewGuid(),
            BalanceUsd = 100,
            Status = "healthy",
            CheckedAtUtc = now,
            LastSuccessAtUtc = now.AddSeconds(-181),
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(
            dbContext,
            options,
            billingJson: null,
            runtimeSettings: new StaticRuntimeSettingsProvider(
                TemplateGenerationRuntimeSettingsProvider.BuildFallback(options)));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("balance_unknown", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldAcceptRecentPersistedBalance()
    {
        await using var dbContext = CreateDbContext();
        var options = CreateOptions(falProviderConcurrencyLimit: 10, criticalBalanceUsd: 5);
        var now = DateTime.UtcNow;
        dbContext.TemplateFalProviderHealthSnapshots.Add(new TemplateFalProviderHealthSnapshot
        {
            Id = Guid.NewGuid(),
            BalanceUsd = 100,
            Status = "healthy",
            CheckedAtUtc = now,
            LastSuccessAtUtc = now.AddSeconds(-179),
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(
            dbContext,
            options,
            billingJson: null,
            runtimeSettings: new StaticRuntimeSettingsProvider(
                TemplateGenerationRuntimeSettingsProvider.BuildFallback(options)));

        var result = await service.EnsureCanAcceptGenerationAsync("video", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    private static FalProviderHealthService CreateService(
        TemplatesDbContext dbContext,
        TemplatesOptions options,
        string? billingJson,
        ITemplateGenerationRuntimeSettingsProvider? runtimeSettings = null)
    {
        return new FalProviderHealthService(
            dbContext,
            new StaticHttpClientFactory(FalProviderHealthService.HttpClientName, billingJson),
            new MemoryCache(new MemoryCacheOptions()),
            options,
            NullLogger<FalProviderHealthService>.Instance,
            runtimeSettings);
    }

    private static TemplatesOptions CreateOptions(
        int falProviderConcurrencyLimit,
        decimal criticalBalanceUsd = 25)
    {
        return new TemplatesOptions
        {
            AiProvider = TemplateAiProviders.Fal,
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru"],
            FalProviderConcurrencyLimit = falProviderConcurrencyLimit,
            FalProviderReservedConcurrency = 1,
            FalProviderBalanceLowThresholdUsd = 100,
            FalProviderBalanceCriticalThresholdUsd = criticalBalanceUsd,
            Fal = new FalAiOptions
            {
                ApiKey = "test-fal-key"
            }
        };
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"fal-provider-health-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private sealed class StaticHttpClientFactory(string expectedName, string? billingJson) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(expectedName, name);
            return new HttpClient(new StaticHandler(billingJson));
        }
    }

    private sealed class StaticHandler(string? billingJson) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (billingJson is null)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable));
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(billingJson)
            });
        }
    }

    private sealed class StaticRuntimeSettingsProvider(TemplateGenerationRuntimeSnapshot current)
        : ITemplateGenerationRuntimeSettingsProvider
    {
        public TemplateGenerationRuntimeSnapshot Current { get; } = current;

        public Task RefreshAsync(CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
