using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using System.Security.Cryptography;

using PetMagic.BuildingBlocks.Results;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StoreSubscriptionVerifierCorrelationTests
{
    [Fact]
    public async Task VerifyProductPurchaseAsync_ShouldAcceptAcknowledgedGooglePlayProduct()
    {
        using var rsa = RSA.Create(2048);
        var handler = new GooglePlayProductHandler(
            """
            {
                "purchaseState": 0,
                "acknowledgementState": 1,
                "orderId": "GPA.1234-5678-9012-34567"
            }
            """);
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(new HttpClient(handler)),
            Options.Create(new EconomyOptions
            {
                GooglePlayServiceAccountEmail = "billing-test@petmagic.iam.gserviceaccount.com",
                GooglePlayPrivateKeyPem = rsa.ExportPkcs8PrivateKeyPem(),
                GooglePlayPackageName = "com.petmagic.app",
                AppStoreBundleId = "com.petmagic.app"
            }),
            new FakeStoreWebhookSecurityValidator(Result.Success()));

        var result = await verifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                Guid.NewGuid(),
                "google_play",
                "com.petmagic.app.tokens.google.pack100",
                "gp-token-acknowledged",
                null,
                "gp-token-acknowledged",
                null),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.True(result.Value.IsPurchased);
        Assert.Equal("GPA.1234-5678-9012-34567", result.Value.ExternalTransactionId);
    }

    [Fact]
    public async Task VerifyProductPurchaseAsync_ShouldRejectUnacknowledgedGooglePlayProduct()
    {
        using var rsa = RSA.Create(2048);
        var handler = new GooglePlayProductHandler(
            """
            {
                "purchaseState": 0,
                "acknowledgementState": 0,
                "orderId": "GPA.1234-5678-9012-34567"
            }
            """);
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(new HttpClient(handler)),
            Options.Create(new EconomyOptions
            {
                GooglePlayServiceAccountEmail = "billing-test@petmagic.iam.gserviceaccount.com",
                GooglePlayPrivateKeyPem = rsa.ExportPkcs8PrivateKeyPem(),
                GooglePlayPackageName = "com.petmagic.app",
                AppStoreBundleId = "com.petmagic.app"
            }),
            new FakeStoreWebhookSecurityValidator(Result.Success()));

        var result = await verifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                Guid.NewGuid(),
                "google_play",
                "com.petmagic.app.tokens.google.pack100",
                "gp-token-unacknowledged",
                null,
                "gp-token-unacknowledged",
                null),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.False(result.Value.IsPurchased);
        Assert.Equal("not_purchased", result.Value.Status);
    }

    [Fact]
    public async Task VerifyProductPurchaseAsync_ShouldRejectAppStoreJws_WhenSignatureValidationFails()
    {
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(new HttpClient(new RecordingHandler())),
            Options.Create(new EconomyOptions
            {
                AppStoreBundleId = "com.petmagic.app"
            }),
            new FakeStoreWebhookSecurityValidator(Result.Failure(EconomyErrors.InvalidStoreWebhookSignature)));

        var result = await verifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                Guid.NewGuid(),
                "app_store",
                "com.petmagic.spark100",
                "header.payload.signature",
                null,
                "txn_123",
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

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
            }),
            new FakeStoreWebhookSecurityValidator(Result.Success()));

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

    [Fact]
    public async Task VerifyProductPurchaseAsync_ShouldLogSafeContext_WhenGooglePlayVerificationThrows()
    {
        using var rsa = RSA.Create(2048);
        var logger = new CapturingLogger<StoreSubscriptionVerifier>();
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(new HttpClient(new ThrowingGooglePlayProductHandler())),
            Options.Create(new EconomyOptions
            {
                GooglePlayServiceAccountEmail = "billing-test@petmagic.iam.gserviceaccount.com",
                GooglePlayPrivateKeyPem = rsa.ExportPkcs8PrivateKeyPem(),
                GooglePlayPackageName = "com.petmagic.app",
                AppStoreBundleId = "com.petmagic.app"
            }),
            new FakeStoreWebhookSecurityValidator(Result.Success()),
            logger);

        var purchaseId = "GPA.1234-5678-9012-34567";
        var verificationData = "gp-sensitive-token-1234567890";
        var result = await verifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                Guid.NewGuid(),
                "google_play",
                "com.petmagic.app.tokens.google.pack100",
                verificationData,
                "local-proof",
                purchaseId,
                "2026-07-01T12:34:56Z"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StoreVerificationUnavailable.Code, result.Error.Code);

        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Store product verification failed.", entry.Message, StringComparison.Ordinal);
        Assert.Contains("Provider=google_play", entry.Message, StringComparison.Ordinal);
        Assert.Contains("Operation=product_verify", entry.Message, StringComparison.Ordinal);
        Assert.Contains("VerificationDataKind=token", entry.Message, StringComparison.Ordinal);
        Assert.Contains("PurchaseId=GPA.***4567", entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(purchaseId, entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(verificationData, entry.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task VerifyAsync_ShouldLogSafeContext_WhenAppStoreVerificationThrows()
    {
        var logger = new CapturingLogger<StoreSubscriptionVerifier>();
        var verifier = new StoreSubscriptionVerifier(
            new SingleClientFactory(new HttpClient(new ThrowingAppStoreHandler())),
            Options.Create(new EconomyOptions
            {
                AppStoreSharedSecret = "app-store-shared-secret",
                AppStoreBundleId = "com.petmagic.app"
            }),
            new FakeStoreWebhookSecurityValidator(Result.Success()),
            logger);

        var purchaseId = "1000001234567890";
        var verificationData = new string('r', 256);
        var result = await verifier.VerifyAsync(
            new StoreSubscriptionVerificationRequest(
                Guid.NewGuid(),
                "app_store",
                "premium_monthly",
                "com.petmagic.spark100",
                verificationData,
                null,
                purchaseId,
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StoreVerificationUnavailable.Code, result.Error.Code);

        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Store subscription verification failed.", entry.Message, StringComparison.Ordinal);
        Assert.Contains("Provider=app_store", entry.Message, StringComparison.Ordinal);
        Assert.Contains("Operation=subscription_verify", entry.Message, StringComparison.Ordinal);
        Assert.Contains("Endpoint=production", entry.Message, StringComparison.Ordinal);
        Assert.Contains("VerificationDataKind=receipt", entry.Message, StringComparison.Ordinal);
        Assert.Contains("PurchaseId=1000***7890", entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(purchaseId, entry.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(verificationData, entry.Message, StringComparison.Ordinal);
    }

    private sealed class SingleClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(StoreSubscriptionVerifier.HttpClientName, name);
            return httpClient;
        }
    }

    private sealed class FakeStoreWebhookSecurityValidator(Result appStoreResult) : IStoreWebhookSecurityValidator
    {
        public Result ValidateAppStoreSignedPayload(string signedPayload)
        {
            return appStoreResult;
        }

        public Task<Result> ValidateGooglePlayPushAsync(string? authorizationHeader, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
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

    private sealed class GooglePlayProductHandler(string productResponseJson) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent("{\"access_token\":\"google-access-token\",\"token_type\":\"Bearer\",\"expires_in\":3600}")
                });
            }

            if (request.RequestUri?.Host == "androidpublisher.googleapis.com")
            {
                Assert.True(request.Headers.Authorization?.Scheme == "Bearer");
                Assert.Equal("google-access-token", request.Headers.Authorization?.Parameter);
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent(productResponseJson)
                });
            }

            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.NotFound));
        }
    }

    private sealed class ThrowingGooglePlayProductHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StringContent("{\"access_token\":\"google-access-token\",\"token_type\":\"Bearer\",\"expires_in\":3600}")
                });
            }

            throw new HttpRequestException("google play verification upstream unavailable");
        }
    }

    private sealed class ThrowingAppStoreHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            throw new HttpRequestException("app store verification upstream unavailable");
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
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception));
        }
    }

    private sealed record CapturedLogEntry(LogLevel LogLevel, string Message, Exception? Exception);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
