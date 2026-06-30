using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

using Microsoft.Extensions.Logging;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StripePaymentGatewayCorrelationTests
{
    [Fact]
    public async Task CreatePaymentAsync_ShouldSendStripeRequestsThroughFactoryBackedCorrelationHandler()
    {
        using var correlationScope = CorrelationContext.Push("stripe-correlation-test");
        var recordingHandler = new RecordingHandler();
        var httpClient = new HttpClient(new TestCorrelationHandler
        {
            InnerHandler = recordingHandler
        });
        var gateway = new StripePaymentGateway(
            new EconomyOptions
            {
                StripeCheckoutSuccessUrl = "https://petmagic.app/success",
                StripeCheckoutCancelUrl = "https://petmagic.app/cancel"
            },
            new SingleClientFactory(httpClient));

        var result = await gateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                "stripe",
                Guid.NewGuid(),
                Guid.NewGuid(),
                9.99m,
                "USD",
                100,
                "Test pack",
                ApiSecretKey: "sk_" + "test_factory_correlation",
                PublishableKey: "pk_" + "test_factory_correlation",
                ExternalCustomerId: "cus_factory_correlation",
                UsePaymentSheet: true),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Contains(recordingHandler.Requests, request =>
            string.Equals(request.RequestUri?.AbsolutePath, "/v1/ephemeral_keys", StringComparison.Ordinal));
        Assert.Contains(recordingHandler.Requests, request =>
            string.Equals(request.RequestUri?.AbsolutePath, "/v1/payment_intents", StringComparison.Ordinal));
        Assert.All(recordingHandler.Requests, request =>
        {
            Assert.True(request.Headers.TryGetValues(CorrelationContext.HeaderName, out var values));
            Assert.Equal("stripe-correlation-test", Assert.Single(values));
        });
    }

    [Fact]
    public async Task CreatePaymentAsync_ShouldLogSafeContext_WhenEphemeralKeyRequestFails()
    {
        var logger = new CapturingLogger<StripePaymentGateway>();
        var gateway = new StripePaymentGateway(
            new EconomyOptions
            {
                StripeCheckoutSuccessUrl = "https://petmagic.app/success",
                StripeCheckoutCancelUrl = "https://petmagic.app/cancel"
            },
            new SingleClientFactory(new HttpClient(new EphemeralKeyFailureHandler())),
            logger);

        var apiSecretKey = "sk_test_super_secret_value";
        var customerId = "cus_sensitive_customer_123456";
        var result = await gateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                "stripe",
                Guid.NewGuid(),
                Guid.NewGuid(),
                9.99m,
                "USD",
                100,
                "Test pack",
                ApiSecretKey: apiSecretKey,
                PublishableKey: "pk_test_public_value",
                ExternalCustomerId: customerId,
                UsePaymentSheet: true),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Stripe gateway operation returned non-success status.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("create_payment_ephemeral_key", entry.Properties["Operation"]);
        Assert.Equal("cus_***3456", entry.Properties["ExternalCustomerId"]);
        Assert.Equal(500, entry.Properties["StatusCode"]);
        Assert.DoesNotContain(customerId, entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(apiSecretKey, entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CreatePaymentAsync_ShouldLogSafeContext_WhenPaymentIntentCreationFails()
    {
        var logger = new CapturingLogger<StripePaymentGateway>();
        var gateway = new StripePaymentGateway(
            new EconomyOptions
            {
                StripeCheckoutSuccessUrl = "https://petmagic.app/success",
                StripeCheckoutCancelUrl = "https://petmagic.app/cancel"
            },
            new SingleClientFactory(new HttpClient(new PaymentIntentFailureHandler())),
            logger);

        var apiSecretKey = "sk_test_super_secret_value";
        var customerId = "cus_sensitive_customer_123456";
        var result = await gateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                "stripe",
                Guid.NewGuid(),
                Guid.NewGuid(),
                9.99m,
                "USD",
                100,
                "Test pack",
                ApiSecretKey: apiSecretKey,
                PublishableKey: "pk_test_public_value",
                ExternalCustomerId: customerId,
                UsePaymentSheet: true),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Stripe gateway operation failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("create_payment_sheet_payment_intent", entry.Properties["Operation"]);
        Assert.Equal("cus_***3456", entry.Properties["ExternalCustomerId"]);
        Assert.Equal(true, entry.Properties["UsePaymentSheet"]);
        Assert.DoesNotContain(customerId, entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(apiSecretKey, entry.Message, StringComparison.Ordinal);
    }

    private sealed class SingleClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(StripePaymentGateway.HttpClientName, name);
            return httpClient;
        }
    }

    private sealed class TestCorrelationHandler : DelegatingHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (!request.Headers.Contains(CorrelationContext.HeaderName))
            {
                request.Headers.TryAddWithoutValidation(CorrelationContext.HeaderName, CorrelationContext.ResolveOrCreate());
            }

            return base.SendAsync(request, cancellationToken);
        }
    }

    private sealed class RecordingHandler : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(CloneRequest(request));
            if (string.Equals(request.RequestUri?.AbsolutePath, "/v1/ephemeral_keys", StringComparison.Ordinal))
            {
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent("""{"id":"ephkey_test","object":"ephemeral_key","secret":"ek_test_secret"}""")
                });
            }

            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError)
            {
                Content = new StringContent("""{"error":{"message":"forced test failure"}}""")
            });
        }

        private static HttpRequestMessage CloneRequest(HttpRequestMessage request)
        {
            var clone = new HttpRequestMessage(request.Method, request.RequestUri);
            foreach (var header in request.Headers)
            {
                clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            return clone;
        }
    }

    private sealed class EphemeralKeyFailureHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError)
            {
                Content = new StringContent("""{"error":{"message":"forced ephemeral key failure"}}""")
            });
        }
    }

    private sealed class PaymentIntentFailureHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (string.Equals(request.RequestUri?.AbsolutePath, "/v1/ephemeral_keys", StringComparison.Ordinal))
            {
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent("""{"id":"ephkey_test","object":"ephemeral_key","secret":"ek_test_secret"}""")
                });
            }

            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError)
            {
                Content = new StringContent("""{"error":{"message":"forced payment intent failure"}}""")
            });
        }
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
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values.ToDictionary(x => x.Key, x => x.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel LogLevel,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
