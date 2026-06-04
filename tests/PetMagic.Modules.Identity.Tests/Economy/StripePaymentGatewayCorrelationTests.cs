using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

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
}
