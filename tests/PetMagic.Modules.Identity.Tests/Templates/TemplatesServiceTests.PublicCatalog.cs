using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListPublicCatalogAsync_ShouldReturnOnlyActiveTemplates()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var imageTemplate = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait.jpg", "portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        var draftVideo = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Draft Dance",
                "Draft video",
                "Dance",
                ["draft"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.4),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true),
            CancellationToken.None);

        Assert.True(imageTemplate.IsSuccess);
        Assert.True(draftVideo.IsSuccess);

        var activated = await service.ChangeStatusAsync(
            new ChangeTemplateStatusCommand(imageTemplate.Value.TemplateId, TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(activated.IsSuccess);

        var publicList = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(null, null, null, null, null),
            CancellationToken.None);

        Assert.True(publicList.IsSuccess);
        Assert.Single(publicList.Value.Items);
        Assert.Equal(imageTemplate.Value.TemplateId, publicList.Value.Items[0].Id);
    }

    [Fact]
    public async Task ListPublicCatalogAsync_ShouldUseDefaultPaginationWhenPageParamsAreMissing()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        for (var index = 0; index < 25; index++)
        {
            await CreateActiveImageTemplateAsync(
                service,
                $"Catalog Template {index:D3}",
                "Catalog",
                ["catalog"]);
        }

        var publicList = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(null, null, null, null, null),
            CancellationToken.None);

        Assert.True(publicList.IsSuccess);
        Assert.Equal(1, publicList.Value.Page);
        Assert.Equal(20, publicList.Value.PageSize);
        Assert.Equal(25, publicList.Value.TotalCount);
        Assert.Equal(20, publicList.Value.Items.Count);
        Assert.True(publicList.Value.HasMore);
    }

    [Fact]
    public async Task TemplateResponses_ShouldIncludePetPhotoRequirements()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        string[] expectedRequirements = ["Clear pet face", "Good lighting"];

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Clean Portrait",
                "Bright portrait",
                "Portrait",
                ["clean"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/clean-portrait.jpg", "clean-portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                ["Clear pet face", "Good lighting", "Clear pet face"]),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        Assert.Equal(expectedRequirements, created.Value.PetPhotoRequirements);

        var adminDetail = await service.GetAdminAsync(created.Value.TemplateId, CancellationToken.None);
        var publicDetail = await service.GetPublicAsync(created.Value.TemplateId, null, CancellationToken.None);
        var publicFeed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, null, [], null, "good lighting", 10, null, null),
            CancellationToken.None);

        Assert.True(adminDetail.IsSuccess);
        Assert.True(publicDetail.IsSuccess);
        Assert.True(publicFeed.IsSuccess);
        Assert.Equal(expectedRequirements, adminDetail.Value.PetPhotoRequirements);
        Assert.Equal(expectedRequirements, publicDetail.Value.PetPhotoRequirements);
        var feedItem = Assert.Single(publicFeed.Value.Items);
        Assert.Equal(created.Value.TemplateId, feedItem.TemplateId);
        Assert.Equal("Clean Portrait", feedItem.Title);
    }

    [Fact]
    public async Task PublicTemplateResponses_ShouldExposeGenerationInputCapabilitiesConsistently()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Capability Portrait",
                "Template with generation-result input capabilities",
                "Capability",
                ["capability"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset("https://cdn.example.com/capability-portrait.jpg", "capability-portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                ["Clear pet face"],
                true,
                TemplateType.Video.ToString(),
                true,
                false,
                "high"),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var detail = await service.GetPublicAsync(created.Value.TemplateId, null, CancellationToken.None);
        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 10, null, "Capability", null, ["capability"]),
            CancellationToken.None);
        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Capability", ["capability"], null, null, 10, null, null),
            CancellationToken.None);
        var random = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(null, "Capability", true, null),
            CancellationToken.None);

        Assert.True(detail.IsSuccess);
        Assert.True(catalog.IsSuccess);
        Assert.True(feed.IsSuccess);
        Assert.True(random.IsSuccess);

        AssertDetailCapabilities(detail.Value);
        Assert.Equal(created.Value.TemplateId, Assert.Single(catalog.Value.Items).Id);
        Assert.Equal(created.Value.TemplateId, Assert.Single(feed.Value.Items).TemplateId);
        Assert.NotNull(random.Value.Template);
        AssertListCapabilities(random.Value.Template!);

        static void AssertDetailCapabilities(PublicTemplateResponse item)
        {
            Assert.True(item.SupportsGenerationResultInput);
            Assert.Equal(TemplateType.Video.ToString(), item.RequiredInputMediaType);
            Assert.True(item.RecommendedAfterImageGeneration);
            Assert.False(item.SupportsGenerateSimilar);
            Assert.Equal("high", item.DefaultVariationStrength);
        }

        static void AssertListCapabilities(PublicTemplateListItemResponse item)
        {
            Assert.True(item.SupportsGenerationResultInput);
            Assert.Equal(TemplateType.Video.ToString(), item.RequiredInputMediaType);
            Assert.True(item.RecommendedAfterImageGeneration);
            Assert.False(item.SupportsGenerateSimilar);
            Assert.Equal("high", item.DefaultVariationStrength);
        }
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldPageActiveTemplatesWithStableCursor()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var utcNow = DateTime.UtcNow;

        var oldestId = await CreateActiveImageTemplateAsync(service, "Old Portrait", "Portrait", ["cozy"]);
        var middleId = await CreateActiveImageTemplateAsync(service, "Middle Portrait", "Portrait", ["cozy"]);
        var newestId = await CreateActiveImageTemplateAsync(service, "New Portrait", "Portrait", ["cozy"]);

        await SetUpdatedAtUtcAsync(dbContext, oldestId, utcNow.AddMinutes(-30));
        await SetUpdatedAtUtcAsync(dbContext, middleId, utcNow.AddMinutes(-20));
        await SetUpdatedAtUtcAsync(dbContext, newestId, utcNow.AddMinutes(-10));

        var firstPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["cozy"], null, "portrait", 2, null, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal([newestId, middleId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["cozy"], null, "portrait", 2, firstPage.Value.NextCursor, null),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        Assert.Null(secondPage.Value.NextCursor);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(oldestId, item.TemplateId);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldApplySearchCategoryAndCursorWithoutTags()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var utcNow = DateTime.UtcNow;

        var oldestId = await CreateActiveImageTemplateAsync(service, "Portrait Breeze", "Portrait", ["soft"]);
        var middleId = await CreateActiveImageTemplateAsync(service, "Portrait Glow", "Portrait", ["shine"]);
        await CreateActiveImageTemplateAsync(service, "Dance Burst", "Dance", ["loud"]);
        var newestId = await CreateActiveImageTemplateAsync(service, "PORTRAIT Neon", "Portrait", ["bright"]);

        await SetUpdatedAtUtcAsync(dbContext, oldestId, utcNow.AddMinutes(-30));
        await SetUpdatedAtUtcAsync(dbContext, middleId, utcNow.AddMinutes(-20));
        await SetUpdatedAtUtcAsync(dbContext, newestId, utcNow.AddMinutes(-10));

        var firstPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "portrait", [], null, "portrait", 2, null, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal([newestId, middleId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "PORTRAIT", [], null, "PoRtRaIt", 2, firstPage.Value.NextCursor, null),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        Assert.Null(secondPage.Value.NextCursor);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(oldestId, item.TemplateId);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldSearchAcrossTitleDescriptionCategoryTagsAndRequirements()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var titleMatchId = await CreateActiveImageTemplateAsync(
            service,
            "Aurora Title Signal",
            "Portrait",
            ["gallery"]);
        var categoryMatchId = await CreateActiveImageTemplateAsync(
            service,
            "Category Search Candidate",
            "CategorySignal",
            ["gallery"]);
        var tagMatchId = await CreateActiveImageTemplateAsync(
            service,
            "Tag Search Candidate",
            "Portrait",
            ["tag-signal"]);
        await CreateActiveImageTemplateAsync(
            service,
            "Unrelated Candidate",
            "Portrait",
            ["gallery"]);

        var descriptionMatch = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Description Search Candidate",
                "Contains midnight-description-token only here.",
                "Portrait",
                ["gallery"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset("https://cdn.example.com/description-search.jpg", "description-search.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);
        var requirementsMatch = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Requirements Search Candidate",
                "Neutral description",
                "Portrait",
                ["gallery"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset("https://cdn.example.com/requirements-search.jpg", "requirements-search.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                ["Side profile with left ear visible"]),
            CancellationToken.None);

        Assert.True(descriptionMatch.IsSuccess);
        Assert.True(requirementsMatch.IsSuccess);

        async Task<Guid> SingleSearchResultAsync(string search)
        {
            var feed = await service.ListPublicFeedAsync(
                new PublicTemplatesFeedQuery(null, null, [], null, search, 10, null, null),
                CancellationToken.None);

            Assert.True(feed.IsSuccess);
            var item = Assert.Single(feed.Value.Items);
            return item.TemplateId;
        }

        Assert.Equal(titleMatchId, await SingleSearchResultAsync("aurora title"));
        Assert.Equal(descriptionMatch.Value.TemplateId, await SingleSearchResultAsync("midnight-description-token"));
        Assert.Equal(categoryMatchId, await SingleSearchResultAsync("categorysignal"));
        Assert.Equal(tagMatchId, await SingleSearchResultAsync("tag-signal"));
        Assert.Equal(requirementsMatch.Value.TemplateId, await SingleSearchResultAsync("left ear visible"));
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldPageTemplatesWithSameTimestampUsingVersionCursor()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var updatedAtUtc = DateTime.UtcNow.AddMinutes(-5);

        var oldestVersionId = await CreateActiveImageTemplateAsync(service, "Same Time One", "Portrait", ["stable"]);
        var middleVersionId = await CreateActiveImageTemplateAsync(service, "Same Time Two", "Portrait", ["stable"]);
        var newestVersionId = await CreateActiveImageTemplateAsync(service, "Same Time Three", "Portrait", ["stable"]);

        await SetUpdatedAtUtcAsync(dbContext, oldestVersionId, updatedAtUtc);
        await SetUpdatedAtUtcAsync(dbContext, middleVersionId, updatedAtUtc);
        await SetUpdatedAtUtcAsync(dbContext, newestVersionId, updatedAtUtc);

        var firstPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["stable"], null, "same time", 2, null, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal(3, firstPage.Value.NextCursor.Split(':').Length);
        Assert.Equal([newestVersionId, middleVersionId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["stable"], null, "same time", 2, firstPage.Value.NextCursor, null),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        Assert.Null(secondPage.Value.NextCursor);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(oldestVersionId, item.TemplateId);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldPageTemplatesWithSameTimestampAndVersionUsingIdCursor()
    {
        await using var dbContext = CreateDbContext();
        var updatedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        var version = 42L;
        var highestId = Guid.Parse("ffffffff-ffff-ffff-ffff-ffffffffffff");
        var middleId = Guid.Parse("88888888-8888-8888-8888-888888888888");
        var lowestId = Guid.Parse("11111111-1111-1111-1111-111111111111");

        dbContext.TemplateItems.AddRange(
            CreatePublicFeedTemplate(highestId, "Same Cursor Three", updatedAtUtc, version),
            CreatePublicFeedTemplate(middleId, "Same Cursor Two", updatedAtUtc, version),
            CreatePublicFeedTemplate(lowestId, "Same Cursor One", updatedAtUtc, version));
        await dbContext.SaveChangesAsync(CancellationToken.None);

        var service = CreateService(dbContext);
        var firstPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["cursor"], null, "same cursor", 2, null, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal([highestId, middleId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["cursor"], null, "same cursor", 2, firstPage.Value.NextCursor, null),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        Assert.Null(secondPage.Value.NextCursor);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(lowestId, item.TemplateId);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldBoundPublicSearchAndCategoryFilters()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var title = new string('A', 120);
        var category = new string('C', 64);

        var templateId = await CreateActiveImageTemplateAsync(service, title, category, ["bounded"]);

        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(
                null,
                category + new string('x', 200),
                ["bounded"],
                null,
                title + new string('z', 200),
                10,
                null,
                null),
            CancellationToken.None);

        Assert.True(feed.IsSuccess);
        var item = Assert.Single(feed.Value.Items);
        Assert.Equal(templateId, item.TemplateId);
    }

    [Fact]
    public async Task PublicCatalogQueries_ShouldNotBroadenWhenTagFiltersAreOutOfBounds()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        await CreateActiveImageTemplateAsync(service, "Bounded Portrait", "Portrait", ["cozy"]);

        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, null, [new string('x', 33)], null, null, 10, null, null),
            CancellationToken.None);
        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 10, null, null, null, [.. Enumerable.Range(0, 13).Select(index => $"tag{index}")]),
            CancellationToken.None);

        Assert.True(feed.IsSuccess);
        Assert.True(catalog.IsSuccess);
        Assert.Empty(feed.Value.Items);
        Assert.Empty(catalog.Value.Items);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldStayBoundedAndStableWithMoreThanThousandTemplates()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var utcNow = DateTime.UtcNow;
        var templates = new List<TemplateItem>(capacity: 1005);

        for (var index = 0; index < 1005; index++)
        {
            var templateId = Guid.CreateVersion7();
            var updatedAtUtc = utcNow.AddSeconds(-index);
            templates.Add(new TemplateItem
            {
                Id = templateId,
                Version = index + 1,
                TemplateType = index % 5 == 0 ? TemplateType.Video : TemplateType.Image,
                Title = $"Scale Portrait {index:D4}",
                ShortDescription = $"Scale test template {index:D4}",
                Category = index % 2 == 0 ? "Scale" : "Other",
                Tags = index % 3 == 0 ? "scale,pet" : "pet",
                IsPremium = false,
                TokenCost = 20,
                Status = TemplateStatus.Active,
                PromoBadgeMode = TemplatePromoBadgeMode.Auto,
                MusicDescription = index % 5 == 0 ? "Loop" : null,
                ReferenceVideoDurationSeconds = index % 5 == 0 ? 5 : null,
                ImageModel = "openai/gpt-image-2/edit",
                ImagePrompt = "Keep the same pet.",
                CreatedAtUtc = updatedAtUtc.AddMinutes(-1),
                UpdatedAtUtc = updatedAtUtc,
                Assets =
                [
                    new TemplateAsset
                    {
                        Id = Guid.CreateVersion7(),
                        TemplateId = templateId,
                        AssetKind = TemplateAssetKind.Preview,
                        Url = index % 5 == 0
                            ? $"https://cdn.example.com/scale-{index:D4}.mp4"
                            : $"https://cdn.example.com/scale-{index:D4}.jpg",
                        FileName = index % 5 == 0
                            ? $"scale-{index:D4}.mp4"
                            : $"scale-{index:D4}.jpg",
                        ContentType = index % 5 == 0 ? "video/mp4" : "image/jpeg",
                        FileSizeBytes = index % 5 == 0 ? 524_288 : 48_000,
                        DurationSeconds = index % 5 == 0 ? 5 : null
                    }
                ]
            });
        }

        dbContext.TemplateItems.AddRange(templates);
        await dbContext.SaveChangesAsync(CancellationToken.None);

        var firstPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Scale", [], null, "scale portrait", 1000, null, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.Equal(50, firstPage.Value.Items.Count);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal(
            [.. firstPage.Value.Items.Select(item => item.TemplateId)],
            [.. firstPage.Value.Items.Select(item => item.TemplateId).Distinct()]);
        Assert.All(firstPage.Value.Items, item =>
        {
            Assert.Equal("Scale", item.Category);
            Assert.Contains("Scale Portrait", item.Title);
            if (item.TemplateType == TemplateType.Video.ToString())
            {
                Assert.Null(item.ThumbnailUrl);
            }
            else
            {
                Assert.Equal(item.PreviewAsset?.Url, item.ThumbnailUrl);
            }
        });

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Scale", [], null, "scale portrait", 50, firstPage.Value.NextCursor, null),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.Equal(50, secondPage.Value.Items.Count);
        Assert.DoesNotContain(
            secondPage.Value.Items,
            item => firstPage.Value.Items.Any(first => first.TemplateId == item.TemplateId));
        Assert.True(
            firstPage.Value.Items.Last().Title.CompareTo(secondPage.Value.Items.First().Title) < 0,
            "Second cursor page should continue after the first page in updatedAt desc order.");
    }

    [Fact]
    public async Task GetPublicRandomTemplateAsync_ShouldFilterByTypeCategoryAndPremiumAvailability()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var freeTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Free Portrait",
            "Portrait",
            ["random", "free"]);

        var premiumTemplate = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Premium Portrait",
                "Premium portrait",
                "Portrait",
                ["random", "premium"],
                true,
                60,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset("https://cdn.example.com/premium-portrait.jpg", "premium-portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(premiumTemplate.IsSuccess);

        var freeRandom = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(TemplateType.Image, "portrait", false, null),
            CancellationToken.None);

        Assert.True(freeRandom.IsSuccess);
        Assert.NotNull(freeRandom.Value.Template);
        Assert.Equal(freeTemplateId, freeRandom.Value.Template!.TemplateId);
        Assert.False(freeRandom.Value.Template.IsPremium);
        Assert.Equal(freeRandom.Value.Template.PreviewAsset?.Url, freeRandom.Value.Template.ThumbnailUrl);

        var premiumRandom = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(TemplateType.Image, "portrait", false, null, "premium"),
            CancellationToken.None);

        Assert.True(premiumRandom.IsSuccess);
        Assert.NotNull(premiumRandom.Value.Template);
        Assert.Equal(premiumTemplate.Value.TemplateId, premiumRandom.Value.Template!.TemplateId);
        Assert.True(premiumRandom.Value.Template.IsPremium);

        var noVideoInPortrait = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(TemplateType.Video, "Portrait", true, null),
            CancellationToken.None);

        Assert.True(noVideoInPortrait.IsSuccess);
        Assert.Null(noVideoInPortrait.Value.Template);
    }

    [Fact]
    public async Task GetPublicRandomTemplateAsync_ShouldExcludeCurrentTemplate()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var excludedTemplateId = await CreateActiveVideoTemplateAsync(
            service,
            "Current Video",
            "Recommendations",
            ["random", "current"]);
        var expectedTemplateId = await CreateActiveVideoTemplateAsync(
            service,
            "Next Video",
            "Recommendations",
            ["random", "next"]);

        var random = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(
                TemplateType.Video,
                "Recommendations",
                true,
                null,
                ExcludeTemplateId: excludedTemplateId),
            CancellationToken.None);

        Assert.True(random.IsSuccess);
        Assert.NotNull(random.Value.Template);
        Assert.Equal(expectedTemplateId, random.Value.Template!.TemplateId);
    }

    [Fact]
    public async Task GetPublicRandomTemplateAsync_ShouldBoundCategoryFilter()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var boundedCategory = new string('a', 64);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Bounded Random",
            boundedCategory,
            ["random", "bounded"]);

        var overlongCategory = boundedCategory + "ignored";
        var random = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(TemplateType.Image, overlongCategory, true, null),
            CancellationToken.None);

        Assert.True(random.IsSuccess);
        Assert.NotNull(random.Value.Template);
        Assert.Equal(templateId, random.Value.Template!.TemplateId);
        Assert.Equal(boundedCategory, random.Value.Template.Category);
    }

    [Fact]
    public async Task ListPublicCategoriesAsync_ShouldReturnNonArchivedSortedCategories()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        await CreateActiveImageTemplateAsync(service, "Magic Portrait", "Magic", ["spark"]);
        await CreateActiveImageTemplateAsync(service, "Adventure Portrait", "Adventure", ["story"]);

        var archived = await dbContext.TemplateCategories.SingleAsync(x => x.Name == "Adventure");
        archived.IsArchived = true;
        await dbContext.SaveChangesAsync();

        var categories = await service.ListPublicCategoriesAsync(CancellationToken.None);

        Assert.True(categories.IsSuccess);
        Assert.Equal(["Magic"], [.. categories.Value.Select(x => x.Name)]);
    }
}
