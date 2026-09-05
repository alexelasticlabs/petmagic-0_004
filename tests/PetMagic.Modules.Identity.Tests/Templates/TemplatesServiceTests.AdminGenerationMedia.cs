using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Theory]
    [InlineData(false, false, false)]
    [InlineData(true, false, false)]
    [InlineData(true, true, false)]
    [InlineData(false, false, true)]
    public async Task GetAdminGenerationAsync_ShouldResolveLegacyVideoAndRespectWatermarkAndDeletion(
        bool watermarkRequired, bool watermarkRemoved, bool deleted)
    {
        await using var dbContext = CreateDbContext();
        var storage = new RecordingMediaStorage(signReadUrls: true);
        var service = CreateService(dbContext, storage);
        var templateId = await CreateActiveImageTemplateAsync(service, "Media history", "Portrait", ["media-history"]);
        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var inputId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = templateId,
            Status = TemplateGenerationStatus.Completed,
            SourceImageUrl = "templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            InputMediaAssetId = inputId,
            // Legacy jobs can have result media linked only by GenerationId.
            ResultMediaAssetId = null,
            IsWatermarkRequired = watermarkRequired,
            IsWatermarkRemoved = watermarkRemoved,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            CompletedAtUtc = now
        });
        dbContext.TemplateMediaRecords.Add(CreateGenerationMediaRecord(
            inputId, userId, generationId, "user_upload", "templates-media/source.jpg", "templates-media/source.webp", now));
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            GenerationId = generationId,
            MediaType = "video",
            SourceType = "generation_result",
            Url = "templates-media/result.mp4",
            PreviewUrl = "templates-media/result.webp",
            WatermarkedStoragePath = "templates-media/marked.mp4",
            WatermarkedPreviewUrl = "templates-media/marked.webp",
            FileName = "result.mp4",
            ContentType = "video/mp4",
            UploadedAtUtc = now,
            IsDeleted = deleted
        });
        await dbContext.SaveChangesAsync();

        var result = await service.GetAdminGenerationAsync(generationId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = result.Value.Generation;
        Assert.Equal(!deleted, item.CanCompareBeforeAfter);
        if (deleted)
        {
            Assert.Null(item.ResultMediaUrl);
            Assert.Null(item.ResultPreviewUrl);
            return;
        }
        var name = watermarkRequired && !watermarkRemoved ? "marked" : "result";
        Assert.Equal("video", item.ResultMediaType);
        Assert.Equal($"templates-media/{name}.mp4?signed=1", item.ResultMediaUrl);
        Assert.Equal($"templates-media/{name}.webp?signed=1", item.ResultPreviewUrl);
        if (watermarkRequired && !watermarkRemoved)
        {
            Assert.DoesNotContain("templates-media/result.mp4", storage.ReadUrls);
        }
    }
}
