using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

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

        var publicList = await service.ListPublicAsync(null, null, null, null, CancellationToken.None);

        Assert.True(publicList.IsSuccess);
        Assert.Single(publicList.Value);
        Assert.Equal(imageTemplate.Value.TemplateId, publicList.Value[0].TemplateId);
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
        var publicDetail = await service.GetPublicAsync(created.Value.TemplateId, CancellationToken.None);
        var publicFeed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, null, [], null, "good lighting", 10, null),
            CancellationToken.None);

        Assert.True(adminDetail.IsSuccess);
        Assert.True(publicDetail.IsSuccess);
        Assert.True(publicFeed.IsSuccess);
        Assert.Equal(expectedRequirements, adminDetail.Value.PetPhotoRequirements);
        Assert.Equal(expectedRequirements, publicDetail.Value.PetPhotoRequirements);
        var feedItem = Assert.Single(publicFeed.Value.Items);
        Assert.Equal(created.Value.TemplateId, feedItem.TemplateId);
        Assert.Equal(expectedRequirements, feedItem.PetPhotoRequirements);
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
            new PublicTemplatesFeedQuery(null, "Portrait", ["cozy"], null, "portrait", 2, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal([newestId, middleId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "Portrait", ["cozy"], null, "portrait", 2, firstPage.Value.NextCursor),
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
            new PublicTemplatesFeedQuery(null, "portrait", [], null, "portrait", 2, null),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.True(firstPage.Value.HasMore);
        Assert.NotNull(firstPage.Value.NextCursor);
        Assert.Equal([newestId, middleId], [.. firstPage.Value.Items.Select(item => item.TemplateId)]);

        var secondPage = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, "PORTRAIT", [], null, "PoRtRaIt", 2, firstPage.Value.NextCursor),
            CancellationToken.None);

        Assert.True(secondPage.IsSuccess);
        Assert.False(secondPage.Value.HasMore);
        Assert.Null(secondPage.Value.NextCursor);
        var item = Assert.Single(secondPage.Value.Items);
        Assert.Equal(oldestId, item.TemplateId);
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
        Assert.False(await dbContext.TemplateItems.AnyAsync(x => x.Id == created.Value.TemplateId));
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


}
