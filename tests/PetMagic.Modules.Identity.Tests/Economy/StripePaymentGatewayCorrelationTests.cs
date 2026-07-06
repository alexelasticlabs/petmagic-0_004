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
        Assert.Equal("cus_***3456", entry.Properties["ExternalCustomerIdSafe"]);
        Assert.False(entry.Properties.ContainsKey("ExternalCustomerId"));
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
        Assert.Equal("cus_***3456", entry.Properties["ExternalCustomerIdSafe"]);
        Assert.False(entry.Properties.ContainsKey("ExternalCustomerId"));
        Assert.Equal(true, entry.Properties["UsePaymentSheet"]);
        Assert.DoesNotContain(customerId, entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(apiSecretKey, entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CreatePaymentWithSavedMethodAsync_ShouldRejectNonSucceededPaymentIntentStatus()
    {
        var logger = new CapturingLogger<StripePaymentGateway>();
        var gateway = new StripePaymentGateway(
            new EconomyOptions(),
            new SingleClientFactory(new HttpClient(new SavedMethodPaymentIntentStatusHandler("requires_action"))),
            logger);

        var result = await gateway.CreatePaymentWithSavedMethodAsync(
            new PaymentSavedMethodCreateRequest(
                "stripe",
                Guid.NewGuid(),
                Guid.NewGuid(),
                9.99m,
                "USD",
                100,
                "Test pack",
                "cus_sensitive_customer_123456",
                "pm_sensitive_payment_method_123456",
                "sk_test_super_secret_value"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Stripe gateway operation returned non-success status.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("create_saved_method_payment_intent", entry.Properties["Operation"]);
        Assert.Equal("cus_***3456", entry.Properties["ExternalCustomerIdSafe"]);
        Assert.Equal("pi_***1234", entry.Properties["ExternalPaymentIdSafe"]);
        Assert.Equal("pm_***3456", entry.Properties["ExternalPaymentMethodIdSafe"]);
        Assert.False(entry.Properties.ContainsKey("ExternalCustomerId"));
        Assert.False(entry.Properties.ContainsKey("ExternalPaymentId"));
        Assert.False(entry.Properties.ContainsKey("ExternalPaymentMethodId"));
        Assert.DoesNotContain("cus_sensitive_customer_123456", entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("pm_sensitive_payment_method_123456", entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("sk_test_super_secret_value", entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CreatePaymentWithSavedMethodAsync_ShouldReturnSuccess_WhenPaymentIntentStatusIsSucceeded()
    {
        var gateway = new StripePaymentGateway(
            new EconomyOptions(),
            new SingleClientFactory(new HttpClient(new SavedMethodPaymentIntentStatusHandler("succeeded"))));

        var result = await gateway.CreatePaymentWithSavedMethodAsync(
            new PaymentSavedMethodCreateRequest(
                "stripe",
                Guid.NewGuid(),
                Guid.NewGuid(),
                9.99m,
                "USD",
                100,
                "Test pack",
                "cus_test_customer",
                "pm_test_payment_method",
                "sk_test_super_secret_value"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("pi_saved_method_1234", result.Value.ExternalPaymentId);
        Assert.Equal(string.Empty, result.Value.CheckoutUrl);
    }

    [Fact]
    public async Task ResolveSetupIntentPaymentMethodAsync_ShouldRejectNonSucceededSetupIntentStatusWithoutFetchingPaymentMethod()
    {
        var logger = new CapturingLogger<StripePaymentGateway>();
        var handler = new SetupIntentStatusHandler("requires_action");
        var gateway = new StripePaymentGateway(
            new EconomyOptions
            {
                StripeTestSecretKey = "sk_test_gateway_key"
            },
            new SingleClientFactory(new HttpClient(handler)),
            logger);

        var result = await gateway.ResolveSetupIntentPaymentMethodAsync(
            new PaymentMethodResolveRequest("stripe", "seti_sensitive_123456"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("/v1/setup_intents/seti_sensitive_123456", Assert.Single(handler.RequestPaths));
        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Stripe gateway operation returned non-success status.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("resolve_setup_intent_payment_method", entry.Properties["Operation"]);
        Assert.Equal("seti_***3456", entry.Properties["ExternalSetupIdSafe"]);
        Assert.False(entry.Properties.ContainsKey("ExternalSetupId"));
        Assert.DoesNotContain("seti_sensitive_123456", entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ResolveSetupIntentPaymentMethodAsync_ShouldReturnPaymentMethod_WhenSetupIntentStatusIsSucceeded()
    {
        var handler = new SetupIntentStatusHandler("succeeded");
        var gateway = new StripePaymentGateway(
            new EconomyOptions
            {
                StripeTestSecretKey = "sk_test_gateway_key"
            },
            new SingleClientFactory(new HttpClient(handler)));

        var result = await gateway.ResolveSetupIntentPaymentMethodAsync(
            new PaymentMethodResolveRequest("stripe", "seti_test_1234"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("pm_test_1234", result.Value.ExternalPaymentMethodId);
        Assert.Equal("visa", result.Value.Brand);
        Assert.Equal("4242", result.Value.Last4);
        Assert.Equal(2, handler.RequestPaths.Count);
        Assert.Equal("/v1/setup_intents/seti_test_1234", handler.RequestPaths[0]);
        Assert.Equal("/v1/payment_methods/pm_test_1234", handler.RequestPaths[1]);
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

    private sealed class SavedMethodPaymentIntentStatusHandler(string status) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Assert.Equal("/v1/payment_intents", request.RequestUri?.AbsolutePath);
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(
                    $$"""{"id":"pi_saved_method_1234","object":"payment_intent","status":"{{status}}"}""")
            });
        }
    }

    private sealed class SetupIntentStatusHandler(string status) : HttpMessageHandler
    {
        public List<string> RequestPaths { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var requestPath = request.RequestUri?.AbsolutePath ?? string.Empty;
            RequestPaths.Add(requestPath);

            if (requestPath.StartsWith("/v1/setup_intents/", StringComparison.Ordinal))
            {
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent(
                        $$"""{"id":"seti_test_1234","object":"setup_intent","status":"{{status}}","payment_method":"pm_test_1234"}""")
                });
            }

            Assert.Equal("/v1/payment_methods/pm_test_1234", requestPath);
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"id":"pm_test_1234","object":"payment_method","type":"card","card":{"brand":"visa","last4":"4242","exp_month":12,"exp_year":2030}}""")
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
