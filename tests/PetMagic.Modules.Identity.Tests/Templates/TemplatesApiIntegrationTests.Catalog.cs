using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{

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

        var adminDraftList = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Draft");

        var persistedDraftItem = Assert.Single(adminDraftList.Items);
        var templateId = persistedDraftItem.TemplateId;
        Assert.Equal("Meme soundtrack", persistedDraftItem.MusicDescription);

        var publicBeforeActivation = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?type=Video");

        Assert.Empty(publicBeforeActivation.Items);

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

        var adminActiveList = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Active");

        var listedAdminItem = Assert.Single(adminActiveList.Items);
        Assert.Equal(templateId, listedAdminItem.TemplateId);
        Assert.Equal("Viral Dance Deluxe", listedAdminItem.Title);
        Assert.Equal("Updated soundtrack", listedAdminItem.MusicDescription);

        var publicAfterActivation = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?type=Video");

        var listedPublicItem = Assert.Single(publicAfterActivation.Items);
        Assert.Equal(templateId, listedPublicItem.Id);
        Assert.Equal("Viral Dance Deluxe", listedPublicItem.Title);

        var publicDetail = await GetFromJsonAsync<TemplateDetailDto>(
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

        var publicAfterDelete = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?type=Video");

        Assert.Empty(publicAfterDelete.Items);
    }

    [Fact]
    public async Task EventsStream_ShouldEmitInvalidation_WhenTemplateCatalogChanges()
    {
        await using var application = await TestApplication.CreateAsync();

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var response = await application.Client.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/event-stream", response.Content.Headers.ContentType?.MediaType);

        await using var stream = await response.Content.ReadAsStreamAsync();
        using var reader = new StreamReader(stream, Encoding.UTF8);

        var eventTask = ReadNextServerSentEventAsync(reader);

        var createdCategory = await PostAsJsonAsync<AdminTemplateCategoryListItemResponse>(
            application.Client,
            "/api/admin/templates/categories/",
            new CreateTemplateCategoryCommand("Seasonal"));

        Assert.Equal("Seasonal", createdCategory.Name);

        var receivedEvent = await eventTask.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated, receivedEvent.Topic);
        using var payload = JsonDocument.Parse(receivedEvent.Data);
        Assert.Equal(TemplateFeedInvalidationScopes.Category, payload.RootElement.GetProperty("scope").GetString());
        Assert.Equal("Seasonal", payload.RootElement.GetProperty("category").GetString());
        Assert.Equal("created", payload.RootElement.GetProperty("reason").GetString());
    }

    [Fact]
    public async Task EventsStream_ShouldIgnoreGenerationStatusChangedEvents()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Public Realtime Guard",
            "Security",
            ["realtime", "guard"]);
        var generation = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var response = await application.Client.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/event-stream", response.Content.Headers.ContentType?.MediaType);

        await using var stream = await response.Content.ReadAsStreamAsync();
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var realtime = application.Services.GetRequiredService<ITemplateFeedRealtimeService>();

        await realtime.PublishGenerationStatusChangedAsync(generation);

        var blockedEventTask = ReadNextServerSentEventAsync(reader);
        await Assert.ThrowsAsync<TimeoutException>(() => blockedEventTask.WaitAsync(TimeSpan.FromMilliseconds(400)));

        await realtime.PublishTemplatesFeedInvalidatedAsync(
            new TemplateFeedInvalidationPayload(
                TemplateFeedInvalidationScopes.Full,
                Reason: "security-regression"),
            CancellationToken.None);

        var receivedEvent = await blockedEventTask.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated, receivedEvent.Topic);
        using var payload = JsonDocument.Parse(receivedEvent.Data);
        Assert.Equal(TemplateFeedInvalidationScopes.Full, payload.RootElement.GetProperty("scope").GetString());
        Assert.Equal("security-regression", payload.RootElement.GetProperty("reason").GetString());
    }

    [Fact]
    public async Task GenerationEventsStream_ShouldEmitSanitizedCurrentUserEventsOnly()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "User Realtime Guard",
            "Security",
            ["realtime", "gallery"]);
        var generation = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            JpegBytes());

        var currentUserGeneration = generation with
        {
            Status = "Completed",
            OutputUrl = "https://signed.example.test/current-user-output.png",
            ResultPreviewUrl = "https://signed.example.test/current-user-preview.webp",
            UpdatedAtUtc = DateTime.UtcNow
        };
        var otherUserGeneration = currentUserGeneration with
        {
            GenerationId = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            OutputUrl = "https://signed.example.test/other-user-output.png",
            ResultPreviewUrl = "https://signed.example.test/other-user-preview.webp"
        };

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/templates/generations/events");
        using var response = await application.Client.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/event-stream", response.Content.Headers.ContentType?.MediaType);

        await using var stream = await response.Content.ReadAsStreamAsync();
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var realtime = application.Services.GetRequiredService<ITemplateFeedRealtimeService>();

        await realtime.PublishGenerationStatusChangedAsync(otherUserGeneration);

        var eventTask = ReadNextServerSentEventAsync(reader);
        await Assert.ThrowsAsync<TimeoutException>(() => eventTask.WaitAsync(TimeSpan.FromMilliseconds(400)));

        await realtime.PublishGenerationStatusChangedAsync(currentUserGeneration);

        var receivedEvent = await eventTask.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(TemplateFeedRealtimeTopics.GenerationStatusChanged, receivedEvent.Topic);
        using var payload = JsonDocument.Parse(receivedEvent.Data);
        Assert.Equal("generation.status_changed", payload.RootElement.GetProperty("eventType").GetString());
        Assert.Equal(generation.GenerationId, payload.RootElement.GetProperty("generationId").GetGuid());
        Assert.Equal("Completed", payload.RootElement.GetProperty("status").GetString());
        Assert.True(payload.RootElement.GetProperty("requiresRefetch").GetBoolean());
        Assert.True(payload.RootElement.TryGetProperty("occurredAtUtc", out _));
        Assert.False(payload.RootElement.TryGetProperty("userId", out _));
        Assert.DoesNotContain("outputUrl", receivedEvent.Data, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("previewUrl", receivedEvent.Data, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("signed.example.test", receivedEvent.Data, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task EventsStream_ShouldRejectFourthConcurrentAnonymousConnection()
    {
        await using var application = await TestApplication.CreateAsync();

        using var firstRequest = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var firstResponse = await application.Client.SendAsync(
            firstRequest,
            HttpCompletionOption.ResponseHeadersRead);
        using var secondRequest = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var secondResponse = await application.Client.SendAsync(
            secondRequest,
            HttpCompletionOption.ResponseHeadersRead);
        using var thirdRequest = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var thirdResponse = await application.Client.SendAsync(
            thirdRequest,
            HttpCompletionOption.ResponseHeadersRead);

        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, secondResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, thirdResponse.StatusCode);

        using var fourthRequest = new HttpRequestMessage(HttpMethod.Get, "/api/templates/events");
        using var fourthResponse = await application.Client.SendAsync(
            fourthRequest,
            HttpCompletionOption.ResponseHeadersRead);

        Assert.Equal(HttpStatusCode.TooManyRequests, fourthResponse.StatusCode);
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
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));

        Assert.Equal("Active", created.Status);

        var adminActiveListAfterCreate = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Image&status=Active");

        var persistedActiveItem = Assert.Single(adminActiveListAfterCreate.Items);
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
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));

        Assert.Equal("Cozy Portrait Plus", updated.Title);
        Assert.Equal("Active", updated.Status);
        Assert.Equal(25, updated.TokenCost);

        var adminList = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Image&status=Active");

        var listedAdminItem = Assert.Single(adminList.Items);
        Assert.Equal(templateId, listedAdminItem.TemplateId);
        Assert.Equal("Cozy Portrait Plus", listedAdminItem.Title);
        Assert.Null(listedAdminItem.MusicDescription);

        var publicList = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?type=Image");

        var listedPublicItem = Assert.Single(publicList.Items);
        Assert.Equal(templateId, listedPublicItem.Id);
        Assert.Equal("Cozy Portrait Plus", listedPublicItem.Title);

        var publicDetail = await GetFromJsonAsync<TemplateDetailDto>(
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
    public async Task UpdateImageEndpoint_ShouldRejectOversizedFields_InsteadOfSilentlyNormalizing()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "strict-portrait.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "portrait-image-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Strict Portrait",
                "Validation contract template",
                "Portrait",
                ["strict"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Draft.ToString()));

        using var response = await application.Client.PutAsJsonAsync(
            $"/api/admin/templates/image/{created.TemplateId}",
            new AdminTemplateEndpoints.UpdateImageTemplateRequest(
                "Strict Portrait",
                "Validation contract template",
                "Portrait",
                [new string('t', 33)],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, 0, previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                new string('p', 1001),
                TemplateStatus.Draft.ToString(),
                [new string('r', 161)]));

        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("ImagePrompt", body);
        Assert.Contains("PreviewAsset.FileSizeBytes", body);
        Assert.Contains("Tags[0]", body);
        Assert.Contains("PetPhotoRequirements[0]", body);
    }

    [Fact]
    public async Task PublicTemplatesFeed_ShouldPageAndFilterActiveTemplatesForAnonymousUsers()
    {
        await using var application = await TestApplication.CreateAsync();

        var first = await CreateActiveImageTemplateAsync(application.Client, "Magic Cozy One", "Magic", ["cozy", "magic"]);
        var second = await CreateActiveImageTemplateAsync(application.Client, "Magic Cozy Two", "Magic", ["cozy", "magic", "premium"]);
        await CreateActiveImageTemplateAsync(application.Client, "Surf Buddy", "Fun", ["surf"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var firstPage = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?type=Image&take=1&tags=cozy,magic&search=magic");

        Assert.True(firstPage.HasMore);
        Assert.NotNull(firstPage.NextCursor);
        var firstPageItem = Assert.Single(firstPage.Items);
        Assert.Contains(firstPageItem.TemplateId, new[] { first.TemplateId, second.TemplateId });
        Assert.Contains("cozy", firstPageItem.Tags, StringComparer.OrdinalIgnoreCase);

        var secondPage = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            $"/api/templates/feed?type=Image&take=1&tags=cozy,magic&search=magic&cursor={Uri.EscapeDataString(firstPage.NextCursor!)}");

        Assert.False(secondPage.HasMore);
        Assert.Null(secondPage.NextCursor);
        var secondPageItem = Assert.Single(secondPage.Items);
        Assert.Contains(secondPageItem.TemplateId, new[] { first.TemplateId, second.TemplateId });
        Assert.NotEqual(firstPageItem.TemplateId, secondPageItem.TemplateId);
    }

    [Fact]
    public async Task PublicTemplatesFeed_ShouldExcludeQaOnlyTemplatesByDefaultAndAllowAdminQaMode()
    {
        await using var application = await TestApplication.CreateAsync();

        var production = await CreateActiveImageTemplateAsync(
            application.Client,
            "Production Visible Portrait",
            "Visibility",
            ["visibility"]);
        var qaOnly = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Local Smoke Failing Image",
                "QA-only failing provider fixture.",
                "Visibility",
                ["visibility", "qa"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand("http://localhost:5000/templates-media/qa.jpg", "qa.jpg", "image/jpeg", 64, null),
                "openai/gpt-image-2/edit",
                "__petmagic_fake_fail__",
                TemplateStatus.Active.ToString(),
                IsQaOnly: true));

        application.Client.DefaultRequestHeaders.Authorization = null;
        var publicFeed = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?category=Visibility&take=10");
        Assert.Contains(publicFeed.Items, item => item.TemplateId == production.TemplateId);
        Assert.DoesNotContain(publicFeed.Items, item => item.TemplateId == qaOnly.TemplateId);

        application.Client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue(TestAuthHandler.SchemeName);
        var qaFeed = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?category=Visibility&take=10&includeQa=true");
        Assert.Contains(qaFeed.Items, item => item.TemplateId == qaOnly.TemplateId);
    }

    [Fact]
    public async Task TemplateContentHealthCheck_ShouldMarkMissingPreviewUnhealthyWithoutBreakingFeed()
    {
        await using var application = await TestApplication.CreateAsync();
        var templateId = Guid.NewGuid();
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateItems.Add(new TemplateItem
            {
                Id = templateId,
                Version = 1,
                TemplateType = TemplateType.Image,
                Title = "Broken Preview Drift",
                ShortDescription = "Legacy active template without preview.",
                Category = "Health",
                Tags = "health",
                IsPremium = false,
                TokenCost = 20,
                Status = TemplateStatus.Active,
                PromoBadgeMode = TemplatePromoBadgeMode.New,
                ImageModel = "openai/gpt-image-2/edit",
                ImagePrompt = "Keep the same pet.",
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            });
            await dbContext.SaveChangesAsync();
        }

        application.Client.DefaultRequestHeaders.Authorization = null;
        var feed = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?category=Health&take=10");
        Assert.Contains(feed.Items, item => item.TemplateId == templateId && item.PreviewAsset is null);

        await using var healthScope = application.Services.CreateAsyncScope();
        var healthCheck = new TemplateContentHealthCheck(
            healthScope.ServiceProvider.GetRequiredService<TemplatesDbContext>(),
            healthScope.ServiceProvider.GetRequiredService<TemplatesOptions>(),
            new StaticHttpClientFactory());
        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Unhealthy, result.Status);
        Assert.Equal(1, Assert.IsType<int>(result.Data["problemCount"]));
        Assert.Contains("missing_preview", Assert.IsType<string[]>(result.Data["problems"])[0]);
    }

    [Fact]
    public async Task TemplateContentHealthCheck_ShouldRejectPrivateNetworkPreviewWithoutNetworkRequest()
    {
        await using var application = await TestApplication.CreateAsync();
        var templateId = Guid.NewGuid();
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateItems.Add(new TemplateItem
            {
                Id = templateId,
                Version = 1,
                TemplateType = TemplateType.Image,
                Title = "Private Preview Guard",
                ShortDescription = "Active template must not trigger private network probes.",
                Category = "Health",
                Tags = "health,ssrf",
                IsPremium = false,
                TokenCost = 20,
                Status = TemplateStatus.Active,
                PromoBadgeMode = TemplatePromoBadgeMode.New,
                ImageModel = "openai/gpt-image-2/edit",
                ImagePrompt = "Keep the same pet.",
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow,
                Assets =
                [
                    new TemplateAsset
                    {
                        Id = Guid.NewGuid(),
                        AssetKind = TemplateAssetKind.Preview,
                        Url = "http://169.254.169.254/latest/meta-data/iam/security-credentials",
                        FileName = "metadata.jpg",
                        ContentType = "image/jpeg",
                        FileSizeBytes = 64
                    }
                ]
            });
            await dbContext.SaveChangesAsync();
        }

        await using var healthScope = application.Services.CreateAsyncScope();
        var httpClientFactory = new RecordingHttpClientFactory();
        var healthCheck = new TemplateContentHealthCheck(
            healthScope.ServiceProvider.GetRequiredService<TemplatesDbContext>(),
            healthScope.ServiceProvider.GetRequiredService<TemplatesOptions>(),
            httpClientFactory);
        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Unhealthy, result.Status);
        Assert.Contains(
            Assert.IsType<string[]>(result.Data["problems"]),
            problem => problem.Contains("preview_url_private_network", StringComparison.Ordinal));
        Assert.Empty(httpClientFactory.Requests);
    }

    [Fact]
    public async Task PublicRandomTemplate_ShouldRespectAllTypeCategoryAndPremiumAvailability()
    {
        await using var application = await TestApplication.CreateAsync();

        var free = await CreateActiveImageTemplateAsync(
            application.Client,
            "Random Free Magic",
            "Magic",
            ["random", "free"]);
        var premium = await CreateActivePremiumImageTemplateAsync(
            application.Client,
            "Random Premium Magic",
            "Magic",
            ["random", "premium"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var random = await GetFromJsonAsync<PublicRandomTemplateResponse>(
            application.Client,
            "/api/templates/random?type=all&category=magic&includePremium=false");

        Assert.NotNull(random.Template);
        Assert.Equal(free.TemplateId, random.Template!.TemplateId);
        Assert.False(random.Template.IsPremium);
        Assert.Equal(random.Template.PreviewAsset?.Url, random.Template.ThumbnailUrl);

        var premiumRandom = await GetFromJsonAsync<PublicRandomTemplateResponse>(
            application.Client,
            "/api/templates/random?type=all&category=magic&includePremium=false&access=premium");

        Assert.NotNull(premiumRandom.Template);
        Assert.Equal(premium.TemplateId, premiumRandom.Template!.TemplateId);
        Assert.True(premiumRandom.Template.IsPremium);
    }

    [Fact]
    public async Task PublicTemplateCatalogEndpoints_ShouldAcceptAllTypeFilter()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "All Type Portrait",
            "AllTypes",
            ["all-type"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var feed = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?type=all&category=AllTypes&take=10");
        var catalog = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?type=all&category=AllTypes&page=1&pageSize=10");

        Assert.Contains(feed.Items, item => item.TemplateId == created.TemplateId);
        Assert.Contains(catalog.Items, item => item.Id == created.TemplateId);
    }

    [Fact]
    public async Task PublicTemplateCatalogEndpoint_ShouldKeepTrailingSlashAlias()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Legacy Slash Portrait",
            "LegacySlash",
            ["legacy-slash"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var catalog = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates/?type=Image&category=LegacySlash");

        var item = Assert.Single(catalog.Items);
        Assert.Equal(created.TemplateId, item.Id);
    }

    [Fact]
    public async Task PublicTemplateCatalogEndpoints_ShouldExposeShortCacheHeadersForAnonymousHotPaths()
    {
        await using var application = await TestApplication.CreateAsync();

        await CreateActiveImageTemplateAsync(
            application.Client,
            "Cached Magic Portrait",
            "Cached",
            ["cache"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        await AssertCacheControlAsync("/api/templates?type=Image&category=Cached", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates?type=Image&category=Cached&page=1&pageSize=10", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/feed?type=Image&category=Cached&take=10", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/random?type=Image&category=Cached", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/catalog-version", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/changes?sinceVersion=0", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/template-of-the-day", "public, max-age=10");
        await AssertCacheControlAsync("/api/templates/categories", "public, max-age=60");

        async Task AssertCacheControlAsync(string path, string expected)
        {
            using var response = await application.Client.GetAsync(path);
            await EnsureSuccessStatusCodeAsync(response, path);
            Assert.Equal(expected, response.Headers.CacheControl?.ToString());
        }
    }

    [Fact]
    public async Task PublicTemplatesFeed_ShouldKeepMobileJsonContractShape()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "contract-feed.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "contract-feed-image-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Contract Feed Portrait",
                "Contract feed description",
                "Contract",
                ["contract", "mobile"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                ["Clear pet face", "Good lighting"]));

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync(
            "/api/templates/feed?type=Image&search=contract%20feed&take=10");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;

        Assert.True(root.TryGetProperty("items", out var items));
        Assert.True(root.TryGetProperty("nextCursor", out _));
        Assert.True(root.TryGetProperty("hasMore", out var hasMore));
        Assert.True(root.TryGetProperty("generatedAtUtc", out _));
        Assert.False(hasMore.GetBoolean());

        var allowedRootProperties = new HashSet<string>(StringComparer.Ordinal)
        {
            "items",
            "nextCursor",
            "hasMore",
            "generatedAtUtc"
        };
        var rootProperties = root.EnumerateObject()
            .Select(property => property.Name)
            .ToHashSet(StringComparer.Ordinal);

        Assert.Equal(allowedRootProperties.Count, rootProperties.Count);
        Assert.Subset(allowedRootProperties, rootProperties);

        var item = Assert.Single(items.EnumerateArray());
        var allowedItemProperties = new HashSet<string>(StringComparer.Ordinal)
        {
            "id",
            "type",
            "title",
            "shortDescription",
            "category",
            "tags",
            "isPremium",
            "access",
            "thumbnailUrl",
            "media",
            "mediaKind",
            "aspectRatio",
            "durationMs",
            "sizeBytes",
            "version",
            "mediaVersion"
        };
        var itemProperties = item.EnumerateObject()
            .Select(property => property.Name)
            .ToHashSet(StringComparer.Ordinal);

        Assert.Equal(allowedItemProperties.Count, itemProperties.Count);
        Assert.Subset(allowedItemProperties, itemProperties);
        Assert.DoesNotContain("imageModel", itemProperties);
        Assert.DoesNotContain("imagePrompt", itemProperties);
        Assert.DoesNotContain("preprocessingModel", itemProperties);
        Assert.DoesNotContain("preprocessingPrompt", itemProperties);
        Assert.DoesNotContain("klingModel", itemProperties);
        Assert.DoesNotContain("klingPrompt", itemProperties);
        Assert.DoesNotContain("keepOriginalSound", itemProperties);
        Assert.DoesNotContain("referenceMotionAsset", itemProperties);
        Assert.DoesNotContain("estimatedProviderCostUsd", itemProperties);
        Assert.DoesNotContain("createdAtUtc", itemProperties);
        Assert.DoesNotContain("templateId", itemProperties);
        Assert.DoesNotContain("templateType", itemProperties);
        Assert.DoesNotContain("previewAsset", itemProperties);
        Assert.DoesNotContain("tokenCost", itemProperties);
        Assert.DoesNotContain("petPhotoRequirements", itemProperties);
        Assert.DoesNotContain("supportsGenerationResultInput", itemProperties);
        Assert.DoesNotContain("requiredInputMediaType", itemProperties);
        Assert.DoesNotContain("recommendedAfterImageGeneration", itemProperties);
        Assert.DoesNotContain("supportsGenerateSimilar", itemProperties);
        Assert.DoesNotContain("defaultVariationStrength", itemProperties);
        Assert.DoesNotContain("updatedAtUtc", itemProperties);
        Assert.DoesNotContain("detailPreviewUrl", itemProperties);
        Assert.Equal(created.TemplateId, item.GetProperty("id").GetGuid());
        Assert.Equal("Image", item.GetProperty("type").GetString());
        Assert.Equal("Contract Feed Portrait", item.GetProperty("title").GetString());
        Assert.Equal("Contract feed description", item.GetProperty("shortDescription").GetString());
        var category = item.GetProperty("category");
        Assert.Equal("Contract", category.GetProperty("title").GetString());
        Assert.Equal("contract", category.GetProperty("slug").GetString());
        Assert.False(item.GetProperty("isPremium").GetBoolean());
        Assert.True(item.GetProperty("version").GetInt64() > 0);
        Assert.Equal(previewAsset.Url, item.GetProperty("thumbnailUrl").GetString());

        var media = item.GetProperty("media");
        var allowedMediaProperties = new HashSet<string>(StringComparer.Ordinal)
        {
            "thumbnailUrl",
            "animatedPreviewUrl",
            "feedLoopLowUrl",
            "feedLoopMediumUrl",
            "mediaKind",
            "aspectRatio",
            "durationMs",
            "sizeBytes",
            "dominantColor",
            "blurHash",
            "mediaVersion"
        };
        var mediaProperties = media.EnumerateObject()
            .Select(property => property.Name)
            .ToHashSet(StringComparer.Ordinal);

        Assert.Equal(allowedMediaProperties.Count, mediaProperties.Count);
        Assert.Subset(allowedMediaProperties, mediaProperties);
        Assert.Equal(previewAsset.Url, media.GetProperty("thumbnailUrl").GetString());
        Assert.Equal("image", media.GetProperty("mediaKind").GetString());

        var typedResponse = JsonSerializer.Deserialize<PublicTemplatesFeedResponse>(body, JsonOptions);
        Assert.NotNull(typedResponse);
        var typedItem = Assert.Single(typedResponse.Items);
        Assert.Equal(created.TemplateId, typedItem.TemplateId);
        Assert.Equal(previewAsset.Url, typedItem.ThumbnailUrl);
        Assert.True(typedItem.Version > 0);
    }

    [Fact]
    public async Task PublicTemplatesFeed_ShouldExposeVideoPreviewWithoutThumbnailFallback()
    {
        await using var application = await TestApplication.CreateAsync();

        var previewAsset = await UploadMediaAsync(
            application.Client,
            "preview.mp4",
            "video/mp4",
            TemplateAssetKind.Preview,
            "feed-video-preview-content"u8.ToArray());
        var referenceAsset = await UploadMediaAsync(
            application.Client,
            "reference.mp4",
            "video/mp4",
            TemplateAssetKind.ReferenceMotion,
            "feed-video-reference-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/video",
            new CreateVideoTemplateCommand(
                "Contract Feed Video",
                "Contract feed video description",
                "VideoContract",
                ["contract", "video"],
                false,
                30,
                TemplatePromoBadgeMode.New.ToString(),
                "Looped video soundtrack",
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                new TemplateAssetCommand(
                    referenceAsset.Url,
                    referenceAsset.FileName,
                    referenceAsset.ContentType,
                    referenceAsset.FileSizeBytes,
                    referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Gentle loop.",
                false,
                TemplateStatus.Active.ToString()));

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync(
            "/api/templates/feed?type=Video&category=VideoContract&take=10");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var document = JsonDocument.Parse(body);
        var item = Assert.Single(document.RootElement.GetProperty("items").EnumerateArray());
        var itemProperties = item.EnumerateObject()
            .Select(property => property.Name)
            .ToHashSet(StringComparer.Ordinal);
        Assert.DoesNotContain("templateId", itemProperties);
        Assert.DoesNotContain("templateType", itemProperties);
        Assert.DoesNotContain("previewAsset", itemProperties);
        Assert.DoesNotContain("referenceVideoDurationSeconds", itemProperties);
        Assert.DoesNotContain("detailPreviewUrl", itemProperties);
        Assert.Equal(created.TemplateId, item.GetProperty("id").GetGuid());
        Assert.Equal("Video", item.GetProperty("type").GetString());
        Assert.Equal(previewAsset.Url, item.GetProperty("thumbnailUrl").GetString());

        var media = item.GetProperty("media");
        Assert.Equal(previewAsset.Url, media.GetProperty("thumbnailUrl").GetString());
        Assert.Equal(previewAsset.Url, media.GetProperty("feedLoopLowUrl").GetString());
        Assert.Equal("video", media.GetProperty("mediaKind").GetString());
        Assert.Equal(4500, media.GetProperty("durationMs").GetInt32());

        var typedResponse = JsonSerializer.Deserialize<PublicTemplatesFeedResponse>(body, JsonOptions);
        Assert.NotNull(typedResponse);
        var typedItem = Assert.Single(typedResponse.Items);
        Assert.Equal(created.TemplateId, typedItem.TemplateId);
        Assert.Equal(TemplateType.Video.ToString(), typedItem.TemplateType);
        Assert.Equal(previewAsset.Url, typedItem.ThumbnailUrl);
        Assert.Equal(previewAsset.Url, typedItem.Media.FeedLoopLowUrl);
        Assert.Equal(4500, typedItem.Media.DurationMs);
    }

    [Theory]
    [InlineData("not-a-cursor")]
    [InlineData("9223372036854775807:35e914434e1a4df28cf77c95662324b4")]
    public async Task PublicTemplatesFeed_ShouldReturnProblem_WhenCursorIsInvalid(string cursor)
    {
        await using var application = await TestApplication.CreateAsync();

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync(
            $"/api/templates/feed?cursor={Uri.EscapeDataString(cursor)}");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_cursor", body);
    }

    [Theory]
    [InlineData("/api/templates?type=Document")]
    [InlineData("/api/templates?type=1")]
    [InlineData("/api/templates/feed?type=Document")]
    [InlineData("/api/templates/feed?type=1")]
    [InlineData("/api/templates/random?type=Document")]
    [InlineData("/api/templates/random?type=1")]
    public async Task PublicTemplateCatalogEndpoints_ShouldReturnProblem_WhenTypeFilterIsInvalid(string path)
    {
        await using var application = await TestApplication.CreateAsync();

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_type", body);
        Assert.DoesNotContain("Template catalog type filter is invalid.", body);
        Assert.DoesNotContain("\"detail\"", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PublicRandomTemplate_ShouldReturnProblem_WhenAccessFilterIsInvalid()
    {
        await using var application = await TestApplication.CreateAsync();

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync("/api/templates/random?access=vip");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_access", body);
        Assert.DoesNotContain("Template catalog access filter is invalid.", body);
        Assert.DoesNotContain("\"detail\"", body, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("/api/admin/templates/?type=Document", "templates.invalid_type")]
    [InlineData("/api/admin/templates/?type=1", "templates.invalid_type")]
    [InlineData("/api/admin/templates/?status=Deleted", "templates.invalid_status")]
    [InlineData("/api/admin/templates/?status=1", "templates.invalid_status")]
    [InlineData("/api/admin/templates/?access=vip", "templates.invalid_access")]
    [InlineData("/api/admin/templates/?sort=random", "templates.invalid_sort")]
    public async Task AdminTemplatesCatalog_ShouldReturnProblem_WhenFilterIsInvalid(string path, string expectedCode)
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected 400 problem details, got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        Assert.Contains(expectedCode, body);
    }

    [Theory]
    [InlineData("/api/admin/feedback?status=Deleted", "feedback.invalid_status")]
    [InlineData("/api/admin/feedback?priority=Urgent", "feedback.invalid_priority")]
    [InlineData("/api/admin/feedback?type=Other", "feedback.invalid_type")]
    public async Task AdminFeedback_ShouldReturnProblem_WhenFilterIsInvalid(string path, string expectedCode)
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected 400 problem details, got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        Assert.Contains(expectedCode, body);
    }

    [Fact]
    public async Task AdminTemplatesCatalog_ShouldPageSearchAndFilterOnBackend()
    {
        await using var application = await TestApplication.CreateAsync();

        await CreateActiveImageTemplateAsync(application.Client, "Catalog Alpha", "Portrait", ["catalog", "alpha"]);
        var premium = await CreateActivePremiumImageTemplateAsync(application.Client, "Catalog Beta", "Portrait", ["catalog", "beta"]);
        await CreateActiveImageTemplateAsync(application.Client, "Catalog Gamma", "Fun", ["catalog", "gamma"]);

        var firstPage = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Image&status=not_archived&search=catalog&category=Portrait&access=premium&sort=title&skip=0&take=1");

        Assert.False(firstPage.HasMore);
        Assert.Equal(0, firstPage.Skip);
        Assert.Equal(1, firstPage.Take);
        Assert.Equal(1, firstPage.TotalCount);
        var firstPageItem = Assert.Single(firstPage.Items);
        Assert.Equal(premium.TemplateId, firstPageItem.TemplateId);
        Assert.True(firstPageItem.IsPremium);
        Assert.Equal("Portrait", firstPageItem.Category);

        var secondPage = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Image&status=not_archived&search=catalog&category=Portrait&access=free&sort=title&skip=1&take=1");

        Assert.False(secondPage.HasMore);
        Assert.Equal(1, secondPage.TotalCount);
        Assert.Empty(secondPage.Items);
    }

    [Fact]
    public async Task PublicTemplateCatalogEndpoints_ShouldReturnVersionedMetadataAndDeletedIds()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await CreateActiveImageTemplateAsync(application.Client, "Catalog Portrait", "Catalog", ["meta"]);
        var premiumCreated = await CreateActivePremiumImageTemplateAsync(application.Client, "Catalog Premium", "Catalog", ["premium"]);

        var page = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?page=1&pageSize=20");

        Assert.True(page.TotalCount >= 1);
        Assert.Contains(page.Items, item => item.Id == created.TemplateId);
        Assert.Contains(page.Items, item => item.Id == premiumCreated.TemplateId && item.IsPremium);

        var version = await GetFromJsonAsync<PublicTemplatesCatalogVersionResponse>(
            application.Client,
            "/api/templates/catalog-version");

        Assert.True(version.Version > 0);

        var initialChanges = await GetFromJsonAsync<PublicTemplatesCatalogChangesResponse>(
            application.Client,
            "/api/templates/changes?sinceVersion=0");

        Assert.Contains(initialChanges.Upserts, item => item.Id == created.TemplateId);
        Assert.Contains(initialChanges.Upserts, item => item.Id == premiumCreated.TemplateId && item.IsPremium);
        Assert.DoesNotContain(created.TemplateId, initialChanges.DeletedIds);

        using var deleteResponse = await application.Client.DeleteAsync($"/api/admin/templates/{created.TemplateId}");
        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        var afterDeleteVersion = await GetFromJsonAsync<PublicTemplatesCatalogVersionResponse>(
            application.Client,
            "/api/templates/catalog-version");

        Assert.True(afterDeleteVersion.Version > version.Version);

        var deleteDelta = await GetFromJsonAsync<PublicTemplatesCatalogChangesResponse>(
            application.Client,
            $"/api/templates/changes?sinceVersion={version.Version}");

        Assert.Contains(created.TemplateId, deleteDelta.DeletedIds);
    }

    [Fact]
    public async Task PublicTemplateChanges_ShouldReturnProblem_WhenSinceVersionIsInvalid()
    {
        await using var application = await TestApplication.CreateAsync();

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync("/api/templates/changes?sinceVersion=-1");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_since_version", body);
        Assert.DoesNotContain("Template catalog version filter is invalid.", body);
        Assert.DoesNotContain("\"detail\"", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PublicPagedTemplateCatalog_ShouldApplyTagsAndPremiumOnlyQueryParameters()
    {
        await using var application = await TestApplication.CreateAsync();

        var free = await CreateActiveImageTemplateAsync(application.Client, "Contract Free", "Contract", ["contract", "free"]);
        var premium = await CreateActivePremiumImageTemplateAsync(application.Client, "Contract Premium", "Contract", ["contract", "premium"]);

        var page = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?page=1&pageSize=20&type=Image&category=Contract&tags=contract,premium&premiumOnly=true");

        var item = Assert.Single(page.Items);
        Assert.Equal(premium.TemplateId, item.Id);
        Assert.DoesNotContain(page.Items, item => item.Id == free.TemplateId);
        Assert.True(item.IsPremium);
        Assert.Equal(1, page.TotalCount);
        Assert.False(page.HasMore);
    }

    [Fact]
    public async Task PublicPagedTemplateCatalog_ShouldClampPageSizeAndHandleOutOfRangePages()
    {
        await using var application = await TestApplication.CreateAsync();

        await CreateActiveImageTemplateAsync(application.Client, "Contract Bounds", "Contract", ["contract"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var normalized = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?page=-10&pageSize=5000&type=Image&category=Contract");

        Assert.Equal(1, normalized.Page);
        Assert.Equal(100, normalized.PageSize);
        Assert.True(normalized.TotalCount >= 1);
        Assert.Contains(normalized.Items, item => item.Title == "Contract Bounds");

        var outOfRange = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?page=2147483647&pageSize=100&type=Image&category=Contract");

        Assert.Equal(2147483647, outOfRange.Page);
        Assert.Equal(100, outOfRange.PageSize);
        Assert.Equal(normalized.TotalCount, outOfRange.TotalCount);
        Assert.False(outOfRange.HasMore);
        Assert.Empty(outOfRange.Items);
    }

    private static async Task<AdminTemplateResponse> CreateActivePremiumImageTemplateAsync(
        HttpClient client,
        string title,
        string category,
        string[] tags)
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
                true,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()));
    }

    [Fact]
    public async Task PublicTemplateCategories_ShouldReturnNonArchivedCategoriesForAnonymousUsers()
    {
        await using var application = await TestApplication.CreateAsync();

        await CreateActiveImageTemplateAsync(application.Client, "Magic Cozy", "Magic", ["cozy"]);
        await CreateActiveImageTemplateAsync(application.Client, "Adventure Buddy", "Adventure", ["story"]);

        var categories = await GetFromJsonAsync<IReadOnlyList<PublicTemplateCategoryResponse>>(
            application.Client,
            "/api/templates/categories");

        Assert.Contains(categories, x => x.Name == "Magic");
        Assert.Contains(categories, x => x.Name == "Adventure");
    }

    [Fact]
    public async Task TemplateCategoryCrud_ShouldSupportCreateRenameArchiveAndDelete()
    {
        await using var application = await TestApplication.CreateAsync();

        var created = await PostAsJsonAsync<AdminTemplateCategoryListItemResponse>(
            application.Client,
            "/api/admin/templates/categories/",
            new CreateTemplateCategoryCommand("Seasonal"));

        Assert.Equal("Seasonal", created.Name);
        Assert.False(created.IsArchived);

        var listed = await GetFromJsonAsync<IReadOnlyList<AdminTemplateCategoryListItemResponse>>(
            application.Client,
            "/api/admin/templates/categories/?includeArchived=true");

        Assert.Contains(listed, category => category.CategoryId == created.CategoryId && category.Name == "Seasonal");

        var updated = await PutAsJsonAsync<AdminTemplateCategoryListItemResponse>(
            application.Client,
            $"/api/admin/templates/categories/{created.CategoryId}",
            new AdminTemplateCategoryEndpoints.UpdateTemplateCategoryRequest("Holiday"));

        Assert.Equal("Holiday", updated.Name);

        var archived = await PutAsJsonAsync<AdminTemplateCategoryListItemResponse>(
            application.Client,
            $"/api/admin/templates/categories/{created.CategoryId}/archive",
            new AdminTemplateCategoryEndpoints.ChangeTemplateCategoryArchiveStateRequest(true));

        Assert.True(archived.IsArchived);

        using var deleteResponse = await application.Client.DeleteAsync($"/api/admin/templates/categories/{created.CategoryId}");

        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        var afterDelete = await GetFromJsonAsync<IReadOnlyList<AdminTemplateCategoryListItemResponse>>(
            application.Client,
            "/api/admin/templates/categories/?includeArchived=true");

        Assert.DoesNotContain(afterDelete, category => category.CategoryId == created.CategoryId);
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

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("templates.reference_duration_required", body);
    }

    [Fact]
    public async Task AnalyticsFeedbackFlow_ShouldRecordPublicFeedbackAndExposeItInAdmin()
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
                "Feedback Dance",
                "Template with feedback flow",
                "Dance",
                ["feedback"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Feedback dance.",
                true,
                TemplateStatus.Active.ToString()));

        using var postResponse = await application.Client.PostAsJsonAsync(
            $"/api/templates/{created.TemplateId}/analytics/events",
            new
            {
                eventType = "feedback",
                source = "profile",
                deviceClass = "web",
                countryCode = "DE",
                generationId = Guid.NewGuid(),
                feedbackMessage = "Добавьте предпросмотр результата до оплаты"
            });

        Assert.Equal(HttpStatusCode.NoContent, postResponse.StatusCode);

        var items = await GetFromJsonAsync<IReadOnlyList<AdminTemplateFeedbackItemResponse>>(
            application.Client,
            $"/api/admin/templates/{created.TemplateId}/statistics/feedback?type=feedback&search=%D0%BF%D1%80%D0%B5%D0%B4%D0%BF%D1%80%D0%BE%D1%81%D0%BC%D0%BE%D1%82%D1%80");

        var item = Assert.Single(items);
        Assert.Equal("feedback", item.EventType);
        Assert.Equal("Добавьте предпросмотр результата до оплаты", item.FeedbackMessage);
        Assert.Equal("profile", item.Source);
        Assert.Equal("web", item.DeviceClass);
        Assert.Equal("DE", item.CountryCode);
    }

    [Fact]
    public async Task PublicAnalyticsEndpoint_ShouldClampAnonymousMetadataPayload()
    {
        await using var application = await TestApplication.CreateAsync();
        var previewAsset = await UploadMediaAsync(
            application.Client,
            "metadata-guard-preview.jpg",
            "image/jpeg",
            TemplateAssetKind.Preview,
            "metadata-guard-preview-content"u8.ToArray());

        var created = await PostAsJsonAsync<AdminTemplateResponse>(
            application.Client,
            "/api/admin/templates/image",
            new CreateImageTemplateCommand(
                "Metadata Guard",
                "Template used to validate analytics metadata guards",
                "Utility",
                ["analytics"],
                false,
                15,
                TemplatePromoBadgeMode.Auto.ToString(),
                new TemplateAssetCommand(
                    previewAsset.Url,
                    previewAsset.FileName,
                    previewAsset.ContentType,
                    previewAsset.FileSizeBytes,
                    previewAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the pet centered.",
                TemplateStatus.Active.ToString()));

        var oversizedValue = new string('x', 240);
        using var postResponse = await application.Client.PostAsJsonAsync(
            $"/api/templates/{created.TemplateId}/analytics/events",
            new
            {
                eventType = "feedback",
                source = "gallery",
                metadata = new Dictionary<string, object?>
                {
                    ["screen"] = "templates",
                    ["longValue"] = oversizedValue,
                    ["nested"] = new { route = "/templates", section = "hero" },
                    ["flag"] = true,
                    ["one"] = "1",
                    ["two"] = "2",
                    ["three"] = "3",
                    ["four"] = "4",
                    ["five"] = "5",
                    ["six"] = "6",
                    ["seven"] = "7",
                    ["eight"] = "8",
                    ["nine"] = "9"
                }
            });

        Assert.Equal(HttpStatusCode.NoContent, postResponse.StatusCode);

        using var scope = application.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var stored = await dbContext.TemplateAnalyticsEvents
            .SingleAsync(x => x.TemplateId == created.TemplateId);

        Assert.NotNull(stored.MetadataJson);

        using var metadata = JsonDocument.Parse(stored.MetadataJson!);
        var properties = metadata.RootElement.EnumerateObject().ToArray();
        Assert.Equal(12, properties.Length);
        Assert.Contains(properties, property => property.NameEquals("screen"));
        Assert.Contains(properties, property => property.NameEquals("longValue"));
        Assert.Contains(properties, property => property.NameEquals("nested"));
        Assert.DoesNotContain(properties, property => property.NameEquals("nine"));

        Assert.True(
            metadata.RootElement.GetProperty("longValue").GetString()!.Length <= 160);
        Assert.True(
            metadata.RootElement.GetProperty("nested").GetString()!.Length <= 160);
    }

    [Fact]
    public async Task PublicAnalyticsEndpoint_ShouldReturnProblem_WhenEventTypeIsUnknown()
    {
        await using var application = await TestApplication.CreateAsync();
        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Analytics Contract Guard",
            "Contracts",
            ["analytics", "contract"]);

        using var response = await application.Client.PostAsJsonAsync(
            $"/api/templates/{created.TemplateId}/analytics/events",
            new
            {
                eventType = "totally_unknown_event",
                source = "mobile"
            });
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_event_type", body);

        using var scope = application.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        Assert.Empty(await dbContext.TemplateAnalyticsEvents.ToListAsync());
    }

    [Fact]
    public async Task PublicAnalyticsEndpoint_ShouldFallbackFromInvalidAnonymousDimensions()
    {
        await using var application = await TestApplication.CreateAsync();
        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Analytics Dimension Guard",
            "Contracts",
            ["analytics", "dimensions"]);

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"/api/templates/{created.TemplateId}/analytics/events");
        request.Headers.UserAgent.ParseAdd("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)");
        request.Headers.Add("X-Country-Code", "BR");
        request.Content = JsonContent.Create(new
        {
            eventType = "feedback",
            source = "profile",
            deviceClass = "ps5-console",
            countryCode = "brazil",
            feedbackMessage = "Need better preview controls"
        });

        using var response = await application.Client.SendAsync(request);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using var scope = application.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var stored = await dbContext.TemplateAnalyticsEvents
            .SingleAsync(x => x.TemplateId == created.TemplateId);

        Assert.Equal("ios", stored.DeviceClass);
        Assert.Equal("BR", stored.CountryCode);
    }

    [Fact]
    public async Task PublicAnalyticsEndpoint_ShouldReturnTooManyRequests_WhenAnonymousRateLimitExceeded()
    {
        await using var application = await TestApplication.CreateAsync();
        var created = await CreateActiveImageTemplateAsync(
            application.Client,
            "Analytics Rate Limit Guard",
            "Contracts",
            ["analytics", "rate-limit"]);

        HttpResponseMessage? lastResponse = null;
        for (var index = 0; index < 49; index++)
        {
            lastResponse?.Dispose();
            lastResponse = await application.Client.PostAsJsonAsync(
                $"/api/templates/{created.TemplateId}/analytics/events",
                new
                {
                    eventType = "view",
                    source = "mobile"
                });
        }

        Assert.NotNull(lastResponse);
        using (lastResponse)
        {
            Assert.Equal(HttpStatusCode.TooManyRequests, lastResponse.StatusCode);
        }
    }

    private sealed class StaticHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            return new HttpClient(new StaticHttpMessageHandler())
            {
                BaseAddress = new Uri("http://localhost")
            };
        }
    }

    private sealed class StaticHttpMessageHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        }
    }

    private sealed class RecordingHttpClientFactory : IHttpClientFactory
    {
        public List<Uri> Requests { get; } = [];

        public HttpClient CreateClient(string name)
        {
            return new HttpClient(new RecordingHttpMessageHandler(Requests))
            {
                BaseAddress = new Uri("http://localhost")
            };
        }
    }

    private sealed class RecordingHttpMessageHandler(List<Uri> requests) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.RequestUri is not null)
            {
                lock (requests)
                {
                    requests.Add(request.RequestUri);
                }
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
        }
    }

}
