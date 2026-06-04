using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StoreSubscriptionVerifierCorrelationTests
{
    [Fact]
    public async Task VerifyProductPurchaseAsync_ShouldSendAppStoreRequestsThroughFactoryBackedCorrelationHandler()
    {
        using var correlationScope = CorrelationContext.Push("store-verifier-correlation-test");
        var recordingHandler = new RecordingHandler();
        using var httpClient = new HttpClient(new TestCorrelationHandler
        {
            InnerHandler = recordingHandler
        });
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(httpClient),
            Options.Create(new EconomyOptions
            {
                AppStoreSharedSecret = "app-store-shared-secret",
                AppStoreBundleId = "com.petmagic.app"
            }));

        var result = await verifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                Guid.NewGuid(),
                "app_store",
                "com.petmagic.spark100",
                "receipt-data",
                null,
                "txn_123",
                null),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.True(result.Value.IsPurchased);
        var request = Assert.Single(recordingHandler.Requests);
        Assert.Equal("https://buy.itunes.apple.com/verifyReceipt", request.RequestUri?.ToString());
        Assert.True(request.Headers.TryGetValues(CorrelationContext.HeaderName, out var values));
        Assert.Equal("store-verifier-correlation-test", Assert.Single(values));
    }

    private sealed class SingleClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(StoreSubscriptionVerifier.HttpClientName, name);
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
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """
                    {
                        "status": 0,
                        "receipt": {
                            "in_app": [
                                {
                                    "product_id": "com.petmagic.spark100",
                                    "transaction_id": "txn_123"
                                }
                            ]
                        }
                    }
                    """)
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
