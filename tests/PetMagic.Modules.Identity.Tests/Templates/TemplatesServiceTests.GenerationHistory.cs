using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldFilterPaginateAndOmitSensitiveFields()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Jobs Portrait", "Portrait", ["admin-jobs"]);
        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var matchingJobId = Guid.NewGuid();

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = matchingJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 20,
                SourceImageUrl = "https://signed.example.com/source.jpg?sig=secret",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                ResultUrl = "https://signed.example.com/output.jpg?sig=secret",
                IdempotencyKey = "idempotency-secret",
                RequestHash = "request-hash-secret",
                UsedPreprocessingModel = "openai/gpt-image-2/edit",
                UsedKlingModel = "fal-ai/kling-video/v3/pro/motion-control",
                PreprocessingProviderRequestId = "provider-request-secret",
                MotionProviderRequestId = "motion-request-secret",
                MotionProviderCostUsd = 0.1234m,
                AttemptCount = 2,
                LastErrorCode = "templates.ai_provider_failed",
                LastErrorMessage = new string('x', 300),
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                StartedAtUtc = now.AddMinutes(-4),
                UpdatedAtUtc = now.AddMinutes(-3),
                CompletedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = otherUserId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/other-source.jpg",
                SourceImageFileName = "other-source.jpg",
                SourceImageContentType = "image/jpeg",
                UsedPreprocessingModel = "openai/gpt-image-2/edit",
                AttemptCount = 1,
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                UpdatedAtUtc = now.AddMinutes(-1),
                CompletedAtUtc = now.AddMinutes(-1)
            });
        await dbContext.SaveChangesAsync();

        var page = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery(
                "failed",
                "fal",
                userId.ToString(),
                matchingJobId.ToString()[..12],
                0,
                10),
            CancellationToken.None);

        Assert.True(page.IsSuccess);
        Assert.Equal(1, page.Value.TotalCount);
        var item = Assert.Single(page.Value.Items);
        Assert.Equal(matchingJobId, item.GenerationId);
        Assert.Equal(userId, item.UserId);
        Assert.Equal("Admin Jobs Portrait", item.TemplateTitle);
        Assert.Equal("Failed", item.Status);
        Assert.Equal("fal-ai", item.Provider);
        Assert.Equal("fal-ai/kling-video/v3/pro/motion-control", item.Model);
        Assert.Equal(0.1234m, item.ProviderCostUsd);
        Assert.Equal("templates.ai_provider_failed", item.FailureCode);
        Assert.True(item.FailureMessage?.Length <= 243);

        var serialized = JsonSerializer.Serialize(item);
        Assert.DoesNotContain("SourceImage", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ResultUrl", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ProviderRequestId", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("RequestHash", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("IdempotencyKey", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("signed.example.com", serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldReturnBatchedRelationshipAndPreviewFields()
    {
        await using var dbContext = CreateDbContext();
        var mediaStorage = new RecordingMediaStorage(signReadUrls: true);
        var service = CreateService(dbContext, mediaStorage);
        var parentTemplateId = await CreateActiveImageTemplateAsync(service, "Admin Parent Portrait", "Portrait", ["admin-jobs"]);
        var childTemplateId = await CreateActiveImageTemplateAsync(service, "Admin Child Portrait", "Portrait", ["admin-jobs"]);
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var parentGenerationId = Guid.NewGuid();
        var childGenerationId = Guid.NewGuid();
        var childOfChildGenerationId = Guid.NewGuid();
        var inputMediaId = Guid.NewGuid();
        var resultMediaId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = parentGenerationId,
                UserId = userId,
                TemplateId = parentTemplateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/parent-source.jpg",
                SourceImageFileName = "parent-source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-8),
                QueuedAtUtc = now.AddMinutes(-8),
                UpdatedAtUtc = now.AddMinutes(-7),
                CompletedAtUtc = now.AddMinutes(-7)
            },
            new TemplateGenerationJob
            {
                Id = childGenerationId,
                UserId = userId,
                TemplateId = childTemplateId,
                ParentGenerationId = parentGenerationId,
                ParentGenerationResultId = parentGenerationId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/child-source.jpg",
                SourceImageFileName = "child-source.jpg",
                SourceImageContentType = "image/jpeg",
                InputSourceType = "generation_result",
                InputMediaAssetId = inputMediaId,
                ResultMediaAssetId = resultMediaId,
                IsWatermarkRequired = true,
                IsWatermarkRemoved = false,
                WatermarkedResultUrl = "https://cdn.example.com/child-watermarked-output.jpg",
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-4),
                CompletedAtUtc = now.AddMinutes(-4)
            },
            new TemplateGenerationJob
            {
                Id = childOfChildGenerationId,
                UserId = userId,
                TemplateId = childTemplateId,
                ParentGenerationId = childGenerationId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/grandchild-source.jpg",
                SourceImageFileName = "grandchild-source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3)
            });
        dbContext.TemplateMediaRecords.AddRange(
            new TemplateMediaRecord
            {
                Id = inputMediaId,
                UserId = userId,
                MediaType = "image",
                SourceType = "generation_result",
                Url = "https://cdn.example.com/input-original.jpg",
                PreviewUrl = "https://cdn.example.com/input-preview.jpg",
                FileName = "input-original.jpg",
                ContentType = "image/jpeg",
                UploadedAtUtc = now.AddMinutes(-6)
            },
            new TemplateMediaRecord
            {
                Id = resultMediaId,
                UserId = userId,
                MediaType = "image",
                SourceType = "generation_result",
                GenerationId = childGenerationId,
                Url = "https://cdn.example.com/result-clean.jpg",
                PreviewUrl = "https://cdn.example.com/result-clean-preview.jpg",
                WatermarkedStoragePath = "https://cdn.example.com/result-watermarked-storage.jpg",
                WatermarkedPreviewUrl = "https://cdn.example.com/result-watermarked-preview.jpg",
                FileName = "result-clean.jpg",
                ContentType = "image/jpeg",
                UploadedAtUtc = now.AddMinutes(-4)
            });
        dbContext.TemplateGenerationWatermarkUnlocks.AddRange(
            new TemplateGenerationWatermarkUnlock
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                GenerationJobId = childGenerationId,
                UnlockMethod = TemplateWatermarkUnlockMethod.Premium,
                CreditsSpent = 0,
                CreatedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationWatermarkUnlock
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                UnlockedByUserId = adminId,
                GenerationJobId = childGenerationId,
                UnlockMethod = TemplateWatermarkUnlockMethod.Admin,
                CreditsSpent = 1,
                CreatedAtUtc = now.AddMinutes(-1)
            });
        await dbContext.SaveChangesAsync();

        var page = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery(null, null, userId.ToString(), childGenerationId.ToString(), 0, 10),
            CancellationToken.None);

        Assert.True(page.IsSuccess);
        var item = Assert.Single(page.Value.Items);
        Assert.Equal(childGenerationId, item.GenerationId);
        Assert.Equal(parentGenerationId, item.ParentGenerationId);
        Assert.Equal(parentGenerationId, item.ParentGenerationResultId);
        Assert.Equal("Admin Parent Portrait", item.ParentTemplateTitle);
        Assert.Equal("Image", item.ParentTemplateType);
        Assert.Equal(1, item.ChildCount);
        Assert.Equal("generation_result", item.InputSourceType);
        Assert.Equal(inputMediaId, item.InputMediaAssetId);
        Assert.Equal("https://cdn.example.com/input-preview.jpg?signed=1", item.InputPreviewUrl);
        Assert.Equal(resultMediaId, item.ResultMediaAssetId);
        Assert.Equal("https://cdn.example.com/result-watermarked-preview.jpg?signed=1", item.ResultPreviewUrl);
        Assert.Equal("https://cdn.example.com/child-watermarked-output.jpg?signed=1", item.WatermarkedMediaPath);
        Assert.Contains("https://cdn.example.com/input-preview.jpg", mediaStorage.ReadUrls);
        Assert.Contains("https://cdn.example.com/result-watermarked-preview.jpg", mediaStorage.ReadUrls);
        Assert.Contains("https://cdn.example.com/child-watermarked-output.jpg", mediaStorage.ReadUrls);
        Assert.All(mediaStorage.ReadTtls, ttl => Assert.Equal(TimeSpan.FromSeconds(900), ttl));
        Assert.Equal("admin", item.WatermarkUnlockMethod);
        Assert.Equal(adminId, item.WatermarkUnlockedByUserId);
        Assert.Equal(1, item.WatermarkCreditsSpent);
        Assert.Equal(now.AddMinutes(-1), item.WatermarkUnlockedAtUtc);
    }

    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldNotExposePrivatePreviewUrls_WhenReadUrlSigningFails()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext, new FailingReadMediaStorage());
        var templateId = await CreateActiveImageTemplateAsync(service, "Private Preview Portrait", "Portrait", ["admin-jobs"]);
        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var inputMediaId = Guid.NewGuid();
        var resultMediaId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = templateId,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "templates-media/private/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            InputMediaAssetId = inputMediaId,
            ResultMediaAssetId = resultMediaId,
            WatermarkedResultUrl = "templates-media/private/watermarked.png",
            IsWatermarkRequired = true,
            CreatedAtUtc = now.AddMinutes(-3),
            QueuedAtUtc = now.AddMinutes(-3),
            CompletedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now.AddMinutes(-2)
        });
        dbContext.TemplateMediaRecords.AddRange(
            CreateGenerationMediaRecord(inputMediaId, userId, generationId, "user_upload", "templates-media/private/source.jpg", "templates-media/private/source-preview.webp", now.AddMinutes(-3)),
            CreateGenerationMediaRecord(resultMediaId, userId, generationId, "generation_result", "templates-media/private/result.png", "templates-media/private/result-preview.webp", now.AddMinutes(-2)));
        await dbContext.SaveChangesAsync();

        var page = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery("completed", null, userId.ToString(), null, 0, 10),
            CancellationToken.None);

        Assert.True(page.IsSuccess);
        var item = Assert.Single(page.Value.Items);
        Assert.Null(item.InputPreviewUrl);
        Assert.Null(item.ResultPreviewUrl);
        Assert.Null(item.WatermarkedMediaPath);
        var serialized = JsonSerializer.Serialize(item);
        Assert.DoesNotContain("templates-media/private", serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task SignUserMediaUrlsAsync_ShouldHidePrivateMedia_WhenReadUrlSigningFails()
    {
        var response = new TemplateGenerationResponse(
            GenerationId: Guid.NewGuid(),
            UserId: Guid.NewGuid(),
            TemplateId: Guid.NewGuid(),
            Status: "Completed",
            TokenCost: 20,
            SourceImageAsset: new TemplateAssetResponse(
                "templates-media/private/source.jpg",
                "source.jpg",
                "image/jpeg",
                1024,
                null),
            NormalizedImageUrl: "templates-media/private/normalized.jpg",
            ReferenceMotionUrl: "https://cdn.example.com/templates/reference.mp4",
            OutputUrl: "templates-media/private/result.png",
            AttemptCount: 1,
            UsedPreprocessingModel: "openai/gpt-image-2/edit",
            UsedKlingModel: null,
            PreprocessingProviderRequestId: null,
            PreprocessingInferenceTimeSeconds: null,
            MotionProviderRequestId: null,
            MotionInferenceTimeSeconds: null,
            OutputVideoDurationSeconds: null,
            MotionProviderCostUsd: null,
            FailureCode: null,
            FailureMessage: null,
            CreatedAtUtc: DateTime.UtcNow.AddMinutes(-2),
            UpdatedAtUtc: DateTime.UtcNow,
            StartedAtUtc: DateTime.UtcNow.AddMinutes(-2),
            PreprocessingCompletedAtUtc: DateTime.UtcNow.AddMinutes(-1),
            MotionGenerationCompletedAtUtc: null,
            MediaImportCompletedAtUtc: DateTime.UtcNow,
            CompletedAtUtc: DateTime.UtcNow,
            UserMediaExpired: false,
            InputPreviewUrl: "templates-media/private/input-preview.webp",
            ResultPreviewUrl: "templates-media/private/result-preview.webp");

        var signed = await TemplateGenerationService.SignUserMediaUrlsAsync(
            new FailingReadMediaStorage(),
            CreateTemplatesOptions(),
            response,
            CancellationToken.None);

        Assert.Null(signed.SourceImageAsset);
        Assert.Null(signed.NormalizedImageUrl);
        Assert.Null(signed.OutputUrl);
        Assert.Null(signed.InputPreviewUrl);
        Assert.Null(signed.ResultPreviewUrl);
        Assert.Equal(response.ReferenceMotionUrl, signed.ReferenceMotionUrl);
    }

    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldSupportCancelledAndRetryingStatusFilters()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Retry Portrait", "Portrait", ["admin-jobs"]);
        var now = DateTime.UtcNow;
        var cancelledJobId = Guid.NewGuid();
        var retryingJobId = Guid.NewGuid();

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = cancelledJobId,
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Cancelled,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/cancelled-source.jpg",
                SourceImageFileName = "cancelled-source.jpg",
                SourceImageContentType = "image/jpeg",
                AttemptCount = 1,
                CreatedAtUtc = now.AddMinutes(-4),
                QueuedAtUtc = now.AddMinutes(-4),
                UpdatedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationJob
            {
                Id = retryingJobId,
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Retrying,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/retrying-source.jpg",
                SourceImageFileName = "retrying-source.jpg",
                SourceImageContentType = "image/jpeg",
                AttemptCount = 2,
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                UpdatedAtUtc = now.AddMinutes(-1)
            });
        await dbContext.SaveChangesAsync();

        var cancelled = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery("cancelled", null, null, null, 0, 10),
            CancellationToken.None);
        var retrying = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery("retrying", null, null, null, 0, 10),
            CancellationToken.None);

        Assert.True(cancelled.IsSuccess);
        Assert.True(retrying.IsSuccess);
        Assert.Equal(cancelledJobId, Assert.Single(cancelled.Value.Items).GenerationId);
        Assert.Equal("Cancelled", cancelled.Value.Items[0].Status);
        Assert.Equal(retryingJobId, Assert.Single(retrying.Value.Items).GenerationId);
        Assert.Equal("Retrying", retrying.Value.Items[0].Status);
    }

    [Fact]
    public async Task GetAdminGenerationDashboardMetricsAsync_ShouldAggregateGlobalStatusCounts()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Metrics Portrait", "Portrait", ["admin-jobs"]);
        var todayStart = DateTime.UtcNow.Date;

        dbContext.TemplateGenerationJobs.AddRange(
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Queued, todayStart.AddHours(1)),
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Processing, todayStart.AddHours(2)),
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Retrying, todayStart.AddHours(3)),
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Failed, todayStart.AddHours(4)),
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Cancelled, todayStart.AddHours(5)),
            CreateAdminMetricsJob(templateId, TemplateGenerationStatus.Completed, todayStart.AddDays(-40).AddHours(1)));
        await dbContext.SaveChangesAsync();

        var metrics = await service.GetAdminGenerationDashboardMetricsAsync(CancellationToken.None);

        Assert.True(metrics.IsSuccess);
        Assert.Equal(6, metrics.Value.TotalJobs);
        Assert.Equal(5, metrics.Value.GenerationsToday);
        Assert.Equal(5, metrics.Value.GenerationsThisWeek);
        Assert.Equal(5, metrics.Value.GenerationsThisMonth);
        Assert.Equal(1, metrics.Value.FailedGenerationsToday);
        Assert.Equal(1, metrics.Value.FailedGenerationsThisWeek);
        Assert.Equal(1, metrics.Value.FailedGenerationsThisMonth);
        Assert.Equal(1, metrics.Value.PendingJobs);
        Assert.Equal(1, metrics.Value.RunningJobs);
        Assert.Equal(1, metrics.Value.CompletedJobs);
        Assert.Equal(1, metrics.Value.FailedJobs);
        Assert.Equal(1, metrics.Value.CancelledJobs);
        Assert.Equal(1, metrics.Value.RetryingJobs);
    }

    [Fact]
    public async Task ListAsync_ShouldCalculateQueueMetricsForQueuedHistory()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var options = CreateTemplatesOptions(globalMaxConcurrentGenerations: 2, estimatedImageGenerationSeconds: 40);
        var generationService = CreateGenerationService(dbContext, options);
        var templateId = await CreateActiveImageTemplateAsync(service, "Queued History Portrait", "Portrait", ["queue-history"]);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var olderForeignQueuedJobId = Guid.NewGuid();
        var firstQueuedJobId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var secondQueuedJobId = Guid.Parse("00000000-0000-0000-0000-000000000002");
        var processingJobId = Guid.NewGuid();
        var tiedQueuedAtUtc = now.AddMinutes(-3);

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = olderForeignQueuedJobId,
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/foreign-queued.jpg",
                SourceImageFileName = "foreign-queued.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                ChargedAtUtc = now.AddMinutes(-5)
            },
            new TemplateGenerationJob
            {
                Id = firstQueuedJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/queued-a.jpg",
                SourceImageFileName = "queued-a.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-4),
                QueuedAtUtc = tiedQueuedAtUtc,
                UpdatedAtUtc = now.AddMinutes(-4),
                ChargedAtUtc = now.AddMinutes(-4)
            },
            new TemplateGenerationJob
            {
                Id = secondQueuedJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/queued-b.jpg",
                SourceImageFileName = "queued-b.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = tiedQueuedAtUtc,
                UpdatedAtUtc = now.AddMinutes(-3),
                ChargedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationJob
            {
                Id = processingJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Processing,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/processing.jpg",
                SourceImageFileName = "processing.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                UpdatedAtUtc = now.AddMinutes(-1),
                StartedAtUtc = now.AddMinutes(-1),
                ChargedAtUtc = now.AddMinutes(-2),
                LockedAtUtc = now.AddMinutes(-1),
                LockedBy = "worker-1"
            });
        await dbContext.SaveChangesAsync();

        var history = await generationService.ListAsync(userId, new TemplateGenerationHistoryQuery("all", null, 10), isPremium: false, CancellationToken.None);

        Assert.True(history.IsSuccess);
        Assert.DoesNotContain(history.Value, x => x.GenerationId == olderForeignQueuedJobId);
        Assert.Equal(3, history.Value.Count);

        var firstQueued = Assert.Single(history.Value, x => x.GenerationId == firstQueuedJobId);
        Assert.Equal(2, firstQueued.QueuePosition);
        Assert.Equal(40, firstQueued.EstimatedWaitSeconds);

        var secondQueued = Assert.Single(history.Value, x => x.GenerationId == secondQueuedJobId);
        Assert.Equal(3, secondQueued.QueuePosition);
        Assert.Equal(60, secondQueued.EstimatedWaitSeconds);

        var processing = Assert.Single(history.Value, x => x.GenerationId == processingJobId);
        Assert.Null(processing.QueuePosition);
        Assert.Null(processing.EstimatedWaitSeconds);
    }

    [Fact]
    public async Task GetAsync_ShouldUseGenerationIdTieBreakerForQueuedPosition()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var options = CreateTemplatesOptions(globalMaxConcurrentGenerations: 2, estimatedImageGenerationSeconds: 40);
        var generationService = CreateGenerationService(dbContext, options);
        var templateId = await CreateActiveImageTemplateAsync(service, "Queued Status Portrait", "Portrait", ["queue-status"]);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var olderForeignQueuedJobId = Guid.NewGuid();
        var firstQueuedJobId = Guid.Parse("00000000-0000-0000-0000-000000000101");
        var secondQueuedJobId = Guid.Parse("00000000-0000-0000-0000-000000000102");
        var tiedQueuedAtUtc = now.AddMinutes(-3);

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = olderForeignQueuedJobId,
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/foreign-status-queued.jpg",
                SourceImageFileName = "foreign-status-queued.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                ChargedAtUtc = now.AddMinutes(-5)
            },
            new TemplateGenerationJob
            {
                Id = firstQueuedJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/status-queued-a.jpg",
                SourceImageFileName = "status-queued-a.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-4),
                QueuedAtUtc = tiedQueuedAtUtc,
                UpdatedAtUtc = now.AddMinutes(-4),
                ChargedAtUtc = now.AddMinutes(-4)
            },
            new TemplateGenerationJob
            {
                Id = secondQueuedJobId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/status-queued-b.jpg",
                SourceImageFileName = "status-queued-b.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = tiedQueuedAtUtc,
                UpdatedAtUtc = now.AddMinutes(-3),
                ChargedAtUtc = now.AddMinutes(-3)
            });
        await dbContext.SaveChangesAsync();

        var firstQueued = await generationService.GetAsync(userId, firstQueuedJobId, isPremium: false, CancellationToken.None);
        var secondQueued = await generationService.GetAsync(userId, secondQueuedJobId, isPremium: false, CancellationToken.None);

        Assert.True(firstQueued.IsSuccess);
        Assert.True(secondQueued.IsSuccess);
        Assert.Equal(2, firstQueued.Value.QueuePosition);
        Assert.Equal(20, firstQueued.Value.EstimatedWaitSeconds);
        Assert.Equal(3, secondQueued.Value.QueuePosition);
        Assert.Equal(40, secondQueued.Value.EstimatedWaitSeconds);
    }

    [Fact]
    public async Task ListAsync_ShouldReturnComparePreviewFieldsForCompletedImages()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Compare History Portrait", "Portrait", ["compare-history"]);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var firstGenerationId = Guid.NewGuid();
        var secondGenerationId = Guid.NewGuid();
        var firstInputMediaId = Guid.NewGuid();
        var secondInputMediaId = Guid.NewGuid();
        var firstResultMediaId = Guid.NewGuid();
        var secondResultMediaId = Guid.NewGuid();

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = firstGenerationId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/input-1.jpg",
                SourceImageFileName = "input-1.jpg",
                SourceImageContentType = "image/jpeg",
                InputMediaAssetId = firstInputMediaId,
                ResultMediaAssetId = firstResultMediaId,
                ResultUrl = "https://cdn.example.com/result-1.png",
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                StartedAtUtc = now.AddMinutes(-2),
                CompletedAtUtc = now.AddMinutes(-1),
                UpdatedAtUtc = now.AddMinutes(-1),
                ChargedAtUtc = now.AddMinutes(-2)
            },
            new TemplateGenerationJob
            {
                Id = secondGenerationId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/input-2.jpg",
                SourceImageFileName = "input-2.jpg",
                SourceImageContentType = "image/jpeg",
                InputMediaAssetId = secondInputMediaId,
                ResultMediaAssetId = secondResultMediaId,
                ResultUrl = "https://cdn.example.com/result-2.png",
                CreatedAtUtc = now.AddMinutes(-4),
                QueuedAtUtc = now.AddMinutes(-4),
                StartedAtUtc = now.AddMinutes(-4),
                CompletedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3),
                ChargedAtUtc = now.AddMinutes(-4)
            });
        dbContext.TemplateMediaRecords.AddRange(
            CreateGenerationMediaRecord(firstInputMediaId, userId, firstGenerationId, "user_upload", "https://cdn.example.com/input-1.jpg", "https://cdn.example.com/input-preview-1.webp", now.AddMinutes(-2)),
            CreateGenerationMediaRecord(secondInputMediaId, userId, secondGenerationId, "user_upload", "https://cdn.example.com/input-2.jpg", "https://cdn.example.com/input-preview-2.webp", now.AddMinutes(-4)),
            CreateGenerationMediaRecord(firstResultMediaId, userId, firstGenerationId, "generation_result", "https://cdn.example.com/result-1.png", "https://cdn.example.com/result-preview-1.webp", now.AddMinutes(-1)),
            CreateGenerationMediaRecord(secondResultMediaId, userId, secondGenerationId, "generation_result", "https://cdn.example.com/result-2.png", "https://cdn.example.com/result-preview-2.webp", now.AddMinutes(-3)));
        await dbContext.SaveChangesAsync();

        var history = await generationService.ListAsync(userId, new TemplateGenerationHistoryQuery("completed", null, 10), isPremium: false, CancellationToken.None);

        Assert.True(history.IsSuccess);
        Assert.Equal(2, history.Value.Count);

        var first = Assert.Single(history.Value, x => x.GenerationId == firstGenerationId);
        Assert.True(first.CanCompareBeforeAfter);
        Assert.Equal(firstInputMediaId, first.InputMediaAssetId);
        Assert.Equal(firstResultMediaId, first.ResultMediaAssetId);
        Assert.Equal("https://cdn.example.com/input-preview-1.webp", first.InputPreviewUrl);
        Assert.Equal("https://cdn.example.com/result-preview-1.webp", first.ResultPreviewUrl);

        var second = Assert.Single(history.Value, x => x.GenerationId == secondGenerationId);
        Assert.True(second.CanCompareBeforeAfter);
        Assert.Equal(secondInputMediaId, second.InputMediaAssetId);
        Assert.Equal(secondResultMediaId, second.ResultMediaAssetId);
        Assert.Equal("https://cdn.example.com/input-preview-2.webp", second.InputPreviewUrl);
        Assert.Equal("https://cdn.example.com/result-preview-2.webp", second.ResultPreviewUrl);
    }

    [Fact]
    public async Task ListAsync_ShouldNotExposeComparePreviewForMissingSourceImageContentType()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Legacy Compare Portrait", "Portrait", ["legacy-compare"]);
        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.TemplateGenerationJobs.Add(
            new TemplateGenerationJob
            {
                Id = generationId,
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/legacy-input.jpg",
                SourceImageFileName = "legacy-input.jpg",
                SourceImageContentType = string.Empty,
                ResultUrl = "https://cdn.example.com/legacy-result.png",
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                StartedAtUtc = now.AddMinutes(-2),
                CompletedAtUtc = now.AddMinutes(-1),
                UpdatedAtUtc = now.AddMinutes(-1),
                ChargedAtUtc = now.AddMinutes(-2)
            });
        await dbContext.SaveChangesAsync();

        var history = await generationService.ListAsync(
            userId,
            new TemplateGenerationHistoryQuery("completed", null, 10),
            isPremium: false,
            CancellationToken.None);

        Assert.True(history.IsSuccess);
        var item = Assert.Single(history.Value);
        Assert.Equal(generationId, item.GenerationId);
        Assert.False(item.CanCompareBeforeAfter);
        Assert.Null(item.InputPreviewUrl);
        Assert.Null(item.ResultPreviewUrl);
    }

    private static TemplateMediaRecord CreateGenerationMediaRecord(
        Guid id,
        Guid userId,
        Guid generationId,
        string sourceType,
        string url,
        string previewUrl,
        DateTime uploadedAtUtc)
    {
        return new TemplateMediaRecord
        {
            Id = id,
            UserId = userId,
            MediaType = "image",
            StoragePath = url,
            PreviewUrl = previewUrl,
            SourceType = sourceType,
            GenerationId = generationId,
            Url = url,
            FileName = Path.GetFileName(url.Replace('\\', '/')),
            ContentType = "image/png",
            Role = sourceType == "generation_result"
                ? TemplateMediaRole.GenerationOutputImage
                : TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = uploadedAtUtc,
            AttachedAtUtc = uploadedAtUtc
        };
    }

    private static TemplateGenerationJob CreateAdminMetricsJob(
        Guid templateId,
        TemplateGenerationStatus status,
        DateTime createdAtUtc)
    {
        return new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Status = status,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/admin-metrics-source.jpg",
            SourceImageFileName = "admin-metrics-source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = createdAtUtc,
            QueuedAtUtc = createdAtUtc,
            UpdatedAtUtc = createdAtUtc,
            CompletedAtUtc = status is TemplateGenerationStatus.Completed or TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled
                ? createdAtUtc
                : null
        };
    }

    [Fact]
    public async Task UserScopedGenerationOperations_ShouldReturnGenerationJobNotFound_ForForeignGenerationId()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var templateId = await CreateActiveImageTemplateAsync(service, "Scoped Portrait", "Portrait", ["scoped"]);
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = templateId,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "https://cdn.example.com/output.png",
            CreatedAtUtc = now.AddMinutes(-3),
            QueuedAtUtc = now.AddMinutes(-3),
            StartedAtUtc = now.AddMinutes(-2),
            CompletedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-3)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var fetched = await generationService.GetAsync(otherUserId, job.Id, CancellationToken.None);
        var markedRead = await generationService.MarkReadAsync(otherUserId, job.Id, isPremium: false, CancellationToken.None);
        var deleted = await generationService.DeleteAsync(otherUserId, job.Id, CancellationToken.None);
        var feedback = await generationService.RecordFeedbackAsync(
            new RecordTemplateGenerationFeedbackCommand(otherUserId, job.Id, 2, [], null, null),
            CancellationToken.None);

        Assert.True(fetched.IsFailure);
        Assert.True(markedRead.IsFailure);
        Assert.True(deleted.IsFailure);
        Assert.True(feedback.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, fetched.Error.Code);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, markedRead.Error.Code);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, deleted.Error.Code);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, feedback.Error.Code);
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
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "https://cdn.example.com/output.png",
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

        var history = await generationService.ListAsync(userId, new TemplateGenerationHistoryQuery("completed", null, 10), isPremium: false, CancellationToken.None);

        Assert.True(history.IsSuccess);
        var item = Assert.Single(history.Value);
        Assert.Equal(job.Id, item.GenerationId);
        Assert.Equal("Completed", item.Status);
        Assert.Equal("completed", item.Stage);
        Assert.Equal(100, item.ProgressPercent);
        Assert.True(item.IsUnread);
        Assert.Equal("Feedback Portrait", item.TemplateTitle);

        var unread = await generationService.GetUnreadCountAsync(userId, CancellationToken.None);
        Assert.True(unread.IsSuccess);
        Assert.Equal(1, unread.Value.Count);

        var markedRead = await generationService.MarkReadAsync(userId, job.Id, isPremium: false, CancellationToken.None);
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
        Assert.Equal(-1, persistedFeedback.Rating);
        Assert.Equal("GenerationResult", persistedFeedback.Type);
        Assert.Equal("face_distorted", persistedFeedback.Category);
        Assert.Equal("New", persistedFeedback.Status);
        Assert.Equal("Medium", persistedFeedback.Priority);
        Assert.Contains("face_distorted", persistedFeedback.SelectedReasons);
        Assert.Equal("The result differs from preview.", persistedFeedback.Comment);
        Assert.Equal("openai/gpt-image-2/edit", persistedFeedback.ModelUsed);
        Assert.Equal("image-request-123", persistedFeedback.ProviderRequestId);
        Assert.NotNull(persistedFeedback.GenerationDurationSeconds);
    }
}
