using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

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

        var adminDraftList = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Draft");

        var persistedDraftItem = Assert.Single(adminDraftList.Items);
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

        var adminActiveList = await GetFromJsonAsync<AdminTemplateCatalogPageResponse>(
            application.Client,
            "/api/admin/templates/?type=Video&status=Active");

        var listedAdminItem = Assert.Single(adminActiveList.Items);
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

        var item = Assert.Single(items.EnumerateArray());
        Assert.Equal(created.TemplateId, item.GetProperty("templateId").GetGuid());
        Assert.Equal("Image", item.GetProperty("templateType").GetString());
        Assert.Equal("Contract Feed Portrait", item.GetProperty("title").GetString());
        Assert.Equal("Contract feed description", item.GetProperty("shortDescription").GetString());
        Assert.Equal("Contract", item.GetProperty("category").GetString());
        Assert.False(item.GetProperty("isPremium").GetBoolean());
        Assert.Equal(20, item.GetProperty("tokenCost").GetInt32());

        var preview = item.GetProperty("previewAsset");
        Assert.Equal(previewAsset.Url, preview.GetProperty("url").GetString());
        Assert.Equal("contract-feed.jpg", preview.GetProperty("fileName").GetString());
        Assert.Equal("image/jpeg", preview.GetProperty("contentType").GetString());

        Assert.Equal(
            ["Clear pet face", "Good lighting"],
            [.. item.GetProperty("petPhotoRequirements").EnumerateArray().Select(requirement => requirement.GetString() ?? string.Empty)]);

        var typedResponse = JsonSerializer.Deserialize<PublicTemplatesFeedResponse>(body, JsonOptions);
        Assert.NotNull(typedResponse);
        var typedItem = Assert.Single(typedResponse.Items);
        Assert.Equal(created.TemplateId, typedItem.TemplateId);
        Assert.Equal(previewAsset.Url, typedItem.PreviewAsset?.Url);
        Assert.Equal(["Clear pet face", "Good lighting"], typedItem.PetPhotoRequirements);
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
    [InlineData("/api/templates/?type=Document")]
    [InlineData("/api/templates/?type=1")]
    [InlineData("/api/templates/feed?type=Document")]
    [InlineData("/api/templates/feed?type=1")]
    public async Task PublicTemplateCatalogEndpoints_ShouldReturnProblem_WhenTypeFilterIsInvalid(string path)
    {
        await using var application = await TestApplication.CreateAsync();

        application.Client.DefaultRequestHeaders.Authorization = null;

        using var response = await application.Client.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.invalid_type", body);
        Assert.Contains("Image or Video", body);
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

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
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
    public async Task PublicPagedTemplateCatalog_ShouldApplyTagsAndPremiumOnlyQueryParameters()
    {
        await using var application = await TestApplication.CreateAsync();

        var free = await CreateActiveImageTemplateAsync(application.Client, "Contract Free", "Contract", ["contract", "free"]);
        var premium = await CreateActivePremiumImageTemplateAsync(application.Client, "Contract Premium", "Contract", ["contract", "premium"]);

        var page = await GetFromJsonAsync<PublicTemplatesCatalogPageResponse>(
            application.Client,
            "/api/templates?page=1&pageSize=20&type=Image&category=Contract&tags=contract&tags=premium&premiumOnly=true");

        var item = Assert.Single(page.Items);
        Assert.Equal(premium.TemplateId, item.Id);
        Assert.DoesNotContain(page.Items, item => item.Id == free.TemplateId);
        Assert.True(item.IsPremium);
        Assert.Equal(1, page.TotalCount);
        Assert.False(page.HasMore);
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
