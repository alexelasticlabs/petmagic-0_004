using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private const string AdminBulkEmailRetryFailedAction = "admin.bulk_email.retry_failed";

    public async Task<Result<AdminEmailBroadcastsPageResponse>> ListAdminEmailBroadcastsAsync(
        int skip,
        int take,
        string? status,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 50, 200);
        if (!TryParseAdminEmailBroadcastStatus(status, out var statusFilter))
        {
            return Result.Failure<AdminEmailBroadcastsPageResponse>(IdentityErrors.BulkEmailBroadcastStatusInvalid);
        }

        var query = dbContext.AdminEmailBroadcasts.AsNoTracking();
        if (statusFilter.HasValue)
        {
            query = query.Where(x => x.Status == statusFilter.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var broadcasts = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake)
            .ToListAsync(cancellationToken);

        return Result.Success(new AdminEmailBroadcastsPageResponse(
            [.. broadcasts.Select(ToAdminEmailBroadcastListItemResponse)],
            normalizedSkip,
            normalizedTake,
            totalCount,
            normalizedSkip + broadcasts.Count < totalCount));
    }

    public async Task<Result<AdminEmailBroadcastDetailResponse>> GetAdminEmailBroadcastAsync(
        Guid broadcastId,
        CancellationToken cancellationToken)
    {
        var broadcast = await dbContext.AdminEmailBroadcasts
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == broadcastId, cancellationToken);
        if (broadcast is null)
        {
            return Result.Failure<AdminEmailBroadcastDetailResponse>(IdentityErrors.BulkEmailBroadcastNotFound);
        }

        var retryableFailedCount = await dbContext.EmailDispatchJobs
            .AsNoTracking()
            .CountAsync(
                x => x.BroadcastId == broadcastId && x.Status == EmailDispatchStatus.Failed,
                cancellationToken);

        return Result.Success(ToAdminEmailBroadcastDetailResponse(broadcast, retryableFailedCount));
    }

    public async Task<Result<AdminEmailBroadcastRetryResponse>> RetryFailedAdminEmailBroadcastAsync(
        Guid broadcastId,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.AdminEmailBroadcasts
            .AsNoTracking()
            .AnyAsync(x => x.Id == broadcastId, cancellationToken);
        if (!exists)
        {
            return Result.Failure<AdminEmailBroadcastRetryResponse>(IdentityErrors.BulkEmailBroadcastNotFound);
        }

        var now = DateTime.UtcNow;
        var retriedCount = dbContext.Database.IsRelational()
            ? await RetryFailedAdminEmailBroadcastRelationalAsync(broadcastId, now, cancellationToken)
            : await RetryFailedAdminEmailBroadcastTrackedAsync(broadcastId, now, cancellationToken);

        var detailResult = await GetAdminEmailBroadcastAsync(broadcastId, cancellationToken);
        if (detailResult.IsFailure)
        {
            return Result.Failure<AdminEmailBroadcastRetryResponse>(detailResult.Error);
        }

        var detail = detailResult.Value;
        return Result.Success(new AdminEmailBroadcastRetryResponse(
            detail.BroadcastId,
            retriedCount,
            detail.Status,
            detail.PendingCount,
            detail.SentCount,
            detail.FailedCount,
            detail.UpdatedAtUtc));
    }

    private async Task<int> RetryFailedAdminEmailBroadcastRelationalAsync(
        Guid broadcastId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var retriedCount = await dbContext.EmailDispatchJobs
            .Where(x => x.BroadcastId == broadcastId && x.Status == EmailDispatchStatus.Failed)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(x => x.Status, EmailDispatchStatus.Queued)
                    .SetProperty(x => x.AttemptCount, 0)
                    .SetProperty(x => x.QueuedAtUtc, now)
                    .SetProperty(x => x.UpdatedAtUtc, now)
                    .SetProperty(x => x.LastAttemptAtUtc, (DateTime?)null)
                    .SetProperty(x => x.NextAttemptAtUtc, now)
                    .SetProperty(x => x.LockId, (Guid?)null)
                    .SetProperty(x => x.LockExpiresAtUtc, (DateTime?)null)
                    .SetProperty(x => x.SentAtUtc, (DateTime?)null)
                    .SetProperty(x => x.FailureCode, (string?)null)
                    .SetProperty(x => x.FailureMessage, (string?)null),
                cancellationToken);

        if (retriedCount > 0)
        {
            await dbContext.AdminEmailBroadcasts
                .Where(x => x.Id == broadcastId)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(
                            x => x.FailedCount,
                            x => x.FailedCount >= retriedCount ? x.FailedCount - retriedCount : 0)
                        .SetProperty(
                            x => x.Status,
                            x => x.SentCount > 0
                                ? AdminEmailBroadcastStatus.Processing
                                : AdminEmailBroadcastStatus.Queued)
                        .SetProperty(x => x.UpdatedAtUtc, now)
                        .SetProperty(x => x.CompletedAtUtc, (DateTime?)null),
                    cancellationToken);

            dbContext.AuditEvents.Add(CreateAdminEmailBroadcastRetryAuditEvent(broadcastId, retriedCount, now));
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return retriedCount;
    }

    private async Task<int> RetryFailedAdminEmailBroadcastTrackedAsync(
        Guid broadcastId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var broadcast = await dbContext.AdminEmailBroadcasts
            .SingleAsync(x => x.Id == broadcastId, cancellationToken);
        var failedJobs = await dbContext.EmailDispatchJobs
            .Where(x => x.BroadcastId == broadcastId && x.Status == EmailDispatchStatus.Failed)
            .ToListAsync(cancellationToken);

        foreach (var job in failedJobs)
        {
            job.Status = EmailDispatchStatus.Queued;
            job.AttemptCount = 0;
            job.QueuedAtUtc = now;
            job.UpdatedAtUtc = now;
            job.LastAttemptAtUtc = null;
            job.NextAttemptAtUtc = now;
            job.LockId = null;
            job.LockExpiresAtUtc = null;
            job.SentAtUtc = null;
            job.FailureCode = null;
            job.FailureMessage = null;
        }

        if (failedJobs.Count > 0)
        {
            broadcast.FailedCount = Math.Max(0, broadcast.FailedCount - failedJobs.Count);
            broadcast.Status = broadcast.SentCount > 0
                ? AdminEmailBroadcastStatus.Processing
                : AdminEmailBroadcastStatus.Queued;
            broadcast.UpdatedAtUtc = now;
            broadcast.CompletedAtUtc = null;
            dbContext.AuditEvents.Add(CreateAdminEmailBroadcastRetryAuditEvent(broadcastId, failedJobs.Count, now));
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return failedJobs.Count;
    }

    private AuditEvent CreateAdminEmailBroadcastRetryAuditEvent(Guid broadcastId, int retriedCount, DateTime now)
    {
        var httpContext = httpContextAccessor.HttpContext;
        return new AuditEvent
        {
            Id = Guid.NewGuid(),
            ActorUserId = ResolveActorUserId(httpContext),
            ActorRole = ResolveActorRole(httpContext),
            Action = AdminBulkEmailRetryFailedAction,
            TargetType = "email-broadcast",
            TargetId = broadcastId.ToString("D"),
            NewValue = $"retry-failed:{retriedCount}",
            IpAddress = ResolveClientIpAddress(httpContext),
            UserAgent = httpContext?.Request.Headers.UserAgent.ToString(),
            CorrelationId = CorrelationContext.ResolveOrCreate(),
            Details = $"Requeued {retriedCount} failed email dispatch jobs.",
            CreatedAtUtc = now,
            OccurredAtUtc = now
        };
    }

    private static AdminEmailBroadcastQueueResponse ToAdminEmailBroadcastQueueResponse(
        Guid broadcastId,
        int recipientCount,
        AdminEmailBroadcastStatus status,
        DateTime createdAtUtc)
    {
        return new AdminEmailBroadcastQueueResponse(
            broadcastId,
            recipientCount,
            ToAdminEmailBroadcastStatus(status),
            createdAtUtc);
    }

    private static AdminEmailBroadcastListItemResponse ToAdminEmailBroadcastListItemResponse(
        AdminEmailBroadcast broadcast)
    {
        return new AdminEmailBroadcastListItemResponse(
            broadcast.Id,
            broadcast.Audience,
            broadcast.Subject,
            ToAdminEmailBroadcastStatus(broadcast.Status),
            broadcast.RecipientCount,
            CalculatePendingCount(broadcast),
            broadcast.SentCount,
            broadcast.FailedCount,
            broadcast.CreatedAtUtc,
            broadcast.UpdatedAtUtc,
            broadcast.CompletedAtUtc);
    }

    private static AdminEmailBroadcastDetailResponse ToAdminEmailBroadcastDetailResponse(
        AdminEmailBroadcast broadcast,
        int retryableFailedCount)
    {
        return new AdminEmailBroadcastDetailResponse(
            broadcast.Id,
            broadcast.Audience,
            broadcast.Subject,
            ToAdminEmailBroadcastStatus(broadcast.Status),
            broadcast.RecipientCount,
            CalculatePendingCount(broadcast),
            broadcast.SentCount,
            broadcast.FailedCount,
            retryableFailedCount,
            broadcast.CreatedAtUtc,
            broadcast.UpdatedAtUtc,
            broadcast.CompletedAtUtc);
    }

    private static int CalculatePendingCount(AdminEmailBroadcast broadcast)
    {
        return broadcast.Status == AdminEmailBroadcastStatus.Legacy
            ? 0
            : Math.Max(0, broadcast.RecipientCount - broadcast.SentCount - broadcast.FailedCount);
    }

    private static string ToAdminEmailBroadcastStatus(AdminEmailBroadcastStatus status)
    {
        return status switch
        {
            AdminEmailBroadcastStatus.Queued => AdminEmailBroadcastStatuses.Queued,
            AdminEmailBroadcastStatus.Processing => AdminEmailBroadcastStatuses.Processing,
            AdminEmailBroadcastStatus.Completed => AdminEmailBroadcastStatuses.Completed,
            AdminEmailBroadcastStatus.PartiallyFailed => AdminEmailBroadcastStatuses.PartiallyFailed,
            AdminEmailBroadcastStatus.Failed => AdminEmailBroadcastStatuses.Failed,
            _ => AdminEmailBroadcastStatuses.Legacy
        };
    }

    private static bool TryParseAdminEmailBroadcastStatus(
        string? status,
        out AdminEmailBroadcastStatus? parsedStatus)
    {
        var normalized = status?.Trim().ToLowerInvariant();
        parsedStatus = normalized switch
        {
            null or "" => null,
            AdminEmailBroadcastStatuses.Legacy => AdminEmailBroadcastStatus.Legacy,
            AdminEmailBroadcastStatuses.Queued => AdminEmailBroadcastStatus.Queued,
            AdminEmailBroadcastStatuses.Processing => AdminEmailBroadcastStatus.Processing,
            AdminEmailBroadcastStatuses.Completed => AdminEmailBroadcastStatus.Completed,
            AdminEmailBroadcastStatuses.PartiallyFailed => AdminEmailBroadcastStatus.PartiallyFailed,
            AdminEmailBroadcastStatuses.Failed => AdminEmailBroadcastStatus.Failed,
            _ => null
        };

        return string.IsNullOrWhiteSpace(normalized) || parsedStatus.HasValue;
    }
}
