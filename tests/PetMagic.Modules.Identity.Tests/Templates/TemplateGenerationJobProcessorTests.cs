using System.Collections.Concurrent;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;
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

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed class TemplateGenerationJobProcessorTests
{
    [Fact]
    public async Task ProcessNextAsync_ShouldSanitizeDurableBillingFailureDiagnostics()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var template = CreateReadyImageTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        job.ChargedAtUtc = null;
        job.CompletedAtUtc = null;
        var billingCommand = new TemplateGenerationBillingCommand
        {
            Id = Guid.NewGuid(),
            GenerationId = job.Id,
            UserId = job.UserId,
            TokenCost = job.TokenCost,
            Status = TemplateGenerationBillingCommandStatuses.Pending,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        var billing = new TestTemplateGenerationBilling
        {
            ChargeError = new Error(
                "economy.insufficient_balance token=charge-code-secret",
                "charge failed token=charge-message-secret api_secret=charge-api-secret requestId=req-secret")
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        dbContext.TemplateGenerationBillingCommands.Add(billingCommand);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, billing: billing)
            .ProcessNextAsync(CancellationToken.None);

        var persistedJob = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        var persistedCommand = await dbContext.TemplateGenerationBillingCommands.SingleAsync(x => x.Id == billingCommand.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persistedJob.Status);
        Assert.Equal(TemplateGenerationBillingCommandStatuses.Failed, persistedCommand.Status);
        Assert.NotNull(persistedJob.LastErrorCode);
        Assert.NotNull(persistedJob.LastErrorMessage);
        Assert.NotNull(persistedCommand.LastErrorCode);
        Assert.NotNull(persistedCommand.LastErrorMessage);
        Assert.DoesNotContain("charge-code-secret", persistedJob.LastErrorCode, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("charge-message-secret", persistedJob.LastErrorMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("charge-api-secret", persistedCommand.LastErrorMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("req-secret", persistedCommand.LastErrorMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldSanitizeDurableGenerationFailureDiagnostics()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var template = CreateReadyImageTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        job.CompletedAtUtc = null;
        var logger = new CapturingLogger<TemplateGenerationJobProcessor>();
        var imageGenerator = new FailingImageGenerator(new Error(
            "templates.ai_provider_failed token=provider-code-secret",
            "provider failed token=provider-message-secret requestId=req-secret"));

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                imageGenerator: imageGenerator,
                logger: logger)
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.NotNull(persisted.LastErrorCode);
        Assert.NotNull(persisted.LastErrorMessage);
        Assert.DoesNotContain("provider-code-secret", persisted.LastErrorCode, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("provider-message-secret", persisted.LastErrorMessage, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("req-secret", persisted.LastErrorMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            logger.Entries,
            entry => entry.LogLevel == LogLevel.Error
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && !errorCode.Contains("provider-code-secret", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task RetryNextRefundAsync_ShouldSanitizeDurableRefundFailureCode()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var template = CreateReadyTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Failed, now.AddMinutes(-10));
        job.RefundAttemptCount = 1;
        job.RefundLastErrorCode = "economy.unavailable";
        job.RefundLastAttemptedAtUtc = now.AddMinutes(-5);
        var billing = new TestTemplateGenerationBilling
        {
            RefundError = new Error("economy.refund_failed token=refund-code-secret", "refund failed")
        };
        var logger = new CapturingLogger<TemplateGenerationJobProcessor>();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                billing: billing,
                options: CreateOptions(refundRetryDelayMilliseconds: 0),
                logger: logger)
            .RetryNextRefundAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Null(persisted.RefundedAtUtc);
        Assert.NotNull(persisted.RefundLastErrorCode);
        Assert.DoesNotContain("refund-code-secret", persisted.RefundLastErrorCode, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            logger.Entries,
            entry => entry.LogLevel == LogLevel.Warning
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && !errorCode.Contains("refund-code-secret", StringComparison.OrdinalIgnoreCase));
    }

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
    public async Task RetryNextRefundAsync_ShouldRetryPendingCancelledRefundAndPersistSuccess()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        var template = CreateReadyImageTemplate();
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Cancelled, now.AddMinutes(-10));
        job.CancelledAtUtc = now.AddMinutes(-10);
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
        Assert.Equal(TemplateGenerationStatus.Cancelled, persisted.Status);
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
    public async Task ProcessNextAsync_ShouldFailOrphanQueuedJobWithoutCharge()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now.AddMinutes(-10));
        job.ChargedAtUtc = null;
        job.CompletedAtUtc = null;
        job.QueuedAtUtc = now.AddMinutes(-10);
        job.UpdatedAtUtc = now.AddMinutes(-10);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            options: CreateOptions(orphanQueuedJobTimeoutMilliseconds: 1));

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Equal(TemplatesErrors.GenerationQueueOrphaned.Code, persisted.LastErrorCode);
        Assert.Null(persisted.ChargedAtUtc);
        Assert.Null(persisted.RefundedAtUtc);
        Assert.NotNull(persisted.CompletedAtUtc);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldProcessImage_WhenVideoSlotIsOccupied()
    {
        var databaseName = $"scheduler-media-isolation-{Guid.NewGuid():N}";
        var root = new InMemoryDatabaseRoot();
        var videoTemplate = CreateReadyTemplate();
        var imageTemplate = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var videoJob = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.Queued, now);
        videoJob.QueuedAtUtc = now.AddMinutes(-10);
        var imageJob = CreateGenerationJob(imageTemplate, TemplateGenerationStatus.Queued, now);
        imageJob.QueuedAtUtc = now.AddMinutes(-1);

        await using (var setup = CreateDbContext(databaseName, root))
        {
            setup.TemplateItems.AddRange(videoTemplate, imageTemplate);
            setup.TemplateGenerationJobs.AddRange(videoJob, imageJob);
            await setup.SaveChangesAsync();
        }

        await using var videoContext = CreateDbContext(databaseName, root);
        await using var imageContext = CreateDbContext(databaseName, root);
        var blockingVideo = new BlockingVideoMotionGenerator();
        var options = CreateOptions(globalMaxConcurrentGenerations: 2, imageMaxConcurrentGenerations: 1, videoMaxConcurrentGenerations: 1);
        var videoTask = CreateProcessor(videoContext, videoMotionGenerator: blockingVideo, options: options)
            .ProcessNextAsync(CancellationToken.None);
        await blockingVideo.Started.Task.WaitAsync(TimeSpan.FromSeconds(3));

        var imageProcessed = await CreateProcessor(imageContext, options: options)
            .ProcessNextAsync(CancellationToken.None);

        blockingVideo.Release.SetResult();
        await videoTask.WaitAsync(TimeSpan.FromSeconds(3));

        await using var verify = CreateDbContext(databaseName, root);
        Assert.True(imageProcessed);
        Assert.Equal(TemplateGenerationStatus.Completed, await verify.TemplateGenerationJobs
            .Where(x => x.Id == imageJob.Id)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldPreferPremiumWithinMediaLane()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var free = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        free.QueueTier = TemplateGenerationQueue.TierFree;
        free.QueuedAtUtc = now.AddMinutes(-1);
        var premium = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        premium.QueueTier = TemplateGenerationQueue.TierPremium;
        premium.QueuedAtUtc = now;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(free, premium);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, options: CreateOptions(queuePriorityAgingIntervalSeconds: 3600))
            .ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == free.Id)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(TemplateGenerationStatus.Completed, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == premium.Id)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldLetVideoBorrow_WhenImageQueueIsEmpty()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var activeVideo = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        activeVideo.CompletedAtUtc = null;
        activeVideo.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        var borrowedCandidate = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        borrowedCandidate.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(activeVideo, borrowedCandidate);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, options: CreateElasticBorrowingOptions())
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == borrowedCandidate.Id);
        Assert.True(processed);
        Assert.NotEqual(TemplateGenerationStatus.Queued, persisted.Status);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldNotLetVideoBorrow_WhenImageBacklogExceedsThreshold()
    {
        await using var dbContext = CreateDbContext();
        var videoTemplate = CreateReadyTemplate();
        var imageTemplate = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var activeVideo = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.ProviderQueued, now);
        activeVideo.CompletedAtUtc = null;
        activeVideo.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        var videoCandidate = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.Queued, now);
        videoCandidate.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        videoCandidate.QueueTier = TemplateGenerationQueue.TierPremium;
        var imageCandidates = Enumerable.Range(0, 4)
            .Select(index =>
            {
                var job = CreateGenerationJob(imageTemplate, TemplateGenerationStatus.Queued, now.AddSeconds(index));
                job.QueueMediaType = TemplateGenerationQueue.MediaTypeImage;
                job.QueueTier = TemplateGenerationQueue.TierFree;
                return job;
            })
            .ToArray();

        dbContext.TemplateItems.AddRange(videoTemplate, imageTemplate);
        dbContext.TemplateGenerationJobs.AddRange(activeVideo, videoCandidate);
        dbContext.TemplateGenerationJobs.AddRange(imageCandidates);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                options: CreateElasticBorrowingOptions(imageWaitBorrowThresholdSeconds: 1))
            .ProcessNextAsync(CancellationToken.None);

        var persistedVideo = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == videoCandidate.Id);
        var persistedImages = await dbContext.TemplateGenerationJobs
            .Where(x => x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage)
            .ToArrayAsync();
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, persistedVideo.Status);
        Assert.Contains(persistedImages, x => x.Status != TemplateGenerationStatus.Queued);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldNotExceedVideoBorrowMax()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var activeVideos = Enumerable.Range(0, 3)
            .Select(_ =>
            {
                var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
                job.CompletedAtUtc = null;
                job.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
                return job;
            })
            .ToArray();
        var candidate = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        candidate.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(activeVideos);
        dbContext.TemplateGenerationJobs.Add(candidate);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, options: CreateElasticBorrowingOptions(videoBorrowMax: 2))
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == candidate.Id);
        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldNotExceedVideoHardMax()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var activeVideos = Enumerable.Range(0, 4)
            .Select(_ =>
            {
                var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
                job.CompletedAtUtc = null;
                job.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
                return job;
            })
            .ToArray();
        var candidate = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        candidate.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(activeVideos);
        dbContext.TemplateGenerationJobs.Add(candidate);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, options: CreateElasticBorrowingOptions(videoMax: 4, videoBorrowMax: 3))
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == candidate.Id);
        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRespectGlobalCapBeforeBorrowing()
    {
        await using var dbContext = CreateDbContext();
        var videoTemplate = CreateReadyTemplate();
        var imageTemplate = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var activeJobs = new[]
        {
            CreateGenerationJob(videoTemplate, TemplateGenerationStatus.ProviderQueued, now),
            CreateGenerationJob(imageTemplate, TemplateGenerationStatus.ProviderQueued, now)
        };
        foreach (var job in activeJobs)
        {
            job.CompletedAtUtc = null;
        }

        activeJobs[0].QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        activeJobs[1].QueueMediaType = TemplateGenerationQueue.MediaTypeImage;
        var candidate = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.Queued, now);
        candidate.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;

        dbContext.TemplateItems.AddRange(videoTemplate, imageTemplate);
        dbContext.TemplateGenerationJobs.AddRange(activeJobs);
        dbContext.TemplateGenerationJobs.Add(candidate);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                options: CreateElasticBorrowingOptions(globalMax: 2, imageMax: 2, imageProtected: 1, videoReserved: 1, videoMax: 2, videoBorrowMax: 1))
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == candidate.Id);
        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldLetPremiumVideoBorrowBeforeFreeVideo()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var activeVideo = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        activeVideo.CompletedAtUtc = null;
        activeVideo.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        var free = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        free.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        free.QueueTier = TemplateGenerationQueue.TierFree;
        free.QueuedAtUtc = now.AddMinutes(-1);
        var premium = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        premium.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        premium.QueueTier = TemplateGenerationQueue.TierPremium;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(activeVideo, free, premium);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                options: CreateElasticBorrowingOptions(queuePriorityAgingIntervalSeconds: 3600))
            .ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == free.Id)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.NotEqual(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == premium.Id)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRestrictBorrowedVideoToConfiguredTiers()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var activeVideo = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        activeVideo.CompletedAtUtc = null;
        activeVideo.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        var free = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now.AddMinutes(-10));
        free.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        free.QueueTier = TemplateGenerationQueue.TierFree;
        var premium = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        premium.QueueMediaType = TemplateGenerationQueue.MediaTypeVideo;
        premium.QueueTier = TemplateGenerationQueue.TierPremium;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(activeVideo, free, premium);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(
                dbContext,
                options: CreateElasticBorrowingOptions(
                    queuePriorityAgingIntervalSeconds: 3600,
                    borrowingPriorityTiers: TemplateGenerationQueue.TierPremium))
            .ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == free.Id)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.NotEqual(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == premium.Id)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldSubmitAsyncImageAndReleaseClaim()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        var asyncImageGenerator = new AsyncSubmittingImageGenerator();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext, imageGenerator: asyncImageGenerator)
            .ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal(1, asyncImageGenerator.SubmitCount);
        Assert.Equal(0, asyncImageGenerator.CreateCount);
        Assert.Equal(TemplateGenerationStatus.ProviderQueued, persisted.Status);
        Assert.Equal("image-provider-request-1", persisted.PreprocessingProviderRequestId);
        Assert.Equal("image_generation", persisted.CurrentProviderStage);
        Assert.Equal("IN_QUEUE", persisted.ProviderStatus);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
        Assert.Null(persisted.ResultUrl);
        Assert.Null(persisted.CompletedAtUtc);
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldStageImageImportAndIgnoreDuplicateWebhook()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-1";
        job.PreprocessingProviderStatusUrl = "https://queue.fal.run/fal-ai/test/status/image-provider-request-1";
        job.PreprocessingProviderResponseUrl = "https://queue.fal.run/fal-ai/test/response/image-provider-request-1";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "IN_QUEUE";
        job.UsedPreprocessingModel = template.ImageModel;
        var imageGenerator = new AsyncSubmittingImageGenerator();
        var importer = new TrackingGeneratedMediaImporter();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            imageGenerator: imageGenerator,
            generatedMediaImporter: importer);
        var command = CreateFalWebhookCommand("image-provider-request-1", "OK");

        var processed = await processor.ProcessFalWebhookAsync(command, CancellationToken.None);
        var duplicate = await processor.ProcessFalWebhookAsync(command, CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed.IsSuccess);
        Assert.Equal("processed", processed.Value.Result);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal("ignored_import_pending", duplicate.Value.Result);
        Assert.Equal(TemplateGenerationStatus.ImportingMedia, persisted.Status);
        Assert.Equal("image-provider-request-1", persisted.PreprocessingProviderRequestId);
        Assert.NotNull(persisted.WebhookReceivedAtUtc);
        Assert.NotNull(persisted.ProviderCompletedAtUtc);
        Assert.Null(persisted.ImportStartedAtUtc);
        Assert.Null(persisted.MediaImportCompletedAtUtc);
        Assert.Equal("https://fal.example.test/generated-image.png", persisted.ProviderResultUrl);
        Assert.Null(persisted.ResultUrl);
        Assert.Equal(0, importer.ImageImportCount);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);

        var imported = await processor.ProcessNextAsync(CancellationToken.None);
        persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(imported, $"status={persisted.Status}; lock={persisted.LockedBy}; providerResult={persisted.ProviderResultUrl}; result={persisted.ResultUrl}; error={persisted.LastErrorCode}");
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.NotNull(persisted.ImportStartedAtUtc);
        Assert.NotNull(persisted.MediaImportCompletedAtUtc);
        Assert.Equal("templates-media/output.png", persisted.ResultUrl);
        Assert.Null(persisted.ProviderResultUrl);
        Assert.Equal("https://fal.example.test/generated-image.png", importer.GeneratedImageUrl);
        Assert.Equal(1, importer.ImageImportCount);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldIgnoreLateResultWhileCancellationIsPending()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.CancellationRequested, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-cancelling";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "IN_PROGRESS";
        job.CancellationPreviousStatus = TemplateGenerationStatus.ProviderProcessing;
        job.CancellationRequestedAtUtc = now;
        job.CancellationNextAttemptAtUtc = now.AddSeconds(5);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(dbContext);
        var webhook = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("image-provider-request-cancelling", "OK"),
            CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(webhook.IsSuccess);
        Assert.Equal("ignored_terminal", webhook.Value.Result);
        Assert.Equal(TemplateGenerationStatus.CancellationRequested, persisted.Status);
        Assert.NotNull(persisted.WebhookReceivedAtUtc);
        Assert.Null(persisted.ResultUrl);
        Assert.Null(persisted.CompletedAtUtc);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldSanitizeDurableWatermarkFailureCode()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-watermark-failure";
        job.PreprocessingProviderStatusUrl = "https://queue.fal.run/fal-ai/test/status/image-provider-request-watermark-failure";
        job.PreprocessingProviderResponseUrl = "https://queue.fal.run/fal-ai/test/response/image-provider-request-watermark-failure";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "IN_QUEUE";
        job.UsedPreprocessingModel = template.ImageModel;
        var imageGenerator = new AsyncSubmittingImageGenerator();
        var importer = new TrackingGeneratedMediaImporter();
        var logger = new CapturingLogger<TemplateGenerationJobProcessor>();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            imageGenerator: imageGenerator,
            generatedMediaImporter: importer,
            logger: logger,
            watermarkRenderer: new FailingWatermarkRenderer("watermark token=watermark-code-secret"));

        var webhookResult = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("image-provider-request-watermark-failure", "OK"),
            CancellationToken.None);
        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(webhookResult.IsSuccess);
        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.NotNull(persisted.WatermarkFailureCode);
        Assert.DoesNotContain("watermark-code-secret", persisted.WatermarkFailureCode, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            logger.Entries,
            entry => entry.LogLevel == LogLevel.Warning
                && entry.Properties.TryGetValue("ErrorCode", out var value)
                && value is string errorCode
                && !errorCode.Contains("watermark-code-secret", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldAdvanceVideoPreprocessThenCompleteVideo()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "preprocess-provider-request-1";
        job.PreprocessingProviderStatusUrl = "https://queue.fal.run/fal-ai/test/status/preprocess-provider-request-1";
        job.PreprocessingProviderResponseUrl = "https://queue.fal.run/fal-ai/test/response/preprocess-provider-request-1";
        job.CurrentProviderStage = "video_preprocessing";
        job.ProviderStatus = "IN_QUEUE";
        job.UsedPreprocessingModel = template.PreprocessingModel;
        var preprocessor = new AsyncSubmittingImagePreprocessor();
        var motionGenerator = new AsyncSubmittingVideoMotionGenerator();
        var importer = new TrackingGeneratedMediaImporter();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            imagePreprocessor: preprocessor,
            videoMotionGenerator: motionGenerator,
            generatedMediaImporter: importer);

        var preprocess = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("preprocess-provider-request-1", "OK"),
            CancellationToken.None);
        var afterPreprocess = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(preprocess.IsSuccess);
        Assert.Equal("processed", preprocess.Value.Result);
        Assert.Equal("https://fal.example.test/normalized-webhook.jpg", afterPreprocess.NormalizedImageUrl);
        Assert.Null(afterPreprocess.MotionProviderRequestId);
        Assert.Equal("video_preprocessing", afterPreprocess.CurrentProviderStage);
        Assert.Equal(TemplateGenerationStatus.ProviderQueued, afterPreprocess.Status);
        Assert.NotNull(afterPreprocess.ProviderCompletedAtUtc);
        Assert.NotNull(afterPreprocess.PreprocessingCompletedAtUtc);
        Assert.Null(afterPreprocess.LockedBy);
        Assert.Null(afterPreprocess.LockedAtUtc);

        var submittedVideo = await processor.ProcessNextAsync(CancellationToken.None);
        var afterVideoSubmit = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(submittedVideo);
        Assert.Equal("video-provider-request-1", afterVideoSubmit.MotionProviderRequestId);
        Assert.Equal("video_generation", afterVideoSubmit.CurrentProviderStage);
        Assert.Equal(TemplateGenerationStatus.ProviderQueued, afterVideoSubmit.Status);
        Assert.Null(afterVideoSubmit.LockedBy);
        Assert.Null(afterVideoSubmit.LockedAtUtc);

        var video = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("video-provider-request-1", "OK"),
            CancellationToken.None);
        var duplicateVideo = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("video-provider-request-1", "OK"),
            CancellationToken.None);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(video.IsSuccess);
        Assert.Equal("processed", video.Value.Result);
        Assert.True(duplicateVideo.IsSuccess);
        Assert.Equal("ignored_import_pending", duplicateVideo.Value.Result);
        Assert.Equal(TemplateGenerationStatus.ImportingMedia, persisted.Status);
        Assert.Equal("https://fal.example.test/generated-webhook.mp4", persisted.ProviderResultUrl);
        Assert.Null(persisted.ResultUrl);
        Assert.Equal(0, importer.VideoImportCount);
        Assert.NotNull(persisted.MotionGenerationCompletedAtUtc);
        Assert.Null(persisted.MediaImportCompletedAtUtc);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);

        var imported = await processor.ProcessNextAsync(CancellationToken.None);
        persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(imported, $"status={persisted.Status}; lock={persisted.LockedBy}; providerResult={persisted.ProviderResultUrl}; result={persisted.ResultUrl}; error={persisted.LastErrorCode}");
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal("templates-media/output.mp4", persisted.ResultUrl);
        Assert.Null(persisted.ProviderResultUrl);
        Assert.Equal("https://fal.example.test/generated-webhook.mp4", importer.GeneratedVideoUrl);
        Assert.Equal(1, importer.VideoImportCount);
        Assert.NotNull(persisted.MotionGenerationCompletedAtUtc);
        Assert.NotNull(persisted.MediaImportCompletedAtUtc);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldCreateVideoResultPreviewThumbnail()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ImportingMedia, now);
        job.CompletedAtUtc = null;
        job.ProviderResultUrl = "https://fal.example.test/generated-video.mp4";
        job.CurrentProviderStage = "video_generation";
        job.ProviderCompletedAtUtc = now.AddSeconds(-5);
        job.UsedKlingModel = template.KlingModel;
        var thumbnailGenerator = new RecordingVideoThumbnailGenerator();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            videoThumbnailGenerator: thumbnailGenerator);

        var imported = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs
            .Include(x => x.MediaRecords)
            .SingleAsync(x => x.Id == job.Id);
        var media = Assert.Single(persisted.MediaRecords, record => record.SourceType == "generation_result");
        Assert.True(imported);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal("templates-media/output.mp4", persisted.ResultUrl);
        Assert.Equal($"templates-media/generation-{job.Id:N}-result-preview.jpg", media.PreviewUrl);
        var resultThumbnailCall = Assert.Single(
            thumbnailGenerator.Calls,
            call => call.OutputFileName == $"generation-{job.Id:N}-result-preview.jpg");
        Assert.Equal("image/jpeg", resultThumbnailCall.ContentType);
        Assert.Equal($"users/{job.UserId:N}/generations/{job.Id:N}/result-preview.jpg", resultThumbnailCall.PreferredStorageKey);
        Assert.Equal("templates-media/output.mp4", resultThumbnailCall.OriginalStorageKey);
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldCompleteVideo_WhenThumbnailGenerationFails()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ImportingMedia, now);
        job.CompletedAtUtc = null;
        job.ProviderResultUrl = "https://fal.example.test/generated-video.mp4";
        job.CurrentProviderStage = "video_generation";
        job.ProviderCompletedAtUtc = now.AddSeconds(-5);
        job.UsedKlingModel = template.KlingModel;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            videoThumbnailGenerator: new FailingVideoThumbnailGenerator());

        var imported = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs
            .Include(x => x.MediaRecords)
            .SingleAsync(x => x.Id == job.Id);
        var media = Assert.Single(persisted.MediaRecords, record => record.SourceType == "generation_result");
        Assert.True(imported);
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal("templates-media/output.mp4", persisted.ResultUrl);
        Assert.Null(media.PreviewUrl);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldStagePollerResultAndIgnoreLaterWebhook()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-1";
        job.PreprocessingProviderStatusUrl = "https://queue.fal.test/status/image-provider-request-1";
        job.PreprocessingProviderResponseUrl = "https://queue.fal.test/response/image-provider-request-1";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "IN_QUEUE";
        job.ProviderStatusCheckedAtUtc = now.AddMinutes(-1);
        job.UsedPreprocessingModel = template.ImageModel;
        var imageGenerator = new AsyncSubmittingImageGenerator();
        var importer = new TrackingGeneratedMediaImporter();
        var falHandler = new CompletedFalQueueHandler();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            imageGenerator: imageGenerator,
            generatedMediaImporter: importer,
            falQueueClient: CreateFalQueueClient(dbContext, falHandler));

        var staged = await processor.ProcessNextAsync(CancellationToken.None);
        var webhook = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("image-provider-request-1", "OK"),
            CancellationToken.None);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);

        Assert.True(staged);
        Assert.True(webhook.IsSuccess);
        Assert.Equal("ignored_import_pending", webhook.Value.Result);
        Assert.Equal(TemplateGenerationStatus.ImportingMedia, persisted.Status);
        Assert.Equal("https://fal.example.test/generated-image.png", persisted.ProviderResultUrl);
        Assert.Equal(1, falHandler.StatusCount);
        Assert.Equal(1, falHandler.ResponseCount);
        Assert.Equal(0, importer.ImageImportCount);

        var imported = await processor.ProcessNextAsync(CancellationToken.None);
        persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(imported, $"status={persisted.Status}; lock={persisted.LockedBy}; providerResult={persisted.ProviderResultUrl}; result={persisted.ResultUrl}; error={persisted.LastErrorCode}");
        Assert.Equal(TemplateGenerationStatus.Completed, persisted.Status);
        Assert.Equal("templates-media/output.png", persisted.ResultUrl);
        Assert.Equal(1, importer.ImageImportCount);
        Assert.Null(persisted.ProviderResultUrl);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRefundOnceWhenStagedImportFails()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ImportingMedia, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-1";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "COMPLETED";
        job.ProviderCompletedAtUtc = now.AddSeconds(-5);
        job.ProviderResultUrl = "https://fal.example.test/generated-image.png";
        job.UsedPreprocessingModel = template.ImageModel;
        var billing = new TestTemplateGenerationBilling();
        var importer = new FailingGeneratedMediaImporter();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            billing: billing,
            imageGenerator: new AsyncSubmittingImageGenerator(),
            generatedMediaImporter: importer);

        var processed = await processor.ProcessNextAsync(CancellationToken.None);
        var duplicateWebhook = await processor.ProcessFalWebhookAsync(
            CreateFalWebhookCommand("image-provider-request-1", "OK"),
            CancellationToken.None);
        var retryRefund = await processor.RetryNextRefundAsync(CancellationToken.None);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);

        Assert.True(processed);
        Assert.True(duplicateWebhook.IsSuccess);
        Assert.Equal("ignored_terminal", duplicateWebhook.Value.Result);
        Assert.False(retryRefund);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.Equal(TemplatesErrors.MediaStorageFailed.Code, persisted.LastErrorCode);
        Assert.NotNull(persisted.RefundedAtUtc);
        Assert.Equal(1, importer.ImageImportCount);
        Assert.Single(billing.RefundedGenerationIds);
        Assert.Equal(job.Id, Assert.Single(billing.RefundedGenerationIds));
    }

    [Fact]
    public async Task ProcessFalWebhookAsync_ShouldRefundProviderFailureOnce()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.ProviderQueued, now);
        job.CompletedAtUtc = null;
        job.PreprocessingProviderRequestId = "image-provider-request-failed";
        job.CurrentProviderStage = "image_generation";
        job.ProviderStatus = "IN_QUEUE";
        job.UsedPreprocessingModel = template.ImageModel;
        var billing = new TestTemplateGenerationBilling();

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(dbContext, billing: billing);
        var command = CreateFalWebhookCommand("image-provider-request-failed", "ERROR", "provider failed");

        var failed = await processor.ProcessFalWebhookAsync(command, CancellationToken.None);
        var duplicate = await processor.ProcessFalWebhookAsync(command, CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(failed.IsSuccess);
        Assert.Equal("failed", failed.Value.Result);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal("ignored_terminal", duplicate.Value.Result);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.NotNull(persisted.RefundedAtUtc);
        Assert.Single(billing.RefundedGenerationIds);
        Assert.Equal(job.Id, Assert.Single(billing.RefundedGenerationIds));
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldAgeOldFreeJobAheadOfNewPremium()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var free = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        free.QueueTier = TemplateGenerationQueue.TierFree;
        free.QueuedAtUtc = now.AddMinutes(-40);
        var premium = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        premium.QueueTier = TemplateGenerationQueue.TierPremium;
        premium.QueuedAtUtc = now;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.AddRange(free, premium);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext).ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal(TemplateGenerationStatus.Completed, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == free.Id)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == premium.Id)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRespectGlobalCapAcrossMediaLanes()
    {
        var databaseName = $"scheduler-global-cap-{Guid.NewGuid():N}";
        var root = new InMemoryDatabaseRoot();
        var imageTemplate = CreateReadyImageTemplate();
        var videoTemplate = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var imageJob = CreateGenerationJob(imageTemplate, TemplateGenerationStatus.Queued, now);
        imageJob.QueuedAtUtc = now.AddMinutes(-1);
        var videoJob = CreateGenerationJob(videoTemplate, TemplateGenerationStatus.Queued, now);
        videoJob.QueuedAtUtc = now;

        await using (var setup = CreateDbContext(databaseName, root))
        {
            setup.TemplateItems.AddRange(imageTemplate, videoTemplate);
            setup.TemplateGenerationJobs.AddRange(imageJob, videoJob);
            await setup.SaveChangesAsync();
        }

        await using var imageContext = CreateDbContext(databaseName, root);
        await using var videoContext = CreateDbContext(databaseName, root);
        var blockingImage = new BlockingImageGenerator();
        var options = CreateOptions(globalMaxConcurrentGenerations: 1, imageMaxConcurrentGenerations: 1, videoMaxConcurrentGenerations: 1);
        var imageTask = CreateProcessor(imageContext, imageGenerator: blockingImage, options: options)
            .ProcessNextAsync(CancellationToken.None);
        await blockingImage.Started.Task.WaitAsync(TimeSpan.FromSeconds(3));

        var secondProcessed = await CreateProcessor(videoContext, options: options)
            .ProcessNextAsync(CancellationToken.None);

        blockingImage.Release.SetResult();
        await imageTask.WaitAsync(TimeSpan.FromSeconds(3));

        Assert.False(secondProcessed);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldReuseNormalizedImage_WhenVideoRetryAlreadyPreprocessed()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Queued, now);
        job.NormalizedImageUrl = "https://cdn.example.test/normalized-existing.jpg";
        job.PreprocessingCompletedAtUtc = now.AddMinutes(-5);

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var preprocessor = new CountingImagePreprocessor();
        var motionGenerator = new CapturingVideoMotionGenerator();
        var processed = await CreateProcessor(
                dbContext,
                imagePreprocessor: preprocessor,
                videoMotionGenerator: motionGenerator)
            .ProcessNextAsync(CancellationToken.None);

        Assert.True(processed);
        Assert.Equal(0, preprocessor.CallCount);
        Assert.Equal("https://cdn.example.test/normalized-existing.jpg", motionGenerator.NormalizedImageUrl);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldNotClaimCancelledQueuedJob()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Cancelled, now);
        job.CompletedAtUtc = now.AddMinutes(-1);
        job.CancelledAtUtc = now.AddMinutes(-1);
        job.QueuedAtUtc = now.AddMinutes(-10);
        job.QueueMediaType = TemplateGenerationQueue.MediaTypeImage;
        job.QueueTier = TemplateGenerationQueue.TierPremium;

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processed = await CreateProcessor(dbContext).ProcessNextAsync(CancellationToken.None);

        Assert.False(processed);
        Assert.Equal(TemplateGenerationStatus.Cancelled, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == job.Id)
            .Select(x => x.Status)
            .SingleAsync());
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
        Assert.Equal(job.Id, notification.GenerationId);
        Assert.Equal(userId, notification.UserId);
        Assert.Equal(petId, notification.PetId);
        Assert.Equal(template.Id, notification.TemplateId);
        Assert.True(notification.IsTemplateOfTheDay);
        Assert.True(notification.IsPremium);
    }

    [Fact]
    public async Task NotifyGamificationAsync_ShouldLogStructuredWarning_WhenGamificationSyncFails()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = template.TokenCost,
            CreatedAtUtc = now.AddMinutes(-1),
            QueuedAtUtc = now.AddMinutes(-1),
            ChargedAtUtc = now.AddMinutes(-1),
            CompletedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var logger = new CapturingLogger<TemplateGenerationJobProcessor>();
        var processor = CreateProcessor(
            dbContext,
            gamificationService: new ThrowingGamificationService(),
            economyService: PremiumEconomyServiceProxy.Create(isPremium: true),
            logger: logger);

        var notifyMethod = typeof(TemplateGenerationJobProcessor)
            .GetMethod("NotifyGamificationAsync", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(notifyMethod);
        var task = Assert.IsAssignableFrom<Task>(notifyMethod!.Invoke(processor, [job, CancellationToken.None]));
        await task;

        var entry = Assert.Single(logger.Entries, x => x.LogLevel == LogLevel.Warning);
        Assert.Contains("Template generation gamification sync failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("notify_gamification", entry.Properties["Operation"]);
        Assert.False(entry.Properties.ContainsKey("JobId"));
        Assert.False(entry.Properties.ContainsKey("UserId"));
        Assert.False(entry.Properties.ContainsKey("TemplateId"));
        Assert.Equal(SafeLogValues.StableHash(job.Id.ToString("D")), entry.Properties["JobIdHash"]);
        Assert.Equal(SafeLogValues.StableHash(userId.ToString("D")), entry.Properties["UserIdHash"]);
        Assert.Equal(SafeLogValues.StableHash(template.Id.ToString("D")), entry.Properties["TemplateIdHash"]);
        Assert.Equal(true, entry.Properties["HasEconomyService"]);
        Assert.Equal(true, entry.Properties["GenerationStillCompleted"]);
        Assert.Equal("InvalidOperationException", entry.Properties["ExceptionType"]);
        Assert.Null(entry.Exception);
    }

    [Fact]
    public async Task ProcessNextPendingGamificationAsync_ShouldPersistRetryAndCompleteOnReplay()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = template.TokenCost,
            SourceImageUrl = "http://localhost:5000/templates-media/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            SourceImageFileSizeBytes = 1024,
            CreatedAtUtc = now.AddMinutes(-2),
            QueuedAtUtc = now.AddMinutes(-2),
            ChargedAtUtc = now.AddMinutes(-2),
            CompletedAtUtc = now.AddMinutes(-1),
            UpdatedAtUtc = now.AddMinutes(-1)
        };
        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var failingProcessor = CreateProcessor(
            dbContext,
            gamificationService: new ThrowingGamificationService(),
            economyService: PremiumEconomyServiceProxy.Create(isPremium: false));

        Assert.True(await failingProcessor.ProcessNextPendingGamificationAsync(CancellationToken.None));
        Assert.Null(job.GamificationProcessedAtUtc);
        Assert.Equal(1, job.GamificationAttemptCount);
        Assert.Equal("templates.gamification_sync_failed", job.GamificationLastErrorCode);
        Assert.True(job.GamificationNextAttemptAtUtc > now);

        job.GamificationNextAttemptAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();
        var recordingGamification = new RecordingGamificationService();
        var succeedingProcessor = CreateProcessor(
            dbContext,
            gamificationService: recordingGamification,
            economyService: PremiumEconomyServiceProxy.Create(isPremium: false));

        Assert.True(await succeedingProcessor.ProcessNextPendingGamificationAsync(CancellationToken.None));
        Assert.Equal(job.Id, Assert.Single(recordingGamification.CompletedGenerations).GenerationId);
        Assert.NotNull(job.GamificationProcessedAtUtc);
        Assert.Null(job.GamificationNextAttemptAtUtc);
        Assert.Null(job.GamificationLastErrorCode);
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
    public async Task ProcessNextAsync_ShouldPreserveProviderRequestIds_WhenRecoveringStaleProcessingJob()
    {
        await using var dbContext = CreateDbContext();
        var template = CreateReadyImageTemplate();
        var now = DateTime.UtcNow;
        var job = CreateGenerationJob(template, TemplateGenerationStatus.Processing, now.AddMinutes(-20));
        job.LockedAtUtc = now.AddMinutes(-20);
        job.LockedBy = "stale-worker";
        job.PreprocessingProviderRequestId = "provider-request-existing";

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var processor = CreateProcessor(
            dbContext,
            imageGenerator: new FailingImageGenerator(),
            options: CreateOptions(staleProcessingRecoveryDelayMilliseconds: 0));

        var processed = await processor.ProcessNextAsync(CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.True(processed);
        Assert.Equal("provider-request-existing", persisted.PreprocessingProviderRequestId);
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

    private static TemplatesDbContext CreateDbContext(string databaseName, InMemoryDatabaseRoot root)
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase(databaseName, root)
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
        IVideoThumbnailGenerator? videoThumbnailGenerator = null,
        TemplatesOptions? options = null,
        IGamificationService? gamificationService = null,
        IEconomyService? economyService = null,
        FalQueueClient? falQueueClient = null,
        ILogger<TemplateGenerationJobProcessor>? logger = null,
        ITemplateWatermarkRenderer? watermarkRenderer = null)
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
            videoThumbnailGenerator: videoThumbnailGenerator ?? new NoopVideoThumbnailGenerator(),
            billing: billing ?? new TestTemplateGenerationBilling(),
            realtimeService: new RecordingTemplateFeedRealtimeService(),
            pushNotificationSender: new NoopPushNotificationSender(),
            options: options ?? CreateOptions(),
            logger: logger ?? NullLogger<TemplateGenerationJobProcessor>.Instance,
            falQueueClient: falQueueClient,
            watermarkRenderer: watermarkRenderer ?? new PassthroughWatermarkRenderer(),
            gamificationService: gamificationService,
            economyService: economyService);
    }

    private static FalQueueClient CreateFalQueueClient(
        TemplatesDbContext dbContext,
        HttpMessageHandler handler)
    {
        var options = CreateOptions();

        return new FalQueueClient(
            new FixedHttpClientFactory(new HttpClient(handler)
            {
                BaseAddress = new Uri("https://queue.fal.test")
            }),
            options,
            new TemplateAiProviderRateLimiter(dbContext, options),
            NullLogger<FalQueueClient>.Instance);
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

    private sealed class NoopVideoThumbnailGenerator : IVideoThumbnailGenerator
    {
        public Task<StoredMediaResponse?> CreateThumbnailAsync(
            StoredMediaResponse original,
            Guid generationId,
            string outputFileName,
            string? preferredStorageKey,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<StoredMediaResponse?>(null);
        }
    }

    private sealed class RecordingVideoThumbnailGenerator : IVideoThumbnailGenerator
    {
        public List<ThumbnailCall> Calls { get; } = [];

        public Task<StoredMediaResponse?> CreateThumbnailAsync(
            StoredMediaResponse original,
            Guid generationId,
            string outputFileName,
            string? preferredStorageKey,
            CancellationToken cancellationToken)
        {
            var contentType = "image/jpeg";
            Calls.Add(new ThumbnailCall(outputFileName, preferredStorageKey, original.StorageKey, contentType));
            return Task.FromResult<StoredMediaResponse?>(new StoredMediaResponse(
                $"http://localhost:5000/templates-media/{outputFileName}",
                $"templates-media/{outputFileName}",
                outputFileName,
                contentType,
                2048,
                null));
        }

        public sealed record ThumbnailCall(
            string OutputFileName,
            string? PreferredStorageKey,
            string OriginalStorageKey,
            string ContentType);
    }

    private sealed class FailingVideoThumbnailGenerator : IVideoThumbnailGenerator
    {
        public Task<StoredMediaResponse?> CreateThumbnailAsync(
            StoredMediaResponse original,
            Guid generationId,
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

    private sealed class FailingWatermarkRenderer(string code) : ITemplateWatermarkRenderer
    {
        public Task<Result<StoredMediaResponse>> CreateWatermarkedCopyAsync(
            StoredMediaResponse original,
            TemplateType mediaType,
            Guid generationId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<StoredMediaResponse>(new Error(code, "Watermark failed.")));
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

        public ValueTask PublishTemplatesFeedInvalidatedAsync(
            TemplateFeedInvalidationPayload payload,
            CancellationToken cancellationToken = default)
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
            Guid generationId,
            Guid userId,
            Guid petId,
            Guid templateId,
            bool isTemplateOfTheDay,
            bool isPremium,
            CancellationToken cancellationToken)
        {
            CompletedGenerations.Add(new GamificationCompletionCall(
                generationId,
                userId,
                petId,
                templateId,
                isTemplateOfTheDay,
                isPremium));
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

        public Task RecordCreationSharedAsync(Guid generationId, Guid userId, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private sealed class ThrowingGamificationService : IGamificationService
    {
        public Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
            Guid generationId,
            Guid userId,
            Guid petId,
            Guid templateId,
            bool isTemplateOfTheDay,
            bool isPremium,
            CancellationToken cancellationToken)
        {
            throw new InvalidOperationException("gamification backend unavailable");
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

        public Task RecordCreationSharedAsync(Guid generationId, Guid userId, CancellationToken cancellationToken)
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
        Guid GenerationId,
        Guid UserId,
        Guid PetId,
        Guid TemplateId,
        bool IsTemplateOfTheDay,
        bool IsPremium);

    private static TemplatesOptions CreateOptions(
        int refundRetryDelayMilliseconds = 30_000,
        int retentionDays = 7,
        int staleProcessingRecoveryDelayMilliseconds = 900_000,
        int orphanQueuedJobTimeoutMilliseconds = 120_000,
        int globalMaxConcurrentGenerations = 3,
        int imageMaxConcurrentGenerations = 2,
        int videoMaxConcurrentGenerations = 1,
        int imageReservedConcurrentGenerations = 0,
        int imageProtectedConcurrentGenerations = 0,
        int videoReservedConcurrentGenerations = 0,
        int videoBorrowMaxConcurrentGenerations = 0,
        bool enableElasticLaneBorrowing = false,
        int imageWaitBorrowThresholdSeconds = 120,
        string borrowingPriorityTiers = "premium,privileged,admin,free",
        int queuePriorityAgingIntervalSeconds = 60)
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
            GlobalMaxConcurrentGenerations = globalMaxConcurrentGenerations,
            ImageReservedConcurrentGenerations = imageReservedConcurrentGenerations,
            ImageMaxConcurrentGenerations = imageMaxConcurrentGenerations,
            ImageProtectedConcurrentGenerations = imageProtectedConcurrentGenerations,
            VideoReservedConcurrentGenerations = videoReservedConcurrentGenerations,
            VideoMaxConcurrentGenerations = videoMaxConcurrentGenerations,
            VideoBorrowMaxConcurrentGenerations = videoBorrowMaxConcurrentGenerations,
            EnableElasticLaneBorrowing = enableElasticLaneBorrowing,
            AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds = imageWaitBorrowThresholdSeconds,
            BorrowingPriorityTiers = borrowingPriorityTiers,
            QueuePriorityAgingIntervalSeconds = queuePriorityAgingIntervalSeconds,
            MaxAiProviderRequestsPerMinute = 100,
            Fal = new FalAiOptions
            {
                ApiKey = "test-fal-key",
                QueueBaseUrl = "https://queue.fal.test",
                PollIntervalMilliseconds = 250,
                MaxPollingAttempts = 1
            },
            JobLockTimeoutMilliseconds = staleProcessingRecoveryDelayMilliseconds,
            StaleProcessingRecoveryDelayMilliseconds = staleProcessingRecoveryDelayMilliseconds,
            OrphanQueuedJobTimeoutMilliseconds = orphanQueuedJobTimeoutMilliseconds,
            MaxGenerationAttempts = 3,
            MaxRefundAttempts = 3,
            RefundRetryDelayMilliseconds = refundRetryDelayMilliseconds,
            GenerationRetentionDaysAfterCompletion = retentionDays
        };
    }

    private static TemplatesOptions CreateElasticBorrowingOptions(
        int globalMax = 4,
        int imageMax = 3,
        int imageReserved = 2,
        int imageProtected = 2,
        int videoReserved = 1,
        int videoMax = 4,
        int videoBorrowMax = 3,
        int imageWaitBorrowThresholdSeconds = 120,
        string borrowingPriorityTiers = "premium,privileged,admin,free",
        int queuePriorityAgingIntervalSeconds = 60)
    {
        return CreateOptions(
            globalMaxConcurrentGenerations: globalMax,
            imageMaxConcurrentGenerations: imageMax,
            videoMaxConcurrentGenerations: videoMax,
            imageReservedConcurrentGenerations: imageReserved,
            imageProtectedConcurrentGenerations: imageProtected,
            videoReservedConcurrentGenerations: videoReserved,
            videoBorrowMaxConcurrentGenerations: videoBorrowMax,
            enableElasticLaneBorrowing: true,
            imageWaitBorrowThresholdSeconds: imageWaitBorrowThresholdSeconds,
            borrowingPriorityTiers: borrowingPriorityTiers,
            queuePriorityAgingIntervalSeconds: queuePriorityAgingIntervalSeconds);
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
                ? values.ToDictionary(x => x.Key, x => x.Value)
                : new Dictionary<string, object?>();
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel LogLevel,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
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
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = TemplateGenerationQueue.TierFree,
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

    private static FalProviderWebhookCommand CreateFalWebhookCommand(
        string requestId,
        string status,
        string? error = null)
    {
        using var payload = JsonDocument.Parse("{}");
        return new FalProviderWebhookCommand(
            requestId,
            status,
            payload.RootElement.Clone(),
            error,
            DateTime.UtcNow);
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

    private sealed class FailingImageGenerator : IImageGenerator
    {
        private readonly Error failure;

        public FailingImageGenerator(Error? failure = null)
        {
            this.failure = failure ?? TemplatesErrors.AiProviderFailed;
        }

        public Task<Result<ImageGenerationResult>> CreateAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<ImageGenerationResult>(failure));
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

    private sealed class AsyncSubmittingImageGenerator : IImageGenerator, IAsyncImageGenerationQueue
    {
        public int SubmitCount { get; private set; }
        public int CreateCount { get; private set; }

        public Task<Result<ImageGenerationResult>> CreateAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            CreateCount++;
            return Task.FromResult(Result.Success(new ImageGenerationResult(
                "https://fal.example.test/generated-image.png",
                "image-provider-request-sync",
                3.5)));
        }

        public Task<Result<ProviderQueueSubmission>> SubmitAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            SubmitCount++;
            return Task.FromResult(Result.Success(new ProviderQueueSubmission(
                "image-provider-request-1",
                "https://queue.fal.run/fal-ai/test/status/image-provider-request-1",
                "https://queue.fal.run/fal-ai/test/response/image-provider-request-1")));
        }

        public Result<ImageGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
        {
            return Result.Success(new ImageGenerationResult(
                "https://fal.example.test/generated-image.png",
                requestId,
                inferenceTimeSeconds));
        }
    }

    private sealed class AsyncSubmittingImagePreprocessor : IImagePreprocessor, IAsyncImagePreprocessingQueue
    {
        public Task<Result<ImagePreprocessResult>> NormalizeAsync(
            string originalImageUrl,
            string model,
            string prompt,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ImagePreprocessResult(
                "https://fal.example.test/normalized-sync.jpg",
                "preprocess-provider-sync",
                1.25)));
        }

        public Task<Result<ProviderQueueSubmission>> SubmitAsync(
            string originalImageUrl,
            string model,
            string prompt,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ProviderQueueSubmission(
                "preprocess-provider-request-1",
                "https://queue.fal.run/fal-ai/test/status/preprocess-provider-request-1",
                "https://queue.fal.run/fal-ai/test/response/preprocess-provider-request-1")));
        }

        public Result<ImagePreprocessResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
        {
            return Result.Success(new ImagePreprocessResult(
                "https://fal.example.test/normalized-webhook.jpg",
                requestId,
                inferenceTimeSeconds));
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

    private sealed class AsyncSubmittingVideoMotionGenerator : IVideoMotionGenerator, IAsyncVideoMotionGenerationQueue
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
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated-sync.mp4",
                "video-provider-sync",
                8.4)));
        }

        public Task<Result<ProviderQueueSubmission>> SubmitAsync(
            string normalizedImageUrl,
            string referenceVideoUrl,
            string characterOrientation,
            bool keepOriginalSound,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new ProviderQueueSubmission(
                "video-provider-request-1",
                "https://queue.fal.run/fal-ai/test/status/video-provider-request-1",
                "https://queue.fal.run/fal-ai/test/response/video-provider-request-1")));
        }

        public Result<VideoMotionGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
        {
            return Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated-webhook.mp4",
                requestId,
                inferenceTimeSeconds));
        }
    }

    private sealed class BlockingImageGenerator : IImageGenerator
    {
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<Result<ImageGenerationResult>> CreateAsync(
            string sourceImageUrl,
            string prompt,
            string model,
            int? seed,
            CancellationToken cancellationToken)
        {
            Started.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return Result.Success(new ImageGenerationResult(
                "https://fal.example.test/generated-image.png",
                "image-request-blocking",
                1.5));
        }
    }

    private sealed class BlockingVideoMotionGenerator : IVideoMotionGenerator
    {
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

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
            Started.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated.mp4",
                "motion-request-blocking",
                8.4));
        }
    }

    private sealed class CountingImagePreprocessor : IImagePreprocessor
    {
        public int CallCount { get; private set; }

        public Task<Result<ImagePreprocessResult>> NormalizeAsync(
            string originalImageUrl,
            string model,
            string prompt,
            CancellationToken cancellationToken)
        {
            CallCount++;
            return Task.FromResult(Result.Success(new ImagePreprocessResult(
                "http://localhost:5000/templates-media/normalized.jpg",
                "preprocess-request-counting",
                1.25)));
        }
    }

    private sealed class CapturingVideoMotionGenerator : IVideoMotionGenerator
    {
        public string? NormalizedImageUrl { get; private set; }

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
            NormalizedImageUrl = normalizedImageUrl;
            return Task.FromResult(Result.Success(new VideoMotionGenerationResult(
                "https://fal.example.test/generated.mp4",
                "motion-request-capturing",
                8.4)));
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
        public int VideoImportCount { get; private set; }
        public int ImageImportCount { get; private set; }

        public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            GeneratedVideoUrl = generatedVideoUrl;
            VideoImportCount++;
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
            ImageImportCount++;
            return Task.FromResult(Result.Success(new StoredMediaResponse(
            "http://localhost:5000/templates-media/output.png",
            "templates-media/output.png",
            "output.png",
            "image/png",
            1024,
            null)));
        }
    }

    private sealed class FailingGeneratedMediaImporter : IGeneratedMediaImporter
    {
        public int VideoImportCount { get; private set; }
        public int ImageImportCount { get; private set; }

        public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
        {
            VideoImportCount++;
            return Task.FromResult(Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed));
        }

        public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
        {
            ImageImportCount++;
            return Task.FromResult(Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed));
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

        public Error? ChargeError { get; init; }

        public Error? RefundError { get; init; }

        public Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(ChargeError is null ? Result.Success() : Result.Failure(ChargeError));
        }

        public Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            RefundedGenerationIds.Add(generationId);
            return Task.FromResult(RefundError is null ? Result.Success() : Result.Failure(RefundError));
        }

        public Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(0));
        }
    }

    private sealed class FixedHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class CompletedFalQueueHandler : HttpMessageHandler
    {
        public int StatusCount { get; private set; }
        public int ResponseCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri?.AbsolutePath ?? string.Empty;
            if (path.StartsWith("/status/", StringComparison.Ordinal))
            {
                StatusCount++;
                return JsonAsync(
                    """
                    {
                      "status": "COMPLETED",
                      "request_id": "image-provider-request-1",
                      "metrics": {
                        "inference_time": 1.25
                      }
                    }
                    """);
            }

            if (path.StartsWith("/response/", StringComparison.Ordinal))
            {
                ResponseCount++;
                return JsonAsync(
                    """
                    {
                      "images": [
                        {
                          "url": "https://fal.example.test/generated-image.png"
                        }
                      ]
                    }
                    """);
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static Task<HttpResponseMessage> JsonAsync(string json)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
        }
    }
}
