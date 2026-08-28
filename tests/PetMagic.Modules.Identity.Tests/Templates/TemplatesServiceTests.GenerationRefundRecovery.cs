using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldExposeAndFilterRefundRecoveryState()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Refund Recovery Portrait",
            "Portrait",
            ["refund-recovery"]);
        var now = DateTime.UtcNow;
        var pending = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Failed,
            now.AddMinutes(-4),
            refundAttemptCount: 2,
            charged: true);
        pending.RefundLastAttemptedAtUtc = now.AddMinutes(-2);
        pending.RefundLastErrorCode = "economy.temporarily_unavailable";
        var exhausted = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Cancelled,
            now.AddMinutes(-3),
            refundAttemptCount: 5,
            charged: true);
        var refunded = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Failed,
            now.AddMinutes(-2),
            refundAttemptCount: 1,
            charged: true);
        refunded.RefundedAtUtc = now.AddMinutes(-1);
        var notApplicable = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Completed,
            now.AddMinutes(-1),
            refundAttemptCount: 0,
            charged: true);
        dbContext.TemplateGenerationJobs.AddRange(pending, exhausted, refunded, notApplicable);
        await dbContext.SaveChangesAsync();

        var page = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery(null, null, null, null, 0, 10),
            CancellationToken.None);
        var exhaustedPage = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery(null, null, null, null, 0, 10, "exhausted"),
            CancellationToken.None);
        var metrics = await service.GetAdminGenerationDashboardMetricsAsync(CancellationToken.None);

        Assert.True(page.IsSuccess);
        var byId = page.Value.Items.ToDictionary(item => item.GenerationId);
        Assert.Equal("pending", byId[pending.Id].RefundState);
        Assert.Equal(pending.ChargedAtUtc, byId[pending.Id].ChargedAtUtc);
        Assert.Equal(2, byId[pending.Id].RefundAttemptCount);
        Assert.Equal(5, byId[pending.Id].RefundAttemptLimit);
        Assert.Equal(pending.RefundLastAttemptedAtUtc, byId[pending.Id].RefundLastAttemptedAtUtc);
        Assert.Equal("economy.temporarily_unavailable", byId[pending.Id].RefundLastErrorCode);
        Assert.False(byId[pending.Id].CanRetryRefund);
        Assert.Equal("exhausted", byId[exhausted.Id].RefundState);
        Assert.True(byId[exhausted.Id].CanRetryRefund);
        Assert.Equal("refunded", byId[refunded.Id].RefundState);
        Assert.False(byId[refunded.Id].CanRetryRefund);
        Assert.Equal("not_applicable", byId[notApplicable.Id].RefundState);

        Assert.True(exhaustedPage.IsSuccess);
        Assert.Equal(exhausted.Id, Assert.Single(exhaustedPage.Value.Items).GenerationId);
        Assert.True(metrics.IsSuccess);
        Assert.Equal(1, metrics.Value.PendingRefunds);
        Assert.Equal(1, metrics.Value.ExhaustedRefunds);
    }

    [Fact]
    public async Task RetryAdminGenerationRefundAsync_ShouldPersistReceiptReplaySafelyAndNeverMoveCredits()
    {
        await using var dbContext = CreateDbContext();
        var catalogService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            catalogService,
            "Refund Recovery Action",
            "Portrait",
            ["refund-recovery"]);
        var billing = new RecordingGenerationBilling();
        var audit = new RecordingAdminAuditLog();
        var generationService = CreateGenerationService(
            dbContext,
            billing: billing,
            adminAuditLog: audit);
        var now = DateTime.UtcNow;
        var job = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Failed,
            now.AddMinutes(-5),
            refundAttemptCount: 5,
            charged: true);
        job.RefundLastAttemptedAtUtc = now.AddMinutes(-1);
        job.RefundLastErrorCode = "economy.temporarily_unavailable";
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();
        var adminUserId = Guid.NewGuid();
        const string idempotencyKey = "generation-refund-retry:test-operation";

        var first = await generationService.RetryAdminGenerationRefundAsync(
            adminUserId,
            job.Id,
            "Customer credits are still unsettled.",
            idempotencyKey,
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        var receipt = await dbContext.AdminGenerationRefundRetryReceipts.AsNoTracking().SingleAsync();
        Assert.Equal(adminUserId, receipt.ActorUserId);
        Assert.Equal(job.Id, receipt.GenerationId);
        Assert.Equal(idempotencyKey, receipt.IdempotencyKey);
        Assert.Equal(5, receipt.PreviousRefundAttemptCount);
        Assert.Equal("economy.temporarily_unavailable", receipt.PreviousRefundLastErrorCode);
        Assert.Equal(64, receipt.RequestHash.Length);
        var outboxMessage = await dbContext.PushOutboxMessages.SingleAsync(
            message => message.Kind == TemplateAdminAuditOutbox.Kind);
        Assert.Equal(TemplateAdminAuditOutbox.Kind, outboxMessage.Kind);
        Assert.Equal($"templates_admin_audit:{receipt.Id:D}", outboxMessage.DeduplicationKey);
        Assert.Equal(PushOutboxStatus.Sent, outboxMessage.Status);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(item => item.Id == job.Id);
        Assert.Equal(0, persisted.RefundAttemptCount);
        Assert.Null(persisted.RefundLastAttemptedAtUtc);
        Assert.Null(persisted.RefundLastErrorCode);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Empty(billing.RefundedGenerationIds);

        persisted.RefundAttemptCount = 2;
        persisted.RefundLastAttemptedAtUtc = DateTime.UtcNow;
        persisted.RefundLastErrorCode = "economy.retrying";
        await dbContext.SaveChangesAsync();

        var replay = await generationService.RetryAdminGenerationRefundAsync(
            adminUserId,
            job.Id,
            "Customer credits are still unsettled.",
            idempotencyKey,
            CancellationToken.None);
        var conflict = await generationService.RetryAdminGenerationRefundAsync(
            adminUserId,
            job.Id,
            "A different operation payload.",
            idempotencyKey,
            CancellationToken.None);

        Assert.True(replay.IsSuccess);
        Assert.True(conflict.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationRefundRetryIdempotencyConflict.Code, conflict.Error.Code);
        Assert.Equal(1, await dbContext.AdminGenerationRefundRetryReceipts.CountAsync());
        dbContext.ChangeTracker.Clear();
        var afterReplay = await dbContext.TemplateGenerationJobs.AsNoTracking().SingleAsync(item => item.Id == job.Id);
        Assert.Equal(2, afterReplay.RefundAttemptCount);
        Assert.Equal("economy.retrying", afterReplay.RefundLastErrorCode);
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Empty(billing.RefundedGenerationIds);

        Assert.Single(audit.Entries);
        Assert.All(audit.Entries, entry =>
        {
            Assert.Equal("admin.templates.generation.refund_retry", entry.Action);
            Assert.Equal(adminUserId, entry.ActorUserId);
            Assert.Equal(job.UserId, entry.SubjectUserId);
            Assert.Equal(receipt.Id, entry.EventId);
            Assert.Equal(receipt.CorrelationId, entry.CorrelationId);
            Assert.Contains("retryBudgetReset=true", entry.Details, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task RetryAdminGenerationRefundAsync_ShouldRejectWhileAutomaticRetryBudgetIsActive()
    {
        await using var dbContext = CreateDbContext();
        var catalogService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            catalogService,
            "Active Refund Retry Budget",
            "Portrait",
            ["refund-recovery"]);
        var audit = new RecordingAdminAuditLog();
        var generationService = CreateGenerationService(dbContext, adminAuditLog: audit);
        var job = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Failed,
            DateTime.UtcNow.AddMinutes(-5),
            refundAttemptCount: 2,
            charged: true);
        job.RefundLastAttemptedAtUtc = DateTime.UtcNow.AddMinutes(-1);
        job.RefundLastErrorCode = "economy.temporarily_unavailable";
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var result = await generationService.RetryAdminGenerationRefundAsync(
            Guid.NewGuid(),
            job.Id,
            "Wait for the automatic worker budget to exhaust.",
            "generation-refund-retry:active-budget",
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationRefundRetryNotExhausted.Code, result.Error.Code);
        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(item => item.Id == job.Id);
        Assert.Equal(2, persisted.RefundAttemptCount);
        Assert.Equal("economy.temporarily_unavailable", persisted.RefundLastErrorCode);
        Assert.Empty(await dbContext.AdminGenerationRefundRetryReceipts.ToListAsync());
        Assert.Empty(await dbContext.PushOutboxMessages
            .Where(message => message.Kind == TemplateAdminAuditOutbox.Kind)
            .ToListAsync());
        Assert.Empty(audit.Entries);
    }

    [Fact]
    public async Task RetryAdminGenerationRefundAsync_ShouldKeepAuditQueuedWhenImmediateSinkFailsAndReplayThroughWorker()
    {
        await using var dbContext = CreateDbContext();
        var catalogService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            catalogService,
            "Durable Refund Recovery Audit",
            "Portrait",
            ["refund-recovery"]);
        var generationService = CreateGenerationService(
            dbContext,
            adminAuditLog: new ThrowingAdminAuditLog());
        var job = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Cancelled,
            DateTime.UtcNow.AddMinutes(-5),
            refundAttemptCount: 5,
            charged: true);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var result = await generationService.RetryAdminGenerationRefundAsync(
            Guid.NewGuid(),
            job.Id,
            "Recover the exhausted refund.",
            "generation-refund-retry:durable-audit",
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var receipt = await dbContext.AdminGenerationRefundRetryReceipts.SingleAsync();
        var queued = await dbContext.PushOutboxMessages.SingleAsync(
            message => message.Kind == TemplateAdminAuditOutbox.Kind);
        Assert.Equal(PushOutboxStatus.Queued, queued.Status);
        Assert.Equal($"templates_admin_audit:{receipt.Id:D}", queued.DeduplicationKey);

        var localizationMessages = await dbContext.PushOutboxMessages
            .Where(message => message.Kind == TemplateLocalizationOutbox.Kind)
            .ToArrayAsync();
        dbContext.PushOutboxMessages.RemoveRange(localizationMessages);
        await dbContext.SaveChangesAsync();

        var pushDelivery = new RecordingTemplatePushDeliverySender();
        var pushProcessor = new TemplatePushOutboxProcessor(
            dbContext,
            pushDelivery,
            NullLogger<TemplatePushOutboxProcessor>.Instance);
        Assert.False(await pushProcessor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(0, pushDelivery.DeliveryCount);
        Assert.Equal(PushOutboxStatus.Queued, queued.Status);

        var recoveredAudit = new RecordingAdminAuditLog();
        var processor = new TemplateAdminAuditOutboxProcessor(
            dbContext,
            recoveredAudit,
            NullLogger<TemplateAdminAuditOutboxProcessor>.Instance);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(PushOutboxStatus.Sent, queued.Status);
        var delivered = Assert.Single(recoveredAudit.Entries);
        Assert.Equal(receipt.Id, delivered.EventId);
        Assert.Equal("admin.templates.generation.refund_retry", delivered.Action);
    }

    [Fact]
    public async Task RetryAdminGenerationRefundAsync_ShouldKeepLegacyRequestCompatible()
    {
        await using var dbContext = CreateDbContext();
        var catalogService = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            catalogService,
            "Legacy Refund Recovery",
            "Portrait",
            ["refund-recovery"]);
        var billing = new RecordingGenerationBilling();
        var generationService = CreateGenerationService(dbContext, billing: billing);
        var job = CreateRefundRecoveryJob(
            templateId,
            TemplateGenerationStatus.Cancelled,
            DateTime.UtcNow.AddMinutes(-5),
            refundAttemptCount: 5,
            charged: true);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();

        var result = await generationService.RetryAdminGenerationRefundAsync(
            Guid.NewGuid(),
            job.Id,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(0, (await dbContext.TemplateGenerationJobs.SingleAsync(item => item.Id == job.Id)).RefundAttemptCount);
        Assert.Empty(await dbContext.AdminGenerationRefundRetryReceipts.ToListAsync());
        Assert.Empty(billing.ChargedGenerationIds);
        Assert.Empty(billing.RefundedGenerationIds);
    }

    [Theory]
    [InlineData("empty_key", "templates.generation_refund_retry_idempotency_key_invalid")]
    [InlineData("long_key", "templates.generation_refund_retry_idempotency_key_invalid")]
    [InlineData("long_reason", "templates.generation_refund_retry_reason_invalid")]
    public async Task RetryAdminGenerationRefundAsync_ShouldRejectInvalidRecoveryMetadata(
        string scenario,
        string expectedErrorCode)
    {
        await using var dbContext = CreateDbContext();
        var generationService = CreateGenerationService(dbContext);
        var reason = scenario == "long_reason" ? new string('r', 501) : null;
        var idempotencyKey = scenario switch
        {
            "empty_key" => " ",
            "long_key" => new string('x', 257),
            _ => "valid-key"
        };

        var result = await generationService.RetryAdminGenerationRefundAsync(
            Guid.NewGuid(),
            Guid.NewGuid(),
            reason,
            idempotencyKey,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(expectedErrorCode, result.Error.Code);
        Assert.Empty(await dbContext.AdminGenerationRefundRetryReceipts.ToListAsync());
    }

    private static TemplateGenerationJob CreateRefundRecoveryJob(
        Guid templateId,
        TemplateGenerationStatus status,
        DateTime createdAtUtc,
        int refundAttemptCount,
        bool charged)
    {
        return new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = templateId,
            Status = status,
            TokenCost = 20,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.com/refund-recovery-source.jpg",
            SourceImageFileName = "refund-recovery-source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = createdAtUtc,
            QueuedAtUtc = createdAtUtc,
            UpdatedAtUtc = createdAtUtc,
            CompletedAtUtc = createdAtUtc,
            ChargedAtUtc = charged ? createdAtUtc : null,
            RefundAttemptCount = refundAttemptCount
        };
    }

    private sealed class ThrowingAdminAuditLog : IAdminAuditLog
    {
        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("Simulated central admin audit outage.");
    }

    private sealed class RecordingTemplatePushDeliverySender : ITemplateGenerationPushDeliverySender
    {
        public int DeliveryCount { get; private set; }

        public Task<PushDeliveryResult> DeliverGenerationTerminalAsync(
            TemplateGenerationResponse generation,
            CancellationToken cancellationToken)
        {
            DeliveryCount++;
            return Task.FromResult(PushDeliveryResult.Delivered);
        }
    }
}
