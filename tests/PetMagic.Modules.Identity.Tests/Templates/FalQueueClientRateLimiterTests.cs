using System.Net;
using System.Reflection;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalQueueClientRateLimiterTests
{
    [Fact]
    public async Task RunAsync_ShouldThrottleSubmitOnly_AndNotPollingRequests()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new RecordingFalHandler();
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            timeout.Token);

        Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : "unexpected failure");
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(1, handler.StatusCount);
        Assert.Equal(1, handler.ResponseCount);
    }

    [Fact]
    public async Task RunAsync_ShouldWaitForNextPermitBeforeSecondSubmit()
    {
        ResetLocalRateLimiterState();
        await WaitUntilCurrentMinuteHasAtLeastAsync(TimeSpan.FromSeconds(2));
        await using var dbContext = CreateDbContext();
        var handler = new RecordingFalHandler();
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var first = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/first.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);
        Assert.True(first.IsSuccess, first.IsFailure ? first.Error.Code : "unexpected failure");

        using var timeout = new CancellationTokenSource(TimeSpan.FromMilliseconds(250));
        await Assert.ThrowsAsync<TaskCanceledException>(() =>
            client.RunAsync(
                "fal-ai/test-model",
                new { image_url = "https://cdn.example.com/second.jpg" },
                new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
                timeout.Token));

        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(1, handler.StatusCount);
        Assert.Equal(1, handler.ResponseCount);
    }

    [Fact]
    public async Task RunAsync_ShouldRejectSubmitResponse_WhenStatusUrlUsesDifferentHost()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new InvalidCallbackFalHandler(
            """
            {
              "request_id": "fal-request-1",
              "status_url": "https://evil.example.com/fal-ai/test-model/requests/fal-request-1/status",
              "response_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/response",
              "cancel_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel"
            }
            """);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderSubmissionUnknown.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(0, handler.StatusCount);
        Assert.Equal(0, handler.ResponseCount);
    }

    [Fact]
    public async Task RunAsync_ShouldRejectSubmitResponse_WhenResponseUrlEscapesQueueBasePath()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new InvalidCallbackFalHandler(
            """
            {
              "request_id": "fal-request-1",
              "status_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/status",
              "response_url": "https://queue.fal.test/other/fal-ai/test-model/requests/fal-request-1/response",
              "cancel_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel"
            }
            """);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderSubmissionUnknown.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(0, handler.StatusCount);
        Assert.Equal(0, handler.ResponseCount);
    }

    [Theory]
    [InlineData("openai/gpt-image-2/edit", "openai/gpt-image-2")]
    [InlineData("fal-ai/flux-2-pro/edit", "fal-ai/flux-2-pro")]
    [InlineData("fal-ai/kling-video/v3/standard/motion-control", "fal-ai/kling-video")]
    public async Task RunAsync_ShouldAcceptCanonicalCallbacksForNestedModelRoute(
        string model,
        string canonicalModelRoute)
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new CanonicalCallbackFalHandler(canonicalModelRoute);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            model,
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : "unexpected failure");
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(1, handler.StatusCount);
        Assert.Equal(1, handler.ResponseCount);
    }

    [Fact]
    public async Task SubmitAsync_ShouldRejectCallbacksThatResolveToDifferentCanonicalModelRoutes()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new InvalidCallbackFalHandler(
            """
            {
              "request_id": "fal-request-1",
              "status_url": "https://queue.fal.test/fal-ai/kling-video/requests/fal-request-1/status",
              "response_url": "https://queue.fal.test/fal-ai/kling-video/v3/requests/fal-request-1",
              "cancel_url": "https://queue.fal.test/fal-ai/kling-video/requests/fal-request-1/cancel"
            }
            """);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.SubmitAsync(
            "fal-ai/kling-video/v3/standard/motion-control",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("video", FalQueueStages.VideoGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderSubmissionUnknown.Code, result.Error.Code);
    }

    [Fact]
    public async Task SubmitAsync_ShouldReturnSubmissionUnknown_WhenAcceptedPayloadIsMalformed()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new InvalidCallbackFalHandler("{not-json");
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.SubmitAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderSubmissionUnknown.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(0, handler.StatusCount);
        Assert.Equal(0, handler.ResponseCount);
    }

    [Fact]
    public async Task SubmitAsync_ShouldReturnRateLimited_WhenProviderReturnsTooManyRequests()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new CancellationFalHandler(HttpStatusCode.TooManyRequests, "RATE_LIMITED");
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.SubmitAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderRateLimited.Code, result.Error.Code);
        Assert.Equal(HttpMethod.Post, handler.Method);
    }

    [Theory]
    [InlineData("https://evil.example.com/steal")]
    [InlineData("//evil.example.com/steal")]
    [InlineData("../steal")]
    [InlineData("fal-ai/test-model?redirect=https://evil.example.com")]
    public async Task SubmitAsync_ShouldRejectModelRouteThatEscapesFalQueueOrigin(string model)
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new RecordingFalHandler();
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.SubmitAsync(
            model,
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
        Assert.Equal(0, handler.SubmitCount);
        Assert.Equal(0, handler.StatusCount);
        Assert.Equal(0, handler.ResponseCount);
    }

    [Fact]
    public async Task RunAsync_ShouldReturnProviderFailure_WhenStatusPayloadIsMalformed()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new MalformedFalHandler(statusJson: "{not-json", responseJson: """{"images":[]}""");
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(1, handler.StatusCount);
        Assert.Equal(0, handler.ResponseCount);
    }

    [Fact]
    public async Task RunAsync_ShouldReturnProviderFailure_WhenResponsePayloadIsMalformed()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new MalformedFalHandler(statusJson: """{"status":"COMPLETED"}""", responseJson: "{not-json");
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
        Assert.Equal(1, handler.StatusCount);
        Assert.Equal(1, handler.ResponseCount);
    }

    [Theory]
    [InlineData(HttpStatusCode.Accepted, "CANCELLATION_REQUESTED", 0)]
    [InlineData(HttpStatusCode.BadRequest, "ALREADY_COMPLETED", 1)]
    [InlineData(HttpStatusCode.NotFound, "NOT_FOUND", 2)]
    [InlineData(HttpStatusCode.TooManyRequests, "RATE_LIMITED", 3)]
    [InlineData(HttpStatusCode.ServiceUnavailable, "UNAVAILABLE", 3)]
    public async Task CancelAsync_ShouldMapFalQueueOutcome(
        HttpStatusCode statusCode,
        string providerStatus,
        int expectedOutcome)
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new CancellationFalHandler(statusCode, providerStatus);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);
        var cancelUri = new Uri(
            "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel");

        var result = await client.CancelAsync(
            "fal-ai/test-model",
            "fal-request-1",
            cancelUri,
            CancellationToken.None);

        Assert.Equal((FalQueueCancellationOutcome)expectedOutcome, result.Outcome);
        Assert.Equal(HttpMethod.Put, handler.Method);
        Assert.Equal("Key", handler.AuthorizationScheme);
        Assert.Equal("test-fal-key", handler.AuthorizationParameter);
    }

    [Fact]
    public async Task CancelAsync_ShouldRejectUntrustedOrMismatchedUrlWithoutNetworkCall()
    {
        ResetLocalRateLimiterState();
        await using var dbContext = CreateDbContext();
        var handler = new CancellationFalHandler(HttpStatusCode.Accepted, "CANCELLATION_REQUESTED");
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.CancelAsync(
            "fal-ai/test-model",
            "fal-request-1",
            new Uri("https://evil.example.com/fal-ai/test-model/requests/fal-request-1/cancel"),
            CancellationToken.None);

        Assert.Equal(FalQueueCancellationOutcome.PermanentFailure, result.Outcome);
        Assert.Null(handler.Method);
    }

    [Fact]
    public void ResolveCancellationUri_ShouldDeriveTrustedLegacyUrlFromStatusUrl()
    {
        ResetLocalRateLimiterState();
        using var dbContext = CreateDbContext();
        var client = CreateClient(
            dbContext,
            new CancellationFalHandler(HttpStatusCode.Accepted, "CANCELLATION_REQUESTED"),
            maxRequestsPerMinute: 1);

        var result = client.ResolveCancellationUri(
            "fal-ai/test-model",
            "fal-request-1",
            cancelUrl: null,
            statusUrl: "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/status");

        Assert.Equal(
            "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel",
            result?.ToString());
        Assert.Null(client.ResolveCancellationUri(
            "fal-ai/test-model",
            "fal-request-1",
            cancelUrl: null,
            statusUrl: "https://queue.fal.test/fal-ai/other-model/requests/fal-request-1/status"));
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"fal-queue-rate-limiter-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static FalQueueClient CreateClient(
        TemplatesDbContext dbContext,
        HttpMessageHandler handler,
        int maxRequestsPerMinute)
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = Path.GetTempPath(),
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "image",
            AllowedImageModels = ["fal-ai/test-model"],
            AllowedPreprocessingModels = ["fal-ai/test-model"],
            AllowedKlingModels = ["fal-ai/test-model"],
            SupportedLocalizationLocales = ["en"],
            MaxAiProviderRequestsPerMinute = maxRequestsPerMinute,
            Fal = new FalAiOptions
            {
                ApiKey = "test-fal-key",
                QueueBaseUrl = "https://queue.fal.test",
                PollIntervalMilliseconds = 250,
                MaxPollingAttempts = 1
            }
        };

        return new FalQueueClient(
            new FixedHttpClientFactory(new HttpClient(handler)
            {
                BaseAddress = new Uri("https://queue.fal.test")
            }),
            options,
            new TemplateAiProviderRateLimiter(dbContext, options),
            NullLogger<FalQueueClient>.Instance);
    }

    private static void ResetLocalRateLimiterState()
    {
        var field = typeof(TemplateAiProviderRateLimiter).GetField(
            "LocalPermitCounts",
            BindingFlags.NonPublic | BindingFlags.Static);
        var state = field?.GetValue(null);
        state?.GetType().GetMethod("Clear")?.Invoke(state, null);
    }

    private static async Task WaitUntilCurrentMinuteHasAtLeastAsync(TimeSpan remaining)
    {
        while (true)
        {
            var now = DateTime.UtcNow;
            var nextMinute = new DateTime(now.Year, now.Month, now.Day, now.Hour, now.Minute, 0, DateTimeKind.Utc)
                .AddMinutes(1);
            if (nextMinute - now >= remaining)
            {
                return;
            }

            await Task.Delay(50);
        }
    }

    private sealed class FixedHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class RecordingFalHandler : HttpMessageHandler
    {
        public int SubmitCount { get; private set; }

        public int StatusCount { get; private set; }

        public int ResponseCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            if (request.Method == HttpMethod.Post)
            {
                SubmitCount++;
                return JsonAsync(
                    """
                    {
                      "request_id": "fal-request-1",
                      "status_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/status",
                      "response_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/response",
                      "cancel_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel"
                    }
                    """);
            }

            if (path.EndsWith("/status", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync(
                    """
                    {
                      "status": "COMPLETED",
                      "request_id": "fal-request-1",
                      "metrics": {
                        "inference_time": 1.25
                      }
                    }
                    """);
            }

            if (path.EndsWith("/response", StringComparison.Ordinal))
            {
                ResponseCount++;
                return JsonAsync(
                    """
                    {
                      "images": [
                        {
                          "url": "https://cdn.example.com/generated.png"
                        }
                      ]
                    }
                    """);
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static Task<HttpResponseMessage> JsonAsync(string json)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
        }
    }

    private sealed class InvalidCallbackFalHandler(string submitJson) : HttpMessageHandler
    {
        public int SubmitCount { get; private set; }

        public int StatusCount { get; private set; }

        public int ResponseCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            if (request.Method == HttpMethod.Post)
            {
                SubmitCount++;
                return JsonAsync(submitJson);
            }

            if (path.EndsWith("/status", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync("""{"status":"COMPLETED"}""");
            }

            if (path.EndsWith("/response", StringComparison.Ordinal))
            {
                ResponseCount++;
                return JsonAsync("""{"images":[]}""");
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static Task<HttpResponseMessage> JsonAsync(string json)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
        }
    }

    private sealed class CanonicalCallbackFalHandler(string canonicalModelRoute) : HttpMessageHandler
    {
        public int SubmitCount { get; private set; }

        public int StatusCount { get; private set; }

        public int ResponseCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            var requestPath = $"/{canonicalModelRoute}/requests/fal-request-1";
            if (request.Method == HttpMethod.Post)
            {
                SubmitCount++;
                return JsonAsync($$"""
                    {
                      "request_id": "fal-request-1",
                      "status_url": "https://queue.fal.test/{{canonicalModelRoute}}/requests/fal-request-1/status",
                      "response_url": "https://queue.fal.test/{{canonicalModelRoute}}/requests/fal-request-1",
                      "cancel_url": "https://queue.fal.test/{{canonicalModelRoute}}/requests/fal-request-1/cancel"
                    }
                    """);
            }

            if (string.Equals(path, requestPath + "/status", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync("""{"status":"COMPLETED","request_id":"fal-request-1"}""");
            }

            if (string.Equals(path, requestPath, StringComparison.Ordinal))
            {
                ResponseCount++;
                return JsonAsync("""{"images":[]}""");
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static Task<HttpResponseMessage> JsonAsync(string json)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
        }
    }

    private sealed class MalformedFalHandler(string statusJson, string responseJson) : HttpMessageHandler
    {
        public int SubmitCount { get; private set; }

        public int StatusCount { get; private set; }

        public int ResponseCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            if (request.Method == HttpMethod.Post)
            {
                SubmitCount++;
                return JsonAsync(
                    """
                    {
                      "request_id": "fal-request-1",
                      "status_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/status",
                      "response_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/response",
                      "cancel_url": "https://queue.fal.test/fal-ai/test-model/requests/fal-request-1/cancel"
                    }
                    """);
            }

            if (path.EndsWith("/status", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync(statusJson);
            }

            if (path.EndsWith("/response", StringComparison.Ordinal))
            {
                ResponseCount++;
                return JsonAsync(responseJson);
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static Task<HttpResponseMessage> JsonAsync(string json)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
        }
    }

    private sealed class CancellationFalHandler(
        HttpStatusCode statusCode,
        string providerStatus) : HttpMessageHandler
    {
        public HttpMethod? Method { get; private set; }

        public string? AuthorizationScheme { get; private set; }

        public string? AuthorizationParameter { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Method = request.Method;
            AuthorizationScheme = request.Headers.Authorization?.Scheme;
            AuthorizationParameter = request.Headers.Authorization?.Parameter;
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(
                    $$"""{"status":"{{providerStatus}}"}""",
                    Encoding.UTF8,
                    "application/json")
            });
        }
    }
}
