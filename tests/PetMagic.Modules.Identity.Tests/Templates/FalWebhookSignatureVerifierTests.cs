using System.Net;
using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using NSec.Cryptography;

using PetMagic.Modules.Templates.Api;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalWebhookSignatureVerifierTests
{
    [Fact]
    public void TemplatesApiModule_ShouldDisableJwksRedirectsAndBoundTimeout()
    {
        using var handler = Assert.IsType<HttpClientHandler>(
            TemplatesApiModule.CreateFalWebhookJwksPrimaryHandler());
        Assert.False(handler.AllowAutoRedirect);

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddTemplatesApiModule();
        using var provider = services.BuildServiceProvider();
        using var client = provider
            .GetRequiredService<IHttpClientFactory>()
            .CreateClient(FalWebhookSignatureVerifier.HttpClientName);

        Assert.Equal(TimeSpan.FromSeconds(10), client.Timeout);
    }

    [Fact]
    public async Task VerifyAsync_WithValidEd25519Signature_ShouldAcceptUntamperedBodyOnly()
    {
        var algorithm = SignatureAlgorithm.Ed25519;
        using var signingKey = Key.Create(
            algorithm,
            new KeyCreationParameters { ExportPolicy = KeyExportPolicies.AllowPlaintextExport });
        var publicKey = signingKey.PublicKey.Export(KeyBlobFormat.RawPublicKey);
        var jwks = $$"""{"keys":[{"kty":"OKP","crv":"Ed25519","x":"{{Base64Url(publicKey)}}"}]}""";
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler(responseBody: jwks);
        var verifier = CreateVerifier("https://rest.fal.ai/.well-known/jwks.json", handler, cache);
        var body = Encoding.UTF8.GetBytes("""{"request_id":"fal-request-1","status":"OK"}""");
        var headers = CreateSignedHeaders(algorithm, signingKey, body);

        var verified = await verifier.VerifyAsync(headers, body, CancellationToken.None);
        var tampered = await verifier.VerifyAsync(
            headers,
            Encoding.UTF8.GetBytes("""{"request_id":"fal-request-1","status":"ERROR"}"""),
            CancellationToken.None);

        Assert.True(verified);
        Assert.False(tampered);
        Assert.Equal(1, handler.RequestCount);
    }

    [Fact]
    public async Task VerifyAsync_WithStaleTimestamp_ShouldRejectBeforeFetchingJwks()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler();
        var verifier = CreateVerifier("https://rest.fal.ai/.well-known/jwks.json", handler, cache);
        var headers = CreateHeaders();
        headers["X-Fal-Webhook-Timestamp"] = DateTimeOffset.UtcNow
            .AddMinutes(-6)
            .ToUnixTimeSeconds()
            .ToString();

        var verified = await verifier.VerifyAsync(headers, [], CancellationToken.None);

        Assert.False(verified);
        Assert.Equal(0, handler.RequestCount);
    }

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

    [Fact]
    public async Task VerifyAsync_WithRedirectResponse_ShouldRejectWithoutFollowingTarget()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var handler = new RecordingHandler(statusCode: HttpStatusCode.Redirect);
        var verifier = CreateVerifier("https://rest.fal.ai/.well-known/jwks.json", handler, cache);

        var verified = await verifier.VerifyAsync(CreateHeaders(), [], CancellationToken.None);

        Assert.False(verified);
        Assert.Equal(1, handler.RequestCount);
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

    private static HeaderDictionary CreateSignedHeaders(
        SignatureAlgorithm algorithm,
        Key signingKey,
        byte[] body)
    {
        const string requestId = "fal-request-1";
        const string userId = "fal-user-1";
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var bodyHashHex = Convert.ToHexString(SHA256.HashData(body)).ToLowerInvariant();
        var message = Encoding.UTF8.GetBytes(string.Join('\n', requestId, userId, timestamp, bodyHashHex));
        var signature = algorithm.Sign(signingKey, message);
        return new HeaderDictionary
        {
            ["X-Fal-Webhook-Request-Id"] = requestId,
            ["X-Fal-Webhook-User-Id"] = userId,
            ["X-Fal-Webhook-Timestamp"] = timestamp,
            ["X-Fal-Webhook-Signature"] = Convert.ToHexString(signature)
        };
    }

    private static string Base64Url(byte[] value) => Convert
        .ToBase64String(value)
        .TrimEnd('=')
        .Replace('+', '-')
        .Replace('/', '_');

    private sealed class StaticHttpClientFactory(RecordingHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class RecordingHandler(
        string responseBody = """{"keys":[]}""",
        HttpStatusCode statusCode = HttpStatusCode.OK) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        public Uri? LastRequestUri { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            LastRequestUri = request.RequestUri;
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(responseBody)
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
