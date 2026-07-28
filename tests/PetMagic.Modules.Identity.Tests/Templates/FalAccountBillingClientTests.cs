using System.Net;
using System.Text;

using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalAccountBillingClientTests
{
    [Theory]
    [InlineData("{\"credits\":{\"current_balance\":12.34}}", "12.34")]
    [InlineData("{\"credits\":{\"current_balance\":\"56.78\"}}", "56.78")]
    public async Task GetCurrentBalanceAsync_ShouldParseDocumentedCreditsBalance(
        string payload,
        string expected)
    {
        var handler = new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        });
        var client = CreateClient(handler, "server-only-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(
            decimal.Parse(expected, System.Globalization.CultureInfo.InvariantCulture),
            result.BalanceUsd);
        Assert.Equal("https://api.fal.ai/v1/account/billing?expand=credits", handler.RequestUri?.ToString());
        Assert.Equal("Key", handler.AuthorizationScheme);
        Assert.Equal("server-only-key", handler.AuthorizationParameter);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldRejectInvalidPayload()
    {
        var client = CreateClient(
            new RecordingHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"credits\":{}}")
            }),
            "server-only-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("invalid_response", result.ErrorCode);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldNotSendRequest_WhenApiKeyIsMissing()
    {
        var handler = new RecordingHandler(_ => throw new InvalidOperationException("HTTP must not be called."));
        var client = CreateClient(handler, string.Empty);

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("api_key_missing", result.ErrorCode);
        Assert.Equal(0, handler.CallCount);
    }

    [Fact]
    public async Task GetCurrentBalanceAsync_ShouldReturnSafeFailure_OnTimeout()
    {
        var client = CreateClient(
            new RecordingHandler(_ => throw new TaskCanceledException("simulated timeout")),
            "server-only-key");

        var result = await client.GetCurrentBalanceAsync(CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("request_failed", result.ErrorCode);
    }

    private static FalAccountBillingClient CreateClient(HttpMessageHandler handler, string apiKey)
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
                Fal = new FalAiOptions { ApiKey = apiKey }
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
