using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyPushOutboxProcessor(
    EconomyDbContext dbContext,
    IEconomyPushDeliverySender deliverySender,
    ILogger<EconomyPushOutboxProcessor> logger,
    IAdminAuditLog? adminAuditLog = null,
    IOptions<EconomyOptions>? economyOptions = null,
    IAdminNotificationSink? adminNotificationSink = null)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var message = await ClaimNextAsync(cancellationToken);
        if (message is null)
        {
            return await CleanupNextSentAsync(cancellationToken);
        }

        PushOutboxMetrics.RecordAttempt("economy");

        PushDeliveryResult result;
        if (message.AttemptCount > PushOutboxPolicy.MaxAttempts)
        {
            result = PushDeliveryResult.PermanentFailure(
                message.Kind == EconomyAdminAuditOutbox.Kind
                    ? "audit.attempts_exhausted"
                    : "push.attempts_exhausted");
        }
        else try
        {
            result = await DeliverAsync(message, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Economy outbox delivery failed. MessageIdHash={MessageIdHash} Kind={Kind} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(message.Id.ToString("D")),
                message.Kind,
                SafeLogValues.ExceptionType(exception));
            result = PushDeliveryResult.Retry(
                message.Kind == EconomyAdminAuditOutbox.Kind
                    ? "audit.delivery_failed"
                    : "fcm.transport_error");
        }

        ApplyResult(message, result);
        PushOutboxMetrics.RecordResult("economy", message);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            logger.LogInformation(
                "Economy outbox completion ignored because the processing lease was reclaimed. MessageIdHash={MessageIdHash}",
                SafeLogValues.StableHash(message.Id.ToString("D")));
        }
        return true;
    }

    private async Task<PushOutboxMessage?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational())
        {
            return await ClaimNextTrackedAsync(cancellationToken);
        }

        var now = DateTime.UtcNow;
        var lockId = Guid.NewGuid();
        var lockExpiresAtUtc = now.Add(PushOutboxPolicy.LeaseDuration);
        var canDeliverAdminAudit = adminAuditLog is not null;
        var canDeliverAdminNotification = adminNotificationSink is not null;
        var canDeliverPush = economyOptions?.Value.IsFirebasePushConfigured ?? true;
        var ids = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE economy_push_outbox
            SET "Status" = {1},
                "AttemptCount" = "AttemptCount" + 1,
                "LockId" = {4},
                "LockExpiresAtUtc" = {5},
                "UpdatedAtUtc" = {2}
            WHERE "Id" = (
                SELECT "Id"
                FROM economy_push_outbox
                WHERE (("Status" = {0} AND "NextAttemptAtUtc" <= {2} AND "AttemptCount" < {3})
                       OR ("Status" = {1} AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
                  AND (("Kind" = {6} AND {7})
                       OR ("Kind" = {11} AND {12})
                       OR ("Kind" IN ({8}, {9}) AND {10})
                       OR "Kind" NOT IN ({6}, {8}, {9}, {11}))
                ORDER BY "NextAttemptAtUtc", "CreatedAtUtc"
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING "Id" AS "Value";
            """,
            (int)PushOutboxStatus.Queued,
            (int)PushOutboxStatus.Processing,
            now,
            PushOutboxPolicy.MaxAttempts,
            lockId,
            lockExpiresAtUtc,
            EconomyAdminAuditOutbox.Kind,
            canDeliverAdminAudit,
            EconomyPushNotificationOutbox.WalletKind,
            EconomyPushNotificationOutbox.PremiumKind,
            canDeliverPush,
            AdminNotificationOutbox.Kind,
            canDeliverAdminNotification).ToListAsync(cancellationToken);

        var id = ids.FirstOrDefault();
        return id == Guid.Empty
            ? null
            : await dbContext.PushOutboxMessages.SingleAsync(x => x.Id == id, cancellationToken);
    }

    private async Task<PushOutboxMessage?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var canDeliverAdminAudit = adminAuditLog is not null;
        var canDeliverAdminNotification = adminNotificationSink is not null;
        var canDeliverPush = economyOptions?.Value.IsFirebasePushConfigured ?? true;
        var message = await dbContext.PushOutboxMessages
            .Where(x => (x.Status == PushOutboxStatus.Queued
                        && x.NextAttemptAtUtc <= now
                        && x.AttemptCount < PushOutboxPolicy.MaxAttempts)
                    || (x.Status == PushOutboxStatus.Processing
                        && (x.LockExpiresAtUtc == null || x.LockExpiresAtUtc <= now)))
            .Where(x => (x.Kind == EconomyAdminAuditOutbox.Kind && canDeliverAdminAudit)
                || (x.Kind == AdminNotificationOutbox.Kind && canDeliverAdminNotification)
                || ((x.Kind == EconomyPushNotificationOutbox.WalletKind
                        || x.Kind == EconomyPushNotificationOutbox.PremiumKind)
                    && canDeliverPush)
                || (x.Kind != EconomyAdminAuditOutbox.Kind
                    && x.Kind != AdminNotificationOutbox.Kind
                    && x.Kind != EconomyPushNotificationOutbox.WalletKind
                    && x.Kind != EconomyPushNotificationOutbox.PremiumKind))
            .OrderBy(x => x.NextAttemptAtUtc)
            .ThenBy(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (message is null)
        {
            return null;
        }

        message.Status = PushOutboxStatus.Processing;
        message.AttemptCount++;
        message.LockId = Guid.NewGuid();
        message.LockExpiresAtUtc = now.Add(PushOutboxPolicy.LeaseDuration);
        message.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return message;
    }

    private async Task<PushDeliveryResult> DeliverAsync(PushOutboxMessage message, CancellationToken cancellationToken)
    {
        return message.Kind switch
        {
            EconomyPushNotificationOutbox.WalletKind => await DeliverWalletAsync(message, cancellationToken),
            EconomyPushNotificationOutbox.PremiumKind => await DeliverPremiumAsync(message, cancellationToken),
            EconomyAdminAuditOutbox.Kind => await DeliverAdminAuditAsync(message, cancellationToken),
            AdminNotificationOutbox.Kind => await DeliverAdminNotificationAsync(message, cancellationToken),
            _ => PushDeliveryResult.PermanentFailure("push.kind_unknown")
        };
    }

    private async Task<PushDeliveryResult> DeliverWalletAsync(
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        WalletPushNotification notification;
        try
        {
            notification = Deserialize<WalletPushNotification>(message.PayloadJson);
        }
        catch (JsonException)
        {
            return PushDeliveryResult.PermanentFailure("push.payload_invalid");
        }

        return await deliverySender.DeliverWalletUpdateAsync(message.UserId, notification, cancellationToken);
    }

    private async Task<PushDeliveryResult> DeliverPremiumAsync(
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        PremiumPushNotification notification;
        try
        {
            notification = Deserialize<PremiumPushNotification>(message.PayloadJson);
        }
        catch (JsonException)
        {
            return PushDeliveryResult.PermanentFailure("push.payload_invalid");
        }

        return await deliverySender.DeliverPremiumUpdateAsync(message.UserId, notification, cancellationToken);
    }

    private async Task<PushDeliveryResult> DeliverAdminAuditAsync(
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        AdminAuditEntry entry;
        try
        {
            entry = Deserialize<AdminAuditEntry>(message.PayloadJson);
        }
        catch (JsonException)
        {
            return PushDeliveryResult.PermanentFailure("audit.payload_invalid");
        }

        if (!entry.EventId.HasValue
            || entry.EventId.Value == Guid.Empty
            || string.IsNullOrWhiteSpace(entry.Action)
            || string.IsNullOrWhiteSpace(entry.TargetType)
            || string.IsNullOrWhiteSpace(entry.TargetId))
        {
            return PushDeliveryResult.PermanentFailure("audit.payload_invalid");
        }

        if (adminAuditLog is null)
        {
            return PushDeliveryResult.Retry("audit.sink_unavailable");
        }

        await adminAuditLog.WriteAsync(entry, cancellationToken);
        return PushDeliveryResult.Delivered;
    }

    private async Task<PushDeliveryResult> DeliverAdminNotificationAsync(
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        if (adminNotificationSink is null)
        {
            return PushDeliveryResult.Retry("admin_notification.sink_unavailable");
        }

        AdminNotificationMessage notification;
        try
        {
            notification = AdminNotificationOutbox.Deserialize(message.PayloadJson);
        }
        catch (JsonException)
        {
            return PushDeliveryResult.PermanentFailure("admin_notification.payload_invalid");
        }

        await adminNotificationSink.PublishAsync(notification, cancellationToken);
        return PushDeliveryResult.Delivered;
    }

    private static T Deserialize<T>(string payloadJson) =>
        JsonSerializer.Deserialize<T>(payloadJson, JsonOptions)
        ?? throw new JsonException("Push outbox payload is empty.");

    private static void ApplyResult(PushOutboxMessage message, PushDeliveryResult result)
    {
        var now = DateTime.UtcNow;
        message.LockId = null;
        message.LockExpiresAtUtc = null;
        message.UpdatedAtUtc = now;
        message.LastErrorCode = result.ErrorCode;

        if (result.Disposition == PushDeliveryDisposition.Delivered)
        {
            message.Status = PushOutboxStatus.Sent;
            message.SentAtUtc = now;
            return;
        }

        if (result.Disposition == PushDeliveryDisposition.PermanentFailure
            || message.AttemptCount >= PushOutboxPolicy.MaxAttempts)
        {
            message.Status = PushOutboxStatus.DeadLetter;
            return;
        }

        message.Status = PushOutboxStatus.Queued;
        message.NextAttemptAtUtc = now.Add(PushOutboxPolicy.RetryDelay(message.AttemptCount));
    }

    private async Task<bool> CleanupNextSentAsync(CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow.Subtract(PushOutboxPolicy.SentRetention);
        var message = await dbContext.PushOutboxMessages
            .Where(x => x.Status == PushOutboxStatus.Sent && x.SentAtUtc <= cutoff)
            .OrderBy(x => x.SentAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (message is null)
        {
            return false;
        }

        dbContext.PushOutboxMessages.Remove(message);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}
