using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateAdminAuditOutboxProcessor(
    TemplatesDbContext dbContext,
    IAdminAuditLog adminAuditLog,
    ILogger<TemplateAdminAuditOutboxProcessor> logger)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var message = await ClaimNextAsync(cancellationToken);
        if (message is null)
        {
            return await CleanupNextSentAsync(cancellationToken);
        }

        PushOutboxMetrics.RecordAttempt("templates_admin_audit");

        PushDeliveryResult result;
        if (message.AttemptCount > PushOutboxPolicy.MaxAttempts)
        {
            result = PushDeliveryResult.PermanentFailure("admin_audit.attempts_exhausted");
        }
        else try
        {
            result = await DeliverAdminAuditAsync(message, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template admin audit outbox delivery failed. MessageIdHash={MessageIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(message.Id.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            result = PushDeliveryResult.Retry("admin_audit.write_failed");
        }

        ApplyResult(message, result);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            PushOutboxMetrics.RecordResult("templates_admin_audit", message);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            logger.LogInformation(
                "Template admin audit outbox completion ignored because the processing lease was reclaimed. MessageIdHash={MessageIdHash}",
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
            UPDATE templates_push_outbox
            SET "Status" = {1}, "AttemptCount" = "AttemptCount" + 1,
                "LockId" = {4}, "LockExpiresAtUtc" = {5}, "UpdatedAtUtc" = {2}
            WHERE "Id" = (
                SELECT "Id" FROM templates_push_outbox
                WHERE (("Status" = {0} AND "NextAttemptAtUtc" <= {2} AND "AttemptCount" < {3})
                       OR ("Status" = {1} AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
                    AND "Kind" = {6}
                ORDER BY "NextAttemptAtUtc", "CreatedAtUtc"
                FOR UPDATE SKIP LOCKED LIMIT 1)
            RETURNING "Id" AS "Value";
            """,
            (int)PushOutboxStatus.Queued,
            (int)PushOutboxStatus.Processing,
            now,
            PushOutboxPolicy.MaxAttempts,
            Guid.NewGuid(),
            now.Add(PushOutboxPolicy.LeaseDuration),
            TemplateAdminAuditOutbox.Kind).ToListAsync(cancellationToken);

        var id = ids.FirstOrDefault();
        return id == Guid.Empty
            ? null
            : await dbContext.PushOutboxMessages.SingleAsync(item => item.Id == id, cancellationToken);
    }

    private async Task<PushOutboxMessage?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var message = await dbContext.PushOutboxMessages
            .Where(item => item.Kind == TemplateAdminAuditOutbox.Kind)
            .Where(item => (item.Status == PushOutboxStatus.Queued
                        && item.NextAttemptAtUtc <= now
                        && item.AttemptCount < PushOutboxPolicy.MaxAttempts)
                    || (item.Status == PushOutboxStatus.Processing
                        && (item.LockExpiresAtUtc == null || item.LockExpiresAtUtc <= now)))
            .OrderBy(item => item.NextAttemptAtUtc)
            .ThenBy(item => item.CreatedAtUtc)
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
        PushOutboxMessage message,
        CancellationToken cancellationToken)
    {
        AdminAuditEntry entry;
        try
        {
            entry = TemplateAdminAuditOutbox.Deserialize(message.PayloadJson);
        }
        catch (System.Text.Json.JsonException)
        {
            return PushDeliveryResult.PermanentFailure("admin_audit.payload_invalid");
        }

        if (!entry.EventId.HasValue
            || entry.EventId.Value == Guid.Empty
            || string.IsNullOrWhiteSpace(entry.Action)
            || string.IsNullOrWhiteSpace(entry.TargetType)
            || string.IsNullOrWhiteSpace(entry.TargetId))
        {
            return PushDeliveryResult.PermanentFailure("admin_audit.payload_invalid");
        }

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
            .Where(item => item.Kind == TemplateAdminAuditOutbox.Kind
                && item.Status == PushOutboxStatus.Sent
                && item.SentAtUtc <= cutoff)
            .OrderBy(item => item.SentAtUtc)
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
