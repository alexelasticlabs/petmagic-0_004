using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Threading.Channels;

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
    private static readonly Guid TestUserId = Guid.Parse("35E91443-4E1A-4DF2-8CF7-7C95662324B4");
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
        Assert.Equal("Meme soundtrack", persistedDraftItem.MusicDescription);

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
        Assert.Equal("Updated soundtrack", listedAdminItem.MusicDescription);

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
        Assert.Equal("{}", receivedEvent.Data);
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
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
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
        Assert.Null(listedAdminItem.MusicDescription);

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
    public async Task PublicTemplatesFeed_ShouldPageAndFilterActiveTemplatesForAnonymousUsers()
    {
        await using var application = await TestApplication.CreateAsync();

        var first = await CreateActiveImageTemplateAsync(application.Client, "Magic Cozy One", "Magic", ["cozy", "magic"]);
        var second = await CreateActiveImageTemplateAsync(application.Client, "Magic Cozy Two", "Magic", ["cozy", "premium"]);
        await CreateActiveImageTemplateAsync(application.Client, "Surf Buddy", "Fun", ["surf"]);

        application.Client.DefaultRequestHeaders.Authorization = null;

        var firstPage = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            "/api/templates/feed?type=Image&take=1&tags=cozy&search=magic");

        Assert.True(firstPage.HasMore);
        Assert.NotNull(firstPage.NextCursor);
        var firstPageItem = Assert.Single(firstPage.Items);
        Assert.Contains(firstPageItem.TemplateId, new[] { first.TemplateId, second.TemplateId });
        Assert.Contains("cozy", firstPageItem.Tags, StringComparer.OrdinalIgnoreCase);

        var secondPage = await GetFromJsonAsync<PublicTemplatesFeedResponse>(
            application.Client,
            $"/api/templates/feed?type=Image&take=1&tags=cozy&search=magic&cursor={Uri.EscapeDataString(firstPage.NextCursor!)}");

        Assert.False(secondPage.HasMore);
        Assert.Null(secondPage.NextCursor);
        var secondPageItem = Assert.Single(secondPage.Items);
        Assert.Contains(secondPageItem.TemplateId, new[] { first.TemplateId, second.TemplateId });
        Assert.NotEqual(firstPageItem.TemplateId, secondPageItem.TemplateId);
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

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
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
    public async Task VideoGenerationFlow_ShouldUploadSourceCreateCompletedJobAndFetchResult()
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
                TemplateStatus.Active.ToString()));

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            "source-pet-image"u8.ToArray());

        Assert.Equal(TestUserId, queued.UserId);
        Assert.Equal(created.TemplateId, queued.TemplateId);
        Assert.Equal("Queued", queued.Status);
        Assert.Null(queued.StartedAtUtc);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Succeeded");
        Assert.NotNull(generation);

        Assert.Equal(TestUserId, generation!.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Succeeded", generation.Status);
        Assert.Equal("succeeded", generation.Stage);
        Assert.Equal(100, generation.ProgressPercent);
        Assert.Equal(60, generation.TokenCost);
        Assert.False(generation.UserMediaExpired);
        Assert.NotNull(generation.SourceImageAsset);
        Assert.Equal("pet.jpg", generation.SourceImageAsset!.FileName);
        Assert.Equal(generation.SourceImageAsset.Url, generation.NormalizedImageUrl);
        Assert.Equal(referenceAsset.Url, generation.ReferenceMotionUrl);
        Assert.EndsWith($"generated-{generation.GenerationId:N}.mp4", generation.OutputUrl, StringComparison.OrdinalIgnoreCase);
        Assert.Null(generation.FailureCode);
        Assert.Empty(application.Billing.RefundedGenerationIds);

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}");

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Succeeded", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
    }

    [Fact]
    public async Task ImageGenerationFlow_ShouldUploadSourceCreateCompletedJobAndFetchResult()
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

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            "source-pet-image"u8.ToArray());

        Assert.Equal(TestUserId, queued.UserId);
        Assert.Equal(created.TemplateId, queued.TemplateId);
        Assert.Equal("Queued", queued.Status);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);

        var generation = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Succeeded");

        Assert.Equal(TestUserId, generation.UserId);
        Assert.Equal(created.TemplateId, generation.TemplateId);
        Assert.Equal("Succeeded", generation.Status);
        Assert.Equal(20, generation.TokenCost);
        Assert.NotNull(generation.SourceImageAsset);
        Assert.Equal("pet.jpg", generation.SourceImageAsset!.FileName);
        Assert.Null(generation.NormalizedImageUrl);
        Assert.Null(generation.ReferenceMotionUrl);
        Assert.EndsWith($"generated-{generation.GenerationId:N}.png", generation.OutputUrl, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("openai/gpt-image-2/edit", generation.UsedPreprocessingModel);
        Assert.Null(generation.UsedKlingModel);
        Assert.NotNull(generation.PreprocessingCompletedAtUtc);
        Assert.Null(generation.MotionGenerationCompletedAtUtc);
        Assert.Equal(0.219m, generation.MotionProviderCostUsd);
        Assert.Null(generation.FailureCode);
        Assert.Empty(application.Billing.RefundedGenerationIds);

        var fetched = await GetFromJsonAsync<TemplateGenerationResponse>(
            application.Client,
            $"/api/templates/generations/{generation.GenerationId}");

        Assert.Equal(generation.GenerationId, fetched.GenerationId);
        Assert.Equal("Succeeded", fetched.Status);
        Assert.Equal(generation.OutputUrl, fetched.OutputUrl);
    }

    [Fact]
    public async Task VideoGenerationFlow_ShouldRejectDraftTemplateAndCleanupUploadedSource()
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
                "Draft Dance",
                "Draft dance template",
                "Dance",
                ["draft"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/standard/motion-control",
                "Dance prompt.",
                true,
                TemplateStatus.Draft.ToString()));

        using var multipart = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent("source-pet-image"u8.ToArray());
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        multipart.Add(fileContent, "sourceImage", "pet.jpg");

        using var response = await application.Client.PostAsync($"/api/templates/{created.TemplateId}/generations", multipart);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("templates.invalid_status", body);
        Assert.Single(application.MediaStorage.DeletedUrls);
        Assert.Empty(application.Billing.ChargedGenerationIds);
    }

    [Fact]
    public async Task VideoGenerationFlow_ShouldRefundCharge_WhenGeneratedMediaImportFails()
    {
        await using var application = await TestApplication.CreateAsync(failGeneratedMediaImport: true);

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
                "Refund Dance",
                "Refund on failed generation",
                "Dance",
                ["refund"],
                true,
                45,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                new TemplateAssetCommand(previewAsset.Url, previewAsset.FileName, previewAsset.ContentType, previewAsset.FileSizeBytes, previewAsset.DurationSeconds),
                new TemplateAssetCommand(referenceAsset.Url, referenceAsset.FileName, referenceAsset.ContentType, referenceAsset.FileSizeBytes, referenceAsset.DurationSeconds),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/standard/motion-control",
                "Dance prompt.",
                true,
                TemplateStatus.Active.ToString()));

        var queued = await UploadGenerationSourceAsync(
            application.Client,
            created.TemplateId,
            "pet.jpg",
            "image/jpeg",
            "source-pet-image"u8.ToArray());

        var failed = await WaitForGenerationStatusAsync(application.Client, queued.GenerationId, "Failed");

        Assert.Equal("templates.generated_media_import_failed", failed.FailureCode);
        Assert.Null(failed.OutputUrl);
        Assert.Contains(queued.GenerationId, application.Billing.ChargedGenerationIds);
        Assert.Contains(queued.GenerationId, application.Billing.RefundedGenerationIds);
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

        public static async Task<TestApplication> CreateAsync(bool failGeneratedMediaImport = false)
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
                PreviewMaxFileSizeBytes = 5 * 1024 * 1024,
                ReferenceMotionMaxFileSizeBytes = 5 * 1024 * 1024,
                SeedSampleTemplates = false,
                GenerationWorkerPollIntervalMilliseconds = 10,
                GeneratedVideoMaxFileSizeBytes = 5 * 1024 * 1024,
            });

            var mediaStorage = new InMemoryMediaStorage();
            var billing = new TestTemplateGenerationBilling();
            builder.Services.AddSingleton<IMediaStorage>(mediaStorage);
            builder.Services.AddSingleton<IMediaMetadataReader, TestMediaMetadataReader>();
            builder.Services.AddSingleton<ITemplateMediaUploadPolicy>(new FixedTemplateMediaUploadPolicy());
            builder.Services.AddSingleton<IImagePreprocessor, TestImagePreprocessor>();
            builder.Services.AddSingleton<IImageGenerator, TestImageGenerator>();
            builder.Services.AddSingleton<IVideoMotionGenerator, TestVideoMotionGenerator>();
            builder.Services.AddSingleton<IGeneratedMediaImporter>(new TestGeneratedMediaImporter(mediaStorage, failGeneratedMediaImport));
            builder.Services.AddSingleton<ITemplateGenerationBilling>(billing);
            builder.Services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
            builder.Services.AddSingleton<ITemplateGenerationPushNotificationSender, NoopPushNotificationSender>();
            builder.Services.AddScoped<ITemplateMediaLifecycleService, TemplateMediaLifecycleService>();
            builder.Services.AddScoped<ITemplatesService, TemplatesService>();
            builder.Services.AddScoped<ITemplateGenerationService, TemplateGenerationService>();
            builder.Services.AddScoped<ITemplatePushTokenService, TemplatePushTokenService>();
            builder.Services.AddScoped<TemplateGenerationJobProcessor>();
            builder.Services.AddHostedService<TemplateGenerationWorker>();
            builder.Services.AddTemplatesApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapTemplatesApiModule();

            await app.StartAsync();

            var client = app.GetTestClient();
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
            var stored = new StoredMediaResponse(url, $"templates-media/{asset.FileName}", asset.FileName, asset.ContentType, asset.Content.LongLength, null);
            assets[url] = stored;
            return Task.FromResult(Result.Success(stored));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            assets.TryRemove(assetUrl, out _);
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

    private sealed class TestImagePreprocessor : IImagePreprocessor
    {
        public Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImagePreprocessResult(originalImageUrl, null, null)));
        }
    }

    private sealed class TestImageGenerator : IImageGenerator
    {
        public Task<Result<ImageGenerationResult>> CreateAsync(string sourceImageUrl, string prompt, string model, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImageGenerationResult($"https://fal.example.test/generated/{Guid.NewGuid():N}.png", null, null)));
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
                new Claim(ClaimTypes.NameIdentifier, TestUserId.ToString()),
                new Claim(ClaimTypes.Name, "integration-test-user"),
                new Claim(ClaimTypes.Role, "Admin"),
            };

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
            var line = await reader.ReadLineAsync();
            if (line is null)
            {
                throw new InvalidOperationException("SSE stream closed before an event was received.");
            }

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
