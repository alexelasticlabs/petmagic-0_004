using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateAdminNotificationOutbox
{
    public static Task EnqueueProviderCapacityAlertAsync(
        TemplatesDbContext dbContext,
        string provider,
        string state,
        string? errorCode,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken) => EnqueueAsync(
            dbContext,
            new AdminNotificationMessage(
                "capacity.provider_alert",
                1,
                JsonSerializer.SerializeToElement(new
                {
                    provider,
                    state,
                    errorCode,
                }),
                "capacity",
                AdminNotificationPriorities.Critical,
                ["Admin"],
                "templates",
                $"provider-alert:{provider}:{state}:{occurredAtUtc.Ticks}",
                "/generations?panel=capacity",
                OccurredAtUtc: occurredAtUtc),
            $"templates_admin_notification:provider-alert:{provider}:{state}:{occurredAtUtc.Ticks}",
            cancellationToken);

    public static Task EnqueueGenerationFailedAsync(
        TemplatesDbContext dbContext,
        TemplateGenerationJob job,
        string failureCode,
        CancellationToken cancellationToken) => EnqueueAsync(
            dbContext,
            new AdminNotificationMessage(
                "generation.failed",
                1,
                JsonSerializer.SerializeToElement(new
                {
                    generationId = job.Id,
                    templateId = job.TemplateId,
                    status = "failed",
                    failureCode,
                    refundRequired = job.ChargedAtUtc.HasValue && !job.RefundedAtUtc.HasValue,
                }),
                "generation",
                AdminNotificationPriorities.Warning,
                ["Admin", "Moderator"],
                "templates",
                $"generation-failed:{job.Id:D}",
                $"/generations?selected={job.Id:D}",
                OccurredAtUtc: job.CompletedAtUtc ?? job.UpdatedAtUtc),
            $"templates_admin_notification:generation-failed:{job.Id:D}",
            cancellationToken);

    public static Task EnqueueRefundExhaustedAsync(
        TemplatesDbContext dbContext,
        TemplateGenerationJob job,
        string? errorCode,
        CancellationToken cancellationToken) => EnqueueAsync(
            dbContext,
            new AdminNotificationMessage(
                "generation.refund_exhausted",
                1,
                JsonSerializer.SerializeToElement(new
                {
                    generationId = job.Id,
                    templateId = job.TemplateId,
                    refundAttemptCount = job.RefundAttemptCount,
                    errorCode,
                }),
                "generation",
                AdminNotificationPriorities.Critical,
                ["Admin"],
                "templates",
                $"refund-exhausted:{job.Id:D}",
                $"/generations?refundState=exhausted&selected={job.Id:D}",
                OccurredAtUtc: job.RefundLastAttemptedAtUtc ?? job.UpdatedAtUtc),
            $"templates_admin_notification:refund-exhausted:{job.Id:D}",
            cancellationToken);

    private static async Task EnqueueAsync(
        TemplatesDbContext dbContext,
        AdminNotificationMessage notification,
        string outboxDeduplicationKey,
        CancellationToken cancellationToken)
    {
        if (dbContext.PushOutboxMessages.Local.Any(x => x.DeduplicationKey == outboxDeduplicationKey)
            || await dbContext.PushOutboxMessages.AsNoTracking().AnyAsync(
                x => x.DeduplicationKey == outboxDeduplicationKey,
                cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = outboxDeduplicationKey,
            Kind = AdminNotificationOutbox.Kind,
            UserId = Guid.Empty,
            PayloadJson = AdminNotificationOutbox.Serialize(notification),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
    }
}
