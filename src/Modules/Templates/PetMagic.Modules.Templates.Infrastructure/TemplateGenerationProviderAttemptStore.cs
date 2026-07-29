using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed record TemplateGenerationProviderAttemptReservation(
    Guid GenerationJobId,
    TemplateGenerationProviderAttemptStage Stage,
    string Provider,
    string SubmissionTokenHash,
    DateTime SubmissionDeadlineAtUtc,
    DateTime ProcessingDeadlineAtUtc,
    DateTime ReconciliationDeadlineAtUtc,
    string? ExpectedJobLockOwner = null,
    TemplateGenerationStatus? ExpectedJobStatus = null);

internal sealed record TemplateGenerationProviderAttemptClaim(
    Guid AttemptId,
    Guid GenerationJobId,
    TemplateGenerationProviderAttemptStage Stage,
    int Ordinal,
    TemplateGenerationProviderAttemptState State,
    string Provider,
    string SubmissionTokenHash,
    string? ProviderRequestId,
    string? ProviderStatusUrl,
    string? ProviderResponseUrl,
    string? ProviderCancelUrl,
    int PollAttemptCount,
    int CancelAttemptCount,
    DateTime SubmissionDeadlineAtUtc,
    DateTime ProcessingDeadlineAtUtc,
    DateTime ReconciliationDeadlineAtUtc,
    bool IsBorrowedCapacity,
    string ClaimToken);

internal sealed record TemplateProviderWebhookInboxClaim(
    Guid InboxId,
    Guid? ProviderAttemptId,
    Guid? GenerationJobId,
    string Provider,
    string? CallbackTokenHash,
    string? ProviderRequestId,
    string EventType,
    string PayloadJson,
    TemplateProviderWebhookInboxStatus Status,
    int AttemptCount,
    int FailureCount,
    DateTime ReceivedAtUtc,
    string ClaimToken);

internal interface ITemplateGenerationProviderAttemptStore
{
    Task<TemplateGenerationProviderAttempt?> TryReserveAsync(
        TemplateGenerationProviderAttemptReservation reservation,
        CancellationToken cancellationToken);

    Task MarkSubmissionAcceptedAsync(
        Guid attemptId,
        string providerRequestId,
        string? statusUrl,
        string? responseUrl,
        string? cancelUrl,
        DateTime nextPollAtUtc,
        CancellationToken cancellationToken);

    Task MarkSubmittingAsync(Guid attemptId, CancellationToken cancellationToken);

    Task MarkSubmissionUnknownAsync(
        Guid attemptId,
        string errorCode,
        DateTime nextPollAtUtc,
        CancellationToken cancellationToken);

    Task MarkSubmissionFailedAsync(
        Guid attemptId,
        string errorCode,
        CancellationToken cancellationToken);

    Task<TemplateGenerationProviderAttemptClaim?> ClaimDueAsync(
        string workerId,
        TimeSpan lockTimeout,
        CancellationToken cancellationToken);

    Task ReleaseClaimAsync(
        Guid attemptId,
        string claimToken,
        CancellationToken cancellationToken);

    Task UpdateClaimedStateAsync(
        Guid attemptId,
        string workerId,
        TemplateGenerationProviderAttemptState state,
        DateTime? nextPollAtUtc,
        string? lastErrorCode,
        bool providerCompleted,
        CancellationToken cancellationToken);

    Task<bool> TryBeginPollAsync(
        Guid attemptId,
        string claimToken,
        int maxAttempts,
        CancellationToken cancellationToken);

    Task<bool> TryBeginCancellationAsync(
        Guid attemptId,
        string claimToken,
        int maxAttempts,
        CancellationToken cancellationToken);

    Task<Guid> EnqueueWebhookAsync(
        string provider,
        string deduplicationKey,
        string? callbackTokenHash,
        string? providerRequestId,
        string eventType,
        string payloadJson,
        DateTime signatureVerifiedAtUtc,
        CancellationToken cancellationToken);

    Task<TemplateProviderWebhookInboxClaim?> ClaimNextWebhookAsync(
        string workerId,
        TimeSpan lockTimeout,
        CancellationToken cancellationToken);

    Task MarkWebhookProcessedAsync(
        Guid inboxId,
        string workerId,
        CancellationToken cancellationToken);

    Task DeferWebhookAsync(
        Guid inboxId,
        string workerId,
        string errorCode,
        DateTime nextAttemptAtUtc,
        CancellationToken cancellationToken);

    Task<bool> MarkWebhookFailedAsync(
        Guid inboxId,
        string workerId,
        string errorCode,
        DateTime nextAttemptAtUtc,
        CancellationToken cancellationToken);

    Task<int> CleanupTerminalWebhooksAsync(
        DateTime cutoffUtc,
        int batchSize,
        CancellationToken cancellationToken);
}

internal sealed class TemplateGenerationProviderAttemptStore(
    TemplatesDbContext dbContext,
    ITemplateGenerationRuntimePolicyProvider runtimePolicyProvider,
    IFalProviderRuntimeSnapshotService providerRuntimeSnapshotService,
    TemplatesOptions? options = null)
    : ITemplateGenerationProviderAttemptStore
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const int WebhookPayloadMaxChars = 64 * 1024;
    private static readonly TemplateGenerationProviderAttemptState[] ActiveStates =
    [
        TemplateGenerationProviderAttemptState.SubmitReserved,
        TemplateGenerationProviderAttemptState.Submitting,
        TemplateGenerationProviderAttemptState.ProviderQueued,
        TemplateGenerationProviderAttemptState.ProviderProcessing,
        TemplateGenerationProviderAttemptState.SubmissionUnknown
    ];

    public async Task<TemplateGenerationProviderAttempt?> TryReserveAsync(
        TemplateGenerationProviderAttemptReservation reservation,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(reservation.Provider);
        ArgumentException.ThrowIfNullOrWhiteSpace(reservation.SubmissionTokenHash);
        if (reservation.SubmissionTokenHash.Length != 64)
        {
            throw new ArgumentException("Submission token hash must be a SHA-256 hex value.", nameof(reservation));
        }

        await using var transaction = await BeginTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext('templates:provider-capacity'))",
                cancellationToken);
        }

        var runtimePolicy = await runtimePolicyProvider.GetRuntimePolicyAsync(cancellationToken);
        if (runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations <= 0)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return null;
        }

        if (string.Equals(reservation.Provider, "fal", StringComparison.OrdinalIgnoreCase))
        {
            var providerSnapshot = await providerRuntimeSnapshotService.GetSnapshotAsync(cancellationToken);
            if (providerSnapshot.BalanceState is TemplateProviderBalanceState.Critical
                or TemplateProviderBalanceState.Unknown)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return null;
            }
        }

        if (!await IsExpectedJobClaimCurrentAsync(reservation, transaction, cancellationToken))
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return null;
        }

        var existing = await dbContext.TemplateGenerationProviderAttempts
            .FirstOrDefaultAsync(
                x => x.GenerationJobId == reservation.GenerationJobId
                    && x.Stage == reservation.Stage
                    && ActiveStates.Contains(x.State),
                cancellationToken);
        if (existing is not null)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return existing;
        }

        var active = dbContext.TemplateGenerationProviderAttempts
            .Where(x => ActiveStates.Contains(x.State));
        var activeTotal = await active.CountAsync(cancellationToken);
        if (activeTotal >= runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return null;
        }

        var activeImages = await active.CountAsync(
            x => x.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration,
            cancellationToken);
        var activeVideos = activeTotal - activeImages;
        var isImage = reservation.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration;
        if (isImage)
        {
            var hasVideoBacklog = await HasPendingProviderReservationAsync(
                TemplateGenerationQueue.MediaTypeVideo,
                cancellationToken);
            var imageLimit = runtimePolicy.EffectiveProfile.ImageMaxConcurrentGenerations;
            if (hasVideoBacklog)
            {
                imageLimit = Math.Min(
                    imageLimit,
                    Math.Max(
                        0,
                        runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations
                            - runtimePolicy.EffectiveProfile.VideoReservedConcurrentGenerations));
            }

            if (activeImages >= imageLimit)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return null;
            }
        }
        else
        {
            if (activeVideos >= runtimePolicy.EffectiveProfile.VideoMaxConcurrentGenerations)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return null;
            }

            var borrowedVideoAttempts = await active.CountAsync(
                x => x.IsBorrowedCapacity,
                cancellationToken);
            var usesBorrowedCapacity = activeVideos
                >= runtimePolicy.EffectiveProfile.VideoReservedConcurrentGenerations;
            if (usesBorrowedCapacity
                && borrowedVideoAttempts >= runtimePolicy.EffectiveProfile.VideoBorrowMaxConcurrentGenerations)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return null;
            }

            var hasImageBacklog = await HasPendingProviderReservationAsync(
                TemplateGenerationQueue.MediaTypeImage,
                cancellationToken);
            var remainingImageCapacity = runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations
                - (activeVideos + 1);
            if (usesBorrowedCapacity
                && hasImageBacklog
                && remainingImageCapacity < runtimePolicy.EffectiveProfile.ImageProtectedConcurrentGenerations)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return null;
            }

            if (reservation.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing)
            {
                var activePreprocessing = await active.CountAsync(
                    x => x.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing,
                    cancellationToken);
                if (activePreprocessing >= runtimePolicy.EffectiveProfile.VideoPreprocessingMaxConcurrentGenerations)
                {
                    if (transaction is not null)
                    {
                        await transaction.RollbackAsync(cancellationToken);
                    }

                    return null;
                }
            }
        }

        var ordinal = (await dbContext.TemplateGenerationProviderAttempts
            .Where(x => x.GenerationJobId == reservation.GenerationJobId && x.Stage == reservation.Stage)
            .MaxAsync(x => (int?)x.Ordinal, cancellationToken) ?? 0) + 1;
        var now = DateTime.UtcNow;
        var attempt = new TemplateGenerationProviderAttempt
        {
            Id = Guid.NewGuid(),
            GenerationJobId = reservation.GenerationJobId,
            Stage = reservation.Stage,
            Ordinal = ordinal,
            State = TemplateGenerationProviderAttemptState.SubmitReserved,
            IsBorrowedCapacity = !isImage
                && activeVideos >= runtimePolicy.EffectiveProfile.VideoReservedConcurrentGenerations,
            Provider = reservation.Provider.Trim().ToLowerInvariant(),
            SubmissionTokenHash = reservation.SubmissionTokenHash.ToUpperInvariant(),
            SubmissionDeadlineAtUtc = reservation.SubmissionDeadlineAtUtc,
            ProcessingDeadlineAtUtc = reservation.ProcessingDeadlineAtUtc,
            ReconciliationDeadlineAtUtc = reservation.ReconciliationDeadlineAtUtc,
            NextPollAtUtc = reservation.SubmissionDeadlineAtUtc,
            SubmitAttemptCount = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateGenerationProviderAttempts.Add(attempt);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return attempt;
    }

    private Task<bool> HasPendingProviderReservationAsync(
        string mediaType,
        CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs.AnyAsync(
            job => job.QueueMediaType == mediaType
                && (job.Status == TemplateGenerationStatus.Queued
                    || job.Status == TemplateGenerationStatus.Retrying
                    || (job.Status == TemplateGenerationStatus.Processing
                        && !job.ProviderAttempts.Any(attempt => ActiveStates.Contains(attempt.State)))
                    || (mediaType == TemplateGenerationQueue.MediaTypeVideo
                        && job.Status == TemplateGenerationStatus.ProviderQueued
                        && job.CurrentProviderStage == "video_preprocessing"
                        && job.ProviderCompletedAtUtc != null
                        && job.NormalizedImageUrl != null
                        && job.MotionProviderRequestId == null)),
            cancellationToken);
    }

    private async Task<bool> IsExpectedJobClaimCurrentAsync(
        TemplateGenerationProviderAttemptReservation reservation,
        IDbContextTransaction? transaction,
        CancellationToken cancellationToken)
    {
        if (reservation.ExpectedJobStatus is null
            && string.IsNullOrWhiteSpace(reservation.ExpectedJobLockOwner))
        {
            return true;
        }

        if (reservation.ExpectedJobStatus is null
            || string.IsNullOrWhiteSpace(reservation.ExpectedJobLockOwner))
        {
            return false;
        }

        if (transaction is not null)
        {
            var matchingIds = await dbContext.Database.SqlQueryRaw<Guid>(
                """
                SELECT "Id" AS "Value"
                FROM templates_generation_jobs
                WHERE "Id" = {0}
                  AND "Status" = {1}
                  AND "LockedBy" = {2}
                FOR UPDATE
                """,
                reservation.GenerationJobId,
                (int)reservation.ExpectedJobStatus.Value,
                reservation.ExpectedJobLockOwner)
                .ToListAsync(cancellationToken);
            return matchingIds.Count == 1;
        }

        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .AnyAsync(
                job => job.Id == reservation.GenerationJobId
                    && job.Status == reservation.ExpectedJobStatus.Value
                    && job.LockedBy == reservation.ExpectedJobLockOwner,
                cancellationToken);
    }

    public async Task MarkSubmissionAcceptedAsync(
        Guid attemptId,
        string providerRequestId,
        string? statusUrl,
        string? responseUrl,
        string? cancelUrl,
        DateTime nextPollAtUtc,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(providerRequestId);
        try
        {
            var attempt = await dbContext.TemplateGenerationProviderAttempts
                .Include(x => x.GenerationJob)
                .SingleAsync(x => x.Id == attemptId, cancellationToken);
            if (attempt.State is TemplateGenerationProviderAttemptState.Completed
                or TemplateGenerationProviderAttemptState.Cancelled
                or TemplateGenerationProviderAttemptState.Failed)
            {
                return;
            }

            var now = DateTime.UtcNow;
            attempt.State = TemplateGenerationProviderAttemptState.ProviderQueued;
            attempt.ProviderRequestId = providerRequestId;
            attempt.ProviderStatusUrl = statusUrl;
            attempt.ProviderResponseUrl = responseUrl;
            attempt.ProviderCancelUrl = cancelUrl;
            attempt.NextPollAtUtc = nextPollAtUtc;
            attempt.SubmittedAtUtc ??= now;
            attempt.UpdatedAtUtc = now;
            attempt.LastErrorCode = null;
            attempt.Version++;
            ApplyLegacySubmission(attempt.GenerationJob, attempt, now);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            // A provider response can arrive immediately before a failed/ambiguous database
            // write. Never let the mutated ProviderQueued graph poison the fallback query:
            // reload durable state so it is either accepted-with-request-id or can safely be
            // moved from Submitting to SubmissionUnknown without a blind resubmit.
            dbContext.ChangeTracker.Clear();
            throw;
        }
    }

    public async Task MarkSubmittingAsync(Guid attemptId, CancellationToken cancellationToken)
    {
        var attempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleAsync(x => x.Id == attemptId, cancellationToken);
        if (attempt.State != TemplateGenerationProviderAttemptState.SubmitReserved)
        {
            return;
        }

        attempt.State = TemplateGenerationProviderAttemptState.Submitting;
        attempt.NextPollAtUtc = attempt.SubmissionDeadlineAtUtc;
        attempt.UpdatedAtUtc = DateTime.UtcNow;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task MarkSubmissionUnknownAsync(
        Guid attemptId,
        string errorCode,
        DateTime nextPollAtUtc,
        CancellationToken cancellationToken)
    {
        try
        {
            var attempt = await dbContext.TemplateGenerationProviderAttempts
                .Include(x => x.GenerationJob)
                .SingleAsync(x => x.Id == attemptId, cancellationToken);
            if (attempt.State != TemplateGenerationProviderAttemptState.SubmitReserved
                && attempt.State != TemplateGenerationProviderAttemptState.Submitting)
            {
                return;
            }

            var now = DateTime.UtcNow;
            attempt.State = TemplateGenerationProviderAttemptState.SubmissionUnknown;
            attempt.NextPollAtUtc = nextPollAtUtc;
            attempt.LastErrorCode = Truncate(errorCode, 128);
            attempt.UpdatedAtUtc = now;
            attempt.Version++;
            attempt.GenerationJob.Status = TemplateGenerationStatus.SubmittingToProvider;
            attempt.GenerationJob.CurrentProviderStage = ToProviderStage(attempt.Stage);
            attempt.GenerationJob.ProviderStatus = "SUBMISSION_UNKNOWN";
            attempt.GenerationJob.ProviderStatusCheckedAtUtc = now;
            attempt.GenerationJob.LockedAtUtc = null;
            attempt.GenerationJob.LockedBy = null;
            attempt.GenerationJob.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            dbContext.ChangeTracker.Clear();
            throw;
        }
    }

    public async Task MarkSubmissionFailedAsync(
        Guid attemptId,
        string errorCode,
        CancellationToken cancellationToken)
    {
        var attempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleAsync(x => x.Id == attemptId, cancellationToken);
        if (attempt.State is TemplateGenerationProviderAttemptState.Completed
            or TemplateGenerationProviderAttemptState.Failed
            or TemplateGenerationProviderAttemptState.Cancelled)
        {
            return;
        }

        var now = DateTime.UtcNow;
        attempt.State = TemplateGenerationProviderAttemptState.Failed;
        attempt.NextPollAtUtc = null;
        attempt.LastErrorCode = Truncate(errorCode, 128);
        attempt.CompletedAtUtc = now;
        attempt.LockedBy = null;
        attempt.LockedAtUtc = null;
        attempt.UpdatedAtUtc = now;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<TemplateGenerationProviderAttemptClaim?> ClaimDueAsync(
        string workerId,
        TimeSpan lockTimeout,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(workerId);
        var now = DateTime.UtcNow;
        var staleBefore = now.Subtract(lockTimeout);
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        TemplateGenerationProviderAttempt? attempt;
        if (transaction is null)
        {
            attempt = await dbContext.TemplateGenerationProviderAttempts
                .Where(x => ActiveStates.Contains(x.State)
                    && x.NextPollAtUtc <= now
                    && (x.LockedAtUtc == null || x.LockedAtUtc < staleBefore))
                .OrderBy(x => x.NextPollAtUtc)
                .ThenBy(x => x.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }
        else
        {
            attempt = await dbContext.TemplateGenerationProviderAttempts
                .FromSqlRaw(
                    """
                    SELECT *
                    FROM templates_generation_provider_attempts
                    WHERE "State" IN (1, 2, 3, 4, 5)
                      AND "NextPollAtUtc" IS NOT NULL
                      AND "NextPollAtUtc" <= {0}
                      AND ("LockedAtUtc" IS NULL OR "LockedAtUtc" < {1})
                    ORDER BY "NextPollAtUtc", "CreatedAtUtc"
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED
                    """,
                    now,
                    staleBefore)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (attempt is null)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return null;
        }

        var claimToken = CreateClaimToken(workerId, "attempt");
        attempt.LockedBy = claimToken;
        attempt.LockedAtUtc = now;
        attempt.UpdatedAtUtc = now;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return MapClaim(attempt, claimToken);
    }

    public async Task ReleaseClaimAsync(
        Guid attemptId,
        string claimToken,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(claimToken);
        var now = DateTime.UtcNow;
        if (string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            await dbContext.TemplateGenerationProviderAttempts
                .Where(attempt => attempt.Id == attemptId && attempt.LockedBy == claimToken)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(attempt => attempt.LockedBy, (string?)null)
                        .SetProperty(attempt => attempt.LockedAtUtc, (DateTime?)null)
                        .SetProperty(attempt => attempt.UpdatedAtUtc, now)
                        .SetProperty(attempt => attempt.Version, attempt => attempt.Version + 1),
                    cancellationToken);
            return;
        }

        var claimedAttempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleOrDefaultAsync(
                attempt => attempt.Id == attemptId && attempt.LockedBy == claimToken,
                cancellationToken);
        if (claimedAttempt is null)
        {
            return;
        }

        claimedAttempt.LockedBy = null;
        claimedAttempt.LockedAtUtc = null;
        claimedAttempt.UpdatedAtUtc = now;
        claimedAttempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdateClaimedStateAsync(
        Guid attemptId,
        string workerId,
        TemplateGenerationProviderAttemptState state,
        DateTime? nextPollAtUtc,
        string? lastErrorCode,
        bool providerCompleted,
        CancellationToken cancellationToken)
    {
        var attempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleAsync(x => x.Id == attemptId, cancellationToken);
        if (!string.Equals(attempt.LockedBy, Truncate(workerId, 128), StringComparison.Ordinal))
        {
            throw new DbUpdateConcurrencyException("Provider attempt claim is no longer owned by this worker.");
        }

        var now = DateTime.UtcNow;
        attempt.State = state;
        attempt.NextPollAtUtc = nextPollAtUtc;
        attempt.LastErrorCode = Truncate(lastErrorCode, 128);
        attempt.ProviderCompletedAtUtc = providerCompleted ? now : attempt.ProviderCompletedAtUtc;
        attempt.CompletedAtUtc = state is TemplateGenerationProviderAttemptState.Completed
            or TemplateGenerationProviderAttemptState.Failed
            or TemplateGenerationProviderAttemptState.Cancelled
                ? now
                : null;
        attempt.LockedBy = null;
        attempt.LockedAtUtc = null;
        attempt.UpdatedAtUtc = now;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> TryBeginPollAsync(
        Guid attemptId,
        string claimToken,
        int maxAttempts,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(claimToken);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(maxAttempts);

        var attempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleAsync(x => x.Id == attemptId, cancellationToken);
        EnsureAttemptClaimOwner(attempt, claimToken);
        if (attempt.PollAttemptCount >= maxAttempts)
        {
            return false;
        }

        // Spend the polling budget only at the provider I/O boundary. Merely
        // claiming a due row or failing to acquire the generation-job lease must
        // never exhaust the budget of a still-running paid provider operation.
        attempt.PollAttemptCount++;
        attempt.UpdatedAtUtc = DateTime.UtcNow;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> TryBeginCancellationAsync(
        Guid attemptId,
        string claimToken,
        int maxAttempts,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(claimToken);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(maxAttempts);

        var attempt = await dbContext.TemplateGenerationProviderAttempts
            .SingleAsync(x => x.Id == attemptId, cancellationToken);
        EnsureAttemptClaimOwner(attempt, claimToken);

        if (attempt.CancelAttemptCount >= maxAttempts)
        {
            return false;
        }

        attempt.CancelAttemptCount++;
        attempt.UpdatedAtUtc = DateTime.UtcNow;
        attempt.Version++;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<Guid> EnqueueWebhookAsync(
        string provider,
        string deduplicationKey,
        string? callbackTokenHash,
        string? providerRequestId,
        string eventType,
        string payloadJson,
        DateTime signatureVerifiedAtUtc,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(provider);
        ArgumentException.ThrowIfNullOrWhiteSpace(deduplicationKey);
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);
        ArgumentNullException.ThrowIfNull(payloadJson);
        if (payloadJson.Length > WebhookPayloadMaxChars)
        {
            throw new ArgumentException("Provider webhook payload exceeds the persistence limit.", nameof(payloadJson));
        }

        var normalizedProvider = provider.Trim().ToLowerInvariant();
        var normalizedDedupe = Truncate(deduplicationKey.Trim(), 160)!;
        var existing = await dbContext.TemplateProviderWebhookInbox
            .AsNoTracking()
            .SingleOrDefaultAsync(
                x => x.Provider == normalizedProvider && x.DeduplicationKey == normalizedDedupe,
                cancellationToken);
        if (existing is not null)
        {
            return existing.Id;
        }

        var normalizedToken = NormalizeHash(callbackTokenHash);
        var normalizedRequestId = Truncate(providerRequestId?.Trim(), 128);
        TemplateGenerationProviderAttempt? attempt;
        if (normalizedToken is not null)
        {
            // A signed callback token is the primary correlation identity. Never allow a
            // conflicting request id to redirect the webhook to another (newer) attempt.
            attempt = await dbContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(x => x.Provider == normalizedProvider && x.SubmissionTokenHash == normalizedToken)
                .OrderByDescending(x => x.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
            if (attempt is not null
                && normalizedRequestId is not null
                && attempt.ProviderRequestId is not null
                && !string.Equals(attempt.ProviderRequestId, normalizedRequestId, StringComparison.Ordinal))
            {
                attempt = null;
            }
        }
        else if (normalizedRequestId is not null)
        {
            attempt = await dbContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(x => x.Provider == normalizedProvider && x.ProviderRequestId == normalizedRequestId)
                .OrderByDescending(x => x.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }
        else
        {
            attempt = null;
        }
        var now = DateTime.UtcNow;
        var inbox = new TemplateProviderWebhookInbox
        {
            Id = CreateWebhookId(normalizedProvider, normalizedDedupe),
            ProviderAttemptId = attempt?.Id,
            GenerationJobId = attempt?.GenerationJobId,
            Provider = normalizedProvider,
            DeduplicationKey = normalizedDedupe,
            CallbackTokenHash = normalizedToken,
            ProviderRequestId = normalizedRequestId,
            EventType = Truncate(eventType.Trim(), 64)!,
            PayloadJson = payloadJson,
            Status = TemplateProviderWebhookInboxStatus.Queued,
            SignatureVerifiedAtUtc = signatureVerifiedAtUtc,
            ReceivedAtUtc = now,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateProviderWebhookInbox.Add(inbox);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return inbox.Id;
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(inbox).State = EntityState.Detached;
            return (await dbContext.TemplateProviderWebhookInbox
                .AsNoTracking()
                .SingleAsync(
                    x => x.Provider == normalizedProvider && x.DeduplicationKey == normalizedDedupe,
                cancellationToken)).Id;
        }
    }

    public async Task<TemplateProviderWebhookInboxClaim?> ClaimNextWebhookAsync(
        string workerId,
        TimeSpan lockTimeout,
        CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(workerId);
        var normalizedWorkerId = Truncate(workerId.Trim(), 128)!;
        var now = DateTime.UtcNow;
        var staleBefore = now.Subtract(lockTimeout);
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        TemplateProviderWebhookInbox? inbox;
        if (transaction is null)
        {
            inbox = await dbContext.TemplateProviderWebhookInbox
                .Where(x => (x.Status == TemplateProviderWebhookInboxStatus.Queued
                        || x.Status == TemplateProviderWebhookInboxStatus.Failed
                        || (x.Status == TemplateProviderWebhookInboxStatus.Processing
                            && x.LockedAtUtc < staleBefore))
                    && x.NextAttemptAtUtc <= now
                    && (x.LockedAtUtc == null || x.LockedAtUtc < staleBefore))
                .OrderBy(x => x.NextAttemptAtUtc)
                .ThenBy(x => x.ReceivedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }
        else
        {
            inbox = await dbContext.TemplateProviderWebhookInbox
                .FromSqlRaw(
                    """
                    SELECT *
                    FROM templates_provider_webhook_inbox
                    WHERE ("Status" IN (1, 4)
                           OR ("Status" = 2 AND "LockedAtUtc" < {1}))
                      AND "NextAttemptAtUtc" <= {0}
                      AND ("LockedAtUtc" IS NULL OR "LockedAtUtc" < {1})
                    ORDER BY "NextAttemptAtUtc", "ReceivedAtUtc"
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED
                    """,
                    now,
                    staleBefore)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (inbox is null)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return null;
        }

        var claimToken = CreateClaimToken(normalizedWorkerId, "webhook");
        inbox.Status = TemplateProviderWebhookInboxStatus.Processing;
        inbox.LockedBy = claimToken;
        inbox.LockedAtUtc = now;
        inbox.AttemptCount++;
        inbox.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        return new TemplateProviderWebhookInboxClaim(
            inbox.Id,
            inbox.ProviderAttemptId,
            inbox.GenerationJobId,
            inbox.Provider,
            inbox.CallbackTokenHash,
            inbox.ProviderRequestId,
            inbox.EventType,
            inbox.PayloadJson,
            inbox.Status,
            inbox.AttemptCount,
            inbox.FailureCount,
            inbox.ReceivedAtUtc,
            claimToken);
    }

    public async Task MarkWebhookProcessedAsync(
        Guid inboxId,
        string workerId,
        CancellationToken cancellationToken)
    {
        var inbox = await dbContext.TemplateProviderWebhookInbox
            .SingleAsync(x => x.Id == inboxId, cancellationToken);
        if (inbox.Status is TemplateProviderWebhookInboxStatus.Processed
            or TemplateProviderWebhookInboxStatus.DeadLettered)
        {
            return;
        }

        EnsureWebhookClaimOwner(inbox, workerId);
        var now = DateTime.UtcNow;
        inbox.Status = TemplateProviderWebhookInboxStatus.Processed;
        inbox.ProcessedAtUtc = now;
        inbox.DeadLetteredAtUtc = null;
        inbox.LastErrorCode = null;
        inbox.LockedBy = null;
        inbox.LockedAtUtc = null;
        inbox.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task DeferWebhookAsync(
        Guid inboxId,
        string workerId,
        string errorCode,
        DateTime nextAttemptAtUtc,
        CancellationToken cancellationToken)
    {
        var inbox = await dbContext.TemplateProviderWebhookInbox
            .SingleAsync(x => x.Id == inboxId, cancellationToken);
        if (inbox.Status is TemplateProviderWebhookInboxStatus.Processed
            or TemplateProviderWebhookInboxStatus.DeadLettered)
        {
            return;
        }

        var normalizedErrorCode = Truncate(errorCode, 128);
        if (inbox.Status == TemplateProviderWebhookInboxStatus.Failed
            && inbox.LockedBy is null
            && inbox.LastErrorCode == normalizedErrorCode
            && inbox.NextAttemptAtUtc == nextAttemptAtUtc)
        {
            return;
        }

        EnsureWebhookClaimOwner(inbox, workerId);
        inbox.Status = TemplateProviderWebhookInboxStatus.Failed;
        inbox.NextAttemptAtUtc = nextAttemptAtUtc;
        inbox.LastErrorCode = normalizedErrorCode;
        inbox.LockedBy = null;
        inbox.LockedAtUtc = null;
        inbox.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> MarkWebhookFailedAsync(
        Guid inboxId,
        string workerId,
        string errorCode,
        DateTime nextAttemptAtUtc,
        CancellationToken cancellationToken)
    {
        var inbox = await dbContext.TemplateProviderWebhookInbox
            .SingleAsync(x => x.Id == inboxId, cancellationToken);
        if (inbox.Status is TemplateProviderWebhookInboxStatus.Processed
            or TemplateProviderWebhookInboxStatus.DeadLettered)
        {
            return inbox.Status == TemplateProviderWebhookInboxStatus.DeadLettered;
        }

        EnsureWebhookClaimOwner(inbox, workerId);
        var now = DateTime.UtcNow;
        inbox.FailureCount++;
        inbox.LastErrorCode = Truncate(errorCode, 128);
        inbox.LockedBy = null;
        inbox.LockedAtUtc = null;
        inbox.UpdatedAtUtc = now;
        if (inbox.FailureCount >= (options?.ProviderWebhookInboxMaxFailureCount ?? 8))
        {
            inbox.Status = TemplateProviderWebhookInboxStatus.DeadLettered;
            inbox.DeadLetteredAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }

        inbox.Status = TemplateProviderWebhookInboxStatus.Failed;
        inbox.NextAttemptAtUtc = nextAttemptAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
        return false;
    }

    public async Task<int> CleanupTerminalWebhooksAsync(
        DateTime cutoffUtc,
        int batchSize,
        CancellationToken cancellationToken)
    {
        if (cutoffUtc.Kind != DateTimeKind.Utc)
        {
            throw new ArgumentException("Webhook retention cutoff must be UTC.", nameof(cutoffUtc));
        }

        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(batchSize);
        var terminalRows = dbContext.TemplateProviderWebhookInbox
            .Where(x => (x.Status == TemplateProviderWebhookInboxStatus.Processed
                    || x.Status == TemplateProviderWebhookInboxStatus.DeadLettered)
                && x.UpdatedAtUtc <= cutoffUtc)
            .OrderBy(x => x.UpdatedAtUtc)
            .ThenBy(x => x.Id);
        if (!string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            var rows = await terminalRows
                .Take(batchSize)
                .ToListAsync(cancellationToken);
            if (rows.Count == 0)
            {
                return 0;
            }

            dbContext.TemplateProviderWebhookInbox.RemoveRange(rows);
            await dbContext.SaveChangesAsync(cancellationToken);
            return rows.Count;
        }

        var ids = await terminalRows
            .AsNoTracking()
            .Select(x => x.Id)
            .Take(batchSize)
            .ToArrayAsync(cancellationToken);
        if (ids.Length == 0)
        {
            return 0;
        }

        return await dbContext.TemplateProviderWebhookInbox
            .Where(x => ids.Contains(x.Id)
                && (x.Status == TemplateProviderWebhookInboxStatus.Processed
                    || x.Status == TemplateProviderWebhookInboxStatus.DeadLettered)
                && x.UpdatedAtUtc <= cutoffUtc)
            .ExecuteDeleteAsync(cancellationToken);
    }

    private static void ApplyLegacySubmission(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttempt attempt,
        DateTime now)
    {
        if (attempt.Stage == TemplateGenerationProviderAttemptStage.VideoGeneration)
        {
            job.MotionProviderRequestId = attempt.ProviderRequestId;
            job.MotionProviderStatusUrl = attempt.ProviderStatusUrl;
            job.MotionProviderResponseUrl = attempt.ProviderResponseUrl;
            job.MotionProviderCancelUrl = attempt.ProviderCancelUrl;
        }
        else
        {
            job.PreprocessingProviderRequestId = attempt.ProviderRequestId;
            job.PreprocessingProviderStatusUrl = attempt.ProviderStatusUrl;
            job.PreprocessingProviderResponseUrl = attempt.ProviderResponseUrl;
            job.PreprocessingProviderCancelUrl = attempt.ProviderCancelUrl;
        }

        job.Status = TemplateGenerationStatus.ProviderQueued;
        job.CurrentProviderStage = ToProviderStage(attempt.Stage);
        job.ProviderStatus = "IN_QUEUE";
        job.ProviderSubmittedAtUtc = now;
        job.ProviderStatusCheckedAtUtc = now;
        job.ProviderCompletedAtUtc = null;
        job.NextAttemptEarliestAtUtc = attempt.NextPollAtUtc;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = now;
    }

    private static string ToProviderStage(TemplateGenerationProviderAttemptStage stage) => stage switch
    {
        TemplateGenerationProviderAttemptStage.ImageGeneration => "image_generation",
        TemplateGenerationProviderAttemptStage.VideoPreprocessing => "video_preprocessing",
        TemplateGenerationProviderAttemptStage.VideoGeneration => "video_generation",
        _ => throw new ArgumentOutOfRangeException(nameof(stage), stage, null)
    };

    private static TemplateGenerationProviderAttemptClaim MapClaim(
        TemplateGenerationProviderAttempt attempt,
        string claimToken) => new(
        attempt.Id,
        attempt.GenerationJobId,
        attempt.Stage,
        attempt.Ordinal,
        attempt.State,
        attempt.Provider,
        attempt.SubmissionTokenHash,
        attempt.ProviderRequestId,
        attempt.ProviderStatusUrl,
        attempt.ProviderResponseUrl,
        attempt.ProviderCancelUrl,
        attempt.PollAttemptCount,
        attempt.CancelAttemptCount,
        attempt.SubmissionDeadlineAtUtc,
        attempt.ProcessingDeadlineAtUtc,
        attempt.ReconciliationDeadlineAtUtc,
        attempt.IsBorrowedCapacity,
        claimToken);

    private static string CreateClaimToken(string workerId, string scope)
    {
        var suffix = $":{scope}:{Guid.NewGuid():N}";
        var prefixLength = 128 - suffix.Length;
        var normalizedWorkerId = workerId.Trim();
        var prefix = normalizedWorkerId.Length <= prefixLength
            ? normalizedWorkerId
            : normalizedWorkerId[..prefixLength];
        return prefix + suffix;
    }

    private static void EnsureAttemptClaimOwner(
        TemplateGenerationProviderAttempt attempt,
        string claimToken)
    {
        if (!string.Equals(attempt.LockedBy, Truncate(claimToken, 128), StringComparison.Ordinal))
        {
            throw new DbUpdateConcurrencyException("Provider attempt claim is no longer owned by this lease.");
        }
    }

    private static void EnsureWebhookClaimOwner(TemplateProviderWebhookInbox inbox, string workerId)
    {
        if (inbox.Status != TemplateProviderWebhookInboxStatus.Processing
            || !string.Equals(inbox.LockedBy, Truncate(workerId.Trim(), 128), StringComparison.Ordinal))
        {
            throw new DbUpdateConcurrencyException("Provider webhook inbox claim is no longer owned by this worker.");
        }
    }

    private Task<IDbContextTransaction?> BeginTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? BeginNpgsqlTransactionAsync(cancellationToken)
            : Task.FromResult<IDbContextTransaction?>(null);
    }

    private async Task<IDbContextTransaction?> BeginNpgsqlTransactionAsync(CancellationToken cancellationToken) =>
        await dbContext.Database.BeginTransactionAsync(cancellationToken);

    private static Guid CreateWebhookId(string provider, string deduplicationKey)
    {
        var raw = $"templates:provider-webhook:{provider}:{deduplicationKey}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(raw)).AsSpan(0, 16));
    }

    private static string? NormalizeHash(string? value)
    {
        var normalized = value?.Trim().ToUpperInvariant();
        return normalized is { Length: 64 }
            && normalized.All(Uri.IsHexDigit)
                ? normalized
                : null;
    }

    private static string? Truncate(string? value, int maxLength) =>
        value is null || value.Length <= maxLength ? value : value[..maxLength];
}
