using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class EmailDispatchProcessor(
    IdentityDbContext dbContext,
    IEmailSender emailSender,
    EmailOptions options,
    ILogger<EmailDispatchProcessor> logger)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var job = await ClaimNextAsync(cancellationToken);
        if (job is null)
        {
            return false;
        }

        PushOutboxMetrics.RecordAttempt("identity_email");

        if (job.AttemptCount > options.MaxDispatchAttempts)
        {
            await MarkFailedAsync(
                job,
                "email.dispatch_attempts_exhausted",
                "Email dispatch lease expired after the maximum number of attempts.",
                cancellationToken);
            return true;
        }

        var sent = await emailSender.SendAsync(job, cancellationToken);
        if (sent.IsSuccess)
        {
            job.Status = EmailDispatchStatus.Sent;
            job.SentAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = job.SentAtUtc.Value;
            job.NextAttemptAtUtc = null;
            job.FailureCode = null;
            job.FailureMessage = null;
            job.LockId = null;
            job.LockExpiresAtUtc = null;
            if (await TrySaveLeaseResultAsync(job, cancellationToken))
            {
                PushOutboxMetrics.RecordSent("identity_email");
            }

            return true;
        }

        await MarkFailedAsync(job, sent.Error.Code, sent.Error.Message, cancellationToken);
        return true;
    }

    public async Task<bool> CleanupNextExpiredDispatchAsync(CancellationToken cancellationToken)
    {
        if (options.CompletedDispatchRetentionDays < 0)
        {
            return false;
        }

        var cutoff = DateTime.UtcNow.AddDays(-options.CompletedDispatchRetentionDays);
        var job = await dbContext.EmailDispatchJobs
            .Where(x => (x.Status == EmailDispatchStatus.Sent || x.Status == EmailDispatchStatus.Failed)
                && ((x.SentAtUtc != null && x.SentAtUtc <= cutoff)
                    || (x.SentAtUtc == null && x.UpdatedAtUtc <= cutoff)))
            .OrderBy(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        dbContext.EmailDispatchJobs.Remove(job);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private Task<EmailDispatchJob?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? ClaimNextPostgresAsync(cancellationToken)
            : ClaimNextTrackedAsync(cancellationToken);
    }

    private async Task<EmailDispatchJob?> ClaimNextPostgresAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var lockId = Guid.NewGuid();
        var lockExpiresAtUtc = now.AddSeconds(Math.Max(30, options.ProcessingLeaseSeconds));
        var claimedIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE email_dispatch_jobs
            SET "Status" = {1},
                "AttemptCount" = "AttemptCount" + 1,
                "LastAttemptAtUtc" = {2},
                "UpdatedAtUtc" = {2},
                "FailureCode" = NULL,
                "FailureMessage" = NULL,
                "LockId" = {4},
                "LockExpiresAtUtc" = {5}
            WHERE "Id" = (
                SELECT "Id"
                FROM email_dispatch_jobs
                WHERE (("Status" = {0}
                          AND ("NextAttemptAtUtc" IS NULL OR "NextAttemptAtUtc" <= {2})
                          AND "AttemptCount" < {3})
                       OR ("Status" = {1}
                          AND ("LockExpiresAtUtc" IS NULL OR "LockExpiresAtUtc" <= {2})))
                ORDER BY "QueuedAtUtc"
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING "Id" AS "Value";
            """,
            (int)EmailDispatchStatus.Queued,
            (int)EmailDispatchStatus.Processing,
            now,
            options.MaxDispatchAttempts,
            lockId,
            lockExpiresAtUtc)
            .ToListAsync(cancellationToken);

        var claimedId = claimedIds.FirstOrDefault();
        if (claimedId == Guid.Empty)
        {
            return null;
        }

        return await dbContext.EmailDispatchJobs
            .SingleAsync(x => x.Id == claimedId, cancellationToken);
    }

    private async Task<EmailDispatchJob?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var job = await dbContext.EmailDispatchJobs
            .Where(x => ((x.Status == EmailDispatchStatus.Queued
                        && (x.NextAttemptAtUtc == null || x.NextAttemptAtUtc <= now)
                        && x.AttemptCount < options.MaxDispatchAttempts)
                    || (x.Status == EmailDispatchStatus.Processing
                        && (x.LockExpiresAtUtc == null || x.LockExpiresAtUtc <= now))))
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return null;
        }

        job.Status = EmailDispatchStatus.Processing;
        job.AttemptCount++;
        job.LastAttemptAtUtc = now;
        job.UpdatedAtUtc = now;
        job.FailureCode = null;
        job.FailureMessage = null;
        job.LockId = Guid.NewGuid();
        job.LockExpiresAtUtc = now.AddSeconds(Math.Max(30, options.ProcessingLeaseSeconds));
        await dbContext.SaveChangesAsync(cancellationToken);
        return job;
    }

    private async Task MarkFailedAsync(EmailDispatchJob job, string errorCode, string errorMessage, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var safeErrorCode = SafeLogValues.SanitizeText(errorCode, 128);
        job.FailureCode = safeErrorCode;
        job.FailureMessage = SafeLogValues.SanitizeText(errorMessage, 2000);
        job.UpdatedAtUtc = now;
        job.LockId = null;
        job.LockExpiresAtUtc = null;

        var exhausted = job.AttemptCount >= options.MaxDispatchAttempts;
        if (exhausted)
        {
            job.Status = EmailDispatchStatus.Failed;
            job.NextAttemptAtUtc = null;
        }
        else
        {
            job.Status = EmailDispatchStatus.Queued;
            job.NextAttemptAtUtc = now.AddSeconds(options.RetryDelaySeconds);
        }

        if (!await TrySaveLeaseResultAsync(job, cancellationToken))
        {
            return;
        }

        if (exhausted)
        {
            PushOutboxMetrics.RecordDeadLetter("identity_email");
            logger.LogWarning(
                "Email dispatch exhausted attempts. EmailJobIdHash={EmailJobIdHash} ErrorCode={ErrorCode}",
                SafeLogValues.StableHash(job.Id.ToString("D")),
                safeErrorCode);
        }
        else
        {
            PushOutboxMetrics.RecordRetry("identity_email");
            logger.LogWarning(
                "Email dispatch failed. EmailJobIdHash={EmailJobIdHash} ErrorCode={ErrorCode}",
                SafeLogValues.StableHash(job.Id.ToString("D")),
                safeErrorCode);
        }
    }

    private async Task<bool> TrySaveLeaseResultAsync(
        EmailDispatchJob job,
        CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            logger.LogInformation(
                "Email dispatch completion ignored because the processing lease was reclaimed. EmailJobIdHash={EmailJobIdHash}",
                SafeLogValues.StableHash(job.Id.ToString("D")));
            return false;
        }
    }
}
