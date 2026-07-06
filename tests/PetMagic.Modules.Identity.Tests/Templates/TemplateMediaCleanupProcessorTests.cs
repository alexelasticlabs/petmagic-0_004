using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
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

public sealed class TemplateMediaCleanupProcessorTests
{
    [Fact]
    public async Task CleanupNextExpiredTemporaryUploadAsync_ShouldDeleteExpiredRecordAndMarkItDeleted()
    {
        await using var dbContext = CreateDbContext();
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = Guid.NewGuid(),
            Url = "http://localhost:5000/templates-media/temp-preview.jpg",
            FileName = "temp-preview.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 1024,
            Role = TemplateMediaRole.PreviewAsset,
            LifecycleState = TemplateMediaLifecycleState.Temporary,
            UploadedAtUtc = DateTime.UtcNow.AddHours(-2),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(-5)
        });
        await dbContext.SaveChangesAsync();

        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(dbContext, mediaStorage: mediaStorage);

        var processed = await processor.CleanupNextExpiredTemporaryUploadAsync(CancellationToken.None);

        var record = await dbContext.TemplateMediaRecords.SingleAsync();
        Assert.True(processed);
        Assert.Contains("http://localhost:5000/templates-media/temp-preview.jpg", mediaStorage.DeletedUrls);
        Assert.Equal(TemplateMediaLifecycleState.Deleted, record.LifecycleState);
        Assert.NotNull(record.DeletedAtUtc);
    }

    [Fact]
    public async Task CleanupNextExpiredTemporaryUploadAsync_ShouldSanitizeDurableFailureDiagnostics()
    {
        await using var dbContext = CreateDbContext();
        var recordId = Guid.NewGuid();
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = recordId,
            Url = "http://localhost:5000/templates-media/temp-preview.jpg",
            FileName = "temp-preview.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 1024,
            Role = TemplateMediaRole.PreviewAsset,
            LifecycleState = TemplateMediaLifecycleState.Temporary,
            UploadedAtUtc = DateTime.UtcNow.AddHours(-2),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(-5)
        });
        await dbContext.SaveChangesAsync();

        var logger = new CapturingLogger<TemplateMediaCleanupProcessor>();
        var processor = CreateProcessor(
            dbContext,
            mediaStorage: new FailingDeleteMediaStorage(
                "storage token=code-secret",
                "delete failed token=raw-secret api_secret=storage-secret requestId=req-secret"),
            logger: logger);

        var processed = await processor.CleanupNextExpiredTemporaryUploadAsync(CancellationToken.None);

        var record = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Id == recordId);
        Assert.True(processed);
        Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, record.LifecycleState);
        Assert.NotNull(record.FailureCode);
        Assert.NotNull(record.FailureMessage);
        Assert.DoesNotContain("code-secret", record.FailureCode, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("raw-secret", record.FailureMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("storage-secret", record.FailureMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("req-secret", record.FailureMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            logger.Entries,
            entry => entry.Level == LogLevel.Warning
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && !errorCode.Contains("code-secret", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task CleanupNextExpiredGenerationMediaAsync_ShouldDeleteUserMediaAndKeepRefundPendingJob()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Failed, DateTime.UtcNow.AddDays(-10));
        job.SourceImageUrl = "http://localhost:5000/templates-media/source.jpg";
        job.NormalizedImageUrl = "http://localhost:5000/templates-media/normalized.jpg";
        job.ReferenceMotionUrl = "http://localhost:5000/templates-media/reference.mp4";
        job.ResultUrl = "http://localhost:5000/templates-media/output.mp4";
        job.WatermarkedResultUrl = "http://localhost:5000/templates-media/output-watermarked.mp4";
        job.RefundAttemptCount = 2;
        job.RefundLastErrorCode = "economy.unavailable";
        job.RefundLastAttemptedAtUtc = DateTime.UtcNow.AddDays(-9);
        job.MediaRecords.Add(new TemplateMediaRecord
        {
            Id = Guid.NewGuid(),
            UserId = job.UserId,
            MediaType = "video",
            StoragePath = "http://localhost:5000/templates-media/output.mp4",
            WatermarkedStoragePath = "http://localhost:5000/templates-media/output-watermarked.mp4",
            PreviewUrl = "http://localhost:5000/templates-media/output-thumb.jpg",
            WatermarkedPreviewUrl = "http://localhost:5000/templates-media/output-watermarked-thumb.jpg",
            SourceType = "generation_result",
            GenerationId = job.Id,
            Url = "http://localhost:5000/templates-media/output.mp4",
            FileName = "output.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 1024,
            Role = TemplateMediaRole.GenerationOutputVideo,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            GenerationJobId = job.Id,
            UploadedAtUtc = DateTime.UtcNow.AddDays(-10),
            AttachedAtUtc = DateTime.UtcNow.AddDays(-10)
        });

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(dbContext, mediaStorage: mediaStorage);

        var processed = await processor.CleanupNextExpiredGenerationMediaAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.NotNull(persisted.UserMediaDeletedAtUtc);
        Assert.Equal(string.Empty, persisted.SourceImageUrl);
        Assert.Null(persisted.NormalizedImageUrl);
        Assert.Null(persisted.ResultUrl);
        Assert.Null(persisted.WatermarkedResultUrl);
        Assert.Null(persisted.UserMediaCleanupFailureCode);
        Assert.Contains("http://localhost:5000/templates-media/source.jpg", mediaStorage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/normalized.jpg", mediaStorage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/output.mp4", mediaStorage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/output-watermarked.mp4", mediaStorage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/output-thumb.jpg", mediaStorage.DeletedUrls);
        Assert.Contains("http://localhost:5000/templates-media/output-watermarked-thumb.jpg", mediaStorage.DeletedUrls);
        Assert.DoesNotContain("http://localhost:5000/templates-media/reference.mp4", mediaStorage.DeletedUrls);
    }

    [Fact]
    public async Task CleanupNextExpiredGenerationMediaAsync_ShouldSanitizeDurableFailureCode()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Failed, DateTime.UtcNow.AddDays(-10));
        job.SourceImageUrl = "http://localhost:5000/templates-media/source.jpg";
        job.ResultUrl = "http://localhost:5000/templates-media/output.mp4";

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var logger = new CapturingLogger<TemplateMediaCleanupProcessor>();
        var processor = CreateProcessor(
            dbContext,
            mediaStorage: new FailingDeleteMediaStorage(
                "storage token=cleanup-code-secret",
                "delete failed token=raw-secret"),
            logger: logger);

        var processed = await processor.CleanupNextExpiredGenerationMediaAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.NotNull(persisted.UserMediaCleanupFailureCode);
        Assert.DoesNotContain("cleanup-code-secret", persisted.UserMediaCleanupFailureCode, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            logger.Entries,
            entry => entry.Level == LogLevel.Warning
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && !errorCode.Contains("cleanup-code-secret", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task CleanupNextExpiredGenerationMediaAsync_ShouldNotDeleteCompletedResultBeforeRetentionCutoff()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Completed, DateTime.UtcNow.AddDays(-1));
        job.SourceImageUrl = "templates-media/source.jpg";
        job.ResultUrl = "templates-media/output.mp4";

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var mediaStorage = new TrackingMediaStorage();
        var processor = CreateProcessor(dbContext, mediaStorage: mediaStorage, options: CreateOptions(retentionDays: 7));

        var processed = await processor.CleanupNextExpiredGenerationMediaAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.False(processed);
        Assert.Null(persisted.UserMediaDeletedAtUtc);
        Assert.Equal("templates-media/source.jpg", persisted.SourceImageUrl);
        Assert.Equal("templates-media/output.mp4", persisted.ResultUrl);
        Assert.Empty(mediaStorage.DeletedUrls);
    }

    [Fact]
    public async Task CleanupNextExpiredMetadataTempFileAsync_ShouldDeleteOldOwnedFile()
    {
        var path = await TemplateMediaTempFiles.WriteAsync("metadata"u8.ToArray(), ".tmp", CancellationToken.None);
        File.SetLastWriteTimeUtc(path, DateTime.UtcNow.AddHours(-6));

        await using var dbContext = CreateDbContext();
        var processor = CreateProcessor(dbContext, options: CreateOptions(metadataTempRetentionHours: 1));

        var processed = await processor.CleanupNextExpiredMetadataTempFileAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.False(File.Exists(path));
    }

    [Fact]
    public async Task CleanupNextExpiredMetadataTempFileAsync_ShouldNotDeleteActivePartFiles()
    {
        var path = await TemplateMediaTempFiles.WriteAsync("metadata"u8.ToArray(), ".tmp.part", CancellationToken.None);
        File.SetLastWriteTimeUtc(path, DateTime.UtcNow.AddHours(-6));

        try
        {
            await using var dbContext = CreateDbContext();
            var processor = CreateProcessor(dbContext, options: CreateOptions(metadataTempRetentionHours: 1));

            await processor.CleanupNextExpiredMetadataTempFileAsync(CancellationToken.None);

            Assert.True(File.Exists(path));
        }
        finally
        {
            TemplateMediaTempFiles.TryDeleteIfOwned(path);
        }
    }

    [Fact]
    public async Task CleanupNextExpiredMetadataTempFileAsync_ShouldKeepUnsafeOutsideFiles()
    {
        var outsidePath = Path.Combine(Path.GetTempPath(), $"petmagic-outside-metadata-{Guid.NewGuid():N}.tmp");
        await File.WriteAllBytesAsync(outsidePath, "metadata"u8.ToArray());
        File.SetLastWriteTimeUtc(outsidePath, DateTime.UtcNow.AddHours(-6));

        try
        {
            TemplateMediaTempFiles.TryDeleteIfOwned(outsidePath);

            await using var dbContext = CreateDbContext();
            var processor = CreateProcessor(dbContext, options: CreateOptions(metadataTempRetentionHours: 1));
            await processor.CleanupNextExpiredMetadataTempFileAsync(CancellationToken.None);

            Assert.True(File.Exists(outsidePath));
        }
        finally
        {
            if (File.Exists(outsidePath))
            {
                File.Delete(outsidePath);
            }
        }
    }

    [Fact]
    public async Task CleanupNextExpiredMetadataTempFileAsync_ShouldLogWarning_WhenOwnedFileIsLocked()
    {
        var path = await TemplateMediaTempFiles.WriteAsync("metadata"u8.ToArray(), ".tmp", CancellationToken.None);
        File.SetLastWriteTimeUtc(path, DateTime.UtcNow.AddHours(-6));
        var logger = new CapturingLogger<TemplateMediaCleanupProcessor>();
        await using var lockStream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None);

        try
        {
            await using var dbContext = CreateDbContext();
            var processor = CreateProcessor(
                dbContext,
                options: CreateOptions(metadataTempRetentionHours: 1),
                logger: logger);

            var processed = await processor.CleanupNextExpiredMetadataTempFileAsync(CancellationToken.None);

            Assert.False(processed);
            Assert.Contains(
                logger.Entries,
                entry => entry.Level == LogLevel.Warning
                    && entry.Message.Contains("Template metadata temp file sweep failed.", StringComparison.Ordinal)
                    && Equals(entry.Properties["Operation"], "sweep_expired"));
        }
        finally
        {
            lockStream.Dispose();
            TemplateMediaTempFiles.TryDeleteIfOwned(path);
        }
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"template-media-cleanup-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static TemplateMediaCleanupProcessor CreateProcessor(
        TemplatesDbContext dbContext,
        IMediaStorage? mediaStorage = null,
        TemplatesOptions? options = null,
        ILogger<TemplateMediaCleanupProcessor>? logger = null)
    {
        return new TemplateMediaCleanupProcessor(
            dbContext,
            mediaStorage ?? new TrackingMediaStorage(),
            options ?? CreateOptions(),
            logger ?? NullLogger<TemplateMediaCleanupProcessor>.Instance);
    }

    private static TemplatesOptions CreateOptions(int retentionDays = 7, int metadataTempRetentionHours = 24)
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
            GenerationRetentionDaysAfterCompletion = retentionDays,
            MediaCleanupRetryDelayMilliseconds = 0,
            MetadataTempRetentionHours = metadataTempRetentionHours,
            CleanupExpiredGenerationMediaWhileRefundPending = true
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
            Title = "Cleanup Template",
            ShortDescription = "Ready video template",
            Category = "Tests",
            Tags = "cleanup",
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

    private sealed class TrackingMediaStorage : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];

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
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class FailingDeleteMediaStorage(string code, string message) : IMediaStorage
    {
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
            return Task.FromResult(Result.Failure(new Error(code, message)));
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values
                    .Where(x => !string.Equals(x.Key, "{OriginalFormat}", StringComparison.Ordinal))
                    .ToDictionary(x => x.Key, x => x.Value)
                : [];

            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), properties));
        }

        private sealed class NullScope : IDisposable
        {
            public static readonly NullScope Instance = new();

            public void Dispose()
            {
            }
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        IReadOnlyDictionary<string, object?> Properties);
}
