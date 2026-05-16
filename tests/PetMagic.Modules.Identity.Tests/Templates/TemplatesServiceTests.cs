using Microsoft.EntityFrameworkCore;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
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
                CreatePreviewAsset("https://cdn.example.com/portrait.jpg", "portrait.jpg", "image/jpeg")),
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
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/old-preview.jpg", "old-preview.jpg", "image/jpeg")),
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
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/new-preview.jpg", "new-preview.jpg", "image/jpeg")),
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
                preview),
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
                preview),
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
                CreatePreviewAsset("http://localhost:5000/templates-media/2026/05/preview.jpg", "preview.jpg", "image/jpeg")),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var deleted = await service.DeleteAsync(created.Value.TemplateId, CancellationToken.None);

        Assert.True(deleted.IsFailure);
        Assert.Equal("templates.media_storage_failed", deleted.Error.Code);
        Assert.True(await dbContext.TemplateItems.AnyAsync(x => x.Id == created.Value.TemplateId));
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

    private static TemplatesService CreateService(TemplatesDbContext dbContext, IMediaStorage? mediaStorage = null)
    {
        var options = new TemplatesOptions
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
            SeedSampleTemplates = false
        };

        IMediaMetadataReader metadataReader = new TestMediaMetadataReader();
        ITemplateMediaLifecycleService lifecycleService = new TemplateMediaLifecycleService(dbContext, options);
        return new TemplatesService(dbContext, options, metadataReader, mediaStorage ?? new RecordingMediaStorage(), lifecycleService);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"templates-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
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
}
