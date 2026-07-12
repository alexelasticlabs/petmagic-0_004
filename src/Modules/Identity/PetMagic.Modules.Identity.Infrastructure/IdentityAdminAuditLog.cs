using System.Security.Claims;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class IdentityAdminAuditLog(
    IdentityDbContext dbContext,
    IHttpContextAccessor httpContextAccessor) : IAdminAuditLog
{
    public async Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
    {
        if (entry.EventId.HasValue
            && await dbContext.AuditEvents.AsNoTracking().AnyAsync(
                auditEvent => auditEvent.Id == entry.EventId.Value,
                cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;
        var httpContext = httpContextAccessor.HttpContext;

        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = entry.EventId ?? Guid.NewGuid(),
            SubjectUserId = entry.SubjectUserId,
            ActorUserId = entry.ActorUserId ?? ResolveActorUserId(httpContext),
            ActorRole = ResolveActorRole(httpContext),
            Action = Truncate(entry.Action, 120) ?? string.Empty,
            TargetType = Truncate(entry.TargetType, 80),
            TargetId = SanitizeAndTruncate(entry.TargetId, 160),
            OldValue = SanitizeAndTruncate(entry.OldValue, 2000),
            NewValue = SanitizeAndTruncate(entry.NewValue, 2000),
            IpAddress = Truncate(ResolveClientIpAddress(httpContext), 64),
            UserAgent = SanitizeAndTruncate(httpContext?.Request.Headers.UserAgent.ToString(), 512),
            CorrelationId = Truncate(entry.CorrelationId ?? CorrelationContext.ResolveOrCreate(), 128),
            Details = SanitizeAndTruncate(entry.Details ?? entry.Action, 2000) ?? string.Empty,
            CreatedAtUtc = now,
            OccurredAtUtc = now
        });

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException) when (entry.EventId.HasValue)
        {
            dbContext.ChangeTracker.Clear();
            if (await dbContext.AuditEvents.AsNoTracking().AnyAsync(
                    auditEvent => auditEvent.Id == entry.EventId.Value,
                    cancellationToken))
            {
                return;
            }

            throw;
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

    private static string? ResolveClientIpAddress(HttpContext? httpContext)
    {
        if (httpContext is null)
        {
            return null;
        }

        return httpContext.Connection.RemoteIpAddress?.ToString();
    }

    private static string? SanitizeAndTruncate(string? value, int maxLength)
    {
        if (value is null)
        {
            return null;
        }

        return SafeLogValues.SanitizeText(value, maxLength);
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength];
    }
}
