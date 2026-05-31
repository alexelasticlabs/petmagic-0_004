using System.Net;
using System.Net.Http.Json;
using System.Text;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

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


}
