using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Infrastructure.Data;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyAdminAuditOutbox(
    EconomyDbContext dbContext,
    IAdminAuditLog? adminAuditLog = null,
    IHttpContextAccessor? httpContextAccessor = null,
    ILogger<EconomyAdminAuditOutbox>? logger = null)
{
    internal const string Kind = "admin_audit";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal PendingAdminAudit Enqueue(AdminAuditEntry entry)
    {
        var now = DateTime.UtcNow;
        var httpContext = httpContextAccessor?.HttpContext;
        var capturedEntry = new AdminAuditEntry(
            Truncate(entry.Action, 120) ?? string.Empty,
            Truncate(entry.TargetType, 80) ?? string.Empty,
            SafeLogValues.SanitizeText(entry.TargetId, 160),
            SanitizeNullable(entry.OldValue, 2000),
            SanitizeNullable(entry.NewValue, 2000),
            SanitizeNullable(entry.Details ?? entry.Action, 2000),
            entry.SubjectUserId,
            entry.EventId is { } eventId && eventId != Guid.Empty ? eventId : Guid.NewGuid(),
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
            DeduplicationKey = $"admin-audit:{capturedEntry.EventId!.Value:D}",
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

    internal async Task TryDeliverAsync(PendingAdminAudit pending, CancellationToken cancellationToken)
    {
        if (adminAuditLog is null)
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
                "Immediate economy admin audit delivery failed; the durable outbox event remains queued. EventIdHash={EventIdHash} ExceptionType={ExceptionType}",
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
            // The central sink is idempotent by EventId. Keep the durable event queued
            // when its completion marker cannot be persisted so the worker can replay it.
            message.Status = PushOutboxStatus.Queued;
            message.SentAtUtc = null;
            message.UpdatedAtUtc = queuedUpdatedAtUtc;
            message.LastErrorCode = null;
            message.LockId = null;
            message.LockExpiresAtUtc = null;
            dbContext.Entry(message).State = EntityState.Unchanged;

            logger?.LogWarning(
                "Immediate economy admin audit completion could not be persisted; the event remains replayable. EventIdHash={EventIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(pending.Entry.EventId!.Value.ToString("D")),
                SafeLogValues.ExceptionType(exception));
        }
    }

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

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength];
    }

    private static string? SanitizeNullable(string? value, int maxLength) =>
        value is null ? null : SafeLogValues.SanitizeText(value, maxLength);

    internal sealed record PendingAdminAudit(PushOutboxMessage Message, AdminAuditEntry Entry);
}
