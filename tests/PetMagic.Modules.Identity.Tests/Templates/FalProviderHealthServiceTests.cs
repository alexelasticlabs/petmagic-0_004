using System.Net;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
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

    private static FalProviderHealthService CreateService(
        TemplatesDbContext dbContext,
        TemplatesOptions options,
        string? billingJson)
    {
        return new FalProviderHealthService(
            dbContext,
            new StaticHttpClientFactory(FalProviderHealthService.HttpClientName, billingJson),
            new MemoryCache(new MemoryCacheOptions()),
            options,
            NullLogger<FalProviderHealthService>.Instance);
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
}
