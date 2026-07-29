using System.Net;
using System.Net.Http.Headers;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalProviderRuntimeSnapshotServiceTests
{
    [Theory]
    [InlineData("{\"credits\":{\"current_balance\":20.25}}", "20.25")]
    [InlineData("{\"credits\":{\"current_balance\":\"20.25\"}}", "20.25")]
    public async Task RefreshAsync_ShouldAcceptNumericAndStringBalances(
        string responseJson,
        string expectedBalanceText)
    {
        await using var dbContext = CreateDbContext();
        var handler = new StubHttpMessageHandler(_ => JsonResponse(HttpStatusCode.OK, responseJson));
        var service = CreateService(dbContext, handler);
        var startedAtUtc = DateTime.UtcNow;

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(decimal.Parse(expectedBalanceText, System.Globalization.CultureInfo.InvariantCulture), snapshot.CurrentBalanceUsd);
        Assert.Equal(TemplateProviderBalanceState.Fresh, snapshot.BalanceState);
        Assert.NotNull(snapshot.LastSuccessfulAtUtc);
        Assert.InRange(snapshot.LastSuccessfulAtUtc!.Value, startedAtUtc, DateTime.UtcNow);
        Assert.Equal(0, snapshot.ConsecutiveFailures);
        Assert.Null(snapshot.LastErrorCode);
        Assert.Equal(
            new Uri("https://api.fal.ai/v1/account/billing?expand=credits"),
            handler.LastRequestUri);
        Assert.Equal(new AuthenticationHeaderValue("Key", "fal-runtime-test-key"), handler.LastAuthorization);
    }

    [Theory]
    [InlineData("5", TemplateProviderBalanceState.Critical)]
    [InlineData("9.99", TemplateProviderBalanceState.Low)]
    [InlineData("10", TemplateProviderBalanceState.Fresh)]
    public async Task RefreshAsync_ShouldApplyConfiguredBalanceThresholds(
        string balanceText,
        TemplateProviderBalanceState expectedState)
    {
        await using var dbContext = CreateDbContext();
        var handler = new StubHttpMessageHandler(_ => JsonResponse(
            HttpStatusCode.OK,
            $"{{\"credits\":{{\"current_balance\":{balanceText}}}}}"));
        var service = CreateService(dbContext, handler);

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(expectedState, snapshot.BalanceState);
        Assert.Equal(
            decimal.Parse(balanceText, System.Globalization.CultureInfo.InvariantCulture),
            snapshot.CurrentBalanceUsd);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, "authentication_failed")]
    [InlineData(HttpStatusCode.Forbidden, "authentication_failed")]
    [InlineData(HttpStatusCode.TooManyRequests, "http_429")]
    public async Task RefreshAsync_ShouldRecordExpectedFailureForBillingHttpStatus(
        HttpStatusCode statusCode,
        string expectedErrorCode)
    {
        await using var dbContext = CreateDbContext();
        var lastSuccessfulAtUtc = DateTime.UtcNow.AddMinutes(-1);
        await SeedSnapshotAsync(dbContext, TemplateProviderBalanceState.Fresh, lastSuccessfulAtUtc);
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => JsonResponse(statusCode, "{}")));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Stale, snapshot.BalanceState);
        Assert.Equal(expectedErrorCode, snapshot.LastErrorCode);
        Assert.Equal(1, snapshot.ConsecutiveFailures);
        Assert.Equal(20m, snapshot.CurrentBalanceUsd);
        Assert.Equal(lastSuccessfulAtUtc, snapshot.LastSuccessfulAtUtc);
    }

    [Fact]
    public async Task RefreshAsync_ShouldTreatTimeoutAsStaleWhileLastKnownGoodIsFresh()
    {
        await using var dbContext = CreateDbContext();
        var lastSuccessfulAtUtc = DateTime.UtcNow.AddMinutes(-1);
        await SeedSnapshotAsync(dbContext, TemplateProviderBalanceState.Fresh, lastSuccessfulAtUtc);
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => throw new TaskCanceledException("simulated timeout")));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Stale, snapshot.BalanceState);
        Assert.Equal("unexpected_error", snapshot.LastErrorCode);
        Assert.Equal(1, snapshot.ConsecutiveFailures);
        Assert.Equal(lastSuccessfulAtUtc, snapshot.LastSuccessfulAtUtc);
    }

    [Fact]
    public async Task RefreshAsync_ShouldTreatTransportFailureAsUnknownWhenLastKnownGoodExpired()
    {
        await using var dbContext = CreateDbContext();
        var lastSuccessfulAtUtc = DateTime.UtcNow.AddMinutes(-6);
        await SeedSnapshotAsync(dbContext, TemplateProviderBalanceState.Fresh, lastSuccessfulAtUtc);
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => throw new HttpRequestException("simulated transport failure")));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Unknown, snapshot.BalanceState);
        Assert.Equal("unexpected_error", snapshot.LastErrorCode);
        Assert.Equal(1, snapshot.ConsecutiveFailures);
        Assert.Equal(20m, snapshot.CurrentBalanceUsd);
        Assert.Equal(lastSuccessfulAtUtc, snapshot.LastSuccessfulAtUtc);
    }

    [Theory]
    [InlineData("{not-json")]
    [InlineData("{\"credits\":{\"current_balance\":null}}")]
    [InlineData("{\"credits\":{}}")]
    public async Task RefreshAsync_ShouldRejectMalformedBillingResponse(string responseJson)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => JsonResponse(HttpStatusCode.OK, responseJson)));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Unknown, snapshot.BalanceState);
        Assert.Equal("invalid_response", snapshot.LastErrorCode);
        Assert.Equal(1, snapshot.ConsecutiveFailures);
        Assert.Null(snapshot.CurrentBalanceUsd);
        Assert.Null(snapshot.LastSuccessfulAtUtc);
    }

    [Fact]
    public async Task RefreshAsync_ShouldRejectOversizedBillingResponsePrefix()
    {
        await using var dbContext = CreateDbContext();
        var oversizedJson = "{\"credits\":{\"current_balance\":\""
            + new string('9', (16 * 1024) + 1)
            + "\"}}";
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => JsonResponse(HttpStatusCode.OK, oversizedJson)));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Unknown, snapshot.BalanceState);
        Assert.Equal("invalid_response", snapshot.LastErrorCode);
        Assert.Equal(1, snapshot.ConsecutiveFailures);
        Assert.Null(snapshot.CurrentBalanceUsd);
    }

    [Fact]
    public async Task RefreshAsync_ShouldTransitionCriticalBalanceBackToFreshAfterSuccessfulRefresh()
    {
        await using var dbContext = CreateDbContext();
        var previousStatusChangedAtUtc = DateTime.UtcNow.AddMinutes(-2);
        await SeedSnapshotAsync(
            dbContext,
            TemplateProviderBalanceState.Critical,
            DateTime.UtcNow.AddMinutes(-1),
            balanceUsd: 5m,
            statusChangedAtUtc: previousStatusChangedAtUtc);
        var service = CreateService(
            dbContext,
            new StubHttpMessageHandler(_ => JsonResponse(
                HttpStatusCode.OK,
                "{\"credits\":{\"current_balance\":20}}")));

        var snapshot = await service.RefreshAsync(force: true, CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Fresh, snapshot.BalanceState);
        Assert.Equal(20m, snapshot.CurrentBalanceUsd);
        Assert.True(snapshot.StatusChangedAtUtc > previousStatusChangedAtUtc);
        Assert.Null(snapshot.LastErrorCode);
        Assert.Equal(0, snapshot.ConsecutiveFailures);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"fal-runtime-snapshot-{Guid.NewGuid():N}")
            .Options;
        return new TemplatesDbContext(options);
    }

    private static FalProviderRuntimeSnapshotService CreateService(
        TemplatesDbContext dbContext,
        HttpMessageHandler handler) =>
        new(
            dbContext,
            new StubHttpClientFactory(handler),
            CreateOptions(),
            NullLogger<FalProviderRuntimeSnapshotService>.Instance);

    private static TemplatesOptions CreateOptions() => new()
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
        Fal = new FalAiOptions
        {
            ApiKey = "fal-runtime-test-key"
        }
    };

    private static async Task SeedSnapshotAsync(
        TemplatesDbContext dbContext,
        TemplateProviderBalanceState state,
        DateTime lastSuccessfulAtUtc,
        decimal balanceUsd = 20m,
        DateTime? statusChangedAtUtc = null)
    {
        dbContext.TemplateProviderRuntimeSnapshots.Add(new TemplateProviderRuntimeSnapshot
        {
            Id = TemplateGenerationControlPolicyDefaults.FalSnapshotId,
            Provider = "fal",
            BalanceState = state,
            StatusChangedAtUtc = statusChangedAtUtc ?? lastSuccessfulAtUtc,
            CurrentBalanceUsd = balanceUsd,
            LastSuccessfulAtUtc = lastSuccessfulAtUtc,
            CheckedAtUtc = lastSuccessfulAtUtc,
            UpdatedAtUtc = lastSuccessfulAtUtc
        });
        await dbContext.SaveChangesAsync();
    }

    private static HttpResponseMessage JsonResponse(HttpStatusCode statusCode, string json) => new(statusCode)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json")
    };

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(FalProviderRuntimeSnapshotService.HttpClientName, name);
            return new HttpClient(handler, disposeHandler: false);
        }
    }

    private sealed class StubHttpMessageHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        public Uri? LastRequestUri { get; private set; }

        public AuthenticationHeaderValue? LastAuthorization { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            LastRequestUri = request.RequestUri;
            LastAuthorization = request.Headers.Authorization;
            return Task.FromResult(responseFactory(request));
        }
    }
}
