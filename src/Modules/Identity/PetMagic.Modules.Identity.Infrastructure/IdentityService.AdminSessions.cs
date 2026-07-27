using System.Globalization;
using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private const int MaxAdminUserSessionsPageSize = 100;
    private const string AdminUserSessionIdempotencyScope = "petmagic.admin.user-session-revoke:v1";
    private const string AdminUserSessionRevokeAction = "admin.user.session.revoked";
    private const string AdminUserSessionsRevokeAllAction = "admin.user.sessions.revoked_all";

    public async Task<Result<AdminUserSessionsResponse>> GetAdminUserSessionsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (!await dbContext.Users.AsNoTracking().AnyAsync(user => user.Id == userId, cancellationToken))
        {
            return Result.Failure<AdminUserSessionsResponse>(IdentityErrors.UserNotFound);
        }

        var now = DateTime.UtcNow;
        var query = dbContext.RefreshTokenSessions
            .AsNoTracking()
            .Where(session => session.UserId == userId);
        var totalCount = await query.CountAsync(cancellationToken);
        var activeCount = await query.CountAsync(
            session => session.RevokedAtUtc == null && session.ExpiresAtUtc > now,
            cancellationToken);
        var sessions = await query
            .OrderBy(session => session.RevokedAtUtc != null || session.ExpiresAtUtc <= now)
            .ThenByDescending(session => session.CreatedAtUtc)
            .Take(MaxAdminUserSessionsPageSize)
            .Select(session => new
            {
                session.Id,
                session.CreatedAtUtc,
                session.ExpiresAtUtc,
                session.RevokedAtUtc
            })
            .ToListAsync(cancellationToken);

        return Result.Success(new AdminUserSessionsResponse(
            sessions
                .Select(session =>
                {
                    var status = ResolveAdminUserSessionStatus(
                        session.RevokedAtUtc,
                        session.ExpiresAtUtc,
                        now);
                    return new AdminUserSessionListItemResponse(
                        session.Id,
                        status,
                        string.Equals(status, "active", StringComparison.Ordinal),
                        session.CreatedAtUtc,
                        session.ExpiresAtUtc,
                        session.RevokedAtUtc);
                })
                .ToArray(),
            totalCount,
            activeCount,
            totalCount > sessions.Count));
    }

    public Task<Result<AdminUserSessionRevokeResponse>> RevokeAdminUserSessionAsync(
        AdminRevokeUserSessionCommand command,
        CancellationToken cancellationToken)
    {
        return RevokeAdminUserSessionsCoreAsync(
            command.ActorUserId,
            command.UserId,
            command.SessionId,
            command.Reason,
            command.IdempotencyKey,
            revokeAll: false,
            cancellationToken);
    }

    public Task<Result<AdminUserSessionRevokeResponse>> RevokeAllAdminUserSessionsAsync(
        AdminRevokeAllUserSessionsCommand command,
        CancellationToken cancellationToken)
    {
        return RevokeAdminUserSessionsCoreAsync(
            command.ActorUserId,
            command.UserId,
            sessionId: null,
            command.Reason,
            command.IdempotencyKey,
            revokeAll: true,
            cancellationToken);
    }

    private async Task<Result<AdminUserSessionRevokeResponse>> RevokeAdminUserSessionsCoreAsync(
        Guid actorUserId,
        Guid userId,
        Guid? sessionId,
        string reason,
        string? idempotencyKey,
        bool revokeAll,
        CancellationToken cancellationToken)
    {
        var normalizedReason = reason.Trim();
        var normalizedIdempotencyKey = idempotencyKey?.Trim();
        if (actorUserId == Guid.Empty
            || userId == Guid.Empty
            || string.IsNullOrWhiteSpace(normalizedReason)
            || string.IsNullOrWhiteSpace(normalizedIdempotencyKey))
        {
            return Result.Failure<AdminUserSessionRevokeResponse>(IdentityErrors.OperationFailed);
        }

        var userExists = await dbContext.Users
            .AsNoTracking()
            .AnyAsync(user => user.Id == userId, cancellationToken);
        if (!userExists)
        {
            return Result.Failure<AdminUserSessionRevokeResponse>(IdentityErrors.UserNotFound);
        }

        var auditEventId = CreateAdminUserSessionAuditEventId(actorUserId, normalizedIdempotencyKey);
        var requestHash = CreateAdminUserSessionRequestHash(
            userId,
            sessionId,
            normalizedReason,
            revokeAll);
        var replay = await TryResolveAdminUserSessionReplayAsync(
            auditEventId,
            userId,
            sessionId,
            requestHash,
            cancellationToken);
        if (replay is not null)
        {
            return replay;
        }

        for (var attempt = 0; attempt < 2; attempt++)
        {
            var now = DateTime.UtcNow;
            var revokedCount = 0;

            if (revokeAll)
            {
                var activeSessions = await dbContext.RefreshTokenSessions
                    .Where(session => session.UserId == userId
                        && session.RevokedAtUtc == null
                        && session.ExpiresAtUtc > now)
                    .ToListAsync(cancellationToken);
                foreach (var activeSession in activeSessions)
                {
                    activeSession.RevokedAtUtc = now;
                }

                revokedCount = activeSessions.Count;

                var user = await dbContext.Users.SingleAsync(
                    candidate => candidate.Id == userId,
                    cancellationToken);
                user.SecurityStamp = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture);
            }
            else
            {
                var session = await dbContext.RefreshTokenSessions
                    .SingleOrDefaultAsync(
                        candidate => candidate.Id == sessionId && candidate.UserId == userId,
                        cancellationToken);
                if (session is null)
                {
                    return Result.Failure<AdminUserSessionRevokeResponse>(
                        IdentityErrors.AdminUserSessionNotFound);
                }

                if (session.RevokedAtUtc is null && session.ExpiresAtUtc > now)
                {
                    session.RevokedAtUtc = now;
                    revokedCount = 1;
                }
            }

            var httpContext = httpContextAccessor.HttpContext;
            dbContext.AuditEvents.Add(new AuditEvent
            {
                Id = auditEventId,
                SubjectUserId = userId,
                ActorUserId = actorUserId,
                ActorRole = ResolveActorRole(httpContext),
                Action = revokeAll
                    ? AdminUserSessionsRevokeAllAction
                    : AdminUserSessionRevokeAction,
                TargetType = revokeAll ? "user-sessions" : "refresh-session",
                TargetId = (sessionId ?? userId).ToString("D"),
                OldValue = revokedCount.ToString(CultureInfo.InvariantCulture),
                NewValue = requestHash,
                IpAddress = ResolveClientIpAddress(httpContext),
                UserAgent = httpContext?.Request.Headers.UserAgent.ToString(),
                CorrelationId = CorrelationContext.ResolveOrCreate(),
                Details = revokeAll
                    ? $"Revoked {revokedCount} active user sessions. Reason: {normalizedReason}"
                    : $"Revoked active user session: {revokedCount == 1}. Reason: {normalizedReason}",
                CreatedAtUtc = now,
                OccurredAtUtc = now
            });

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return Result.Success(new AdminUserSessionRevokeResponse(
                    userId,
                    sessionId,
                    revokedCount,
                    now,
                    Replayed: false));
            }
            catch (DbUpdateConcurrencyException) when (attempt == 0)
            {
                dbContext.ChangeTracker.Clear();
                replay = await TryResolveAdminUserSessionReplayAsync(
                    auditEventId,
                    userId,
                    sessionId,
                    requestHash,
                    cancellationToken);
                if (replay is not null)
                {
                    return replay;
                }
            }
            catch (DbUpdateException)
            {
                dbContext.ChangeTracker.Clear();
                replay = await TryResolveAdminUserSessionReplayAsync(
                    auditEventId,
                    userId,
                    sessionId,
                    requestHash,
                    cancellationToken);
                return replay
                    ?? Result.Failure<AdminUserSessionRevokeResponse>(IdentityErrors.OperationFailed);
            }
        }

        return Result.Failure<AdminUserSessionRevokeResponse>(IdentityErrors.OperationFailed);
    }

    private async Task<Result<AdminUserSessionRevokeResponse>?> TryResolveAdminUserSessionReplayAsync(
        Guid auditEventId,
        Guid userId,
        Guid? sessionId,
        string requestHash,
        CancellationToken cancellationToken)
    {
        var existingAuditEvent = await dbContext.AuditEvents
            .AsNoTracking()
            .SingleOrDefaultAsync(auditEvent => auditEvent.Id == auditEventId, cancellationToken);
        if (existingAuditEvent is null)
        {
            return null;
        }

        if (!string.Equals(existingAuditEvent.NewValue, requestHash, StringComparison.Ordinal))
        {
            return Result.Failure<AdminUserSessionRevokeResponse>(
                IdentityErrors.AdminUserSessionIdempotencyConflict);
        }

        _ = int.TryParse(
            existingAuditEvent.OldValue,
            NumberStyles.None,
            CultureInfo.InvariantCulture,
            out var revokedCount);
        return Result.Success(new AdminUserSessionRevokeResponse(
            userId,
            sessionId,
            Math.Max(0, revokedCount),
            existingAuditEvent.OccurredAtUtc,
            Replayed: true));
    }

    private static Guid CreateAdminUserSessionAuditEventId(Guid actorUserId, string idempotencyKey)
    {
        var rawKey = $"{AdminUserSessionIdempotencyScope}:{actorUserId:D}:{idempotencyKey}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey)).AsSpan(0, 16));
    }

    private static string CreateAdminUserSessionRequestHash(
        Guid userId,
        Guid? sessionId,
        string reason,
        bool revokeAll)
    {
        var canonicalRequest = new StringBuilder();
        AppendAdminUserSessionHashPart(canonicalRequest, revokeAll ? "all" : "single");
        AppendAdminUserSessionHashPart(canonicalRequest, userId.ToString("D"));
        AppendAdminUserSessionHashPart(canonicalRequest, sessionId?.ToString("D") ?? string.Empty);
        AppendAdminUserSessionHashPart(canonicalRequest, reason);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalRequest.ToString())));
    }

    private static void AppendAdminUserSessionHashPart(StringBuilder builder, string value)
    {
        builder.Append(value.Length).Append(':').Append(value);
    }

    private static string ResolveAdminUserSessionStatus(
        DateTime? revokedAtUtc,
        DateTime expiresAtUtc,
        DateTime now)
    {
        if (revokedAtUtc.HasValue)
        {
            return "revoked";
        }

        return expiresAtUtc <= now ? "expired" : "active";
    }
}
