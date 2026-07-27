using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateAdminAuditOutbox
{
    internal const string Kind = "admin_audit";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal static PendingAdminAudit Enqueue(
        TemplatesDbContext dbContext,
        AdminAuditEntry entry,
        HttpContext? httpContext = null)
    {
        var eventId = entry.EventId is { } value && value != Guid.Empty
            ? value
            : throw new InvalidOperationException("Durable template admin audit entries require an event id.");
        var now = DateTime.UtcNow;
        var capturedEntry = new AdminAuditEntry(
            Truncate(entry.Action, 120) ?? string.Empty,
            Truncate(entry.TargetType, 80) ?? string.Empty,
            SanitizeNullable(entry.TargetId, 160) ?? string.Empty,
            SanitizeNullable(entry.OldValue, 2000),
            SanitizeNullable(entry.NewValue, 2000),
            SanitizeNullable(entry.Details ?? entry.Action, 2000),
            entry.SubjectUserId,
            eventId,
            entry.ActorUserId ?? ResolveActorUserId(httpContext),
            Truncate(entry.CorrelationId ?? CorrelationContext.ResolveOrCreate(), CorrelationContext.MaxLength))
        {
            ActorRole = SanitizeNullable(entry.ActorRole ?? ResolveActorRole(httpContext), 80),
            IpAddress = SanitizeNullable(
                entry.IpAddress ?? httpContext?.Connection.RemoteIpAddress?.ToString(),
                64),
            UserAgent = SanitizeNullable(
                entry.UserAgent ?? httpContext?.Request.Headers.UserAgent.ToString(),
                512),
            OccurredAtUtc = entry.OccurredAtUtc ?? now
        };

        var message = new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = BuildDeduplicationKey(eventId),
            Kind = Kind,
            UserId = capturedEntry.ActorUserId ?? capturedEntry.SubjectUserId ?? Guid.Empty,
            PayloadJson = JsonSerializer.Serialize(capturedEntry, JsonOptions),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.PushOutboxMessages.Add(message);
        return new PendingAdminAudit(message, capturedEntry);
    }

    internal static async Task TryDeliverAsync(
        TemplatesDbContext dbContext,
        IAdminAuditLog? adminAuditLog,
        ILogger? logger,
        PendingAdminAudit pending,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null || pending.Message.Status == PushOutboxStatus.Sent)
        {
            return;
        }

        try
        {
            await adminAuditLog.WriteAsync(pending.Entry, cancellationToken);
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                "Immediate template admin audit delivery failed; the durable outbox event remains queued. EventIdHash={EventIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(pending.Entry.EventId!.Value.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            return;
        }

        var message = pending.Message;
        var queuedUpdatedAtUtc = message.UpdatedAtUtc;
        var deliveredAtUtc = DateTime.UtcNow;
        message.Status = PushOutboxStatus.Sent;
        message.SentAtUtc = deliveredAtUtc;
        message.UpdatedAtUtc = deliveredAtUtc;
        message.LastErrorCode = null;
        message.LockId = null;
        message.LockExpiresAtUtc = null;

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (Exception exception)
        {
            // Identity audit persistence is idempotent by EventId. Keep the local event queued
            // when its completion marker cannot be saved so the worker can safely replay it.
            message.Status = PushOutboxStatus.Queued;
            message.SentAtUtc = null;
            message.UpdatedAtUtc = queuedUpdatedAtUtc;
            message.LastErrorCode = null;
            message.LockId = null;
            message.LockExpiresAtUtc = null;
            dbContext.Entry(message).State = EntityState.Unchanged;
            logger?.LogWarning(
                "Immediate template admin audit completion could not be persisted; the event remains replayable. EventIdHash={EventIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(pending.Entry.EventId!.Value.ToString("D")),
                SafeLogValues.ExceptionType(exception));
        }
    }

    internal static async Task TryDeliverExistingAsync(
        TemplatesDbContext dbContext,
        IAdminAuditLog? adminAuditLog,
        ILogger? logger,
        Guid eventId,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null)
        {
            return;
        }

        var message = dbContext.PushOutboxMessages.Local.FirstOrDefault(
                item => item.DeduplicationKey == BuildDeduplicationKey(eventId))
            ?? await dbContext.PushOutboxMessages.SingleOrDefaultAsync(
                item => item.DeduplicationKey == BuildDeduplicationKey(eventId),
                cancellationToken);
        if (message is null
            || message.Status == PushOutboxStatus.Sent
            || (message.Status == PushOutboxStatus.Processing
                && message.LockExpiresAtUtc > DateTime.UtcNow))
        {
            return;
        }

        AdminAuditEntry entry;
        try
        {
            entry = Deserialize(message.PayloadJson);
        }
        catch (JsonException exception)
        {
            logger?.LogWarning(
                "Template admin audit replay payload is invalid. EventIdHash={EventIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(eventId.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            return;
        }

        await TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            new PendingAdminAudit(message, entry),
            cancellationToken);
    }

    internal static AdminAuditEntry Deserialize(string payloadJson) =>
        JsonSerializer.Deserialize<AdminAuditEntry>(payloadJson, JsonOptions)
        ?? throw new JsonException("Template admin audit outbox payload is empty.");

    private static string BuildDeduplicationKey(Guid eventId) =>
        $"templates_admin_audit:{eventId:D}";

    private static Guid? ResolveActorUserId(HttpContext? httpContext)
    {
        var value = httpContext?.User.FindFirst("sub")?.Value
            ?? httpContext?.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? httpContext?.User.FindFirst("userId")?.Value;
        return Guid.TryParse(value, out var userId) ? userId : null;
    }

    private static string? ResolveActorRole(HttpContext? httpContext)
    {
        var roles = httpContext?.User.FindAll(ClaimTypes.Role)
            .Select(claim => claim.Value)
            .Where(role => !string.IsNullOrWhiteSpace(role))
            .OrderBy(role => role, StringComparer.OrdinalIgnoreCase)
            .ToArray();
        return roles is { Length: > 0 } ? string.Join(",", roles) : null;
    }

    private static string? SanitizeNullable(string? value, int maxLength) =>
        value is null ? null : SafeLogValues.SanitizeText(value, maxLength);

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength];
    }

    internal sealed record PendingAdminAudit(PushOutboxMessage Message, AdminAuditEntry Entry);
}
