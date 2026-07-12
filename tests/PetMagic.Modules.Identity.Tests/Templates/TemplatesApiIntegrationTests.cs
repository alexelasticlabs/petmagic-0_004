using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Reflection;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Host.Api.Security;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed partial class TemplatesApiIntegrationTests
{

    private static readonly Guid TestUserId = Guid.Parse("35E91443-4E1A-4DF2-8CF7-7C95662324B4");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private static async Task<TemplateAssetResponse> UploadMediaAsync(
        HttpClient client,
        string fileName,
        string contentType,
        TemplateAssetKind assetKind,
        byte[] content)
    {
        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(WithValidMediaHeader(contentType, fileName, content));
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        multipart.Add(fileContent, "file", fileName);
        multipart.Add(new StringContent(assetKind.ToString()), "assetKind");

        using var response = await client.PostAsync("/api/admin/templates/media/upload", multipart);
        response.EnsureSuccessStatusCode();

        return await ReadJsonAsync<TemplateAssetResponse>(response);
    }

    private static byte[] WithValidMediaHeader(string contentType, string fileName, byte[] content)
    {
        var normalizedContentType = contentType.Trim().ToLowerInvariant();
        if (normalizedContentType == "video/mp4" || normalizedContentType == "application/mp4")
        {
            return [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32, .. content];
        }

        if (normalizedContentType == "image/png" || fileName.EndsWith(".png", StringComparison.OrdinalIgnoreCase))
        {
            return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, .. content];
        }

        return [0xFF, 0xD8, 0xFF, 0xE0, .. content];
    }

    private static async Task<AdminTemplateResponse> CreateActiveImageTemplateAsync(HttpClient client, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var previewAsset = await UploadMediaAsync(
            client,
            $"{slug}.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            Encoding.UTF8.GetBytes($"{slug}-image-content"));

        return await PostAsJsonAsync<AdminTemplateResponse>(
            client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));
    }

    private static async Task<TemplateGenerationResponse> UploadGenerationSourceAsync(
        HttpClient client,
        Guid templateId,
        string fileName,
        string contentType,
        byte[] content)
    {
        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(content);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        multipart.Add(fileContent, "sourceImage", fileName);

        using var response = await client.PostAsync($"/api/templates/{templateId}/generations", multipart);
        await EnsureSuccessStatusCodeAsync(response, $"/api/templates/{templateId}/generations");

        return await ReadJsonAsync<TemplateGenerationResponse>(response);
    }

    private static async Task<TemplateGenerationResponse> WaitForGenerationStatusAsync(HttpClient client, Guid generationId, string expectedStatus)
    {
        TemplateGenerationResponse? last = null;
        for (var attempt = 0; attempt < 50; attempt++)
        {
            last = await GetFromJsonAsync<TemplateGenerationResponse>(client, $"/api/templates/generations/{generationId}");
            if (string.Equals(last.Status, expectedStatus, StringComparison.OrdinalIgnoreCase))
            {
                return last;
            }

            await Task.Delay(50);
        }

        throw new TimeoutException($"Generation {generationId} did not reach {expectedStatus}. Last status: {last?.Status ?? "unknown"}.");
    }

    private static async Task<TResponse> PostAsJsonAsync<TResponse>(HttpClient client, string path, object body)
    {
        using var response = await client.PostAsJsonAsync(path, body);
        await EnsureSuccessStatusCodeAsync(response, path);
        return await ReadJsonAsync<TResponse>(response);
    }

    private static async Task<TResponse> PutAsJsonAsync<TResponse>(HttpClient client, string path, object body)
    {
        using var response = await client.PutAsJsonAsync(path, body);
        await EnsureSuccessStatusCodeAsync(response, path);
        return await ReadJsonAsync<TResponse>(response);
    }

    private static async Task<TResponse> GetFromJsonAsync<TResponse>(HttpClient client, string path)
    {
        using var response = await client.GetAsync(path);
        await EnsureSuccessStatusCodeAsync(response, path);
        return await ReadJsonAsync<TResponse>(response);
    }

    private static async Task EnsureSuccessStatusCodeAsync(HttpResponseMessage response, string path)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var body = await response.Content.ReadAsStringAsync();
        throw new HttpRequestException($"Request to {path} failed with {(int)response.StatusCode} ({response.StatusCode}). Body: {body}");
    }

    private static async Task<TResponse> ReadJsonAsync<TResponse>(HttpResponseMessage response)
    {
        var value = await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions);
        return value ?? throw new InvalidOperationException($"Response body for {typeof(TResponse).Name} was empty.");
    }

    private sealed class TestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private TestApplication(WebApplication app, HttpClient client, InMemoryMediaStorage mediaStorage, TestTemplateGenerationBilling billing)
        {
            this.app = app;
            Client = client;
            MediaStorage = mediaStorage;
            Billing = billing;
        }

        public HttpClient Client { get; }

        public InMemoryMediaStorage MediaStorage { get; }

        public TestTemplateGenerationBilling Billing { get; }

        public IServiceProvider Services => app.Services;

        public static async Task<TestApplication> CreateAsync(
            bool failGeneratedMediaImport = false,
            int? freeImageMaxEstimatedWaitSeconds = null,
            bool startGenerationWorker = true,
            bool qaFixturesEnabled = false)
        {
            var databaseRoot = new InMemoryDatabaseRoot();
            var databaseName = $"templates-api-tests-{Guid.NewGuid():N}";

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(TemplatesApiIntegrationTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Configuration["AllowedHosts"] = "*";

            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });

            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
                options.AddPolicy("AdminOnly", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin");
                });
            });

            builder.Services.AddProblemDetails();
            builder.Services.AddDataProtection();
            builder.Services.AddMemoryCache();
            builder.Services.AddRateLimiter(options =>
            {
                options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
                options.OnRejected = RateLimitProblemResponse.WriteAsync;
                options.AddFixedWindowLimiter("templates", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
                options.AddFixedWindowLimiter("templates-analytics", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 48;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
                options.AddConcurrencyLimiter("templates-events", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 3;
                    limiterOptions.QueueLimit = 0;
                });
                options.AddFixedWindowLimiter("generation-create", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
                options.AddFixedWindowLimiter("generation-status", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
                options.AddFixedWindowLimiter("admin", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
            });

            builder.Services.AddDbContext<TemplatesDbContext>(options =>
                options.UseInMemoryDatabase(databaseName, databaseRoot));

            builder.Services.AddSingleton(new TemplatesOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = "wwwroot/templates-media",
                DefaultImagePrompt = "Create a themed pet portrait.",
                DefaultPreprocessingPrompt = "Keep the same pet.",
                DefaultKlingPrompt = "Funny dance.",
                AllowedImageModels = [
                    "openai/gpt-image-2/edit",
                    "fal-ai/nano-banana-pro/edit"
                ],
                AllowedPreprocessingModels = [
                    "openai/gpt-image-2/edit",
                    "fal-ai/nano-banana-pro/edit"
                ],
                AllowedKlingModels = [
                    "fal-ai/kling-video/v3/pro/motion-control",
                    "fal-ai/kling-video/v3/standard/motion-control"
                ],
                SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
                PreviewMaxFileSizeBytes = 5 * 1024 * 1024,
                ReferenceMotionMaxFileSizeBytes = 5 * 1024 * 1024,
                SeedSampleTemplates = false,
                QaFixturesEnabled = qaFixturesEnabled,
                GenerationWorkerPollIntervalMilliseconds = 10,
                GeneratedVideoMaxFileSizeBytes = 5 * 1024 * 1024,
                FreeImageMaxEstimatedWaitSeconds = freeImageMaxEstimatedWaitSeconds ?? 10_000,
                PremiumImageMaxEstimatedWaitSeconds = 10_000,
                PrivilegedImageMaxEstimatedWaitSeconds = 10_000,
                FreeVideoMaxEstimatedWaitSeconds = 10_000,
                PremiumVideoMaxEstimatedWaitSeconds = 10_000,
                PrivilegedVideoMaxEstimatedWaitSeconds = 10_000
            });

            var mediaStorage = new InMemoryMediaStorage();
            var billing = new TestTemplateGenerationBilling();
            builder.Services.AddSingleton<IMediaStorage>(mediaStorage);
            builder.Services.AddSingleton<IMediaMetadataReader, TestMediaMetadataReader>();
            builder.Services.AddSingleton<ITemplateMediaUploadPolicy>(new FixedTemplateMediaUploadPolicy());
            builder.Services.AddSingleton<IImagePreprocessor, TestImagePreprocessor>();
            builder.Services.AddSingleton<IImageGenerator, TestImageGenerator>();
            builder.Services.AddSingleton<IImagePreviewGenerator>(new TestImagePreviewGenerator(mediaStorage));
            builder.Services.AddSingleton<IVideoThumbnailGenerator>(new TestVideoThumbnailGenerator(mediaStorage));
            builder.Services.AddSingleton<IVideoMotionGenerator, TestVideoMotionGenerator>();
            builder.Services.AddSingleton<IGeneratedMediaImporter>(new TestGeneratedMediaImporter(mediaStorage, failGeneratedMediaImport));
            builder.Services.AddSingleton<ITemplateGenerationBilling>(billing);
            builder.Services.AddSingleton<ITemplateWatermarkRenderer, PassthroughWatermarkRenderer>();
            builder.Services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
            builder.Services.AddSingleton<ITemplateGenerationPushNotificationSender, NoopPushNotificationSender>();
            builder.Services.AddSingleton<IEconomyService>(_ => TestEconomyServiceProxy.Create());
            builder.Services
                .AddHttpClient(TemplateLocalizationTranslator.HttpClientName)
                .ConfigurePrimaryHttpMessageHandler(() => new UnavailableTranslationHandler());
            builder.Services.AddScoped<ITemplateMediaLifecycleService, TemplateMediaLifecycleService>();
            builder.Services.AddScoped<ITemplatesService, TemplatesService>();
            builder.Services.AddScoped<TemplateGenerationService>();
            builder.Services.AddScoped<ITemplateGenerationService>(serviceProvider =>
                serviceProvider.GetRequiredService<TemplateGenerationService>());
            builder.Services.AddScoped<ITemplateGenerationQaFixtureService, TemplateGenerationQaFixtureService>();
            builder.Services.AddScoped<IPetsService, PetsService>();
            builder.Services.AddScoped<IFeedbackService, FeedbackService>();
            builder.Services.AddScoped<ITemplatePushTokenService, TemplatePushTokenService>();
            builder.Services.AddScoped<TemplateGenerationJobProcessor>();
            if (startGenerationWorker)
            {
                builder.Services.AddHostedService<TemplateGenerationWorker>();
            }
            builder.Services.AddTemplatesApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapTemplatesApiModule();

            await app.StartAsync();

            var client = app.GetTestClient();
            client.BaseAddress = new Uri("http://localhost");
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName);

            return new TestApplication(app, client, mediaStorage, billing);
        }

        private sealed class NoopPushNotificationSender : ITemplateGenerationPushNotificationSender
        {
            public Task NotifyGenerationTerminalAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken)
            {
                return Task.CompletedTask;
            }
        }

        private sealed class PassthroughWatermarkRenderer : ITemplateWatermarkRenderer
        {
            public Task<Result<StoredMediaResponse>> CreateWatermarkedCopyAsync(
                StoredMediaResponse original,
                TemplateType mediaType,
                Guid generationId,
                CancellationToken cancellationToken)
            {
                return Task.FromResult(Result.Success(original));
            }
        }

        public async ValueTask DisposeAsync()
        {
            Client.Dispose();
            await app.StopAsync();
            await app.DisposeAsync();
        }
    }

    private sealed class InMemoryMediaStorage : IMediaStorage
    {
        private readonly ConcurrentDictionary<string, StoredMediaResponse> assets = new(StringComparer.OrdinalIgnoreCase);

        public ConcurrentBag<string> DeletedUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            var url = $"http://localhost:5000/templates-media/{Guid.NewGuid():N}/{asset.FileName}";
            var stored = new StoredMediaResponse(
                url,
                $"templates-media/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0,
                null);
            assets[url] = stored;
            return Task.FromResult(Result.Success(stored));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            assets.TryRemove(assetUrl, out _);
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class TestMediaMetadataReader : IMediaMetadataReader
    {
        public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            var duration = storedMedia.FileName switch
            {
                "reference.mp4" => 8.75,
                "preview.mp4" => 4.5,
                _ => (double?)null,
            };

            return Task.FromResult(Result.Success(duration));
        }
    }

    private sealed class FixedTemplateMediaUploadPolicy : ITemplateMediaUploadPolicy
    {
        public long GetMaxFileSizeBytes(TemplateAssetKind assetKind) => 5 * 1024 * 1024;
    }

    private sealed class UnavailableTranslationHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.ServiceUnavailable));
        }
    }

    private sealed class TestImagePreprocessor : IImagePreprocessor
    {
        public Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImagePreprocessResult(originalImageUrl, null, null)));
        }
    }

    private sealed class TestImageGenerator : IImageGenerator
    {
        public Task<Result<ImageGenerationResult>> CreateAsync(string sourceImageUrl, string prompt, string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImageGenerationResult($"https://fal.example.test/generated/{Guid.NewGuid():N}.png", null, null)));
        }
    }

    private sealed class TestImagePreviewGenerator(IMediaStorage mediaStorage) : IImagePreviewGenerator
    {
        public async Task<StoredMediaResponse?> CreatePreviewAsync(
            StoredMediaResponse original,
            string outputFileName,
            string? preferredStorageKey,
            CancellationToken cancellationToken)
        {
            var result = await mediaStorage.StoreAsync(
                new MediaUploadCommand(outputFileName, "image/webp", "preview-content"u8.ToArray()),
                cancellationToken);

            return result.IsSuccess ? result.Value : null;
        }
    }

    private sealed class TestVideoThumbnailGenerator(IMediaStorage mediaStorage) : IVideoThumbnailGenerator
    {
        public async Task<StoredMediaResponse?> CreateThumbnailAsync(
            StoredMediaResponse original,
            Guid generationId,
            string outputFileName,
            string? preferredStorageKey,
            CancellationToken cancellationToken)
        {
            var result = await mediaStorage.StoreAsync(
                new MediaUploadCommand(outputFileName, "image/jpeg", "video-thumbnail-content"u8.ToArray()),
                cancellationToken);

            return result.IsSuccess ? result.Value : null;
        }
    }

    private sealed class TestVideoMotionGenerator : IVideoMotionGenerator
    {
        public Task<Result<VideoMotionGenerationResult>> CreateAsync(
            string normalizedImageUrl,
            string referenceVideoUrl,
            string characterOrientation,
            bool keepOriginalSound,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult($"https://fal.example.test/generated/{Guid.NewGuid():N}.mp4", null, null)));
        }
    }

    private sealed class TestGeneratedMediaImporter(IMediaStorage mediaStorage, bool shouldFail) : IGeneratedMediaImporter
    {
        public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            if (shouldFail)
            {
                return Task.FromResult(Result.Failure<StoredMediaResponse>(new Error("templates.generated_media_import_failed", "Generated media import failed.")));
            }

            return mediaStorage.StoreAsync(
                new MediaUploadCommand($"generated-{generationId:N}.mp4", "video/mp4", "generated-video-content"u8.ToArray()),
                cancellationToken);
        }

        public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
        {
            if (shouldFail)
            {
                return Task.FromResult(Result.Failure<StoredMediaResponse>(new Error("templates.generated_media_import_failed", "Generated media import failed.")));
            }

            return mediaStorage.StoreAsync(
                new MediaUploadCommand($"generated-{generationId:N}.png", "image/png", "generated-image-content"u8.ToArray()),
                cancellationToken);
        }
    }

    private sealed class TestTemplateGenerationBilling : ITemplateGenerationBilling
    {
        public ConcurrentBag<Guid> ChargedGenerationIds { get; } = [];

        public ConcurrentBag<Guid> RefundedGenerationIds { get; } = [];

        public Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            ChargedGenerationIds.Add(generationId);
            return Task.FromResult(Result.Success());
        }

        public Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            RefundedGenerationIds.Add(generationId);
            return Task.FromResult(Result.Success());
        }

        public Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(0));
        }
    }

    private class TestEconomyServiceProxy : DispatchProxy
    {
        public static IEconomyService Create()
        {
            return Create<IEconomyService, TestEconomyServiceProxy>();
        }

        protected override object Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(IEconomyService.CreditAsync)
                && args is [CreditBalanceCommand command, CancellationToken])
            {
                return Task.FromResult(Result.Success(new WalletOperationResponse(
                    command.UserId,
                    command.Amount,
                    command.Amount,
                    command.Source,
                    DateTime.UtcNow,
                    null,
                    0)));
            }

            throw new NotSupportedException(targetMethod?.Name ?? "Unknown economy method");
        }
    }

    private sealed class TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers.TryGetValue("X-Test-Role", out var roleValues)
                ? roleValues.ToString()
                : "Admin";
            var userId = Request.Headers.TryGetValue("X-Test-UserId", out var userIdValues)
                && Guid.TryParse(userIdValues.ToString(), out var parsedUserId)
                    ? parsedUserId
                    : TestUserId;

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId.ToString()),
                new(ClaimTypes.Name, "integration-test-user"),
            };

            if (!string.IsNullOrWhiteSpace(role))
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            if (Request.Headers.TryGetValue("X-Test-Premium", out var premiumValues))
            {
                var premiumRaw = premiumValues.ToString();
                if (bool.TryParse(premiumRaw, out var isPremium))
                {
                    claims.Add(new Claim("premium", isPremium ? "true" : "false"));
                }
            }

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }

    private static async Task<TemplateFeedRealtimeEvent> ReadNextServerSentEventAsync(StreamReader reader)
    {
        string? topic = null;
        var dataLines = new List<string>();

        while (true)
        {
            var line = await reader.ReadLineAsync() ?? throw new InvalidOperationException("SSE stream closed before an event was received.");
            if (line.Length == 0)
            {
                if (!string.IsNullOrWhiteSpace(topic))
                {
                    return new TemplateFeedRealtimeEvent(topic, string.Join("\n", dataLines));
                }

                dataLines.Clear();
                continue;
            }

            if (line.StartsWith(':'))
            {
                continue;
            }

            if (line.StartsWith("event:", StringComparison.Ordinal))
            {
                topic = line[6..].Trim();
                continue;
            }

            if (line.StartsWith("data:", StringComparison.Ordinal))
            {
                dataLines.Add(line[5..].TrimStart());
            }
        }
    }
}
