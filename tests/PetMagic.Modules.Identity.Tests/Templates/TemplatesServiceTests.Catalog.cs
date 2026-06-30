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
    public async Task UpdateImageAsync_ShouldRetryPreviewChange_WhenFirstSaveHitsConcurrency()
    {
        var concurrency = new OneShotConcurrencyInterceptor();
        await using var dbContext = CreateDbContext(concurrency);
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

        concurrency.Enabled = true;

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
        Assert.Equal(1, concurrency.ThrowCount);
        Assert.Equal("http://localhost:5000/templates-media/2026/05/new-preview.jpg", updated.Value.PreviewAsset?.Url);
        Assert.Single(storage.DeletedUrls);
        Assert.Equal("http://localhost:5000/templates-media/2026/05/old-preview.jpg", storage.DeletedUrls[0]);
    }

    [Fact]
    public async Task UpdateImageAsync_ShouldPreserveBoundaryLengthFields_WhenPreviewChanges()
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
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/old-preview.jpg", "old-preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var promptAtLimit = new string('p', 1000);
        var requirementAtLimit = new string('r', 160);
        var tagAtLimit = new string('t', 32);
        var updated = await service.UpdateImageAsync(
            new UpdateImageTemplateCommand(
                created.Value.TemplateId,
                "Portrait",
                "Cozy portrait",
                "Portrait",
                [tagAtLimit],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/new-preview.jpg", "new-preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                promptAtLimit,
                TemplateStatus.Draft.ToString(),
                [requirementAtLimit]),
            CancellationToken.None);

        Assert.True(updated.IsSuccess);
        var persisted = await dbContext.TemplateItems.SingleAsync(x => x.Id == created.Value.TemplateId);
        Assert.Equal(promptAtLimit, persisted.ImagePrompt);
        Assert.Equal(requirementAtLimit, updated.Value.PetPhotoRequirements!.Single());
        Assert.Equal(tagAtLimit, updated.Value.Tags.Single());
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
        var unknownCategory = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(1, 20, null, "missing", null, ["canonical"]),
            CancellationToken.None);

        Assert.True(catalog.IsSuccess);
        Assert.True(feed.IsSuccess);
        Assert.True(unknownCategory.IsSuccess);

        var catalogItem = Assert.Single(catalog.Value.Items);
        Assert.Equal(portraitTemplateId, catalogItem.Id);
        Assert.Equal("Portrait", catalogItem.Category);

        var feedItem = Assert.Single(feed.Value.Items);
        Assert.Equal(portraitTemplateId, feedItem.TemplateId);
        Assert.Equal("Portrait", feedItem.Category);

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
