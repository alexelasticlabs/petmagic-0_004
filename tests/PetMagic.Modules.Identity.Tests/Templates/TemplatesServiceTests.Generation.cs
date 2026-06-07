using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{

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
    public async Task StartAsync_ShouldPersistCurrentCorrelationId()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Correlated Portrait", "Portrait", ["correlation"]);
        var userId = Guid.NewGuid();

        using var correlationScope = CorrelationContext.Push("generation-create-correlation");
        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "correlated-key",
                "correlated-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal("generation-create-correlation", persisted.CorrelationId);
    }

    [Fact]
    public async Task StartAdminTestAsync_ShouldPersistCurrentCorrelationId()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Correlated Portrait", "Portrait", ["admin-correlation"]);

        using var correlationScope = CorrelationContext.Push("admin-generation-correlation");
        var started = await generationService.StartAdminTestAsync(
            templateId,
            new TemplateAssetCommand("https://cdn.example.com/admin-source.jpg", "admin-source.jpg", "image/jpeg", 2048, null),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal("admin-generation-correlation", persisted.CorrelationId);
    }

    [Fact]
    public async Task StartAsync_ShouldReturnExistingActiveJob_WhenRequestHashMatches()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Idempotent Portrait", "Portrait", ["idempotent"]);
        var userId = Guid.NewGuid();
        var source = new TemplateAssetCommand("https://cdn.example.com/source-a.jpg", "source-a.jpg", "image/jpeg", 2048, null);

        var first = await generationService.StartAsync(
            new StartTemplateGenerationCommand(userId, templateId, source, null, "request-hash-1", 3),
            CancellationToken.None);

        var second = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-b.jpg", "source-b.jpg", "image/jpeg", 2048, null),
                null,
                "request-hash-1",
                3),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(first.Value.GenerationId, second.Value.GenerationId);
        Assert.Equal(1, await dbContext.TemplateGenerationJobs.CountAsync());
        Assert.Equal(1, second.Value.QueuePosition);
        Assert.NotNull(second.Value.EstimatedWaitSeconds);
    }

    [Fact]
    public async Task StartAsync_ShouldReturnExistingActiveJob_WhenIdempotencyKeyMatches()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Idempotency Key Portrait", "Portrait", ["idempotency-key"]);
        var userId = Guid.NewGuid();

        var first = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-a.jpg", "source-a.jpg", "image/jpeg", 2048, null),
                "same-key",
                "request-hash-a",
                3),
            CancellationToken.None);

        var second = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-b.jpg", "source-b.jpg", "image/jpeg", 2048, null),
                "same-key",
                "request-hash-b",
                3),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(first.Value.GenerationId, second.Value.GenerationId);
        Assert.Equal(1, await dbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldCreateSeparateJobs_WhenDuplicateKeysBelongToDifferentUsers()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Per User Portrait", "Portrait", ["per-user"]);
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();

        var first = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                firstUserId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-a.jpg", "source-a.jpg", "image/jpeg", 2048, null),
                "same-key",
                "same-hash",
                1),
            CancellationToken.None);

        var second = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                secondUserId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-b.jpg", "source-b.jpg", "image/jpeg", 2048, null),
                "same-key",
                "same-hash",
                1),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.NotEqual(first.Value.GenerationId, second.Value.GenerationId);
        Assert.Equal(2, await dbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldFail_WhenActiveGenerationLimitIsReached()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Limited Portrait", "Portrait", ["limit"]);
        var userId = Guid.NewGuid();

        var first = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-a.jpg", "source-a.jpg", "image/jpeg", 2048, null),
                null,
                "limit-hash-1",
                1),
            CancellationToken.None);

        var second = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-b.jpg", "source-b.jpg", "image/jpeg", 2048, null),
                null,
                "limit-hash-2",
                1),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsFailure);
        Assert.Equal(TemplatesErrors.ActiveGenerationLimitReached.Code, second.Error.Code);
    }

    [Fact]
    public async Task StartAsync_ShouldFail_WhenQueueMaxSizeIsReached()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var options = CreateTemplatesOptions(queueMaxSize: 1);
        var generationService = CreateGenerationService(dbContext, options);
        var templateId = await CreateActiveImageTemplateAsync(service, "Overloaded Portrait", "Portrait", ["overload"]);
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();

        var first = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                firstUserId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-a.jpg", "source-a.jpg", "image/jpeg", 2048, null),
                null,
                "overload-hash-1",
                1),
            CancellationToken.None);

        var second = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                secondUserId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-b.jpg", "source-b.jpg", "image/jpeg", 2048, null),
                null,
                "overload-hash-2",
                1),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationQueueOverloaded.Code, second.Error.Code);
    }

    [Fact]
    public async Task StartAsync_ShouldIgnoreCompletedAndFailedJobs_ForActiveLimit()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Terminal Portrait", "Portrait", ["terminal"]);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/completed.jpg",
                SourceImageFileName = "completed.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-4),
                CompletedAtUtc = now.AddMinutes(-4)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/failed.jpg",
                SourceImageFileName = "failed.jpg",
                SourceImageContentType = "image/jpeg",
                LastErrorCode = "templates.ai_provider_failed",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-2),
                CompletedAtUtc = now.AddMinutes(-2)
            });
        await dbContext.SaveChangesAsync();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                null,
                "terminal-hash",
                1),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal("Queued", started.Value.Status);
    }

    [Fact]
    public async Task StartAsync_ShouldCalculateQueueMetricsFromQueuedJobsOnly()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var options = CreateTemplatesOptions(globalMaxConcurrentGenerations: 2, estimatedImageGenerationSeconds: 40);
        var generationService = CreateGenerationService(dbContext, options);
        var templateId = await CreateActiveImageTemplateAsync(service, "Queue Metric Portrait", "Portrait", ["queue"]);
        var now = DateTime.UtcNow;

        dbContext.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/completed.jpg",
                SourceImageFileName = "completed.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-5),
                QueuedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-4),
                CompletedAtUtc = now.AddMinutes(-4)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/failed.jpg",
                SourceImageFileName = "failed.jpg",
                SourceImageContentType = "image/jpeg",
                LastErrorCode = "templates.ai_provider_failed",
                CreatedAtUtc = now.AddMinutes(-4),
                QueuedAtUtc = now.AddMinutes(-4),
                UpdatedAtUtc = now.AddMinutes(-3),
                CompletedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/queued.jpg",
                SourceImageFileName = "queued.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-3),
                QueuedAtUtc = now.AddMinutes(-3),
                UpdatedAtUtc = now.AddMinutes(-3),
                ChargedAtUtc = now.AddMinutes(-3)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
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

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                null,
                "queue-metrics-hash",
                10),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal(2, started.Value.QueuePosition);
        Assert.Equal(40, started.Value.EstimatedWaitSeconds);
    }

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
            new AdminTemplateGenerationsQuery("canceled", null, null, null, 0, 10),
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
        var firstQueuedJobId = Guid.NewGuid();
        var secondQueuedJobId = Guid.NewGuid();
        var processingJobId = Guid.NewGuid();

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
                QueuedAtUtc = now.AddMinutes(-4),
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
                QueuedAtUtc = now.AddMinutes(-3),
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

        var history = await generationService.ListAsync(userId, new TemplateGenerationHistoryQuery("all", null, 10), CancellationToken.None);

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
        var markedRead = await generationService.MarkReadAsync(otherUserId, job.Id, CancellationToken.None);
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
            Status = TemplateGenerationStatus.Succeeded,
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

}
