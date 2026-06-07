using System.Security.Claims;

using Microsoft.AspNetCore.Http;

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
        var now = DateTime.UtcNow;
        var httpContext = httpContextAccessor.HttpContext;

        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = entry.SubjectUserId,
            ActorUserId = ResolveActorUserId(httpContext),
            ActorRole = ResolveActorRole(httpContext),
            Action = Truncate(entry.Action, 120) ?? string.Empty,
            TargetType = Truncate(entry.TargetType, 80),
            TargetId = Truncate(entry.TargetId, 160),
            OldValue = Truncate(entry.OldValue, 2000),
            NewValue = Truncate(entry.NewValue, 2000),
            IpAddress = Truncate(ResolveClientIpAddress(httpContext), 64),
            UserAgent = Truncate(httpContext?.Request.Headers.UserAgent.ToString(), 512),
            CorrelationId = Truncate(CorrelationContext.ResolveOrCreate(), 128),
            Details = Truncate(entry.Details ?? entry.Action, 2000) ?? string.Empty,
            CreatedAtUtc = now,
            OccurredAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
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

        var forwardedFor = httpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(forwardedFor))
        {
            var firstAddress = forwardedFor.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(firstAddress))
            {
                return firstAddress;
            }
        }

        return httpContext.Connection.RemoteIpAddress?.ToString();
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
