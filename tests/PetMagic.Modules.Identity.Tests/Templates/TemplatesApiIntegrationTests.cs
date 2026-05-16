using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesApiIntegrationTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task VideoTemplateFlow_ShouldSupportUploadCreateUpdateActivatePublicFetchAndDelete()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "preview-video-content"u8.ToArray());

        var referenceAsset = await UploadMediaAsync(
            application.Client,
            "reference.mp4",
            "video/mp4",
            TemplateAssetKind.ReferenceMotion,
            "reference-video-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Funny dance.",
                true,
                TemplateStatus.Draft.ToString()));

        Assert.Equal("Draft", created.Status);
        Assert.Equal(8.75, created.ReferenceVideoDurationSeconds);

        var adminDraftList = await GetFromJsonAsync<IReadOnlyList<AdminTemplateListItemResponse>>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Draft");

        var persistedDraftItem = Assert.Single(adminDraftList);
        var templateId = persistedDraftItem.TemplateId;

        var publicBeforeActivation = await GetFromJsonAsync<IReadOnlyList<PublicTemplateListItemResponse>>(
            application.Client,
            "/api/templates/?type=Video");

        Assert.Empty(publicBeforeActivation);

        var updated = await PutAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            $"/api/admin/templates/video/{templateId}",
            new AdminTemplateEndpoints.UpdateVideoTemplateRequest(
                "Viral Dance Deluxe",
                "Updated funny dance template",
                "Dance",
                ["viral", "dance", "updated"],
                true,
                75,
                TemplatePromoBadgeMode.Popular.ToString(),
                "Updated soundtrack",
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet with consistent body pose.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Updated dance prompt.",
                true,
                TemplateStatus.Draft.ToString()));

        Assert.Equal("Viral Dance Deluxe", updated.Title);
        Assert.Equal("Draft", updated.Status);
        Assert.Equal(75, updated.TokenCost);

        var adminDetailBeforeActivation = await GetFromJsonAsync<AdminTemplateResponse>(
            application.Client,
            $"/api/admin/templates/{templateId}");

        Assert.Equal("Viral Dance Deluxe", adminDetailBeforeActivation.Title);
        Assert.Equal("Updated soundtrack", adminDetailBeforeActivation.MusicDescription);

        var activated = await PutAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            $"/api/admin/templates/{templateId}/status",
            new AdminTemplateEndpoints.ChangeTemplateStatusRequest(TemplateStatus.Active.ToString()));

        Assert.Equal("Active", activated.Status);

        var adminActiveList = await GetFromJsonAsync<IReadOnlyList<AdminTemplateListItemResponse>>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Active");

        var listedAdminItem = Assert.Single(adminActiveList);
        Assert.Equal(templateId, listedAdminItem.TemplateId);
        Assert.Equal("Viral Dance Deluxe", listedAdminItem.Title);

        var publicAfterActivation = await GetFromJsonAsync<IReadOnlyList<PublicTemplateListItemResponse>>(
            application.Client,
            "/api/templates/?type=Video");

        var listedPublicItem = Assert.Single(publicAfterActivation);
        Assert.Equal(templateId, listedPublicItem.TemplateId);
        Assert.Equal("Viral Dance Deluxe", listedPublicItem.Title);

        var publicDetail = await GetFromJsonAsync<PublicTemplateResponse>(
            application.Client,
            $"/api/templates/{templateId}");

        Assert.Equal("Viral Dance Deluxe", publicDetail.Title);
        Assert.Equal("Updated soundtrack", publicDetail.MusicDescription);
        Assert.Equal(8.75, publicDetail.ReferenceVideoDurationSeconds);

        using var deleteResponse = await application.Client.DeleteAsync($"/api/admin/templates/{templateId}");

        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);
        Assert.Equal(2, application.MediaStorage.DeletedUrls.Count);
        Assert.Contains(previewAsset.Url, application.MediaStorage.DeletedUrls);
        Assert.Contains(referenceAsset.Url, application.MediaStorage.DeletedUrls);

        var publicAfterDelete = await GetFromJsonAsync<IReadOnlyList<PublicTemplateListItemResponse>>(
            application.Client,
            "/api/templates/?type=Video");

        Assert.Empty(publicAfterDelete);
    }

    [Fact]
    public async Task ImageTemplateFlow_ShouldSupportUploadCreateUpdateListPublicFetchAndDelete()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "portrait.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "portrait-image-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Cozy Portrait",
                "Warm portrait template",
                "Portrait",
                ["cozy", "portrait"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                TemplateStatus.Active.ToString()));

        Assert.Equal("Active", created.Status);

        var adminActiveListAfterCreate = await GetFromJsonAsync<IReadOnlyList<AdminTemplateListItemResponse>>(
            application.Client,
            "/api/admin/templates/?type=Image&status=Active");

        var persistedActiveItem = Assert.Single(adminActiveListAfterCreate);
        var templateId = persistedActiveItem.TemplateId;

        var updated = await PutAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            $"/api/admin/templates/image/{templateId}",
            new AdminTemplateEndpoints.UpdateImageTemplateRequest(
                "Cozy Portrait Plus",
                "Updated warm portrait template",
                "Portrait",
                ["cozy", "portrait", "updated"],
                false,
                25,
                TemplatePromoBadgeMode.Trending.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                TemplateStatus.Active.ToString()));

        Assert.Equal("Cozy Portrait Plus", updated.Title);
        Assert.Equal("Active", updated.Status);
        Assert.Equal(25, updated.TokenCost);

        var adminList = await GetFromJsonAsync<IReadOnlyList<AdminTemplateListItemResponse>>(
            application.Client,
            "/api/admin/templates/?type=Image&status=Active");

        var listedAdminItem = Assert.Single(adminList);
        Assert.Equal(templateId, listedAdminItem.TemplateId);
        Assert.Equal("Cozy Portrait Plus", listedAdminItem.Title);

        var publicList = await GetFromJsonAsync<IReadOnlyList<PublicTemplateListItemResponse>>(
            application.Client,
            "/api/templates/?type=Image");

        var listedPublicItem = Assert.Single(publicList);
        Assert.Equal(templateId, listedPublicItem.TemplateId);
        Assert.Equal("Cozy Portrait Plus", listedPublicItem.Title);

        var publicDetail = await GetFromJsonAsync<PublicTemplateResponse>(
            application.Client,
            $"/api/templates/{templateId}");

        Assert.Equal("Cozy Portrait Plus", publicDetail.Title);
        Assert.Null(publicDetail.MusicDescription);

        using var deleteResponse = await application.Client.DeleteAsync($"/api/admin/templates/{templateId}");

        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);
        Assert.Single(application.MediaStorage.DeletedUrls);
        Assert.Contains(previewAsset.Url, application.MediaStorage.DeletedUrls);
    }

    [Fact]
    public async Task CreateVideoEndpoint_ShouldReturnProblem_WhenActiveTemplateHasNoReferenceDuration()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "preview-video-content"u8.ToArray());

        using var response = await application.Client.PostAsJsonAsync(
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Broken Active Dance",
                "Should fail activation",
                "Dance",
                ["broken"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand("https://cdn.example.com/reference.mp4", "reference.mp4", "video/mp4", 4096, null),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/standard/motion-control",
                "Dance prompt.",
                true,
                TemplateStatus.Active.ToString()));

        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.reference_duration_required", body);
    }

    private static async Task<TemplateAssetResponse> UploadMediaAsync(
        HttpClient client,
        string fileName,
        string contentType,
        TemplateAssetKind assetKind,
        byte[] content)
    {
        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(content);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        multipart.Add(fileContent, "file", fileName);
        multipart.Add(new StringContent(assetKind.ToString()), "assetKind");

        using var response = await client.PostAsync("/api/admin/templates/media/upload", multipart);
        response.EnsureSuccessStatusCode();

        return await ReadJsonAsync<TemplateAssetResponse>(response);
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

        private TestApplication(WebApplication app, HttpClient client, InMemoryMediaStorage mediaStorage)
        {
            this.app = app;
            Client = client;
            MediaStorage = mediaStorage;
        }

        public HttpClient Client { get; }

        public InMemoryMediaStorage MediaStorage { get; }

        public static async Task<TestApplication> CreateAsync()
        {
            var databaseRoot = new InMemoryDatabaseRoot();
            var databaseName = $"templates-api-tests-{Guid.NewGuid():N}";

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(TemplatesApiIntegrationTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();

            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });

            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
            });

            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddFixedWindowLimiter("templates", limiterOptions =>
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
                DefaultPreprocessingPrompt = "Keep the same pet.",
                DefaultKlingPrompt = "Funny dance.",
                AllowedPreprocessingModels = [
                    "openai/gpt-image-2/edit",
                    "fal-ai/nano-banana-pro/edit"
                ],
                AllowedKlingModels = [
                    "fal-ai/kling-video/v3/pro/motion-control",
                    "fal-ai/kling-video/v3/standard/motion-control"
                ],
                PreviewMaxFileSizeBytes = 5 * 1024 * 1024,
                ReferenceMotionMaxFileSizeBytes = 5 * 1024 * 1024,
                SeedSampleTemplates = false,
            });

            var mediaStorage = new InMemoryMediaStorage();
            builder.Services.AddSingleton<IMediaStorage>(mediaStorage);
            builder.Services.AddSingleton<IMediaMetadataReader, TestMediaMetadataReader>();
            builder.Services.AddSingleton<ITemplateMediaUploadPolicy>(new FixedTemplateMediaUploadPolicy());
            builder.Services.AddScoped<ITemplatesService, TemplatesService>();
            builder.Services.AddTemplatesApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapTemplatesApiModule();

            await app.StartAsync();

            var client = app.GetTestClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName);

            return new TestApplication(app, client, mediaStorage);
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
        private readonly Dictionary<string, StoredMediaResponse> assets = new(StringComparer.OrdinalIgnoreCase);

        public List<string> DeletedUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            var url = $"http://localhost:5000/templates-media/{Guid.NewGuid():N}/{asset.FileName}";
            var stored = new StoredMediaResponse(url, $"templates-media/{asset.FileName}", asset.FileName, asset.ContentType, asset.Content.LongLength, null);
            assets[url] = stored;
            return Task.FromResult(Result.Success(stored));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            assets.Remove(assetUrl);
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(Result.Success());
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

    private sealed class TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, "integration-test-user"),
                new Claim(ClaimTypes.Name, "integration-test-user"),
                new Claim(ClaimTypes.Role, "Admin"),
            };

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
