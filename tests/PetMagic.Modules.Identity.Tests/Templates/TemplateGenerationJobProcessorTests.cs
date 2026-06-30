using System.Collections.Concurrent;
using System.Reflection;
using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;
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
        job.ResultUrl = "http://localhost:5000/templates-media/output.mp4";
        job.UserMediaDeletedAtUtc = DateTime.UtcNow.AddDays(-2);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(dbContext, options: CreateOptions(retentionDays: 7));

        var processed = await processor.CleanupNextExpiredGenerationAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.False(await dbContext.TemplateGenerationJobs.AnyAsync(x => x.Id == job.Id));
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

        var processor = CreateProcessor(dbContext, options: CreateOptions(retentionDays: 7));

        var processed = await processor.CleanupNextExpiredGenerationAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Null(persisted.RefundedAtUtc);
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

    [Fact]
    public async Task ProcessNextAsync_ShouldKeepPersistedStatusProcessingAcrossVideoStageTransitions()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var referenceMotion = template.Assets.Single(x => x.AssetKind == TemplateAssetKind.ReferenceMotion);
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
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
            ChargedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var recorder = new ProcessingStatusRecorder(dbContext, job.Id);
        var processor = CreateProcessor(
            dbContext,
            imagePreprocessor: new SnapshotImagePreprocessor(recorder),
            videoMotionGenerator: new SnapshotVideoMotionGenerator(recorder),
            generatedMediaImporter: new SnapshotGeneratedMediaImporter(recorder));

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        var snapshots = recorder.Snapshots.ToArray();
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal(3, snapshots.Length);
        Assert.All(snapshots, snapshot => Assert.Equal(TemplateGenerationStatus.Processing, snapshot.Status));
        Assert.Contains(snapshots, snapshot => snapshot.Label == "preprocessing" && snapshot.Stage == "preprocessing" && snapshot.PreprocessingCompletedAtUtc is null);
        Assert.Contains(snapshots, snapshot => snapshot.Label == "generating" && snapshot.Stage == "generating" && snapshot.PreprocessingCompletedAtUtc is not null && snapshot.MotionGenerationCompletedAtUtc is null);
        Assert.Contains(snapshots, snapshot => snapshot.Label == "finalizing" && snapshot.Stage == "finalizing" && snapshot.MotionGenerationCompletedAtUtc is not null && snapshot.MediaImportCompletedAtUtc is null);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldProcessImageJobAndPersistImportedImage()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            CreatedAtUtc = now.AddMinutes(-1),
            QueuedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var imageGenerator = new TrackingImageGenerator();
        var generatedMediaImporter = new TrackingGeneratedMediaImporter();
        var processor = CreateProcessor(
            dbContext,
            imageGenerator: imageGenerator,
            generatedMediaImporter: generatedMediaImporter);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal(1, persisted.AttemptCount);
        Assert.NotNull(persisted.StartedAtUtc);
        Assert.NotNull(persisted.PreprocessingCompletedAtUtc);
        Assert.NotNull(persisted.MediaImportCompletedAtUtc);
        Assert.NotNull(persisted.CompletedAtUtc);
        Assert.Equal(template.ImageModel, persisted.UsedPreprocessingModel);
        Assert.Null(persisted.UsedKlingModel);
        Assert.Equal("image-request-1", persisted.PreprocessingProviderRequestId);
        Assert.Equal(2.8, persisted.PreprocessingInferenceTimeSeconds);
        Assert.Null(persisted.MotionProviderRequestId);
        Assert.Null(persisted.MotionInferenceTimeSeconds);
        Assert.Null(persisted.OutputVideoDurationSeconds);
        Assert.Equal(0.219m, persisted.MotionProviderCostUsd);
        Assert.Equal(template.ImageModel, imageGenerator.Model);
        Assert.Equal("https://fal.example.test/generated-image.png", generatedMediaImporter.GeneratedImageUrl);
        Assert.Equal("templates-media/output.png", persisted.ResultUrl);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldUseCleanGenerationResultAsset_WhenInputMediaAssetIdIsSet()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        var inputMediaAssetId = Guid.NewGuid();
        var parentGenerationId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/watermarked-parent.jpg",
            SourceImageFileName = "parent.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            InputSourceType = "generation_result",
            InputMediaAssetId = inputMediaAssetId,
            ParentGenerationId = parentGenerationId,
            ParentGenerationResultId = parentGenerationId,
            CreatedAtUtc = now.AddMinutes(-1),
            QueuedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = inputMediaAssetId,
            UserId = userId,
            MediaType = "image",
            StoragePath = "r2://templates/clean-parent.jpg",
            WatermarkedStoragePath = "r2://templates/watermarked-parent.jpg",
            SourceType = "generation_result",
            GenerationId = parentGenerationId,
            Url = "http://localhost:5000/templates-media/clean-parent.jpg",
            FileName = "clean-parent.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 1024,
            Role = TemplateMediaRole.GenerationOutputImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now.AddMinutes(-2),
            AttachedAtUtc = now.AddMinutes(-2)
        });
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var imageGenerator = new TrackingImageGenerator();
        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(
            dbContext,
            imageGenerator: imageGenerator,
            mediaStorage: mediaStorage);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal("signed:r2://templates/clean-parent.jpg", imageGenerator.SourceImageUrl);
        Assert.Contains("r2://templates/clean-parent.jpg", mediaStorage.ReadUrls);
        Assert.DoesNotContain("r2://templates/watermarked-parent.jpg", mediaStorage.ReadUrls);
        Assert.DoesNotContain("http://localhost:5000/templates-media/watermarked-parent.jpg", mediaStorage.ReadUrls);
    }

    [Fact]
    public async Task NotifyGamificationAsync_ShouldForwardTemplateOfTheDayAndPremiumFlags()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PetId = petId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            CreatedAtUtc = now.AddMinutes(-1),
            QueuedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-1),
            CompletedAtUtc = now,
            UpdatedAtUtc = now.AddMinutes(-1)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateOfTheDay.Add(new TemplateOfTheDay
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            StartDate = DateOnly.FromDateTime(job.CreatedAtUtc),
            EndDate = null,
            IsActive = true,
            IsManual = true,
            Priority = 100,
            CreatedAtUtc = now.AddDays(-1),
            UpdatedAtUtc = now.AddDays(-1)
        });
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var gamification = new RecordingGamificationService();
        var processor = CreateProcessor(
            dbContext,
            gamificationService: gamification,
            economyService: PremiumEconomyServiceProxy.Create(isPremium: true));

        var notifyMethod = typeof(TemplateGenerationJobProcessor)
            .GetMethod("NotifyGamificationAsync", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(notifyMethod);
        var task = Assert.IsAssignableFrom<Task>(notifyMethod!.Invoke(processor, [job, CancellationToken.None]));
        await task;

        var notification = Assert.Single(gamification.CompletedGenerations);
        Assert.Equal(userId, notification.UserId);
        Assert.Equal(petId, notification.PetId);
        Assert.Equal(template.Id, notification.TemplateId);
        Assert.True(notification.IsTemplateOfTheDay);
        Assert.True(notification.IsPremium);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRestoreJobCorrelationId_ForProviderCalls()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now.AddMinutes(-1));
        job.CorrelationId = "worker-job-correlation";

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var imageGenerator = new CorrelationCapturingImageGenerator();
        var processor = CreateProcessor(dbContext, imageGenerator: imageGenerator);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal("worker-job-correlation", imageGenerator.CorrelationId);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRecoverStaleProcessingJob_AndRetryIt()
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
            Status = TemplateGenerationStatus.Processing,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            ReferenceMotionUrl = referenceMotion.Url,
            AttemptCount = 1,
            CreatedAtUtc = now.AddMinutes(-25),
            QueuedAtUtc = now.AddMinutes(-25),
            LastAttemptAtUtc = now.AddMinutes(-20),
            StartedAtUtc = now.AddMinutes(-20),
            LockedAtUtc = now.AddMinutes(-20),
            LockedBy = "stale-worker",
            UpdatedAtUtc = now.AddMinutes(-20),
            NormalizedImageUrl = "http://localhost:5000/templates-media/stale-normalized.jpg",
            PreprocessingCompletedAtUtc = now.AddMinutes(-19),
            UsedPreprocessingModel = "stale-model"
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var imagePreprocessor = new TrackingImagePreprocessor();
        var videoMotionGenerator = new TrackingVideoMotionGenerator();
        var generatedMediaImporter = new TrackingGeneratedMediaImporter();
        var processor = CreateProcessor(
            dbContext,
            imagePreprocessor: imagePreprocessor,
            videoMotionGenerator: videoMotionGenerator,
            generatedMediaImporter: generatedMediaImporter,
            options: CreateOptions(staleProcessingRecoveryDelayMilliseconds: 0));

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.NotNull(persisted.StartedAtUtc);
        Assert.Equal(now.AddMinutes(-20), persisted.StartedAtUtc);
        Assert.Equal(template.PreprocessingModel, persisted.UsedPreprocessingModel);
        Assert.NotNull(persisted.PreprocessingCompletedAtUtc);
        Assert.NotNull(persisted.CompletedAtUtc);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldFailStaleProcessingJob_WhenAttemptsAreExhausted()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Processing,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            AttemptCount = 3,
            CreatedAtUtc = now.AddMinutes(-30),
            QueuedAtUtc = now.AddMinutes(-30),
            LastAttemptAtUtc = now.AddMinutes(-20),
            StartedAtUtc = now.AddMinutes(-20),
            LockedAtUtc = now.AddMinutes(-20),
            LockedBy = "stale-worker",
            UpdatedAtUtc = now.AddMinutes(-20),
            ChargedAtUtc = now.AddMinutes(-30)
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var billing = new TestTemplateGenerationBilling();
        var processor = CreateProcessor(
            dbContext,
            billing: billing,
            options: CreateOptions(staleProcessingRecoveryDelayMilliseconds: 0));

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Equal(TemplatesErrors.GenerationAttemptsExceeded.Code, persisted.LastErrorCode);
        Assert.NotNull(persisted.CompletedAtUtc);
        Assert.NotNull(persisted.RefundedAtUtc);
        Assert.Contains(job.Id, billing.RefundedGenerationIds);
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
        ITemplateGenerationBilling? billing = null,
        IImagePreprocessor? imagePreprocessor = null,
        IImageGenerator? imageGenerator = null,
        IVideoMotionGenerator? videoMotionGenerator = null,
        IGeneratedMediaImporter? generatedMediaImporter = null,
        IMediaMetadataReader? mediaMetadataReader = null,
        IMediaStorage? mediaStorage = null,
        TemplatesOptions? options = null,
        IGamificationService? gamificationService = null,
        IEconomyService? economyService = null)
    {
        return new TemplateGenerationJobProcessor(
            dbContext,
            imagePreprocessor ?? new NoopImagePreprocessor(),
            imageGenerator ?? new NoopImageGenerator(),
            videoMotionGenerator ?? new NoopVideoMotionGenerator(),
            generatedMediaImporter ?? new NoopGeneratedMediaImporter(),
            mediaMetadataReader ?? new FixedDurationMetadataReader(),
            mediaStorage ?? new TrackingMediaStorage(),
            imagePreviewGenerator: new NoopImagePreviewGenerator(),
            billing: billing ?? new TestTemplateGenerationBilling(),
            realtimeService: new RecordingTemplateFeedRealtimeService(),
            pushNotificationSender: new NoopPushNotificationSender(),
            options: options ?? CreateOptions(),
            logger: NullLogger<TemplateGenerationJobProcessor>.Instance,
            watermarkRenderer: new PassthroughWatermarkRenderer(),
            gamificationService: gamificationService,
            economyService: economyService);
    }

    private sealed class NoopImagePreviewGenerator : IImagePreviewGenerator
    {
        public Task<StoredMediaResponse?> CreatePreviewAsync(
            StoredMediaResponse original,
            string outputFileName,
            string? preferredStorageKey,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<StoredMediaResponse?>(null);
        }
    }

    private sealed class PassthroughWatermarkRenderer : ITemplateWatermarkRenderer
    {
        public Task<Result<StoredMediaResponse>> CreateWatermarkedCopyAsync(
            StoredMediaResponse original,
            TemplateType mediaType,
            Guid generationId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(original));
        }
    }

    private sealed class NoopPushNotificationSender : ITemplateGenerationPushNotificationSender
    {
        public Task NotifyGenerationTerminalAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private sealed class RecordingTemplateFeedRealtimeService : ITemplateFeedRealtimeService
    {
        public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
        {
            var channel = Channel.CreateUnbounded<TemplateFeedRealtimeEvent>();
            return channel.Reader;
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
        {
            return ValueTask.CompletedTask;
        }

        public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
        {
            return ValueTask.CompletedTask;
        }
    }

    private sealed class RecordingGamificationService : IGamificationService
    {
        public List<GamificationCompletionCall> CompletedGenerations { get; } = [];

        public Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
            Guid userId,
            Guid petId,
            Guid templateId,
            bool isTemplateOfTheDay,
            bool isPremium,
            CancellationToken cancellationToken)
        {
            CompletedGenerations.Add(new GamificationCompletionCall(userId, petId, templateId, isTemplateOfTheDay, isPremium));
            return Task.FromResult(new GenerationProcessResult(0, null, null, false, [], 0));
        }

        public Task<PetProgressResponse?> GetPetProgressAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
        {
            return Task.FromResult<PetProgressResponse?>(null);
        }

        public Task<IReadOnlyList<AchievementResponse>> GetAchievementsAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<AchievementResponse>>([]);
        }

        public Task<IReadOnlyList<AchievementResponse>> GetRecentAchievementsAsync(Guid userId, int count, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<AchievementResponse>>([]);
        }

        public Task<StreakResponse?> GetStreakAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<StreakResponse?>(null);
        }

        public Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(new UseFreezeResult(false, 0));
        }

        public Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<ChallengeResponse>>([]);
        }

        public Task<GamificationSummaryResponse> GetSummaryAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(new GamificationSummaryResponse(null, [], [], []));
        }

        public Task RecordCreationSharedAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private class PremiumEconomyServiceProxy : DispatchProxy
    {
        public bool IsPremium { get; set; }

        public static IEconomyService Create(bool isPremium)
        {
            var service = Create<IEconomyService, PremiumEconomyServiceProxy>();
            ((PremiumEconomyServiceProxy)(object)service).IsPremium = isPremium;
            return service;
        }

        protected override object Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(IEconomyService.GetSubscriptionSummaryAsync)
                && args is [Guid, CancellationToken])
            {
                return Task.FromResult(Result.Success(new SubscriptionSummaryResponse(
                    IsPremium,
                    Provider: IsPremium ? "stripe" : null,
                    PurchaseChannel: IsPremium ? "web" : null,
                    Status: IsPremium ? "active" : "inactive",
                    PlanName: IsPremium ? "Premium" : null,
                    BillingPeriod: IsPremium ? "monthly" : null,
                    CurrentPeriodStartUtc: null,
                    CurrentPeriodEndUtc: null,
                    CancelAtPeriodEnd: false,
                    MonthlyTokenLimit: 0,
                    TokensAvailable: 0,
                    CanManageSubscription: IsPremium,
                    ManageSubscriptionAction: IsPremium ? "manage" : "none",
                    LastTokenGrantAtUtc: null,
                    CardBrand: null,
                    CardLast4: null,
                    WeeklyGrantAmount: 0)));
            }

            throw new NotSupportedException(targetMethod?.Name ?? "Unknown economy method");
        }
    }

    private sealed record GamificationCompletionCall(
        Guid UserId,
        Guid PetId,
        Guid TemplateId,
        bool IsTemplateOfTheDay,
        bool IsPremium);

    private static TemplatesOptions CreateOptions(int refundRetryDelayMilliseconds = 30_000, int retentionDays = 7, int staleProcessingRecoveryDelayMilliseconds = 900_000)
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            JobLockTimeoutMilliseconds = staleProcessingRecoveryDelayMilliseconds,
            StaleProcessingRecoveryDelayMilliseconds = staleProcessingRecoveryDelayMilliseconds,
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

    private static TemplateItem CreateReadyImageTemplate()
    {
        var templateId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        return new TemplateItem
        {
            Id = templateId,
            TemplateType = TemplateType.Image,
            Title = "Processor Image Template",
            ShortDescription = "Ready image template",
            Category = "Tests",
            Tags = "processor,image",
            IsPremium = false,
            TokenCost = 15,
            Status = TemplateStatus.Active,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            Assets =
            [
                new TemplateAsset
                {
                    Id = Guid.NewGuid(),
                    TemplateId = templateId,
                    AssetKind = TemplateAssetKind.Preview,
                    Url = "http://localhost:5000/templates-media/preview.jpg",
                    FileName = "preview.jpg",
                    ContentType = "image/jpeg"
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

    private sealed class NoopImageGenerator : IImageGenerator
    {
        public Task<Result<ImageGenerationResult>> CreateAsync(string sourceImageUrl, string prompt, string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImageGenerationResult(sourceImageUrl, null, null)));
        }
    }

    private sealed class TrackingImageGenerator : IImageGenerator
    {
        public string? Model { get; private set; }
        public string? SourceImageUrl { get; private set; }

        public Task<Result<ImageGenerationResult>> CreateAsync(string sourceImageUrl, string prompt, string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            Model = model;
            SourceImageUrl = sourceImageUrl;
            return Task.FromResult(Result.Success(new ImageGenerationResult(
                "https://fal.example.test/generated-image.png",
                "image-request-1",
                2.8)));
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
            int? seed,
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
            int? seed,
            CancellationToken cancellationToken)
        {
            Model = model;
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated.mp4",
                "motion-request-1",
                8.4)));
        }
    }

    private sealed record ProcessingStatusSnapshot(
        string Label,
        TemplateGenerationStatus Status,
        string Stage,
        DateTime? PreprocessingCompletedAtUtc,
        DateTime? MotionGenerationCompletedAtUtc,
        DateTime? MediaImportCompletedAtUtc);

    private sealed class ProcessingStatusRecorder(TemplatesDbContext dbContext, Guid generationId)
    {
        public ConcurrentQueue<ProcessingStatusSnapshot> Snapshots { get; } = [];

        public async Task CaptureAsync(string label, CancellationToken cancellationToken)
        {
            var job = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Include(x => x.Template)
                .SingleAsync(x => x.Id == generationId, cancellationToken);

            Snapshots.Enqueue(new ProcessingStatusSnapshot(
                label,
                job.Status,
                TemplateGenerationService.ResolveStage(job),
                job.PreprocessingCompletedAtUtc,
                job.MotionGenerationCompletedAtUtc,
                job.MediaImportCompletedAtUtc));
        }
    }

    private sealed class SnapshotImagePreprocessor(ProcessingStatusRecorder recorder) : IImagePreprocessor
    {
        public async Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
        {
            await recorder.CaptureAsync("preprocessing", cancellationToken);
            return Result.Success(new ImagePreprocessResult(
                "http://localhost:5000/templates-media/normalized.jpg",
                "preprocess-request-1",
                1.25));
        }
    }

    private sealed class SnapshotVideoMotionGenerator(ProcessingStatusRecorder recorder) : IVideoMotionGenerator
    {
        public async Task<Result<VideoMotionGenerationResult>> CreateAsync(
            string normalizedImageUrl,
            string referenceVideoUrl,
            string characterOrientation,
            bool keepOriginalSound,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            await recorder.CaptureAsync("generating", cancellationToken);
            return Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated.mp4",
                "motion-request-1",
                8.4));
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

        public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                "http://localhost:5000/templates-media/output.png",
                "templates-media/output.png",
                "output.png",
                "image/png",
                1024,
                null)));
        }
    }

    private sealed class CorrelationCapturingImageGenerator : IImageGenerator
    {
        public string? CorrelationId { get; private set; }

        public Task<Result<ImageGenerationResult>> CreateAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            CorrelationId = CorrelationContext.CurrentId;
            return Task.FromResult(Result.Success(new ImageGenerationResult(
                "https://fal.example.test/generated-image.png",
                "image-request-1",
                1.5)));
        }
    }

    private sealed class TrackingGeneratedMediaImporter : IGeneratedMediaImporter
    {
        public string? GeneratedVideoUrl { get; private set; }
        public string? GeneratedImageUrl { get; private set; }

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

        public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
        {
            GeneratedImageUrl = generatedImageUrl;
            return Task.FromResult(Result.Success(new StoredMediaResponse(
            "http://localhost:5000/templates-media/output.png",
            "templates-media/output.png",
            "output.png",
            "image/png",
            1024,
            null)));
        }
    }

    private sealed class SnapshotGeneratedMediaImporter(ProcessingStatusRecorder recorder) : IGeneratedMediaImporter
    {
        public async Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            await recorder.CaptureAsync("finalizing", cancellationToken);
            return Result.Success(new StoredMediaResponse(
                "http://localhost:5000/templates-media/output.mp4",
                "templates-media/output.mp4",
                "output.mp4",
                "video/mp4",
                1024,
                null));
        }

        public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                "http://localhost:5000/templates-media/output.png",
                "templates-media/output.png",
                "output.png",
                "image/png",
                1024,
                null)));
        }
    }

    private sealed class TrackingMediaStorage : IMediaStorage
    {
        public ConcurrentBag<string> DeletedUrls { get; } = [];
        public ConcurrentBag<string> ReadUrls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                $"http://localhost:5000/templates-media/{asset.FileName}",
                $"templates-media/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0,
                null)));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            ReadUrls.Add(assetUrl);
            return Task.FromResult(Result.Success($"signed:{assetUrl}"));
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

        public Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(0));
        }
    }
}
