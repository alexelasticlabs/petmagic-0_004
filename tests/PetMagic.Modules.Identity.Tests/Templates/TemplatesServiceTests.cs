using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesServiceTests
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
        Assert.Equal([newestId, middleId], firstPage.Value.Items.Select(item => item.TemplateId).ToArray());

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
        Assert.Equal([newestId, middleId], firstPage.Value.Items.Select(item => item.TemplateId).ToArray());

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
        Assert.Equal(["Magic"], categories.Value.Select(x => x.Name).ToArray());
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

    [Fact]
    public async Task GetAdminStatisticsAsync_ShouldAggregateGenerationMetrics()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Stats Dance",
                "Template with generation history",
                "Dance",
                ["stats"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                OutputUrl = "https://cdn.example.com/output-1.mp4",
                MotionProviderCostUsd = 0.1200m,
                CreatedAtUtc = now.AddMinutes(-40),
                QueuedAtUtc = now.AddMinutes(-40),
                StartedAtUtc = now.AddMinutes(-39),
                CompletedAtUtc = now.AddMinutes(-36),
                UpdatedAtUtc = now.AddMinutes(-36)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                OutputUrl = "https://cdn.example.com/output-2.mp4",
                MotionProviderCostUsd = 0.1800m,
                CreatedAtUtc = now.AddMinutes(-24),
                QueuedAtUtc = now.AddMinutes(-24),
                StartedAtUtc = now.AddMinutes(-23),
                CompletedAtUtc = now.AddMinutes(-21),
                UpdatedAtUtc = now.AddMinutes(-21)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                FailureCode = "templates.ai_provider_failed",
                FailureMessage = "Provider failed",
                CreatedAtUtc = now.AddMinutes(-12),
                QueuedAtUtc = now.AddMinutes(-12),
                StartedAtUtc = now.AddMinutes(-11),
                CompletedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-4.jpg",
                SourceImageFileName = "source-4.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3)
            });
        await dbContext.SaveChangesAsync();

        var statistics = await service.GetAdminStatisticsAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(statistics.IsSuccess);
        Assert.Equal(created.Value.TemplateId, statistics.Value.TemplateId);
        Assert.Equal(4, statistics.Value.TotalRuns);
        Assert.Equal(1, statistics.Value.QueuedRuns);
        Assert.Equal(0, statistics.Value.ProcessingRuns);
        Assert.Equal(2, statistics.Value.CompletedRuns);
        Assert.Equal(1, statistics.Value.FailedRuns);
        Assert.Equal(50, statistics.Value.SuccessRatePercent);
        Assert.Equal(240, statistics.Value.TotalTokenCost);
        Assert.Equal(60, statistics.Value.AverageTokenCost);
        Assert.Equal(0.3000m, statistics.Value.TotalProviderCostUsd);
        Assert.Equal(0.1500m, statistics.Value.AverageProviderCostUsd);
        Assert.Equal(now.AddMinutes(-3), statistics.Value.LastRunAtUtc);
        Assert.Equal(now.AddMinutes(-21), statistics.Value.LastCompletedAtUtc);
        Assert.Equal(150, statistics.Value.AverageGenerationSeconds);
    }

    [Fact]
    public async Task GetAdminAnalyticsAsync_ShouldReturnTrendRecentRunsAndFailureBreakdown()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Dance",
                "Template with analytics history",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        var failedId = Guid.NewGuid();
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                OutputUrl = "https://cdn.example.com/output-1.mp4",
                UsedPreprocessingModel = "openai/gpt-image-2/edit",
                UsedKlingModel = "fal-ai/kling-video/v3/pro/motion-control",
                MotionProviderCostUsd = 0.2400m,
                CreatedAtUtc = now.AddDays(-1).AddMinutes(-40),
                QueuedAtUtc = now.AddDays(-1).AddMinutes(-40),
                StartedAtUtc = now.AddDays(-1).AddMinutes(-39),
                CompletedAtUtc = now.AddDays(-1).AddMinutes(-36),
                UpdatedAtUtc = now.AddDays(-1).AddMinutes(-36)
            },
            new TemplateGenerationJob
            {
                Id = failedId,
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                AttemptCount = 2,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                FailureCode = "templates.ai_provider_failed",
                FailureMessage = "Provider failed",
                MotionProviderCostUsd = 0.0600m,
                CreatedAtUtc = now.AddMinutes(-8),
                QueuedAtUtc = now.AddMinutes(-8),
                StartedAtUtc = now.AddMinutes(-7),
                CompletedAtUtc = now.AddMinutes(-6),
                UpdatedAtUtc = now.AddMinutes(-6)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = created.Value.TemplateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3)
            });
        await dbContext.SaveChangesAsync();

        var trend = await service.GetAdminTrendAsync(created.Value.TemplateId, CancellationToken.None);
        var recent = await service.GetAdminRecentGenerationsAsync(created.Value.TemplateId, 2, CancellationToken.None);
        var failures = await service.GetAdminFailureBreakdownAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(trend.IsSuccess);
        Assert.Equal(2, trend.Value.Count);
        Assert.Equal(now.AddDays(-1).Date, trend.Value[0].DateUtc);
        Assert.Equal(1, trend.Value[0].CompletedRuns);
        Assert.Equal(0.2400m, trend.Value[0].TotalProviderCostUsd);
        Assert.Equal(now.Date, trend.Value[1].DateUtc);
        Assert.Equal(2, trend.Value[1].TotalRuns);
        Assert.Equal(1, trend.Value[1].QueuedRuns);
        Assert.Equal(1, trend.Value[1].FailedRuns);
        Assert.Equal(0.0600m, trend.Value[1].TotalProviderCostUsd);
        Assert.Equal(0, trend.Value[1].SuccessRatePercent);

        Assert.True(recent.IsSuccess);
        Assert.Equal(2, recent.Value.Count);
        Assert.Equal(TemplateGenerationStatus.Queued.ToString(), recent.Value[0].Status);
        Assert.Equal(failedId, recent.Value[1].GenerationId);
        Assert.Equal(2, recent.Value[1].AttemptCount);

        Assert.True(failures.IsSuccess);
        var failure = Assert.Single(failures.Value);
        Assert.Equal("templates.ai_provider_failed", failure.FailureCode);
        Assert.Equal(1, failure.Count);
        Assert.Equal(now.AddMinutes(-6), failure.LastOccurredAtUtc);
    }

    [Fact]
    public async Task GetAdminEventAnalyticsAsync_ShouldAggregateViewEventDimensions()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Events",
                "Template with tracked public events",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "home", "ios", "us", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "home", "android", "us", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "view", "search", "web", "br", Guid.NewGuid(), null), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "video_view", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid()), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null), CancellationToken.None);

        var analytics = await service.GetAdminEventAnalyticsAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(analytics.IsSuccess);
        Assert.Equal(3, analytics.Value.TotalViews);
        Assert.Equal(1, analytics.Value.TotalVideoViews);
        Assert.Equal(1, analytics.Value.TotalComplaints);

        var home = Assert.Single(analytics.Value.Sources, x => x.Key == "home");
        Assert.Equal(2, home.Count);
        Assert.Equal(66.7, home.SharePercent);

        Assert.Contains(analytics.Value.Devices, x => x.Key == "ios" && x.Count == 1);
        Assert.Contains(analytics.Value.Devices, x => x.Key == "android" && x.Count == 1);
        Assert.Contains(analytics.Value.Geography, x => x.Key == "us" && x.Label == "US" && x.Count == 2);
    }

    [Fact]
    public async Task GetAdminFeedbackAsync_ShouldReturnLatestComplaintAndFeedbackItems()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Feedback Events",
                "Template with user feedback",
                "Dance",
                ["feedback"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null, "Видео зависло на обработке"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid(), "Хочу больше вариантов музыки"), CancellationToken.None);

        var feedback = await service.GetAdminFeedbackAsync(created.Value.TemplateId, new AdminTemplateFeedbackQuery(null, null, 10), CancellationToken.None);

        Assert.True(feedback.IsSuccess);
        Assert.Equal(2, feedback.Value.Count);
        Assert.Contains(feedback.Value, x => x.EventType == "complaint" && x.FeedbackMessage == "Видео зависло на обработке");
        Assert.Contains(feedback.Value, x => x.EventType == "feedback" && x.FeedbackMessage == "Хочу больше вариантов музыки");
    }

    [Fact]
    public async Task GetAdminFeedbackAsync_ShouldFilterByTypeAndSearchMessage()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Feedback Filters",
                "Template with searchable feedback",
                "Dance",
                ["feedback"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "complaint", "profile", "web", "de", Guid.NewGuid(), null, "Видео зависло на обработке"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "ios", "us", Guid.NewGuid(), Guid.NewGuid(), "Хочу больше вариантов музыки"), CancellationToken.None);
        await service.RecordAnalyticsEventAsync(new RecordTemplateAnalyticsEventCommand(created.Value.TemplateId, "feedback", "home", "web", "us", Guid.NewGuid(), Guid.NewGuid(), "Нужен более быстрый рендер"), CancellationToken.None);

        var filtered = await service.GetAdminFeedbackAsync(
            created.Value.TemplateId,
            new AdminTemplateFeedbackQuery("feedback", "музыки", 10),
            CancellationToken.None);

        Assert.True(filtered.IsSuccess);
        var item = Assert.Single(filtered.Value);
        Assert.Equal("feedback", item.EventType);
        Assert.Equal("Хочу больше вариантов музыки", item.FeedbackMessage);
    }

    [Fact]
    public async Task GetAdminTemplatesAnalyticsAsync_ShouldAggregateTemplatesJobsEventsAndCosts()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var video = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Analytics Dance",
                "Template with global analytics",
                "Dance",
                ["analytics"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);
        var image = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Portrait Magic",
                "Image analytics template",
                "Portrait",
                ["analytics"],
                true,
                30,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait.jpg", "portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(video.IsSuccess);
        Assert.True(image.IsSuccess);

        var now = new DateTime(2026, 5, 17, 12, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = video.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-1.jpg",
                SourceImageFileName = "source-1.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                OutputUrl = "https://cdn.example.com/output.mp4",
                MotionProviderCostUsd = 0.5000m,
                CreatedAtUtc = now.AddDays(-1),
                QueuedAtUtc = now.AddDays(-1),
                StartedAtUtc = now.AddDays(-1).AddMinutes(1),
                CompletedAtUtc = now.AddDays(-1).AddMinutes(4),
                UpdatedAtUtc = now.AddDays(-1).AddMinutes(4)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = video.Value.TemplateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 60,
                SourceImageUrl = "https://cdn.example.com/source-2.jpg",
                SourceImageFileName = "source-2.jpg",
                SourceImageContentType = "image/jpeg",
                ReferenceMotionUrl = "https://cdn.example.com/reference.mp4",
                FailureCode = "templates.ai_provider_failed",
                MotionProviderCostUsd = 0.1200m,
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                StartedAtUtc = now.AddMinutes(1),
                CompletedAtUtc = now.AddMinutes(2),
                UpdatedAtUtc = now.AddMinutes(2)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = image.Value.TemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 30,
                SourceImageUrl = "https://cdn.example.com/source-3.jpg",
                SourceImageFileName = "source-3.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                StartedAtUtc = now.AddMinutes(1),
                CompletedAtUtc = now.AddMinutes(2),
                UpdatedAtUtc = now.AddMinutes(2)
            });
        dbContext.TemplateAnalyticsEvents.AddRange(
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "view", Source = "home", DeviceClass = "ios", CountryCode = "US", CreatedAtUtc = now.AddDays(-1) },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "view", Source = "search", DeviceClass = "web", CountryCode = "US", CreatedAtUtc = now },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = image.Value.TemplateId, EventType = "view", Source = "home", DeviceClass = "android", CountryCode = "BR", CreatedAtUtc = now },
            new TemplateAnalyticsEvent { Id = Guid.NewGuid(), TemplateId = video.Value.TemplateId, EventType = "complaint", Source = "profile", DeviceClass = "web", CountryCode = "US", CreatedAtUtc = now });
        await dbContext.SaveChangesAsync();

        var overview = await service.GetAdminTemplatesAnalyticsAsync(new AdminTemplatesAnalyticsQuery(null, null, null, null, null, "views", 10), CancellationToken.None);

        Assert.True(overview.IsSuccess);
        Assert.Equal(2, overview.Value.Summary.TotalTemplates);
        Assert.Equal(1, overview.Value.Summary.VideoTemplates);
        Assert.Equal(1, overview.Value.Summary.ImageTemplates);
        Assert.Equal(3, overview.Value.Summary.TotalViews);
        Assert.Equal(3, overview.Value.Summary.TotalGenerationStarts);
        Assert.Equal(2, overview.Value.Summary.CompletedGenerations);
        Assert.Equal(1, overview.Value.Summary.FailedGenerations);
        Assert.Equal(66.7, overview.Value.Summary.ConversionPercent);
        Assert.Equal(150, overview.Value.Summary.TotalTokenCost);
        Assert.Equal(0.6200m, overview.Value.Summary.TotalProviderCostUsd);
        Assert.Equal(1, overview.Value.Summary.TotalComplaints);
        Assert.Equal(video.Value.TemplateId, overview.Value.TopTemplates[0].TemplateId);
        Assert.Contains(overview.Value.Categories, x => x.Key == "dance" && x.Views == 2 && x.GenerationStarts == 2);
        Assert.Contains(overview.Value.TemplateTypes, x => x.Key == "video" && x.TemplateCount == 1 && x.TotalProviderCostUsd == 0.6200m);
        Assert.Contains(overview.Value.Sources, x => x.Key == "home" && x.Count == 2 && x.SharePercent == 66.7);
        Assert.Contains(overview.Value.Devices, x => x.Key == "ios" && x.Count == 1);
        Assert.Contains(overview.Value.Geography, x => x.Key == "us" && x.Count == 2);
        Assert.Equal(2, overview.Value.TrendPoints.Count);
        Assert.Single(overview.Value.FeedbackItems);
        Assert.Equal("complaint", overview.Value.FeedbackItems[0].EventType);
        Assert.Contains("Dance", overview.Value.AvailableCategories);
        Assert.Contains("Portrait", overview.Value.AvailableCategories);
    }

    [Fact]
    public async Task StartAdminTestAsync_ShouldQueueUnchargedAdminGeneration()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Admin Test Dance",
                "Template for admin test run",
                "Dance",
                ["admin-test"],
                false,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var started = await generationService.StartAdminTestAsync(
            created.Value.TemplateId,
            new TemplateAssetCommand("https://cdn.example.com/admin-source.jpg", "admin-source.jpg", "image/jpeg", 2048, null),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal(created.Value.TemplateId, started.Value.TemplateId);
        Assert.Equal("Queued", started.Value.Status);
        Assert.Equal(60, started.Value.TokenCost);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal(Guid.Empty, persisted.UserId);
        Assert.Null(persisted.ChargedAtUtc);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);

        var fetched = await generationService.GetAdminAsync(started.Value.GenerationId, CancellationToken.None);
        Assert.True(fetched.IsSuccess);
        Assert.Equal(started.Value.GenerationId, fetched.Value.GenerationId);
    }

    [Fact]
    public async Task GenerationHistoryFeedbackAsync_ShouldTrackUnreadAndTypedFeedback()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var userId = Guid.NewGuid();

        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Feedback Portrait",
                "Template for generation feedback",
                "Portrait",
                ["feedback"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/portrait.jpg", "portrait.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "keep pet",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = created.Value.TemplateId,
            Status = TemplateGenerationStatus.Succeeded,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            OutputUrl = "https://cdn.example.com/output.png",
            UsedPreprocessingModel = "openai/gpt-image-2/edit",
            PreprocessingProviderRequestId = "image-request-123",
            AttemptCount = 1,
            CreatedAtUtc = now.AddMinutes(-3),
            QueuedAtUtc = now.AddMinutes(-3),
            StartedAtUtc = now.AddMinutes(-2),
            CompletedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-3)
        };

        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var history = await generationService.ListAsync(userId, new TemplateGenerationHistoryQuery("ready", null, 10), CancellationToken.None);

        Assert.True(history.IsSuccess);
        var item = Assert.Single(history.Value);
        Assert.Equal(job.Id, item.GenerationId);
        Assert.Equal("Succeeded", item.Status);
        Assert.Equal("succeeded", item.Stage);
        Assert.Equal(100, item.ProgressPercent);
        Assert.True(item.IsUnread);
        Assert.Equal("Feedback Portrait", item.TemplateTitle);

        var unread = await generationService.GetUnreadCountAsync(userId, CancellationToken.None);
        Assert.True(unread.IsSuccess);
        Assert.Equal(1, unread.Value.Count);

        var markedRead = await generationService.MarkReadAsync(userId, job.Id, CancellationToken.None);
        Assert.True(markedRead.IsSuccess);

        var unreadAfterRead = await generationService.GetUnreadCountAsync(userId, CancellationToken.None);
        Assert.True(unreadAfterRead.IsSuccess);
        Assert.Equal(0, unreadAfterRead.Value.Count);

        var feedback = await generationService.RecordFeedbackAsync(
            new RecordTemplateGenerationFeedbackCommand(
                userId,
                job.Id,
                1,
                ["face_distorted", "style_mismatch"],
                "The result differs from preview.",
                0.72),
            CancellationToken.None);

        Assert.True(feedback.IsSuccess);
        var persistedFeedback = await dbContext.TemplateGenerationFeedback.SingleAsync();
        Assert.Equal(job.Id, persistedFeedback.GenerationId);
        Assert.Equal(created.Value.TemplateId, persistedFeedback.TemplateId);
        Assert.Equal(1, persistedFeedback.Rating);
        Assert.Contains("face_distorted", persistedFeedback.SelectedReasons);
        Assert.Equal("The result differs from preview.", persistedFeedback.Comment);
        Assert.Equal("openai/gpt-image-2/edit", persistedFeedback.ModelUsed);
        Assert.Equal("image-request-123", persistedFeedback.ProviderRequestId);
        Assert.NotNull(persistedFeedback.GenerationDurationSeconds);
    }

    [Fact]
    public async Task CreateVideoAsync_ShouldResolveNewBadgeInAutoMode_ForFreshTemplates()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Fresh Clip",
                "Fresh template",
                "Dance",
                ["fresh"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/standard/motion-control",
                "clean motion",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        Assert.Equal(TemplatePromoBadgeMode.Auto.ToString(), created.Value.PromoBadgeMode);
        Assert.Equal(TemplatePromoBadgeMode.New.ToString(), created.Value.EffectivePromoBadge);
    }

    [Fact]
    public async Task CreateVideoAsync_ShouldKeepManualPromoBadge_WhenManualModeIsSelected()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Fresh Clip",
                "Fresh template",
                "Dance",
                ["fresh"],
                false,
                20,
                TemplatePromoBadgeMode.Funny.ToString(),
                string.Empty,
                CreatePreviewAsset(),
                CreateReferenceAsset(12.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/standard/motion-control",
                "clean motion",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        Assert.Equal(TemplatePromoBadgeMode.Funny.ToString(), created.Value.PromoBadgeMode);
        Assert.Equal(TemplatePromoBadgeMode.Funny.ToString(), created.Value.EffectivePromoBadge);
    }

    [Fact]
    public async Task CreateVideoAsync_ShouldClaimTemporaryMediaRecords_WhenTemplateIsPersisted()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var now = DateTime.UtcNow;
        var preview = CreatePreviewAsset("https://cdn.example.com/templates/preview.mp4", "preview.mp4", "video/mp4");
        var reference = CreateReferenceAsset(8.5, "https://cdn.example.com/templates/reference.mp4");

        dbContext.TemplateMediaRecords.AddRange(
            new PetMagic.Modules.Templates.Infrastructure.Entities.TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                Url = preview.Url,
                FileName = preview.FileName,
                ContentType = preview.ContentType,
                FileSizeBytes = preview.FileSizeBytes,
                Role = TemplateMediaRole.PreviewAsset,
                LifecycleState = TemplateMediaLifecycleState.Temporary,
                UploadedAtUtc = now,
                ExpiresAtUtc = now.AddHours(1)
            },
            new PetMagic.Modules.Templates.Infrastructure.Entities.TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                Url = reference.Url,
                FileName = reference.FileName,
                ContentType = reference.ContentType,
                FileSizeBytes = reference.FileSizeBytes,
                Role = TemplateMediaRole.ReferenceMotionAsset,
                LifecycleState = TemplateMediaLifecycleState.Temporary,
                UploadedAtUtc = now,
                ExpiresAtUtc = now.AddHours(1)
            });
        await dbContext.SaveChangesAsync();

        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Claimed Dance",
                "Temporary assets should become attached",
                "Dance",
                ["claim"],
                false,
                30,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                preview,
                reference,
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "dance",
                true),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var previewRecord = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Url == preview.Url);
        var referenceRecord = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Url == reference.Url);
        Assert.Equal(TemplateMediaLifecycleState.AttachedToTemplate, previewRecord.LifecycleState);
        Assert.Equal(created.Value.TemplateId, previewRecord.TemplateId);
        Assert.Null(previewRecord.ExpiresAtUtc);
        Assert.Equal(TemplateMediaLifecycleState.AttachedToTemplate, referenceRecord.LifecycleState);
        Assert.Equal(created.Value.TemplateId, referenceRecord.TemplateId);
        Assert.Null(referenceRecord.ExpiresAtUtc);
    }

    private static TemplatesService CreateService(
        TemplatesDbContext dbContext,
        IMediaStorage? mediaStorage = null,
        ITemplateFeedRealtimeService? realtimeService = null)
    {
        var options = new TemplatesOptions
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
            SeedSampleTemplates = false
        };

        IMediaMetadataReader metadataReader = new TestMediaMetadataReader();
        ITemplateMediaLifecycleService lifecycleService = new TemplateMediaLifecycleService(dbContext, options);
        return new TemplatesService(
            dbContext,
            options,
            metadataReader,
            mediaStorage ?? new RecordingMediaStorage(),
            lifecycleService,
            realtimeService ?? new RecordingTemplateFeedRealtimeService());
    }

    private static async Task<Guid> CreateActiveImageTemplateAsync(ITemplatesService service, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset($"https://cdn.example.com/{slug}.jpg", $"{slug}.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        return created.Value.TemplateId;
    }

    private static async Task SetUpdatedAtUtcAsync(TemplatesDbContext dbContext, Guid templateId, DateTime updatedAtUtc)
    {
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        template.UpdatedAtUtc = updatedAtUtc;
        await dbContext.SaveChangesAsync();
    }

    private static TemplateGenerationService CreateGenerationService(TemplatesDbContext dbContext)
    {
        return new TemplateGenerationService(dbContext, new PassiveGenerationBilling());
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"templates-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private sealed class RecordingTemplateFeedRealtimeService : ITemplateFeedRealtimeService
    {
        public int InvalidatedCount { get; private set; }

        public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
        {
            var channel = Channel.CreateUnbounded<TemplateFeedRealtimeEvent>();
            return channel.Reader;
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
        {
            InvalidatedCount++;
            return ValueTask.CompletedTask;
        }

        public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
        {
            return ValueTask.CompletedTask;
        }
    }

    private static TemplateAssetCommand CreatePreviewAsset(
        string url = "https://cdn.example.com/preview.mp4",
        string fileName = "preview.mp4",
        string contentType = "video/mp4")
    {
        return new TemplateAssetCommand(url, fileName, contentType, 2048, 5.0);
    }

    private static TemplateAssetCommand CreateReferenceAsset(double? durationSeconds, string url = "https://cdn.example.com/reference.mp4")
    {
        return new TemplateAssetCommand(
            url,
            "reference.mp4",
            "video/mp4",
            4096,
            durationSeconds);
    }

    private sealed class RecordingMediaStorage : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];

        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(
                new StoredMediaResponse($"http://localhost:5000/stub/{asset.FileName}", $"stub/{asset.FileName}", asset.FileName, asset.ContentType, asset.Content.LongLength, null)));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }
    }

    private sealed class TestMediaMetadataReader : IMediaMetadataReader
    {
        public Task<PetMagic.BuildingBlocks.Results.Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success<double?>(null));
        }
    }

    private sealed class FailingDeleteMediaStorage : IMediaStorage
    {
        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(
                new StoredMediaResponse($"http://localhost:5000/stub/{asset.FileName}", $"stub/{asset.FileName}", asset.FileName, asset.ContentType, asset.Content.LongLength, null)));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Failure(TemplatesErrors.MediaStorageFailed));
        }
    }

    private sealed class PassiveGenerationBilling : ITemplateGenerationBilling
    {
        public Task<PetMagic.BuildingBlocks.Results.Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }
    }
}
