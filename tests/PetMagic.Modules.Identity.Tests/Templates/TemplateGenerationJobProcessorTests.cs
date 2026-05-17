using System.Collections.Concurrent;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationJobProcessorTests
{
    [Fact]
    public async Task RetryNextRefundAsync_ShouldRetryPendingRefundAndPersistSuccess()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Failed, now.AddMinutes(-10));
        job.RefundAttemptCount = 1;
        job.RefundLastErrorCode = "economy.unavailable";
        job.RefundLastAttemptedAtUtc = now.AddMinutes(-5);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var billing = new TestTemplateGenerationBilling();
        var processor = CreateProcessor(dbContext, billing: billing, options: CreateOptions(refundRetryDelayMilliseconds: 0));

        var processed = await processor.RetryNextRefundAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.NotNull(persisted.RefundedAtUtc);
        Assert.Equal(2, persisted.RefundAttemptCount);
        Assert.Null(persisted.RefundLastErrorCode);
        Assert.Contains(job.Id, billing.RefundedGenerationIds);
    }

    [Fact]
    public async Task CleanupNextExpiredGenerationAsync_ShouldRemoveJob_WhenUserMediaWasAlreadyDeleted()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Completed, DateTime.UtcNow.AddDays(-10));
        job.SourceImageUrl = "http://localhost:5000/templates-media/source.jpg";
        job.NormalizedImageUrl = "http://localhost:5000/templates-media/normalized.jpg";
        job.ReferenceMotionUrl = "http://localhost:5000/templates-media/reference.mp4";
        job.OutputUrl = "http://localhost:5000/templates-media/output.mp4";
        job.UserMediaDeletedAtUtc = DateTime.UtcNow.AddDays(-2);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(dbContext, mediaStorage: mediaStorage, options: CreateOptions(retentionDays: 7));

        var processed = await processor.CleanupNextExpiredGenerationAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.False(await dbContext.TemplateGenerationJobs.AnyAsync(x => x.Id == job.Id));
        Assert.Empty(mediaStorage.DeletedUrls);
    }

    [Fact]
    public async Task CleanupNextExpiredGenerationAsync_ShouldKeepFailedChargedJobPendingRefund()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Failed, DateTime.UtcNow.AddDays(-10));
        job.UserMediaDeletedAtUtc = DateTime.UtcNow.AddDays(-2);
        job.RefundAttemptCount = 3;
        job.RefundLastErrorCode = "economy.unavailable";
        job.RefundLastAttemptedAtUtc = DateTime.UtcNow.AddDays(-9);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(dbContext, mediaStorage: mediaStorage, options: CreateOptions(retentionDays: 7));

        var processed = await processor.CleanupNextExpiredGenerationAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Null(persisted.RefundedAtUtc);
        Assert.Empty(mediaStorage.DeletedUrls);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldProcessAdminTestJobAndPersistStageDiagnostics()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var referenceMotion = template.Assets.Single(x => x.AssetKind == TemplateAssetKind.ReferenceMotion);
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = TemplateGenerationService.AdminTestUserId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            ReferenceMotionUrl = referenceMotion.Url,
            CreatedAtUtc = now.AddMinutes(-1),
            QueuedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var imagePreprocessor = new TrackingImagePreprocessor();
        var videoMotionGenerator = new TrackingVideoMotionGenerator();
        var generatedMediaImporter = new TrackingGeneratedMediaImporter();
        var billing = new TestTemplateGenerationBilling();
        var processor = CreateProcessor(
            dbContext,
            billing: billing,
            imagePreprocessor: imagePreprocessor,
            videoMotionGenerator: videoMotionGenerator,
            generatedMediaImporter: generatedMediaImporter);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal(1, persisted.AttemptCount);
        Assert.NotNull(persisted.StartedAtUtc);
        Assert.NotNull(persisted.PreprocessingCompletedAtUtc);
        Assert.NotNull(persisted.MotionGenerationCompletedAtUtc);
        Assert.NotNull(persisted.MediaImportCompletedAtUtc);
        Assert.NotNull(persisted.CompletedAtUtc);
        Assert.True(persisted.StartedAtUtc <= persisted.PreprocessingCompletedAtUtc);
        Assert.True(persisted.PreprocessingCompletedAtUtc <= persisted.MotionGenerationCompletedAtUtc);
        Assert.True(persisted.MotionGenerationCompletedAtUtc <= persisted.MediaImportCompletedAtUtc);
        Assert.True(persisted.MediaImportCompletedAtUtc <= persisted.CompletedAtUtc);
        Assert.Equal(template.PreprocessingModel, persisted.UsedPreprocessingModel);
        Assert.Equal(template.KlingModel, persisted.UsedKlingModel);
        Assert.Equal("preprocess-request-1", persisted.PreprocessingProviderRequestId);
        Assert.Equal(1.25, persisted.PreprocessingInferenceTimeSeconds);
        Assert.Equal("motion-request-1", persisted.MotionProviderRequestId);
        Assert.Equal(8.4, persisted.MotionInferenceTimeSeconds);
        Assert.Equal(7.5, persisted.OutputVideoDurationSeconds);
        Assert.Equal(1.2600m, persisted.MotionProviderCostUsd);
        Assert.Equal(template.PreprocessingModel, imagePreprocessor.Model);
        Assert.Equal(template.KlingModel, videoMotionGenerator.Model);
        Assert.Equal("https://fal.example.test/generated.mp4", generatedMediaImporter.GeneratedVideoUrl);
        Assert.Empty(billing.RefundedGenerationIds);
        Assert.Null(persisted.ChargedAtUtc);
        Assert.Null(persisted.RefundedAtUtc);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"template-generation-processor-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static TemplateGenerationJobProcessor CreateProcessor(
        TemplatesDbContext dbContext,
        IMediaStorage? mediaStorage = null,
        ITemplateGenerationBilling? billing = null,
        IImagePreprocessor? imagePreprocessor = null,
        IVideoMotionGenerator? videoMotionGenerator = null,
        IGeneratedMediaImporter? generatedMediaImporter = null,
        IMediaMetadataReader? mediaMetadataReader = null,
        TemplatesOptions? options = null)
    {
        return new TemplateGenerationJobProcessor(
            dbContext,
            imagePreprocessor ?? new NoopImagePreprocessor(),
            videoMotionGenerator ?? new NoopVideoMotionGenerator(),
            generatedMediaImporter ?? new NoopGeneratedMediaImporter(),
            mediaMetadataReader ?? new FixedDurationMetadataReader(),
            billing ?? new TestTemplateGenerationBilling(),
            options ?? CreateOptions(),
            NullLogger<TemplateGenerationJobProcessor>.Instance);
    }

    private static TemplatesOptions CreateOptions(int refundRetryDelayMilliseconds = 30_000, int retentionDays = 7)
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            MaxGenerationAttempts = 3,
            MaxRefundAttempts = 3,
            RefundRetryDelayMilliseconds = refundRetryDelayMilliseconds,
            GenerationRetentionDaysAfterCompletion = retentionDays
        };
    }

    private static TemplateItem CreateReadyTemplate()
    {
        var templateId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        return new TemplateItem
        {
            Id = templateId,
            TemplateType = TemplateType.Video,
            Title = "Processor Test Template",
            ShortDescription = "Ready video template",
            Category = "Tests",
            Tags = "processor",
            IsPremium = true,
            TokenCost = 25,
            Status = TemplateStatus.Active,
            ReferenceVideoDurationSeconds = 8,
            CharacterOrientation = CharacterOrientation.Video,
            PreprocessingModel = "openai/gpt-image-2/edit",
            KlingModel = "fal-ai/kling-video/v3/pro/motion-control",
            KeepOriginalSound = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            Assets =
            [
                new TemplateAsset
                {
                    Id = Guid.NewGuid(),
                    TemplateId = templateId,
                    AssetKind = TemplateAssetKind.Preview,
                    Url = "http://localhost:5000/templates-media/preview.mp4",
                    FileName = "preview.mp4",
                    ContentType = "video/mp4",
                    DurationSeconds = 8
                },
                new TemplateAsset
                {
                    Id = Guid.NewGuid(),
                    TemplateId = templateId,
                    AssetKind = TemplateAssetKind.ReferenceMotion,
                    Url = "http://localhost:5000/templates-media/reference.mp4",
                    FileName = "reference.mp4",
                    ContentType = "video/mp4",
                    DurationSeconds = 8
                }
            ]
        };
    }

    private static TemplateGenerationJob CreateGenerationJob(TemplateItem template, TemplateGenerationStatus status, DateTime completedAtUtc)
    {
        var now = DateTime.UtcNow;
        return new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = template.Id,
            Status = status,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            AttemptCount = 1,
            CreatedAtUtc = now.AddMinutes(-20),
            QueuedAtUtc = now.AddMinutes(-20),
            UpdatedAtUtc = completedAtUtc,
            ChargedAtUtc = now.AddMinutes(-20),
            CompletedAtUtc = completedAtUtc
        };
    }

    private sealed class NoopImagePreprocessor : IImagePreprocessor
    {
        public Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImagePreprocessResult(originalImageUrl, null, null)));
        }
    }

    private sealed class TrackingImagePreprocessor : IImagePreprocessor
    {
        public string? Model { get; private set; }

        public Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
        {
            Model = model;
            return Task.FromResult(Result.Success(new ImagePreprocessResult(
                "http://localhost:5000/templates-media/normalized.jpg",
                "preprocess-request-1",
                1.25)));
        }
    }

    private sealed class NoopVideoMotionGenerator : IVideoMotionGenerator
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
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult("https://fal.example.test/generated.mp4", null, null)));
        }
    }

    private sealed class TrackingVideoMotionGenerator : IVideoMotionGenerator
    {
        public string? Model { get; private set; }

        public Task<Result<VideoMotionGenerationResult>> CreateAsync(
            string normalizedImageUrl,
            string referenceVideoUrl,
            string characterOrientation,
            bool keepOriginalSound,
            string prompt,
            string model,
            CancellationToken cancellationToken)
        {
            Model = model;
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated.mp4",
                "motion-request-1",
                8.4)));
        }
    }

    private sealed class FixedDurationMetadataReader : IMediaMetadataReader
    {
        public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<double?>(7.5));
        }
    }

    private sealed class NoopGeneratedMediaImporter : IGeneratedMediaImporter
    {
        public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                "http://localhost:5000/templates-media/output.mp4",
                "templates-media/output.mp4",
                "output.mp4",
                "video/mp4",
                1024,
                null)));
        }
    }

    private sealed class TrackingGeneratedMediaImporter : IGeneratedMediaImporter
    {
        public string? GeneratedVideoUrl { get; private set; }

        public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            GeneratedVideoUrl = generatedVideoUrl;
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                "http://localhost:5000/templates-media/output.mp4",
                "templates-media/output.mp4",
                "output.mp4",
                "video/mp4",
                1024,
                null)));
        }
    }

    private sealed class TrackingMediaStorage : IMediaStorage
    {
        public ConcurrentBag<string> DeletedUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                $"http://localhost:5000/templates-media/{asset.FileName}",
                $"templates-media/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                asset.Content.LongLength,
                null)));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(Result.Success());
        }
    }

    private sealed class TestTemplateGenerationBilling : ITemplateGenerationBilling
    {
        public ConcurrentBag<Guid> RefundedGenerationIds { get; } = [];

        public Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            RefundedGenerationIds.Add(generationId);
            return Task.FromResult(Result.Success());
        }
    }
}
