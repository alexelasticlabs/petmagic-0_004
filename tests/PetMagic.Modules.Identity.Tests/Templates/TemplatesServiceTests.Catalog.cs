using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{

    [Fact]
    public async Task CreateVideoAsync_ShouldCalculateImageOrientation_WhenReferenceDurationIsTenSecondsOrLess()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset(),
                CreateReferenceAsset(9.8),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("Image", result.Value.CharacterOrientation);
        Assert.Equal(9.8, result.Value.ReferenceVideoDurationSeconds);
        Assert.Equal(1.8654m, result.Value.EstimatedProviderCostUsd);
    }

    [Fact]
    public async Task CreateVideoAsync_ShouldPersistActiveStatus_WhenRequestedStatusIsActiveAndTemplateIsValid()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset(),
                CreateReferenceAsset(9.8),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(TemplateStatus.Active.ToString(), result.Value.Status);
    }

    [Fact]
    public async Task UpdateCategoryAsync_ShouldRenameLinkedTemplates()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
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

        Assert.True(created.IsSuccess);

        var category = await dbContext.TemplateCategories.SingleAsync(x => x.Name == "Portrait");
        var updatedCategory = await service.UpdateCategoryAsync(
            new UpdateTemplateCategoryCommand(category.Id, "Studio Portrait"),
            CancellationToken.None);

        Assert.True(updatedCategory.IsSuccess);
        Assert.Equal("Studio Portrait", updatedCategory.Value.Name);

        var updatedTemplate = await service.GetAdminAsync(created.Value.TemplateId, CancellationToken.None);
        Assert.True(updatedTemplate.IsSuccess);
        Assert.Equal("Studio Portrait", updatedTemplate.Value.Category);
    }

    [Fact]
    public async Task ChangeCategoryArchiveStateAsync_ShouldToggleArchiveFlag()
    {
        await using var dbContext = CreateDbContext();
        var realtimeService = new RecordingTemplateFeedRealtimeService();
        var service = CreateService(dbContext, realtimeService: realtimeService);

        var createdCategory = await service.CreateCategoryAsync(
            new CreateTemplateCategoryCommand("Seasonal"),
            CancellationToken.None);

        Assert.True(createdCategory.IsSuccess);
        Assert.False(createdCategory.Value.IsArchived);

        var archived = await service.ChangeCategoryArchiveStateAsync(
            new ChangeTemplateCategoryArchiveStateCommand(createdCategory.Value.CategoryId, true),
            CancellationToken.None);

        Assert.True(archived.IsSuccess);
        Assert.True(archived.Value.IsArchived);

        var restored = await service.ChangeCategoryArchiveStateAsync(
            new ChangeTemplateCategoryArchiveStateCommand(createdCategory.Value.CategoryId, false),
            CancellationToken.None);

        Assert.True(restored.IsSuccess);
        Assert.False(restored.Value.IsArchived);
        Assert.Equal(3, realtimeService.InvalidatedCount);
    }

    [Fact]
    public async Task CreateImageAsync_ShouldPublishFeedInvalidation()
    {
        await using var dbContext = CreateDbContext();
        var realtimeService = new RecordingTemplateFeedRealtimeService();
        var service = CreateService(dbContext, realtimeService: realtimeService);

        var created = await service.CreateImageAsync(
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

        Assert.True(created.IsSuccess);
        Assert.Equal(1, realtimeService.InvalidatedCount);
    }

    [Fact]
    public async Task DeleteCategoryAsync_ShouldReject_WhenTemplatesStillReferenceCategory()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
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

        Assert.True(created.IsSuccess);

        var category = await dbContext.TemplateCategories.SingleAsync(x => x.Name == "Portrait");
        var deleted = await service.DeleteCategoryAsync(category.Id, CancellationToken.None);

        Assert.True(deleted.IsFailure);
        Assert.Equal("templates.category_has_templates", deleted.Error.Code);
    }

    [Fact]
    public async Task ListAdminCategoriesAsync_ShouldReturnBackendAggregatedCountsAndTags()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var activeImage = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait Active",
                "Active portrait",
                "Portrait",
                ["cozy", "Spark"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait-active.jpg", "portrait-active.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);
        var draftImage = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait Draft",
                "Draft portrait",
                "Portrait",
                ["cozy", "draft"],
                false,
                10,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait-draft.jpg", "portrait-draft.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);
        var archivedImage = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait Archived",
                "Archived portrait",
                "Portrait",
                ["archive"],
                false,
                10,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait-archived.jpg", "portrait-archived.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Archived.ToString()),
            CancellationToken.None);
        var activePremiumVideo = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Portrait Motion",
                "Premium motion",
                "Portrait",
                ["motion", "spark"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset("https://cdn.example.com/portrait-motion.mp4", "portrait-motion.mp4", "video/mp4"),
                CreateReferenceAsset(8.2),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);
        var seasonal = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Seasonal Portrait",
                "Seasonal portrait",
                "Seasonal",
                ["holiday"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/seasonal.jpg", "seasonal.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(activeImage.IsSuccess);
        Assert.True(draftImage.IsSuccess);
        Assert.True(archivedImage.IsSuccess);
        Assert.True(activePremiumVideo.IsSuccess);
        Assert.True(seasonal.IsSuccess);

        var seasonalCategory = await dbContext.TemplateCategories.SingleAsync(x => x.Name == "Seasonal");
        var archivedCategory = await service.ChangeCategoryArchiveStateAsync(
            new ChangeTemplateCategoryArchiveStateCommand(seasonalCategory.Id, true),
            CancellationToken.None);

        Assert.True(archivedCategory.IsSuccess);

        var activeCategories = await service.ListAdminCategoriesAsync(false, CancellationToken.None);
        var allCategories = await service.ListAdminCategoriesAsync(true, CancellationToken.None);

        Assert.True(activeCategories.IsSuccess);
        Assert.DoesNotContain(activeCategories.Value, category => category.Name == "Seasonal");

        Assert.True(allCategories.IsSuccess);
        var portrait = Assert.Single(allCategories.Value, category => category.Name == "Portrait");
        Assert.Equal(4, portrait.TotalTemplates);
        Assert.Equal(1, portrait.VideoTemplates);
        Assert.Equal(3, portrait.ImageTemplates);
        Assert.Equal(2, portrait.ActiveTemplates);
        Assert.Equal(1, portrait.DraftTemplates);
        Assert.Equal(1, portrait.ArchivedTemplates);
        Assert.Equal(1, portrait.PremiumTemplates);
        Assert.Equal(["archive", "cozy", "draft", "motion", "Spark"], portrait.Tags);

        var archivedSeasonal = Assert.Single(allCategories.Value, category => category.Name == "Seasonal");
        Assert.True(archivedSeasonal.IsArchived);
        Assert.Equal(1, archivedSeasonal.TotalTemplates);
        Assert.Equal(["holiday"], archivedSeasonal.Tags);
    }

    [Fact]
    public async Task ChangeStatusAsync_ShouldRejectActivation_WhenReferenceDurationWasNotResolved()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Long Motion",
                "Needs metadata",
                "Dance",
                ["dance"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(null),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/standard/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        Assert.Null(created.Value.CharacterOrientation);

        var activation = await service.ChangeStatusAsync(
            new ChangeTemplateStatusCommand(created.Value.TemplateId, TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(activation.IsFailure);
        Assert.Equal("templates.reference_duration_required", activation.Error.Code);
    }

    [Fact]
    public async Task ListPublicAsync_ShouldReturnOnlyActiveTemplates()
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

        var publicList = await service.ListPublicAsync(null, null, null, null, null, CancellationToken.None);

        Assert.True(publicList.IsSuccess);
        Assert.Single(publicList.Value);
        Assert.Equal(imageTemplate.Value.TemplateId, publicList.Value[0].TemplateId);
    }

    [Fact]
    public async Task ListPublicAsync_ShouldCapLegacyResponseForUnpagedClients()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        for (var index = 0; index < 105; index++)
        {
            await CreateActiveImageTemplateAsync(
                service,
                $"Legacy Template {index:D3}",
                "Legacy",
                ["legacy"]);
        }

        var publicList = await service.ListPublicAsync(null, null, null, null, null, CancellationToken.None);

        Assert.True(publicList.IsSuccess);
        Assert.Equal(100, publicList.Value.Count);
        Assert.Equal("Legacy Template 000", publicList.Value[0].Title);
        Assert.Equal("Legacy Template 099", publicList.Value[^1].Title);
        Assert.DoesNotContain(publicList.Value, item => item.Title == "Legacy Template 100");
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
        var legacyList = await service.ListPublicAsync(null, "Capability", ["capability"], null, null, CancellationToken.None);
        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Capability", ["capability"], null, null, 10, null, null),
            CancellationToken.None);
        var random = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(null, "Capability", true, null),
            CancellationToken.None);

        Assert.True(detail.IsSuccess);
        Assert.True(legacyList.IsSuccess);
        Assert.True(feed.IsSuccess);
        Assert.True(random.IsSuccess);

        AssertDetailCapabilities(detail.Value);
        AssertListCapabilities(Assert.Single(legacyList.Value));
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
        var legacyList = await service.ListPublicAsync(
            null,
            null,
            [new string('x', 33)],
            null,
            null,
            CancellationToken.None);
        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 10, null, null, null, [.. Enumerable.Range(0, 13).Select(index => $"tag{index}")]),
            CancellationToken.None);

        Assert.True(feed.IsSuccess);
        Assert.True(legacyList.IsSuccess);
        Assert.True(catalog.IsSuccess);
        Assert.Empty(feed.Value.Items);
        Assert.Empty(legacyList.Value);
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

    [Fact]
    public async Task UpdateImageAsync_ShouldDeletePreviousPreview_WhenPreviewUrlChanges()
    {
        await using var dbContext = CreateDbContext();
        var storage = new RecordingMediaStorage();
        var service = CreateService(dbContext, storage);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/old-preview.jpg", "old-preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var updated = await service.UpdateImageAsync(
            new UpdateImageTemplateCommand(
                created.Value.TemplateId,
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/new-preview.jpg", "new-preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(updated.IsSuccess);
        Assert.Single(storage.DeletedUrls);
        Assert.Equal("http://localhost:5000/templates-media/2026/05/old-preview.jpg", storage.DeletedUrls[0]);

        var oldRecord = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Url == "http://localhost:5000/templates-media/2026/05/old-preview.jpg");
        var newRecord = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Url == "http://localhost:5000/templates-media/2026/05/new-preview.jpg");
        Assert.Equal(TemplateMediaLifecycleState.Deleted, oldRecord.LifecycleState);
        Assert.Null(oldRecord.TemplateId);
        Assert.Equal(TemplateMediaLifecycleState.AttachedToTemplate, newRecord.LifecycleState);
        Assert.Equal(created.Value.TemplateId, newRecord.TemplateId);
    }

    [Fact]
    public async Task UpdateVideoAsync_ShouldDeletePreviousReference_WhenReferenceRemoved()
    {
        await using var dbContext = CreateDbContext();
        var storage = new RecordingMediaStorage();
        var service = CreateService(dbContext, storage);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/preview.mp4", "preview.mp4", "video/mp4"),
                CreateReferenceAsset(9.8, "http://localhost:5000/templates-media/2026/05/reference.mp4"),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var updated = await service.UpdateVideoAsync(
            new UpdateVideoTemplateCommand(
                created.Value.TemplateId,
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/preview.mp4", "preview.mp4", "video/mp4"),
                null,
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true),
            CancellationToken.None);

        Assert.True(updated.IsSuccess);
        Assert.Single(storage.DeletedUrls);
        Assert.Equal("http://localhost:5000/templates-media/2026/05/reference.mp4", storage.DeletedUrls[0]);
    }

    [Fact]
    public async Task UpdateVideoAsync_ShouldRejectRequestedActiveStatus_WhenReferenceDurationIsMissing()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Long Motion",
                "Needs metadata",
                "Dance",
                ["dance"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(null),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/standard/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var updated = await service.UpdateVideoAsync(
            new UpdateVideoTemplateCommand(
                created.Value.TemplateId,
                "Long Motion",
                "Needs metadata",
                "Dance",
                ["dance"],
                false,
                40,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(null),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/standard/motion-control",
                "dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(updated.IsFailure);
        Assert.Equal("templates.reference_duration_required", updated.Error.Code);
    }

    [Fact]
    public async Task UpdateImageAsync_ShouldNotDeletePreview_WhenPreviewUrlDoesNotChange()
    {
        await using var dbContext = CreateDbContext();
        var storage = new RecordingMediaStorage();
        var service = CreateService(dbContext, storage);

        var preview = CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/same-preview.jpg", "same-preview.jpg", "image/jpeg");
        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                preview,
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var updated = await service.UpdateImageAsync(
            new UpdateImageTemplateCommand(
                created.Value.TemplateId,
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                preview,
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(updated.IsSuccess);
        Assert.Empty(storage.DeletedUrls);
    }

    [Fact]
    public async Task DeleteAsync_ShouldRemoveTemplateAndCleanupAllAssetUrls()
    {
        await using var dbContext = CreateDbContext();
        var storage = new RecordingMediaStorage();
        var service = CreateService(dbContext, storage);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Viral Dance",
                "Funny dance template",
                "Dance",
                ["viral", "dance"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/preview.mp4", "preview.mp4", "video/mp4"),
                CreateReferenceAsset(9.8, "http://localhost:5000/templates-media/2026/05/reference.mp4"),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "funny dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var deleted = await service.DeleteAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(deleted.IsSuccess);
        Assert.Equal(2, storage.DeletedUrls.Count);
        Assert.Contains("http://localhost:5000/templates-media/2026/05/preview.mp4", storage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/2026/05/reference.mp4", storage.DeletedUrls);
        var deletedTemplate = await dbContext.TemplateItems.SingleOrDefaultAsync(x => x.Id == created.Value.TemplateId);
        Assert.NotNull(deletedTemplate);
        Assert.NotNull(deletedTemplate!.DeletedAtUtc);

        var publicCatalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 20, null, null, null),
            CancellationToken.None);
        Assert.True(publicCatalog.IsSuccess);
        Assert.DoesNotContain(publicCatalog.Value.Items, item => item.Id == created.Value.TemplateId);
    }

    [Fact]
    public async Task ListPublicCatalogAsync_ShouldApplyTagAndPremiumFiltersForPagedClients()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var freeTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Cozy Free",
            "Portrait",
            ["cozy", "free"]);

        var premiumTemplate = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Cozy Premium",
                "Premium portrait",
                "Portrait",
                ["cozy", "premium"],
                true,
                40,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset("https://cdn.example.com/cozy-premium.jpg", "cozy-premium.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(premiumTemplate.IsSuccess);

        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(
                1,
                20,
                TemplateType.Image,
                "Portrait",
                null,
                ["cozy", "premium"],
                true),
            CancellationToken.None);

        Assert.True(catalog.IsSuccess);
        var item = Assert.Single(catalog.Value.Items);
        Assert.Equal(premiumTemplate.Value.TemplateId, item.Id);
        Assert.DoesNotContain(catalog.Value.Items, item => item.Id == freeTemplateId);
        Assert.True(item.IsPremium);
        Assert.Equal(1, catalog.Value.TotalCount);
        Assert.False(catalog.Value.HasMore);
    }

    [Fact]
    public async Task ListPublicCatalogAsync_ShouldUseExtraRowForHasMoreWithoutReturningIt()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var utcNow = DateTime.UtcNow;

        var oldestId = await CreateActiveImageTemplateAsync(service, "Catalog Old", "Portrait", ["catalog-page"]);
        var middleId = await CreateActiveImageTemplateAsync(service, "Catalog Middle", "Portrait", ["catalog-page"]);
        var newestId = await CreateActiveImageTemplateAsync(service, "Catalog New", "Portrait", ["catalog-page"]);

        await SetUpdatedAtUtcAsync(dbContext, oldestId, utcNow.AddMinutes(-30));
        await SetUpdatedAtUtcAsync(dbContext, middleId, utcNow.AddMinutes(-20));
        await SetUpdatedAtUtcAsync(dbContext, newestId, utcNow.AddMinutes(-10));

        var firstPage = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 2, TemplateType.Image, "Portrait", null, ["catalog-page"]),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.Equal(3, firstPage.Value.TotalCount);
        Assert.Equal(2, firstPage.Value.Items.Count);
        Assert.Equal([newestId, middleId], [.. firstPage.Value.Items.Select(item => item.Id)]);
        Assert.DoesNotContain(firstPage.Value.Items, item => item.Id == oldestId);

        var secondPage = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(2, 2, TemplateType.Image, "Portrait", null, ["catalog-page"]),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(oldestId, item.Id);
        Assert.Equal(3, secondPage.Value.TotalCount);
    }

    [Fact]
    public async Task ListPublicCatalogAsync_ShouldUseFeedVersionTieBreakOrder()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var updatedAtUtc = DateTime.UtcNow;

        var lowestVersionId = await CreateActiveImageTemplateAsync(
            service,
            "Catalog Same Time One",
            "Portrait",
            ["catalog-version"]);
        var middleVersionId = await CreateActiveImageTemplateAsync(
            service,
            "Catalog Same Time Two",
            "Portrait",
            ["catalog-version"]);
        var highestVersionId = await CreateActiveImageTemplateAsync(
            service,
            "Catalog Same Time Three",
            "Portrait",
            ["catalog-version"]);

        var lowestVersion = await dbContext.TemplateItems.SingleAsync(x => x.Id == lowestVersionId);
        var middleVersion = await dbContext.TemplateItems.SingleAsync(x => x.Id == middleVersionId);
        var highestVersion = await dbContext.TemplateItems.SingleAsync(x => x.Id == highestVersionId);
        lowestVersion.UpdatedAtUtc = updatedAtUtc;
        lowestVersion.Version = 10;
        middleVersion.UpdatedAtUtc = updatedAtUtc;
        middleVersion.Version = 20;
        highestVersion.UpdatedAtUtc = updatedAtUtc;
        highestVersion.Version = 30;
        await dbContext.SaveChangesAsync(CancellationToken.None);

        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(
                1,
                3,
                TemplateType.Image,
                "Portrait",
                null,
                ["catalog-version"]),
            CancellationToken.None);
        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(
                TemplateType.Image,
                "Portrait",
                ["catalog-version"],
                null,
                null,
                3,
                null,
                null),
            CancellationToken.None);

        Assert.True(catalog.IsSuccess);
        Assert.True(feed.IsSuccess);
        Assert.Equal(
            [highestVersionId, middleVersionId, lowestVersionId],
            [.. catalog.Value.Items.Select(item => item.Id)]);
        Assert.Equal(
            [.. feed.Value.Items.Select(item => item.TemplateId)],
            [.. catalog.Value.Items.Select(item => item.Id)]);
    }

    [Fact]
    public async Task PublicCatalogCategoryFilters_ShouldUseCanonicalCategoryWithoutBroadening()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var portraitTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Canonical Portrait",
            "Portrait",
            ["canonical"]);
        await CreateActiveImageTemplateAsync(
            service,
            "Other Portrait",
            "Other",
            ["canonical"]);

        var catalog = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 20, null, "portrait", null, ["canonical"]),
            CancellationToken.None);
        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "portrait", ["canonical"], null, null, 10, null, null),
            CancellationToken.None);
        var legacyList = await service.ListPublicAsync(
            null,
            "portrait",
            ["canonical"],
            null,
            null,
            CancellationToken.None);
        var unknownCategory = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 20, null, "missing", null, ["canonical"]),
            CancellationToken.None);

        Assert.True(catalog.IsSuccess);
        Assert.True(feed.IsSuccess);
        Assert.True(legacyList.IsSuccess);
        Assert.True(unknownCategory.IsSuccess);

        var catalogItem = Assert.Single(catalog.Value.Items);
        Assert.Equal(portraitTemplateId, catalogItem.Id);
        Assert.Equal("Portrait", catalogItem.Category);

        var feedItem = Assert.Single(feed.Value.Items);
        Assert.Equal(portraitTemplateId, feedItem.TemplateId);
        Assert.Equal("Portrait", feedItem.Category);

        var legacyItem = Assert.Single(legacyList.Value);
        Assert.Equal(portraitTemplateId, legacyItem.TemplateId);
        Assert.Equal("Portrait", legacyItem.Category);
        Assert.Empty(unknownCategory.Value.Items);
    }

    [Fact]
    public async Task ListPublicFeedAsync_ShouldReturnMobileCapabilityAndVersionFields()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Capability Feed",
                "Feed capability template",
                "Capability",
                ["feed", "capability"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/capability-feed.jpg", "capability-feed.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                ["front-facing pet", "clear lighting"],
                SupportsGenerationResultInput: true,
                RequiredInputMediaType: TemplateType.Image.ToString(),
                RecommendedAfterImageGeneration: true,
                SupportsGenerateSimilar: false,
                DefaultVariationStrength: "high"),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Capability", ["feed"], null, null, 10, null, null),
            CancellationToken.None);

        Assert.True(feed.IsSuccess);
        var item = Assert.Single(feed.Value.Items);
        Assert.Equal(created.Value.TemplateId, item.TemplateId);
        Assert.Equal(["front-facing pet", "clear lighting"], item.PetPhotoRequirements);
        Assert.True(item.SupportsGenerationResultInput);
        Assert.Equal(TemplateType.Image.ToString(), item.RequiredInputMediaType);
        Assert.True(item.RecommendedAfterImageGeneration);
        Assert.False(item.SupportsGenerateSimilar);
        Assert.Equal("high", item.DefaultVariationStrength);
        Assert.True(item.Version > 0);
        Assert.NotNull(item.UpdatedAtUtc);
    }

    [Fact]
    public async Task DeleteAsync_ShouldKeepTemplate_WhenMediaCleanupFails()
    {
        await using var dbContext = CreateDbContext();
        var storage = new FailingDeleteMediaStorage();
        var service = CreateService(dbContext, storage);

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait",
                "Cozy portrait",
                "Portrait",
                ["cozy"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/preview.jpg", "preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var deleted = await service.DeleteAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(deleted.IsFailure);
        Assert.Equal("templates.media_storage_failed", deleted.Error.Code);
        Assert.True(await dbContext.TemplateItems.AnyAsync(x => x.Id == created.Value.TemplateId));
    }

    [Fact]
    public async Task CatalogVersionAndChanges_ShouldReturnUpsertsAndDeletedIds()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
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
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var initialVersion = await service.GetPublicCatalogVersionAsync(CancellationToken.None);
        Assert.True(initialVersion.IsSuccess);
        Assert.True(initialVersion.Value.Version > 0);
        var initialChange = await dbContext.TemplateCatalogChanges.SingleAsync(x => x.Version == initialVersion.Value.Version);
        Assert.Equal(initialChange.UpdatedAtUtc, initialVersion.Value.UpdatedAtUtc);

        var firstChanges = await service.GetPublicCatalogChangesAsync(0, null, CancellationToken.None);
        Assert.True(firstChanges.IsSuccess);
        Assert.Single(firstChanges.Value.Upserts);
        Assert.Empty(firstChanges.Value.DeletedIds);
        Assert.Equal(created.Value.TemplateId, firstChanges.Value.Upserts[0].Id);

        var deleted = await service.DeleteAsync(created.Value.TemplateId, CancellationToken.None);
        Assert.True(deleted.IsSuccess);

        var afterDeleteVersion = await service.GetPublicCatalogVersionAsync(CancellationToken.None);
        Assert.True(afterDeleteVersion.IsSuccess);
        Assert.True(afterDeleteVersion.Value.Version > initialVersion.Value.Version);

        var delta = await service.GetPublicCatalogChangesAsync(initialVersion.Value.Version, null, CancellationToken.None);
        Assert.True(delta.IsSuccess);
        Assert.Empty(delta.Value.Upserts);
        Assert.Contains(created.Value.TemplateId, delta.Value.DeletedIds);
    }

    [Fact]
    public async Task CatalogChanges_ShouldRequestFullResync_WhenChangeHistoryIsMissing()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateImageAsync(
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
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == created.Value.TemplateId);
        template.Version = 25;
        template.UpdatedAtUtc = DateTime.UtcNow;
        dbContext.TemplateCatalogChanges.RemoveRange(dbContext.TemplateCatalogChanges);
        await dbContext.SaveChangesAsync(CancellationToken.None);

        var changes = await service.GetPublicCatalogChangesAsync(0, null, CancellationToken.None);

        Assert.True(changes.IsSuccess);
        Assert.True(changes.Value.NeedsFullResync);
        Assert.Empty(changes.Value.Upserts);
        Assert.Empty(changes.Value.DeletedIds);
        Assert.Equal(0, changes.Value.FromVersion);
        Assert.Equal(25, changes.Value.ToVersion);
    }


}
