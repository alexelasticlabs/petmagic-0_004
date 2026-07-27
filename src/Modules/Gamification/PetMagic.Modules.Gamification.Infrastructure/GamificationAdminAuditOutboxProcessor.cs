using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Gamification.Infrastructure.Data;

namespace PetMagic.Modules.Gamification.Infrastructure;

internal sealed class GamificationAdminAuditOutboxProcessor(
    GamificationDbContext dbContext,
    IAdminAuditLog adminAuditLog,
    ILogger<GamificationAdminAuditOutboxProcessor> logger)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var message = await ClaimNextAsync(cancellationToken);
        if (message is null)
        {
            return await CleanupNextSentAsync(cancellationToken);
        }

        PushOutboxMetrics.RecordAttempt("gamification_admin_audit");

        PushDeliveryResult result;
        if (message.AttemptCount > PushOutboxPolicy.MaxAttempts)
        {
            result = PushDeliveryResult.PermanentFailure("admin_audit.attempts_exhausted");
        }
        else try
        {
            result = message.Kind == GamificationAdminAuditOutbox.AdminAuditKind
                ? await DeliverAdminAuditAsync(message.PayloadJson, cancellationToken)
                : PushDeliveryResult.PermanentFailure("admin_audit.kind_unknown");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Gamification admin audit outbox delivery failed. MessageIdHash={MessageIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(message.Id.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            result = PushDeliveryResult.Retry("admin_audit.write_failed");
        }

        ApplyResult(message, result);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            PushOutboxMetrics.RecordResult("gamification_admin_audit", message);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            logger.LogInformation(
                "Gamification admin audit outbox completion ignored because the processing lease was reclaimed. MessageIdHash={MessageIdHash}",
                SafeLogValues.StableHash(message.Id.ToString("D")));
        }

        return true;
    }

    private async Task<PushOutboxMessage?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        if (!string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            return await ClaimNextTrackedAsync(cancellationToken);
        }

        var now = DateTime.UtcNow;
        var ids = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE gamification_push_outbox
            SET "Status" = {1}, "AttemptCount" = "AttemptCount" + 1,
                "LockId" = {4}, "LockExpiresAtUtc" = {5}, "UpdatedAtUtc" = {2}
            WHERE "Id" = (
                SELECT "Id" FROM gamification_push_outbox
                WHERE (("Status" = {0} AND "NextAttemptAtUtc" <= {2} AND "AttemptCount" < {3})
                       OR ("Status" = {1} AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
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

    private async Task<PushOutboxMessage?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var message = await dbContext.PushOutboxMessages
            .Where(x => (x.Status == PushOutboxStatus.Queued
                        && x.NextAttemptAtUtc <= now
                        && x.AttemptCount < PushOutboxPolicy.MaxAttempts)
                    || (x.Status == PushOutboxStatus.Processing
                        && (x.LockExpiresAtUtc == null || x.LockExpiresAtUtc <= now)))
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

    private async Task<PushDeliveryResult> DeliverAdminAuditAsync(
        string payloadJson,
        CancellationToken cancellationToken)
    {
        var entry = JsonSerializer.Deserialize<AdminAuditEntry>(payloadJson, JsonOptions)
            ?? throw new JsonException("Gamification admin audit outbox payload is empty.");
        await adminAuditLog.WriteAsync(entry, cancellationToken);
        return PushDeliveryResult.Delivered;
    }

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
