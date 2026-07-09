using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportChatPushOutboxProcessor(
    SupportChatDbContext dbContext,
    ISupportChatPushDeliverySender deliverySender,
    ILogger<SupportChatPushOutboxProcessor> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var message = await ClaimNextAsync(cancellationToken);
        if (message is null)
        {
            return await CleanupNextSentAsync(cancellationToken);
        }

        PushOutboxMetrics.RecordAttempt("support");

        PushDeliveryResult result;
        try
        {
            result = message.Kind == SupportChatPushNotificationOutbox.UserMessageKind
                ? await deliverySender.DeliverUserAsync(
                    Deserialize<SupportChatPushNotification>(message.PayloadJson),
                    cancellationToken)
                : PushDeliveryResult.PermanentFailure("push.kind_unknown");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Support push outbox delivery failed. MessageIdHash={MessageIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(message.Id.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            result = PushDeliveryResult.Retry("fcm.transport_error");
        }

        ApplyResult(message, result);
        PushOutboxMetrics.RecordResult("support", message);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<PushOutboxMessage?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var ids = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE support_push_outbox
            SET "Status" = {1}, "AttemptCount" = "AttemptCount" + 1,
                "LockId" = {4}, "LockExpiresAtUtc" = {5}, "UpdatedAtUtc" = {2}
            WHERE "Id" = (
                SELECT "Id" FROM support_push_outbox
                WHERE (("Status" = {0} AND "NextAttemptAtUtc" <= {2})
                       OR ("Status" = {1} AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
                  AND "AttemptCount" < {3}
                ORDER BY "NextAttemptAtUtc", "CreatedAtUtc"
                FOR UPDATE SKIP LOCKED LIMIT 1)
            RETURNING "Id" AS "Value";
            """,
            (int)PushOutboxStatus.Queued,
            (int)PushOutboxStatus.Processing,
            now,
            PushOutboxPolicy.MaxAttempts,
            Guid.NewGuid(),
            now.Add(PushOutboxPolicy.LeaseDuration)).ToListAsync(cancellationToken);

        var id = ids.FirstOrDefault();
        return id == Guid.Empty
            ? null
            : await dbContext.PushOutboxMessages.SingleAsync(x => x.Id == id, cancellationToken);
    }

    private static T Deserialize<T>(string json) =>
        JsonSerializer.Deserialize<T>(json, JsonOptions)
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
        }
        else if (result.Disposition == PushDeliveryDisposition.PermanentFailure
                 || message.AttemptCount >= PushOutboxPolicy.MaxAttempts)
        {
            message.Status = PushOutboxStatus.DeadLetter;
        }
        else
        {
            message.Status = PushOutboxStatus.Queued;
            message.NextAttemptAtUtc = now.Add(PushOutboxPolicy.RetryDelay(message.AttemptCount));
        }
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
