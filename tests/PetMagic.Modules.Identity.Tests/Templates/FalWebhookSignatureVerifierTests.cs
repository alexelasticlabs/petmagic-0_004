using System.Net;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Api;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalWebhookSignatureVerifierTests
{
    [Fact]
    public async Task VerifyAsync_WithPublicJwksUrl_ShouldFetchKeys()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler();
        var verifier = CreateVerifier("https://rest.fal.ai/.well-known/jwks.json", handler, cache);

        var verified = await verifier.VerifyAsync(CreateHeaders(), [], CancellationToken.None);

        Assert.False(verified);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal("https://rest.fal.ai/.well-known/jwks.json", handler.LastRequestUri?.ToString());
    }

    [Theory]
    [InlineData("http://rest.fal.ai/.well-known/jwks.json")]
    [InlineData("https://user:pass@rest.fal.ai/.well-known/jwks.json")]
    [InlineData("https://rest.fal.ai/.well-known/jwks.json?token=secret")]
    [InlineData("https://rest.fal.ai/.well-known/jwks.json#fragment")]
    [InlineData("https://localhost/.well-known/jwks.json")]
    [InlineData("https://127.0.0.1/.well-known/jwks.json")]
    [InlineData("https://10.0.0.5/.well-known/jwks.json")]
    [InlineData("https://169.254.169.254/.well-known/jwks.json")]
    [InlineData("https://[::1]/.well-known/jwks.json")]
    [InlineData("https://[fc00::1]/.well-known/jwks.json")]
    [InlineData("https://[fd00::1]/.well-known/jwks.json")]
    [InlineData("https://[::ffff:127.0.0.1]/.well-known/jwks.json")]
    public async Task VerifyAsync_WithUnsafeJwksUrl_ShouldNotOpenNetworkConnection(string jwksUrl)
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler();
        var verifier = CreateVerifier(jwksUrl, handler, cache);

        var verified = await verifier.VerifyAsync(CreateHeaders(), [], CancellationToken.None);

        Assert.False(verified);
        Assert.Equal(0, handler.RequestCount);
    }

    [Fact]
    public async Task VerifyAsync_WithUnsafeJwksUrl_ShouldRedactSecretsFromLogs()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler();
        var logger = new CapturingLogger<FalWebhookSignatureVerifier>();
        var verifier = CreateVerifier(
            "https://user:password@rest.fal.ai/.well-known/jwks.json?token=secret#fragment",
            handler,
            cache,
            logger);

        var verified = await verifier.VerifyAsync(CreateHeaders(), [], CancellationToken.None);

        Assert.False(verified);
        Assert.Equal(0, handler.RequestCount);
        var serializedLogs = string.Join("\n", logger.Entries.Select(entry => entry.Message));
        Assert.Contains("https://rest.fal.ai/***", serializedLogs, StringComparison.Ordinal);
        Assert.DoesNotContain("user", serializedLogs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("password", serializedLogs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("secret", serializedLogs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(".well-known", serializedLogs, StringComparison.OrdinalIgnoreCase);
    }

    private static FalWebhookSignatureVerifier CreateVerifier(
        string jwksUrl,
        RecordingHandler handler,
        IMemoryCache cache,
        ILogger<FalWebhookSignatureVerifier>? logger = null)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Templates:Fal:WebhookJwksUrl"] = jwksUrl
            })
            .Build();

        return new FalWebhookSignatureVerifier(
            new StaticHttpClientFactory(handler),
            configuration,
            cache,
            logger ?? NullLogger<FalWebhookSignatureVerifier>.Instance);
    }

    private static HeaderDictionary CreateHeaders() => new()
    {
        ["X-Fal-Webhook-Request-Id"] = "request-id",
        ["X-Fal-Webhook-User-Id"] = "user-id",
        ["X-Fal-Webhook-Timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(),
        ["X-Fal-Webhook-Signature"] = "00"
    };

    private sealed class StaticHttpClientFactory(RecordingHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class RecordingHandler : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        public Uri? LastRequestUri { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            LastRequestUri = request.RequestUri;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("""{"keys":[]}""")
            });
        }
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull =>
            NullScope.Instance;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception)));
        }
    }

    private sealed record CapturedLogEntry(LogLevel LogLevel, string Message);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
