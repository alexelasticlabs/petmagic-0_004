using System.Net;
using System.Text;

using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalAccountBillingClientTests
{
    [Theory]
    [InlineData("{\"username\":\"petmagic\",\"credits\":{\"current_balance\":12.34,\"currency\":\"USD\"}}", "12.34")]
    [InlineData("{\"username\":\"PetMagic\",\"credits\":{\"current_balance\":\"56.78\",\"currency\":\"usd\"}}", "56.78")]
    public async Task GetCurrentBalanceAsync_ShouldParseDocumentedCreditsBalance(
        string payload,
        string expected)
    {
        var handler = new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        });
        var client = CreateClient(
            handler,
            adminApiKey: "server-only-admin-key",
            expectedAccountUsername: "petmagic",
            generationApiKey: "generation-key-must-not-be-used");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(
            decimal.Parse(expected, System.Globalization.CultureInfo.InvariantCulture),
            result.BalanceUsd);
        Assert.Equal("https://api.fal.ai/v1/account/billing?expand=credits", handler.RequestUri?.ToString());
        Assert.Equal("Key", handler.AuthorizationScheme);
        Assert.Equal("server-only-admin-key", handler.AuthorizationParameter);
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("{\"credits\":{}}")]
    [InlineData("{\"credits\":{\"current_balance\":12.34}}")]
    [InlineData("{\"username\":\"petmagic\",\"credits\":{\"current_balance\":{},\"currency\":\"USD\"}}")]
    [InlineData("not-json")]
    public async Task GetCurrentBalanceAsync_ShouldRejectInvalidPayload(string payload)
    {
        var client = CreateClient(
            new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(payload)
            }),
            adminApiKey: "server-only-admin-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("invalid_response", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldNotFallbackToGenerationKey_WhenAdminApiKeyIsMissing()
    {
        var handler = new RecordingHandler(_ => throw new InvalidOperationException("HTTP must not be called."));
        var client = CreateClient(
            handler,
            adminApiKey: string.Empty,
            generationApiKey: "valid-generation-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("admin_api_key_missing", result.ErrorCode);
        Assert.Equal(0, handler.CallCount);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized, "authentication_failed")]
    [InlineData(HttpStatusCode.Forbidden, "admin_scope_required")]
    [InlineData(HttpStatusCode.TooManyRequests, "rate_limited")]
    [InlineData(HttpStatusCode.InternalServerError, "provider_unavailable")]
    [InlineData(HttpStatusCode.ServiceUnavailable, "provider_unavailable")]
    [InlineData(HttpStatusCode.BadRequest, "request_failed")]
    public async Task GetCurrentBalanceAsync_ShouldMapHttpFailures(
        HttpStatusCode statusCode,
        string expectedErrorCode)
    {
        var client = CreateClient(
            new RecordingHandler(_ => new HttpResponseMessage(statusCode)),
            adminApiKey: "server-only-admin-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal(expectedErrorCode, result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldRejectUnexpectedAccount()
    {
        var client = CreateClient(
            new RecordingHandler(_ => SuccessfulResponse(
                "{\"username\":\"another-account\",\"credits\":{\"current_balance\":42,\"currency\":\"USD\"}}")),
            adminApiKey: "server-only-admin-key",
            expectedAccountUsername: "petmagic");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("account_mismatch", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldRejectMissingUsername_WhenAccountIsPinned()
    {
        var client = CreateClient(
            new RecordingHandler(_ => SuccessfulResponse(
                "{\"credits\":{\"current_balance\":42,\"currency\":\"USD\"}}")),
            adminApiKey: "server-only-admin-key",
            expectedAccountUsername: "petmagic");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("invalid_response", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldRejectUnsupportedCurrency()
    {
        var client = CreateClient(
            new RecordingHandler(_ => SuccessfulResponse(
                "{\"username\":\"petmagic\",\"credits\":{\"current_balance\":42,\"currency\":\"EUR\"}}")),
            adminApiKey: "server-only-admin-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("unsupported_currency", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldReturnSafeFailure_OnTimeout()
    {
        var client = CreateClient(
            new RecordingHandler(_ => throw new TaskCanceledException("simulated timeout")),
            adminApiKey: "server-only-admin-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("request_timeout", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldReturnSafeFailure_OnTransportFailure()
    {
        var client = CreateClient(
            new RecordingHandler(_ => throw new HttpRequestException("sensitive upstream detail")),
            adminApiKey: "server-only-admin-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("request_failed", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldPropagateCallerCancellation()
    {
        var client = CreateClient(
            new RecordingHandler(_ => SuccessfulResponse(
                "{\"username\":\"petmagic\",\"credits\":{\"current_balance\":42,\"currency\":\"USD\"}}")),
            adminApiKey: "server-only-admin-key");
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            client.GetCurrentBalanceAsync(cancellation.Token));
    }

    private static HttpResponseMessage SuccessfulResponse(string payload) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(payload, Encoding.UTF8, "application/json")
    };

    private static FalAccountBillingClient CreateClient(
        HttpMessageHandler handler,
        string adminApiKey,
        string expectedAccountUsername = "",
        string generationApiKey = "generation-key")
    {
        var httpClient = new HttpClient(handler);
        return new FalAccountBillingClient(
            new StaticHttpClientFactory(httpClient),
            new TemplatesOptions
            {
                PublicBaseUrl = "https://api.example.test",
                LocalMediaRootPath = "wwwroot/templates-media",
                DefaultPreprocessingPrompt = "Keep the same pet.",
                DefaultKlingPrompt = "Animate the pet.",
                DefaultImagePrompt = "Create a pet portrait.",
                AllowedImageModels = ["fal-ai/test-image"],
                AllowedPreprocessingModels = ["fal-ai/test-preprocess"],
                AllowedKlingModels = ["fal-ai/test-video"],
                SupportedLocalizationLocales = ["ru"],
                Fal = new FalAiOptions
                {
                    ApiKey = generationApiKey,
                    AdminApiKey = adminApiKey,
                    ExpectedAccountUsername = expectedAccountUsername
                }
            },
            NullLogger<FalAccountBillingClient>.Instance);
    }

    private sealed class StaticHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(FalAccountBillingClient.HttpClientName, name);
            return client;
        }
    }

    private sealed class RecordingHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        public int CallCount { get; private set; }

        public Uri? RequestUri { get; private set; }

        public string? AuthorizationScheme { get; private set; }

        public string? AuthorizationParameter { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            CallCount++;
            RequestUri = request.RequestUri;
            AuthorizationScheme = request.Headers.Authorization?.Scheme;
            AuthorizationParameter = request.Headers.Authorization?.Parameter;
            return Task.FromResult(responseFactory(request));
        }
    }
}
