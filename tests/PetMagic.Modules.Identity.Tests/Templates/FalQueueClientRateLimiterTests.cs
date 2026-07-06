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
              "status_url": "https://evil.example.com/status/fal-request-1",
              "response_url": "https://queue.fal.test/response/fal-request-1"
            }
            """);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
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
              "status_url": "https://queue.fal.test/status/fal-request-1",
              "response_url": "https://queue.fal.test/other/response/fal-request-1"
            }
            """);
        var client = CreateClient(dbContext, handler, maxRequestsPerMinute: 1);

        var result = await client.RunAsync(
            "fal-ai/test-model",
            new { image_url = "https://cdn.example.com/pet.jpg" },
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.SubmitCount);
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
                      "status_url": "https://queue.fal.test/status/fal-request-1",
                      "response_url": "https://queue.fal.test/response/fal-request-1"
                    }
                    """);
            }

            if (path.StartsWith("/status/", StringComparison.Ordinal))
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

            if (path.StartsWith("/response/", StringComparison.Ordinal))
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

            if (path.StartsWith("/status/", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync("""{"status":"COMPLETED"}""");
            }

            if (path.StartsWith("/response/", StringComparison.Ordinal))
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
                      "status_url": "https://queue.fal.test/status/fal-request-1",
                      "response_url": "https://queue.fal.test/response/fal-request-1"
                    }
                    """);
            }

            if (path.StartsWith("/status/", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync(statusJson);
            }

            if (path.StartsWith("/response/", StringComparison.Ordinal))
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
}
