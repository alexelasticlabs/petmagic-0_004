using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const string AdminGenerationRefundRetryIdempotencyScope = "admin_generation_refund_retry";
    private const string AdminGenerationRefundRetryAction = "admin.templates.generation.refund_retry";
    private const int AdminGenerationRefundRetryReasonMaxLength = 500;
    private const int AdminGenerationRefundRetryIdempotencyKeyMaxLength = 256;

    public async Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == AdminTestUserId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    public async Task<Result<RemoveGenerationWatermarkResponse>> GrantAdminCleanDownloadAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        var existing = job.WatermarkUnlocks.FirstOrDefault(x => x.UserId == job.UserId);
        if (existing is null)
        {
            existing = AddWatermarkUnlock(job, TemplateWatermarkUnlockMethod.Admin, creditsSpent: 0, adminUserId);
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.RemovedPremium, "admin", "admin", creditsSpent: 0);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return Result.Success(new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl));
    }

    public async Task<Result<TemplateGenerationResponse>> CancelAdminQueuedAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var cancelled = await CancelAdminAsync(adminUserId, generationId, cancellationToken);
        return cancelled.IsFailure
            ? Result.Failure<TemplateGenerationResponse>(cancelled.Error)
            : Result.Success(cancelled.Value.Generation);
    }

    public async Task<Result<TemplateGenerationResponse>> RetryAdminGenerationAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var retryOwner = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Id == generationId && x.HiddenByUserAtUtc == null)
            .Select(x => new { x.UserId })
            .SingleOrDefaultAsync(cancellationToken);
        if (retryOwner is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        await using var transaction = await BeginGenerationAdmissionTransactionAsync(
            retryOwner.UserId,
            cancellationToken);
        if (transaction is not null)
        {
            await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.HiddenByUserAtUtc == null, cancellationToken);
        if (job is null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (!CanAdminRetryGeneration(job))
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRetryNotAllowed);
        }

        const string queueTier = TemplateGenerationQueue.TierAdmin;
        var admission = await EnsureGenerationAdmissionUnderLockAsync(
            job.UserId,
            job.Template,
            queueTier,
            options.PrivilegedUserMaxActiveGenerations,
            cancellationToken);
        if (admission.IsFailure)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(admission.Error);
        }

        var previousStatus = job.Status;
        var now = DateTime.UtcNow;
        ResetAdminRetryState(job, now);
        job.QueueTier = queueTier;
        job.EstimatedWaitSecondsAtQueue = admission.Value.EstimatedWaitSeconds;
        job.EstimatedCompletionAtQueueUtc = admission.Value.EstimatedCompletionAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        TemplateGenerationMetrics.RecordJobRequeued(job);
        TemplateGenerationMetrics.RecordRetryAttempt(job, "admin_manual");
        var response = await MapResponseWithQueueMetricsAsync(job, cancellationToken);
        if (realtimeService is not null)
        {
            await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
        }

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    "admin.templates.generation.retry",
                    "TemplateGenerationJob",
                    job.Id.ToString(),
                    previousStatus.ToString(),
                    job.Status.ToString(),
                    $"tokenCost={job.TokenCost};chargedAtUtc={job.ChargedAtUtc:O};attemptBudgetReset=true",
                    adminUserId),
                cancellationToken);
        }

        logger?.LogWarning(
            "ADMIN ACTION: generation retry queued. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} UserIdHash={UserIdHash} PreviousStatus={PreviousStatus} TokenCost={TokenCost} CorrelationIdHash={CorrelationIdHash}",
            TemplateLogSanitizer.SafeId(adminUserId),
            TemplateLogSanitizer.SafeId(job.Id),
            TemplateLogSanitizer.SafeId(job.UserId),
            previousStatus,
            job.TokenCost,
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

        return Result.Success(response);
    }

    public Task<Result<TemplateGenerationResponse>> RetryAdminGenerationRefundAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        return RetryAdminGenerationRefundAsync(
            adminUserId,
            generationId,
            reason: null,
            idempotencyKey: null,
            cancellationToken);
    }

    public async Task<Result<TemplateGenerationResponse>> RetryAdminGenerationRefundAsync(
        Guid adminUserId,
        Guid generationId,
        string? reason,
        string? idempotencyKey,
        CancellationToken cancellationToken)
    {
        var normalizedReason = NormalizeAdminGenerationRefundRetryOptionalText(reason);
        if (normalizedReason is { Length: > AdminGenerationRefundRetryReasonMaxLength })
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundRetryReasonInvalid);
        }

        var normalizedIdempotencyKey = NormalizeAdminGenerationRefundRetryOptionalText(idempotencyKey);
        if ((idempotencyKey is not null && normalizedIdempotencyKey is null)
            || normalizedIdempotencyKey is { Length: > AdminGenerationRefundRetryIdempotencyKeyMaxLength })
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundRetryIdempotencyKeyInvalid);
        }

        var requestHash = normalizedIdempotencyKey is null
            ? null
            : CreateAdminGenerationRefundRetryRequestHash(generationId, normalizedReason);
        if (normalizedIdempotencyKey is not null)
        {
            var existingReceipt = await FindAdminGenerationRefundRetryReceiptAsync(
                adminUserId,
                normalizedIdempotencyKey,
                cancellationToken);
            if (existingReceipt is not null)
            {
                return await ResolveAdminGenerationRefundRetryReplayAsync(
                    existingReceipt,
                    requestHash!,
                    cancellationToken);
            }
        }

        await using var transaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
        }

        if (normalizedIdempotencyKey is not null)
        {
            var existingReceipt = await FindAdminGenerationRefundRetryReceiptAsync(
                adminUserId,
                normalizedIdempotencyKey,
                cancellationToken);
            if (existingReceipt is not null)
            {
                if (transaction is not null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                }

                return await ResolveAdminGenerationRefundRetryReplayAsync(
                    existingReceipt,
                    requestHash!,
                    cancellationToken);
            }
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (job.Status is not (TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled)
            || job.ChargedAtUtc is null
            || job.RefundedAtUtc is not null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundNotPending);
        }

        if (job.RefundAttemptCount < options.MaxRefundAttempts)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundRetryNotExhausted);
        }

        // No money moves here: the refund itself stays inside the idempotent worker retry pipeline
        // (generation_refund ledger unique index guarantees at-most-once crediting). This action only
        // re-arms the retry budget so the worker picks the job up again within its poll interval.
        var previousRefundAttemptCount = job.RefundAttemptCount;
        var previousRefundLastAttemptedAtUtc = job.RefundLastAttemptedAtUtc;
        var previousRefundLastErrorCode = job.RefundLastErrorCode;
        var now = DateTime.UtcNow;
        var correlationId = NormalizeAdminGenerationRefundRetryCorrelationId(CorrelationContext.ResolveOrCreate());
        AdminGenerationRefundRetryReceipt? receipt = null;
        if (normalizedIdempotencyKey is not null)
        {
            receipt = new AdminGenerationRefundRetryReceipt
            {
                Id = CreateAdminGenerationRefundRetryReceiptId(adminUserId, normalizedIdempotencyKey),
                ActorUserId = adminUserId,
                GenerationId = generationId,
                IdempotencyKey = normalizedIdempotencyKey,
                RequestHash = requestHash!,
                Reason = normalizedReason,
                PreviousRefundAttemptCount = previousRefundAttemptCount,
                PreviousRefundLastAttemptedAtUtc = previousRefundLastAttemptedAtUtc,
                PreviousRefundLastErrorCode = previousRefundLastErrorCode,
                CorrelationId = correlationId,
                CreatedAtUtc = now
            };
            dbContext.AdminGenerationRefundRetryReceipts.Add(receipt);
        }

        var auditEventId = receipt?.Id ?? Guid.NewGuid();
        var auditEntry = CreateAdminGenerationRefundRetryAuditEntry(
            adminUserId,
            job,
            normalizedReason,
            previousRefundAttemptCount,
            previousRefundLastAttemptedAtUtc,
            previousRefundLastErrorCode,
            correlationId,
            auditEventId,
            now);
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            auditEntry,
            httpContextAccessor?.HttpContext);

        job.RefundAttemptCount = 0;
        job.RefundLastAttemptedAtUtc = null;
        job.RefundLastErrorCode = null;
        job.UpdatedAtUtc = now;

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        catch (DbUpdateException) when (normalizedIdempotencyKey is not null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            dbContext.ChangeTracker.Clear();
            var persistedReceipt = await FindAdminGenerationRefundRetryReceiptAsync(
                adminUserId,
                normalizedIdempotencyKey,
                cancellationToken);
            if (persistedReceipt is not null)
            {
                return await ResolveAdminGenerationRefundRetryReplayAsync(
                    persistedReceipt,
                    requestHash!,
                    cancellationToken);
            }

            throw;
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);

        logger?.LogWarning(
            "ADMIN ACTION: generation refund retry re-armed. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} UserIdHash={UserIdHash} TokenCost={TokenCost} PreviousRefundAttemptCount={PreviousRefundAttemptCount} Idempotent={Idempotent} CorrelationIdHash={CorrelationIdHash}",
            TemplateLogSanitizer.SafeId(adminUserId),
            TemplateLogSanitizer.SafeId(job.Id),
            TemplateLogSanitizer.SafeId(job.UserId),
            job.TokenCost,
            previousRefundAttemptCount,
            receipt is not null,
            SafeLogValues.StableHash(correlationId));

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    private Task<AdminGenerationRefundRetryReceipt?> FindAdminGenerationRefundRetryReceiptAsync(
        Guid adminUserId,
        string idempotencyKey,
        CancellationToken cancellationToken)
    {
        return dbContext.AdminGenerationRefundRetryReceipts
            .AsNoTracking()
            .SingleOrDefaultAsync(
                receipt => receipt.ActorUserId == adminUserId
                    && receipt.IdempotencyKey == idempotencyKey,
                cancellationToken);
    }

    private async Task<Result<TemplateGenerationResponse>> ResolveAdminGenerationRefundRetryReplayAsync(
        AdminGenerationRefundRetryReceipt receipt,
        string requestHash,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(receipt.RequestHash, requestHash, StringComparison.Ordinal))
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundRetryIdempotencyConflict);
        }

        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .SingleOrDefaultAsync(x => x.Id == receipt.GenerationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        await TemplateAdminAuditOutbox.TryDeliverExistingAsync(
            dbContext,
            adminAuditLog,
            logger,
            receipt.Id,
            cancellationToken);

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    private static AdminAuditEntry CreateAdminGenerationRefundRetryAuditEntry(
        Guid adminUserId,
        TemplateGenerationJob job,
        string? reason,
        int previousRefundAttemptCount,
        DateTime? previousRefundLastAttemptedAtUtc,
        string? previousRefundLastErrorCode,
        string correlationId,
        Guid eventId,
        DateTime occurredAtUtc)
    {
        return new AdminAuditEntry(
            AdminGenerationRefundRetryAction,
            "TemplateGenerationJob",
            job.Id.ToString("D"),
            $"refundAttemptCount={previousRefundAttemptCount};refundLastAttemptedAtUtc={previousRefundLastAttemptedAtUtc:O};refundLastErrorCode={previousRefundLastErrorCode ?? "null"}",
            "refundAttemptCount=0;refundLastAttemptedAtUtc=null;refundLastErrorCode=null",
            $"reason={reason ?? "not_provided"};tokenCost={job.TokenCost};retryBudgetReset=true",
            job.UserId,
            eventId,
            adminUserId,
            correlationId)
        {
            OccurredAtUtc = occurredAtUtc
        };
    }

    private static string? NormalizeAdminGenerationRefundRetryOptionalText(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private static string NormalizeAdminGenerationRefundRetryCorrelationId(string value)
    {
        return value.Length <= 128 ? value : value[..128];
    }

    private static Guid CreateAdminGenerationRefundRetryReceiptId(Guid adminUserId, string idempotencyKey)
    {
        var rawKey = $"{AdminGenerationRefundRetryIdempotencyScope}:{adminUserId:D}:{idempotencyKey}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey)).AsSpan(0, 16));
    }

    private static string CreateAdminGenerationRefundRetryRequestHash(Guid generationId, string? reason)
    {
        var canonicalRequest = $"{generationId:D}|{reason?.Length ?? 0}:{reason}";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalRequest)));
    }

    private async Task<IDbContextTransaction?> BeginGenerationAdminActionTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await dbContext.Database.BeginTransactionAsync(cancellationToken)
            : null;
    }

    private async Task LockGenerationRowForAdminActionAsync(Guid generationId, CancellationToken cancellationToken)
    {
        await dbContext.Database.SqlQueryRaw<Guid>(
            """
            SELECT "Id" AS "Value"
            FROM templates_generation_jobs
            WHERE "Id" = {0}
            FOR UPDATE
            """,
            generationId)
            .ToListAsync(cancellationToken);
    }

    private static bool CanAdminRetryGeneration(TemplateGenerationJob job)
    {
        var canReuseCharge = job.UserId == AdminTestUserId
            || (job.ChargedAtUtc is not null && job.RefundedAtUtc is null);
        return job.Status is TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled
            && canReuseCharge;
    }

    private static void ResetAdminRetryState(TemplateGenerationJob job, DateTime now)
    {
        job.Status = TemplateGenerationStatus.Queued;
        job.AttemptCount = 0;
        job.LastAttemptAtUtc = null;
        job.StartedAtUtc = null;
        job.CompletedAtUtc = null;
        job.CancelledAtUtc = null;
        job.QueuedAtUtc = now;
        job.UpdatedAtUtc = now;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.NextAttemptEarliestAtUtc = null;
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.ResultMediaAssetId = null;
        job.IsWatermarkRequired = false;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.PreprocessingProviderRequestId = null;
        job.PreprocessingProviderStatusUrl = null;
        job.PreprocessingProviderResponseUrl = null;
        job.PreprocessingProviderCancelUrl = null;
        job.PreprocessingInferenceTimeSeconds = null;
        job.PreprocessingCompletedAtUtc = null;
        job.MotionProviderRequestId = null;
        job.MotionProviderStatusUrl = null;
        job.MotionProviderResponseUrl = null;
        job.MotionProviderCancelUrl = null;
        job.MotionInferenceTimeSeconds = null;
        job.MotionGenerationCompletedAtUtc = null;
        job.CurrentProviderStage = null;
        job.CancellationRequestedByAdminUserId = null;
        job.CancellationRequestedAtUtc = null;
        job.CancellationLastAttemptedAtUtc = null;
        job.CancellationPreviousStatus = null;
        job.CancellationAttemptCount = 0;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationAcceptedAtUtc = null;
        job.CancellationLastErrorCode = null;
        job.ProviderStatus = null;
        job.ProviderResultUrl = null;
        job.ProviderSubmittedAtUtc = null;
        job.ProviderStatusCheckedAtUtc = null;
        job.ProviderCompletedAtUtc = null;
        job.WebhookReceivedAtUtc = null;
        job.ImportStartedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.OutputVideoDurationSeconds = null;
        job.MotionProviderCostUsd = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.RefundAttemptCount = 0;
        job.RefundLastAttemptedAtUtc = null;
        job.RefundLastErrorCode = null;
    }
}
