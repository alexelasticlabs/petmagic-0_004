using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
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
    public async Task StartAsync_ShouldSettleDurableBillingCommandBeforeJobBecomesClaimable()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Billing Command Portrait", "Portrait", ["billing"]);
        var userId = Guid.NewGuid();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "billing-command-key",
                "billing-command-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsSuccess);

        var persisted = await dbContext.TemplateGenerationJobs
            .SingleAsync(x => x.Id == started.Value.GenerationId);
        var command = await dbContext.TemplateGenerationBillingCommands
            .SingleAsync(x => x.GenerationId == started.Value.GenerationId);

        Assert.NotNull(persisted.ChargedAtUtc);
        Assert.Equal(TemplateGenerationBillingCommandStatuses.Succeeded, command.Status);
        Assert.Equal(persisted.ChargedAtUtc, command.CompletedAtUtc);
        Assert.Equal(userId, command.UserId);
        Assert.Equal(persisted.TokenCost, command.TokenCost);
    }

    [Fact]
    public Task MapResponse_ShouldNormalizeLegacyNullSourceImageAssetFields()
    {
        var now = DateTime.UtcNow;
        var response = TemplateGenerationService.MapResponse(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = Guid.NewGuid(),
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "https://cdn.example.com/legacy-status.jpg",
                SourceImageFileName = null!,
                SourceImageContentType = null!,
                ResultUrl = "https://cdn.example.com/legacy-status-result.png",
                CreatedAtUtc = now.AddMinutes(-2),
                QueuedAtUtc = now.AddMinutes(-2),
                StartedAtUtc = now.AddMinutes(-2),
                CompletedAtUtc = now.AddMinutes(-1),
                UpdatedAtUtc = now.AddMinutes(-1),
                ChargedAtUtc = now.AddMinutes(-2)
            });

        Assert.NotNull(response.SourceImageAsset);
        Assert.Equal(string.Empty, response.SourceImageAsset!.FileName);
        Assert.Equal(string.Empty, response.SourceImageAsset!.ContentType);
        return Task.CompletedTask;
    }

    [Fact]
    public async Task StartAsync_ShouldReturnLaneEtaAndTierSnapshot()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Eta Portrait", "Portrait", ["eta"]);
        var userId = Guid.NewGuid();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "eta-key",
                "eta-hash",
                3,
                QueueTier: TemplateGenerationQueue.TierPremium),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal("image", started.Value.MediaType);
        Assert.Equal("premium", started.Value.PriorityClass);
        Assert.Equal(1, started.Value.QueuePosition);
        Assert.Equal(0, started.Value.EstimatedWaitSeconds);
        Assert.Equal(90, started.Value.EstimatedTotalSeconds);
        Assert.NotNull(started.Value.EstimatedCompletionAtUtc);
        Assert.Equal("capacity:image:premium", started.Value.QueueReason);
        Assert.True(started.Value.CanCancel);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal(TemplateGenerationQueue.MediaTypeImage, persisted.QueueMediaType);
        Assert.Equal(TemplateGenerationQueue.TierPremium, persisted.QueueTier);
        Assert.Equal(0, persisted.EstimatedWaitSecondsAtQueue);
        Assert.NotNull(persisted.EstimatedCompletionAtQueueUtc);
    }

    [Fact]
    public async Task StartAsync_ShouldAllowTemplateInArchivedCategory()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(dbContext, billing: billing);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Archived Category Generation",
            "Seasonal",
            ["generation"]);

        var archivedCategory = await dbContext.TemplateCategories.SingleAsync(category => category.Name == "Seasonal");
        archivedCategory.IsArchived = true;
        await dbContext.SaveChangesAsync();

        var userId = Guid.NewGuid();
        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "archived-category-key",
                "archived-category-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal(started.Value.GenerationId, Assert.Single(billing.ChargedGenerationIds));
        var job = await dbContext.TemplateGenerationJobs.SingleAsync();
        Assert.Equal(templateId, job.TemplateId);
        Assert.Equal(userId, job.UserId);
    }

    [Fact]
    public async Task StartAsync_ShouldRejectTemplateChangedAfterPreviewBeforeCharge()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(dbContext, billing: billing);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Changed Preview Generation",
            "Portrait",
            ["generation"]);

        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var previewVersion = template.Version;
        template.Version = previewVersion + 1;
        template.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                UserId: Guid.NewGuid(),
                TemplateId: templateId,
                SourceImageAsset: new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                IdempotencyKey: "changed-template-key",
                RequestHash: "changed-template-hash",
                ActiveGenerationLimit: 3,
                ExpectedTemplateVersion: previewVersion),
            CancellationToken.None);

        Assert.True(started.IsFailure);
        Assert.Equal(TemplatesErrors.TemplateChanged.Code, started.Error.Code);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Empty(await dbContext.TemplateGenerationJobs.ToArrayAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldRejectOverloadedFreeImageBeforeCharge()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(
            dbContext,
            CreateTemplatesOptions(
                imageMaxConcurrentGenerations: 1,
                estimatedImageGenerationSeconds: 90,
                freeImageMaxEstimatedWaitSeconds: 60),
            billing);
        var templateId = await CreateActiveImageTemplateAsync(service, "Overloaded Portrait", "Portrait", ["overload"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/existing.jpg",
            SourceImageFileName = "existing.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            ChargedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        });
        await dbContext.SaveChangesAsync();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "overload-key",
                "overload-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationWaitTooLong.Code, started.Error.Code);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Equal(1, await dbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldRejectOverloadedFreeVideoBorrowingBeforeCharge()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(
            dbContext,
            CreateTemplatesOptions(
                globalMaxConcurrentGenerations: 4,
                imageMaxConcurrentGenerations: 3,
                imageProtectedConcurrentGenerations: 2,
                videoMaxConcurrentGenerations: 3,
                videoReservedConcurrentGenerations: 1,
                videoBorrowMaxConcurrentGenerations: 2,
                enableElasticLaneBorrowing: true,
                estimatedVideoGenerationSeconds: 420,
                freeVideoMaxEstimatedWaitSeconds: 60),
            billing);
        var templateId = await CreateActiveVideoTemplateAsync(service, "Overloaded Video", "Video", ["overload"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var now = DateTime.UtcNow;

        for (var index = 0; index < 4; index++)
        {
            dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = templateId,
                Template = template,
                Status = TemplateGenerationStatus.Queued,
                TokenCost = template.TokenCost,
                QueueMediaType = TemplateGenerationQueue.MediaTypeVideo,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = $"https://cdn.example.com/existing-video-{index}.jpg",
                SourceImageFileName = $"existing-video-{index}.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now.AddMinutes(-10).AddSeconds(index),
                QueuedAtUtc = now.AddMinutes(-10).AddSeconds(index),
                UpdatedAtUtc = now.AddMinutes(-10).AddSeconds(index),
                ChargedAtUtc = now.AddMinutes(-10).AddSeconds(index)
            });
        }

        await dbContext.SaveChangesAsync();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "video-overload-key",
                "video-overload-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationWaitTooLong.Code, started.Error.Code);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Equal(4, await dbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldRejectProviderCapacityBeforeChargeAndJobCreation()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var providerHealth = new TestAiProviderHealthService(PetMagic.BuildingBlocks.Results.Result.Failure(
            TemplatesErrors.ProviderCapacityUnavailable));
        var generationService = CreateGenerationService(
            dbContext,
            billing: billing,
            aiProviderHealthService: providerHealth);
        var templateId = await CreateActiveImageTemplateAsync(service, "Provider Guard Portrait", "Portrait", ["provider"]);

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "provider-guard-key",
                "provider-guard-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, started.Error.Code);
        Assert.Equal(1, providerHealth.CheckCount);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Empty(await dbContext.TemplateGenerationJobs.ToArrayAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldChargeAndQueue_WhenProviderGuardPasses()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var providerHealth = new TestAiProviderHealthService(PetMagic.BuildingBlocks.Results.Result.Success());
        var generationService = CreateGenerationService(
            dbContext,
            billing: billing,
            aiProviderHealthService: providerHealth);
        var templateId = await CreateActiveImageTemplateAsync(service, "Provider Healthy Portrait", "Portrait", ["provider"]);

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "provider-healthy-key",
                "provider-healthy-hash",
                3),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal(1, providerHealth.CheckCount);
        Assert.Equal(started.Value.GenerationId, Assert.Single(billing.ChargedGenerationIds));
        Assert.Equal(TemplateGenerationStatus.Queued, await dbContext.TemplateGenerationJobs
            .Where(x => x.Id == started.Value.GenerationId)
            .Select(x => x.Status)
            .SingleAsync());
    }

    [Fact]
    public async Task StartAsync_ShouldAcceptPremiumImage_WhenFreeImageBackpressureWouldReject()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(
            dbContext,
            CreateTemplatesOptions(
                imageMaxConcurrentGenerations: 1,
                estimatedImageGenerationSeconds: 90,
                freeImageMaxEstimatedWaitSeconds: 60,
                premiumImageMaxEstimatedWaitSeconds: 180),
            billing);
        var templateId = await CreateActiveImageTemplateAsync(service, "Premium Overload Portrait", "Portrait", ["overload"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/existing.jpg",
            SourceImageFileName = "existing.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-10),
            ChargedAtUtc = DateTime.UtcNow.AddMinutes(-10)
        });
        await dbContext.SaveChangesAsync();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                Guid.NewGuid(),
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "premium-overload-key",
                "premium-overload-hash",
                3,
                QueueTier: TemplateGenerationQueue.TierPremium),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal("premium", started.Value.PriorityClass);
        Assert.Single(billing.ChargedGenerationIds);
        Assert.Equal(2, await dbContext.TemplateGenerationJobs.CountAsync());
    }

    [Fact]
    public async Task CancelQueuedAsync_ShouldRefundPublishAndRemoveFromActiveLimit()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var realtime = new RecordingTemplateFeedRealtimeService();
        var generationService = CreateGenerationService(dbContext, billing: billing, realtimeService: realtime);
        var templateId = await CreateActiveImageTemplateAsync(service, "Cancel Portrait", "Portrait", ["cancel"]);
        var userId = Guid.NewGuid();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "cancel-key",
                "cancel-hash",
                1),
            CancellationToken.None);
        Assert.True(started.IsSuccess);

        var cancelled = await generationService.CancelQueuedAsync(userId, started.Value.GenerationId, CancellationToken.None);

        Assert.True(cancelled.IsSuccess);
        Assert.True(cancelled.Value.Refunded);
        Assert.Equal(started.Value.GenerationId, Assert.Single(billing.RefundedGenerationIds));
        Assert.Contains(realtime.GenerationStatusEvents, x => x.GenerationId == started.Value.GenerationId && x.Status == "Cancelled");
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal(TemplateGenerationStatus.Cancelled, persisted.Status);
        Assert.NotNull(persisted.RefundedAtUtc);
        Assert.NotNull(persisted.CancelledAtUtc);

        var next = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source-2.jpg", "source-2.jpg", "image/jpeg", 2048, null),
                "cancel-key-2",
                "cancel-hash-2",
                1),
            CancellationToken.None);
        Assert.True(next.IsSuccess);
    }

    [Fact]
    public async Task CancelAdminQueuedAsync_ShouldRefundPublishAuditAndReturnGeneration()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var realtime = new RecordingTemplateFeedRealtimeService();
        var audit = new RecordingAdminAuditLog();
        var generationService = CreateGenerationService(
            dbContext,
            billing: billing,
            realtimeService: realtime,
            adminAuditLog: audit);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Cancel Portrait", "Portrait", ["cancel"]);
        var userId = Guid.NewGuid();

        var started = await generationService.StartAsync(
            new StartTemplateGenerationCommand(
                userId,
                templateId,
                new TemplateAssetCommand("https://cdn.example.com/source.jpg", "source.jpg", "image/jpeg", 2048, null),
                "admin-cancel-key",
                "admin-cancel-hash",
                1),
            CancellationToken.None);
        Assert.True(started.IsSuccess);

        var adminUserId = Guid.NewGuid();
        var cancelled = await generationService.CancelAdminQueuedAsync(
            adminUserId,
            started.Value.GenerationId,
            CancellationToken.None);

        Assert.True(cancelled.IsSuccess);
        Assert.Equal("Cancelled", cancelled.Value.Status);
        Assert.False(cancelled.Value.CanCancel);
        Assert.Equal(started.Value.GenerationId, Assert.Single(billing.RefundedGenerationIds));
        Assert.Contains(realtime.GenerationStatusEvents, x => x.GenerationId == started.Value.GenerationId && x.Status == "Cancelled");
        var auditEntry = Assert.Single(audit.Entries);
        Assert.Equal("admin.template_generation.cancelled", auditEntry.Action);
        Assert.Equal("template_generation", auditEntry.TargetType);
        Assert.Equal(started.Value.GenerationId.ToString("D"), auditEntry.TargetId);
        Assert.Equal(userId, auditEntry.SubjectUserId);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        Assert.Equal(TemplateGenerationStatus.Cancelled, persisted.Status);
        Assert.NotNull(persisted.RefundedAtUtc);
    }

    [Fact]
    public async Task RetryAdminGenerationAsync_ShouldRequeueUnrefundedTerminalJobWithoutNewBillingCommand()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var realtime = new RecordingTemplateFeedRealtimeService();
        var audit = new RecordingAdminAuditLog();
        var generationService = CreateGenerationService(
            dbContext,
            realtimeService: realtime,
            adminAuditLog: audit);
        var templateId = await CreateActiveImageTemplateAsync(service, "Retry Portrait", "Portrait", ["retry"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Failed,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = now.AddMinutes(-15),
            QueuedAtUtc = now.AddMinutes(-15),
            StartedAtUtc = now.AddMinutes(-14),
            CompletedAtUtc = now.AddMinutes(-12),
            UpdatedAtUtc = now.AddMinutes(-12),
            ChargedAtUtc = now.AddMinutes(-15),
            AttemptCount = 3,
            LastAttemptAtUtc = now.AddMinutes(-14),
            LastErrorCode = TemplatesErrors.AiProviderFailed.Code,
            LastErrorMessage = TemplatesErrors.AiProviderFailed.Message,
            PreprocessingProviderRequestId = "fal-request",
            ProviderStatus = "failed",
            ProviderResultUrl = "https://provider.example.com/result.png"
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var adminUserId = Guid.NewGuid();
        var retried = await generationService.RetryAdminGenerationAsync(
            adminUserId,
            job.Id,
            CancellationToken.None);

        Assert.True(retried.IsSuccess);
        Assert.Equal("Queued", retried.Value.Status);
        Assert.True(retried.Value.CanCancel);
        Assert.Equal(0, retried.Value.AttemptCount);
        Assert.False(retried.Value.RefundedAtUtc.HasValue);
        Assert.Equal(0, await dbContext.TemplateGenerationBillingCommands.CountAsync());
        Assert.Contains(realtime.GenerationStatusEvents, x => x.GenerationId == job.Id && x.Status == "Queued");
        var auditEntry = Assert.Single(audit.Entries);
        Assert.Equal("admin.templates.generation.retry", auditEntry.Action);
        Assert.Equal(adminUserId, auditEntry.SubjectUserId);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.Equal(TemplateGenerationStatus.Queued, persisted.Status);
        Assert.Equal(0, persisted.AttemptCount);
        Assert.Null(persisted.StartedAtUtc);
        Assert.Null(persisted.CompletedAtUtc);
        Assert.Null(persisted.LastErrorCode);
        Assert.Null(persisted.PreprocessingProviderRequestId);
        Assert.Null(persisted.ProviderResultUrl);
        Assert.NotNull(persisted.ChargedAtUtc);
        Assert.Null(persisted.RefundedAtUtc);
    }

    [Fact]
    public async Task RetryAdminGenerationAsync_ShouldRejectRefundedTerminalJob()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var realtime = new RecordingTemplateFeedRealtimeService();
        var generationService = CreateGenerationService(dbContext, realtimeService: realtime);
        var templateId = await CreateActiveImageTemplateAsync(service, "Refunded Retry Portrait", "Portrait", ["retry"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Failed,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = now.AddMinutes(-15),
            QueuedAtUtc = now.AddMinutes(-15),
            UpdatedAtUtc = now.AddMinutes(-12),
            CompletedAtUtc = now.AddMinutes(-12),
            ChargedAtUtc = now.AddMinutes(-15),
            RefundedAtUtc = now.AddMinutes(-11),
            AttemptCount = 3,
            LastErrorCode = TemplatesErrors.AiProviderFailed.Code
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var retried = await generationService.RetryAdminGenerationAsync(
            Guid.NewGuid(),
            job.Id,
            CancellationToken.None);

        Assert.True(retried.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationRetryNotAllowed.Code, retried.Error.Code);
        Assert.Empty(realtime.GenerationStatusEvents);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.Equal(TemplateGenerationStatus.Failed, persisted.Status);
        Assert.NotNull(persisted.RefundedAtUtc);
    }

    [Fact]
    public async Task CancelAdminQueuedAsync_ShouldRejectProcessingJob()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Admin Processing Cancel Portrait", "Portrait", ["cancel"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Processing,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            StartedAtUtc = DateTime.UtcNow.AddMinutes(-4),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-4),
            ChargedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var cancelled = await generationService.CancelAdminQueuedAsync(
            Guid.NewGuid(),
            job.Id,
            CancellationToken.None);

        Assert.True(cancelled.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationCancelNotAllowed.Code, cancelled.Error.Code);
    }

    [Fact]
    public async Task CancelQueuedAsync_ShouldNotRefundAgain_WhenJobWasAlreadyRefunded()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(dbContext, billing: billing);
        var templateId = await CreateActiveImageTemplateAsync(service, "Already Refunded Portrait", "Portrait", ["cancel"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = now.AddMinutes(-5),
            QueuedAtUtc = now.AddMinutes(-5),
            UpdatedAtUtc = now.AddMinutes(-5),
            ChargedAtUtc = now.AddMinutes(-5),
            RefundedAtUtc = now.AddMinutes(-4)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var cancelled = await generationService.CancelQueuedAsync(userId, job.Id, CancellationToken.None);

        Assert.True(cancelled.IsSuccess);
        Assert.False(cancelled.Value.Refunded);
        Assert.Empty(billing.RefundedGenerationIds);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.Equal(TemplateGenerationStatus.Cancelled, persisted.Status);
        Assert.Equal(now.AddMinutes(-4), persisted.RefundedAtUtc);
    }

    [Fact]
    public async Task CancelQueuedAsync_ShouldRejectProcessingJob()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Processing Cancel Portrait", "Portrait", ["cancel"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var userId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Processing,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            StartedAtUtc = DateTime.UtcNow.AddMinutes(-4),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-4),
            ChargedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var cancelled = await generationService.CancelQueuedAsync(userId, job.Id, CancellationToken.None);

        Assert.True(cancelled.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationCancelNotAllowed.Code, cancelled.Error.Code);
    }

    [Fact]
    public async Task CancelQueuedAsync_ShouldNotRefund_WhenConcurrentClaimWins()
    {
        var concurrencyInterceptor = new OneShotConcurrencyInterceptor();
        await using var dbContext = CreateDbContext(concurrencyInterceptor);
        var service = CreateService(dbContext);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(dbContext, billing: billing);
        var templateId = await CreateActiveImageTemplateAsync(service, "Concurrent Cancel Portrait", "Portrait", ["cancel"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        var userId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = templateId,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            UpdatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            ChargedAtUtc = DateTime.UtcNow.AddMinutes(-5)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        concurrencyInterceptor.Enabled = false;
        await dbContext.SaveChangesAsync();
        concurrencyInterceptor.Enabled = true;

        var cancelled = await generationService.CancelQueuedAsync(userId, job.Id, CancellationToken.None);

        Assert.True(cancelled.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationCancelNotAllowed.Code, cancelled.Error.Code);
        Assert.Empty(billing.RefundedGenerationIds);
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
    public async Task GetCompatibleTemplatesAsync_ShouldReturnOnlyTemplatesCompatibleWithCompletedImageResult()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var userId = Guid.NewGuid();
        var parent = await CreateCompletedImageGenerationAsync(dbContext, service, userId);
        var compatibleVideo = await CreateGenerationResultVideoTemplateAsync(
            service,
            "Compatible Video",
            supportsGenerationResultInput: true,
            requiredInputMediaType: TemplateType.Image.ToString(),
            recommendedAfterImageGeneration: true);
        await CreateGenerationResultVideoTemplateAsync(
            service,
            "Video Result Only",
            supportsGenerationResultInput: true,
            requiredInputMediaType: TemplateType.Video.ToString(),
            recommendedAfterImageGeneration: true);
        await CreateGenerationResultVideoTemplateAsync(
            service,
            "Not Supported",
            supportsGenerationResultInput: false,
            requiredInputMediaType: TemplateType.Image.ToString(),
            recommendedAfterImageGeneration: true);
        var imageCompatible = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Image To Image",
                "Image result compatible but not a continuation video",
                "Image",
                ["from-result"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/image-to-image.jpg", "preview.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "keep pet",
                TemplateStatus.Active.ToString(),
                null,
                SupportsGenerationResultInput: true,
                RequiredInputMediaType: TemplateType.Image.ToString(),
                RecommendedAfterImageGeneration: true),
            CancellationToken.None);
        Assert.True(imageCompatible.IsSuccess);

        var compatible = await generationService.GetCompatibleTemplatesAsync(
            userId,
            parent.Id,
            CancellationToken.None);

        Assert.True(compatible.IsSuccess);
        Assert.Equal(parent.Id, compatible.Value.ResultId);
        Assert.Equal("image", compatible.Value.InputMediaType);
        var template = Assert.Single(compatible.Value.Templates);
        Assert.Equal(compatibleVideo, template.Id);
        Assert.Equal("Video", template.Type);
        Assert.False(template.IsRecommended);
    }

    [Fact]
    public async Task StartFromResultAsync_ShouldCreateChildVideoGenerationWithCleanInternalInput()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var generationService = CreateGenerationService(dbContext);
        var userId = Guid.NewGuid();
        var parent = await CreateCompletedImageGenerationAsync(dbContext, service, userId);
        var videoTemplateId = await CreateGenerationResultVideoTemplateAsync(
            service,
            "Result To Video",
            supportsGenerationResultInput: true,
            requiredInputMediaType: TemplateType.Image.ToString(),
            recommendedAfterImageGeneration: true);

        var started = await generationService.StartFromResultAsync(
            new StartTemplateGenerationFromResultCommand(
                userId,
                parent.Id,
                videoTemplateId,
                "from-result-key",
                3),
            CancellationToken.None);

        Assert.True(started.IsSuccess);
        Assert.Equal(videoTemplateId, started.Value.TemplateId);
        Assert.Equal("Queued", started.Value.Status);
        Assert.Null(started.Value.SourceImageAsset);
        Assert.Equal(parent.Id, started.Value.ParentGenerationId);
        Assert.Equal(parent.Id, started.Value.ParentGenerationResultId);
        Assert.Equal("generation_result", started.Value.InputSourceType);
        Assert.NotNull(started.Value.InputMediaAssetId);

        var child = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == started.Value.GenerationId);
        var persistedParent = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == parent.Id);
        Assert.Equal(parent.Id, child.ParentGenerationId);
        Assert.Equal(parent.Id, child.ParentGenerationResultId);
        Assert.Equal("generation_result", child.InputSourceType);
        Assert.NotNull(child.InputMediaAssetId);
        Assert.NotNull(child.ChargedAtUtc);
        Assert.Null(persistedParent.ChargedAtUtc);

        var inputAsset = await dbContext.TemplateMediaRecords.SingleAsync(x => x.Id == child.InputMediaAssetId);
        Assert.Equal(userId, inputAsset.UserId);
        Assert.Equal("image", inputAsset.MediaType);
        Assert.Equal("generation_result", inputAsset.SourceType);
        Assert.Equal(parent.Id, inputAsset.GenerationId);
        Assert.Equal(parent.ResultUrl, inputAsset.StoragePath);
        Assert.Equal(parent.WatermarkedResultUrl, inputAsset.WatermarkedStoragePath);
        Assert.Equal(inputAsset.Id, started.Value.InputMediaAssetId);

        var analyticsEvents = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == child.Id)
            .OrderBy(x => x.CreatedAtUtc)
            .ToArrayAsync();
        Assert.Contains(analyticsEvents, x => x.EventType == TemplateAnalyticsEventTypes.TemplateSelected);
        Assert.Contains(analyticsEvents, x => x.EventType == TemplateAnalyticsEventTypes.GenerationStarted);
        var startedEvent = analyticsEvents.Single(x => x.EventType == TemplateAnalyticsEventTypes.GenerationStarted);
        using var metadata = JsonDocument.Parse(startedEvent.MetadataJson!);
        Assert.Equal(parent.Id, metadata.RootElement.GetProperty("parentGenerationId").GetGuid());
        Assert.Equal(videoTemplateId, metadata.RootElement.GetProperty("newTemplateId").GetGuid());
        Assert.Equal("video", metadata.RootElement.GetProperty("newTemplateType").GetString());
        Assert.Equal("image", metadata.RootElement.GetProperty("inputMediaType").GetString());
        Assert.Equal(30, metadata.RootElement.GetProperty("creditsCost").GetInt32());
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

    private static async Task<TemplateGenerationJob> CreateCompletedImageGenerationAsync(
        TemplatesDbContext dbContext,
        ITemplatesService service,
        Guid userId)
    {
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            $"Parent Portrait {Guid.NewGuid():N}",
            "Portrait",
            ["parent"]);
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
            SourceImageFileSizeBytes = 2048,
            ResultUrl = "https://cdn.example.com/results/clean-parent.png",
            WatermarkedResultUrl = "https://cdn.example.com/results/watermarked-parent.png",
            CreatedAtUtc = now.AddMinutes(-10),
            QueuedAtUtc = now.AddMinutes(-10),
            UpdatedAtUtc = now.AddMinutes(-5),
            CompletedAtUtc = now.AddMinutes(-5),
            MediaImportCompletedAtUtc = now.AddMinutes(-5)
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();
        return job;
    }

    private static async Task<Guid> CreateGenerationResultVideoTemplateAsync(
        ITemplatesService service,
        string title,
        bool supportsGenerationResultInput,
        string requiredInputMediaType,
        bool recommendedAfterImageGeneration)
    {
        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                title,
                $"{title} description",
                "Video",
                ["from-result"],
                false,
                30,
                TemplatePromoBadgeMode.Auto.ToString(),
                string.Empty,
                CreatePreviewAsset($"https://cdn.example.com/{title.ToLowerInvariant().Replace(' ', '-')}.mp4", "preview.mp4", "video/mp4"),
                CreateReferenceAsset(8.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "cinematic motion",
                true,
                TemplateStatus.Active.ToString(),
                null,
                supportsGenerationResultInput,
                requiredInputMediaType,
                recommendedAfterImageGeneration),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        return created.Value.TemplateId;
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
