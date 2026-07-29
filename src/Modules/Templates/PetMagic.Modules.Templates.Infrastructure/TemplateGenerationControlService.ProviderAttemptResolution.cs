using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationControlService
{
    private const string ProviderAttemptResolutionReceiptScope = "templates:provider-attempt-resolution";
    private const string ProviderAttemptResolutionAuditAction = "templates.generation_control.provider_attempt_resolved";
    private const string CorrelatedAcceptedResolution = "correlated_accepted";
    private const string ConfirmedNotFoundResolution = "confirmed_not_found";
    private const int EvidenceReferenceMinLength = 3;
    private const int EvidenceReferenceMaxLength = 160;

    public async Task<Result<AdminTemplateProviderAttemptResolutionResponse>> ResolveProviderAttemptAsync(
        ResolveAdminTemplateProviderAttemptCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = Normalize(command.IdempotencyKey);
        if (normalizedIdempotencyKey is null || normalizedIdempotencyKey.Length > IdempotencyKeyMaxLength)
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.GenerationControlIdempotencyKeyInvalid);
        }

        var normalizedReason = Normalize(command.Reason);
        if (normalizedReason is null
            || normalizedReason.Length < ReasonMinLength
            || normalizedReason.Length > ReasonMaxLength)
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.GenerationControlReasonInvalid);
        }

        var normalizedEvidenceReference = Normalize(command.EvidenceReference);
        if (!IsValidEvidenceReference(normalizedEvidenceReference))
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionEvidenceInvalid);
        }

        var normalizedResolution = Normalize(command.Resolution)?.ToLowerInvariant();
        if (command.ProviderAttemptId == Guid.Empty
            || command.ExpectedAttemptVersion < 0
            || normalizedResolution is not (CorrelatedAcceptedResolution or ConfirmedNotFoundResolution))
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionInvalid);
        }

        if (normalizedResolution == ConfirmedNotFoundResolution
            && HasProviderCorrelation(command))
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionInvalid);
        }

        var requestHash = CreateResolutionRequestHash(
            command,
            normalizedResolution,
            normalizedReason,
            normalizedEvidenceReference!);
        var receiptId = CreateProviderAttemptResolutionReceiptId(
            command.ActorUserId,
            normalizedIdempotencyKey);
        var existingReceipt = await FindProviderAttemptResolutionReceiptAsync(receiptId, cancellationToken);
        if (existingReceipt is not null)
        {
            return await ResolveProviderAttemptReplayAsync(existingReceipt, requestHash, cancellationToken);
        }

        await EnsurePolicyAsync(cancellationToken);
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext({0}))",
                $"{ProviderAttemptResolutionReceiptScope}:{command.ProviderAttemptId:N}",
                cancellationToken);
        }

        existingReceipt = await FindProviderAttemptResolutionReceiptAsync(receiptId, cancellationToken);
        if (existingReceipt is not null)
        {
            await RollbackIfNeededAsync(transaction, cancellationToken);
            return await ResolveProviderAttemptReplayAsync(existingReceipt, requestHash, cancellationToken);
        }

        dbContext.ChangeTracker.Clear();
        var attempt = await FindProviderAttemptForUpdateAsync(command.ProviderAttemptId, transaction, cancellationToken);
        if (attempt is null)
        {
            await RollbackIfNeededAsync(transaction, cancellationToken);
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptNotFound);
        }

        var job = await FindGenerationJobForUpdateAsync(attempt.GenerationJobId, transaction, cancellationToken);
        if (job is null)
        {
            await RollbackIfNeededAsync(transaction, cancellationToken);
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptNotFound);
        }

        if (attempt.State != TemplateGenerationProviderAttemptState.SubmissionUnknown
            || attempt.Version != command.ExpectedAttemptVersion
            || job.Status != TemplateGenerationStatus.SubmittingToProvider)
        {
            await RollbackIfNeededAsync(transaction, cancellationToken);
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionConflict);
        }

        ProviderQueueSubmission? acceptedSubmission = null;
        if (normalizedResolution == CorrelatedAcceptedResolution)
        {
            var model = ResolveProviderAttemptModel(job, attempt.Stage);
            if (string.IsNullOrWhiteSpace(model)
                || string.IsNullOrWhiteSpace(command.ProviderRequestId))
            {
                await RollbackIfNeededAsync(transaction, cancellationToken);
                return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                    TemplatesErrors.ProviderAttemptCorrelationInvalid);
            }

            acceptedSubmission = FalQueueClient.ValidateProviderSubmissionCorrelation(
                options.Fal,
                model,
                command.ProviderRequestId.Trim(),
                command.ProviderStatusUrl,
                command.ProviderResponseUrl,
                command.ProviderCancelUrl);
            if (acceptedSubmission is null)
            {
                await RollbackIfNeededAsync(transaction, cancellationToken);
                return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                    TemplatesErrors.ProviderAttemptCorrelationInvalid);
            }
        }

        var oldValue = SerializeProviderAttemptResolutionAuditState(attempt, job, providerRequestId: null);
        var now = DateTime.UtcNow;
        var refundScheduled = false;
        if (acceptedSubmission is not null)
        {
            ApplyAcceptedProviderCorrelation(attempt, job, acceptedSubmission, now);
        }
        else
        {
            refundScheduled = ApplyConfirmedProviderNotFound(attempt, job, command.ActorUserId, now);
        }

        var response = new AdminTemplateProviderAttemptResolutionResponse(
            attempt.Id,
            job.Id,
            normalizedResolution,
            attempt.State.ToString(),
            attempt.Version,
            refundScheduled,
            now);
        var currentPolicyRevision = await dbContext.TemplateGenerationControlPolicies
            .AsNoTracking()
            .Where(policy => policy.Id == TemplateGenerationControlPolicyDefaults.PolicyId)
            .Select(policy => policy.Revision)
            .SingleAsync(cancellationToken);
        var scopedIdempotencyKey = CreateProviderAttemptResolutionScopedKey(normalizedIdempotencyKey);
        dbContext.TemplateGenerationControlPolicyCommandReceipts.Add(
            new TemplateGenerationControlPolicyCommandReceipt
            {
                Id = receiptId,
                ActorUserId = command.ActorUserId,
                IdempotencyKey = scopedIdempotencyKey,
                RequestHash = requestHash,
                PolicyRevision = currentPolicyRevision,
                ResponseJson = JsonSerializer.Serialize(response, JsonOptions),
                CreatedAtUtc = now
            });
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            new AdminAuditEntry(
                ProviderAttemptResolutionAuditAction,
                nameof(TemplateGenerationProviderAttempt),
                attempt.Id.ToString("D"),
                oldValue,
                SerializeProviderAttemptResolutionAuditState(attempt, job, acceptedSubmission?.RequestId),
                $"{normalizedReason}; EvidenceReference={normalizedEvidenceReference}",
                SubjectUserId: job.UserId,
                EventId: receiptId,
                ActorUserId: command.ActorUserId,
                CorrelationId: CorrelationContext.ResolveOrCreate())
            {
                OccurredAtUtc = now
            },
            httpContextAccessor?.HttpContext);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        catch (DbUpdateException)
        {
            await RollbackIfNeededAsync(transaction, cancellationToken);
            dbContext.ChangeTracker.Clear();
            var persistedReceipt = await FindProviderAttemptResolutionReceiptAsync(receiptId, cancellationToken);
            if (persistedReceipt is not null)
            {
                return await ResolveProviderAttemptReplayAsync(persistedReceipt, requestHash, cancellationToken);
            }

            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionConflict);
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);
        if (refundScheduled)
        {
            await TryRefundConfirmedNotFoundAsync(job.Id, cancellationToken);
        }

        logger?.LogWarning(
            "ADMIN ACTION: ambiguous provider attempt resolved. Resolution={Resolution} AttemptIdHash={AttemptIdHash} GenerationIdHash={GenerationIdHash} ActorUserIdHash={ActorUserIdHash} RefundScheduled={RefundScheduled}",
            normalizedResolution,
            TemplateLogSanitizer.SafeId(attempt.Id),
            TemplateLogSanitizer.SafeId(job.Id),
            TemplateLogSanitizer.SafeId(command.ActorUserId),
            refundScheduled);

        return Result.Success(response);
    }

    private async Task<Result<AdminTemplateProviderAttemptResolutionResponse>> ResolveProviderAttemptReplayAsync(
        TemplateGenerationControlPolicyCommandReceipt receipt,
        string requestHash,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(receipt.RequestHash, requestHash, StringComparison.Ordinal))
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.GenerationControlIdempotencyConflict);
        }

        var response = JsonSerializer.Deserialize<AdminTemplateProviderAttemptResolutionResponse>(
            receipt.ResponseJson,
            JsonOptions);
        if (response is null)
        {
            return Result.Failure<AdminTemplateProviderAttemptResolutionResponse>(
                TemplatesErrors.ProviderAttemptResolutionConflict);
        }

        await TemplateAdminAuditOutbox.TryDeliverExistingAsync(
            dbContext,
            adminAuditLog,
            logger,
            receipt.Id,
            cancellationToken);
        if (response.RefundScheduled)
        {
            await TryRefundConfirmedNotFoundAsync(response.GenerationId, cancellationToken);
        }

        return Result.Success(response);
    }

    private async Task TryRefundConfirmedNotFoundAsync(Guid generationId, CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();
        await using var claimTransaction = await BeginTransactionAsync(cancellationToken);
        var job = await FindGenerationJobForUpdateAsync(generationId, claimTransaction, cancellationToken);
        if (job is null
            || job.Status != TemplateGenerationStatus.Cancelled
            || job.ChargedAtUtc is null
            || job.RefundedAtUtc is not null)
        {
            await RollbackIfNeededAsync(claimTransaction, cancellationToken);
            return;
        }

        job.RefundAttemptCount++;
        job.RefundLastAttemptedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.RefundLastAttemptedAtUtc.Value;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (claimTransaction is not null)
        {
            await claimTransaction.CommitAsync(cancellationToken);
        }

        Result refund;
        try
        {
            refund = await generationBilling.RefundAsync(
                job.UserId,
                job.Id,
                job.TokenCost,
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                "Provider attempt resolution refund will be retried by maintenance. GenerationIdHash={GenerationIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(generationId),
                SafeLogValues.ExceptionType(exception));
            return;
        }

        dbContext.ChangeTracker.Clear();
        await using var settleTransaction = await BeginTransactionAsync(cancellationToken);
        var settledJob = await FindGenerationJobForUpdateAsync(generationId, settleTransaction, cancellationToken);
        if (settledJob is null || settledJob.RefundedAtUtc is not null)
        {
            await RollbackIfNeededAsync(settleTransaction, cancellationToken);
            return;
        }

        if (refund.IsSuccess)
        {
            settledJob.RefundedAtUtc = DateTime.UtcNow;
            settledJob.RefundLastErrorCode = null;
            TemplateGenerationMetrics.RecordJobRefunded(settledJob);
            TemplateGenerationMetrics.RecordCancelRefund(settledJob);
        }
        else
        {
            settledJob.RefundLastErrorCode = AdminFailureMessageSanitizer.SanitizeCode(refund.Error.Code);
            TemplateGenerationMetrics.RecordRefundFailure(
                settledJob,
                settledJob.RefundLastErrorCode ?? "templates.refund_failed");
        }

        settledJob.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (settleTransaction is not null)
        {
            await settleTransaction.CommitAsync(cancellationToken);
        }
    }

    private Task<TemplateGenerationControlPolicyCommandReceipt?> FindProviderAttemptResolutionReceiptAsync(
        Guid receiptId,
        CancellationToken cancellationToken) =>
        dbContext.TemplateGenerationControlPolicyCommandReceipts
            .AsNoTracking()
            .SingleOrDefaultAsync(receipt => receipt.Id == receiptId, cancellationToken);

    private Task<TemplateGenerationProviderAttempt?> FindProviderAttemptForUpdateAsync(
        Guid attemptId,
        IDbContextTransaction? transaction,
        CancellationToken cancellationToken) =>
        transaction is null
            ? dbContext.TemplateGenerationProviderAttempts.SingleOrDefaultAsync(
                attempt => attempt.Id == attemptId,
                cancellationToken)
            : dbContext.TemplateGenerationProviderAttempts
                .FromSqlRaw(
                    "SELECT * FROM templates_generation_provider_attempts WHERE \"Id\" = {0} FOR UPDATE",
                    attemptId)
                .SingleOrDefaultAsync(cancellationToken);

    private Task<TemplateGenerationJob?> FindGenerationJobForUpdateAsync(
        Guid generationId,
        IDbContextTransaction? transaction,
        CancellationToken cancellationToken) =>
        transaction is null
            ? dbContext.TemplateGenerationJobs.SingleOrDefaultAsync(
                job => job.Id == generationId,
                cancellationToken)
            : dbContext.TemplateGenerationJobs
                .FromSqlRaw(
                    "SELECT * FROM templates_generation_jobs WHERE \"Id\" = {0} FOR UPDATE",
                    generationId)
                .SingleOrDefaultAsync(cancellationToken);

    private static void ApplyAcceptedProviderCorrelation(
        TemplateGenerationProviderAttempt attempt,
        TemplateGenerationJob job,
        ProviderQueueSubmission submission,
        DateTime resolvedAtUtc)
    {
        attempt.State = TemplateGenerationProviderAttemptState.ProviderQueued;
        attempt.ProviderRequestId = submission.RequestId;
        attempt.ProviderStatusUrl = submission.StatusUrl;
        attempt.ProviderResponseUrl = submission.ResponseUrl;
        attempt.ProviderCancelUrl = submission.CancelUrl;
        attempt.NextPollAtUtc = resolvedAtUtc;
        attempt.SubmittedAtUtc ??= job.ProviderSubmittedAtUtc ?? attempt.CreatedAtUtc;
        attempt.LastErrorCode = null;
        attempt.LockedAtUtc = null;
        attempt.LockedBy = null;
        attempt.UpdatedAtUtc = resolvedAtUtc;
        attempt.Version++;

        job.CurrentProviderStage = ResolveProviderStage(attempt.Stage);
        if (attempt.Stage == TemplateGenerationProviderAttemptStage.VideoGeneration)
        {
            job.MotionProviderRequestId = submission.RequestId;
            job.MotionProviderStatusUrl = submission.StatusUrl;
            job.MotionProviderResponseUrl = submission.ResponseUrl;
            job.MotionProviderCancelUrl = submission.CancelUrl;
        }
        else
        {
            job.PreprocessingProviderRequestId = submission.RequestId;
            job.PreprocessingProviderStatusUrl = submission.StatusUrl;
            job.PreprocessingProviderResponseUrl = submission.ResponseUrl;
            job.PreprocessingProviderCancelUrl = submission.CancelUrl;
        }

        job.Status = TemplateGenerationStatus.ProviderQueued;
        job.ProviderStatus = "IN_QUEUE";
        job.ProviderSubmittedAtUtc ??= attempt.SubmittedAtUtc;
        job.ProviderStatusCheckedAtUtc = resolvedAtUtc;
        job.ProviderCompletedAtUtc = null;
        job.NextAttemptEarliestAtUtc = resolvedAtUtc;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = resolvedAtUtc;
    }

    private static bool ApplyConfirmedProviderNotFound(
        TemplateGenerationProviderAttempt attempt,
        TemplateGenerationJob job,
        Guid actorUserId,
        DateTime resolvedAtUtc)
    {
        attempt.State = TemplateGenerationProviderAttemptState.Cancelled;
        attempt.NextPollAtUtc = null;
        attempt.CompletedAtUtc = resolvedAtUtc;
        attempt.LastErrorCode = "templates.provider_submission_confirmed_not_found";
        attempt.LockedAtUtc = null;
        attempt.LockedBy = null;
        attempt.UpdatedAtUtc = resolvedAtUtc;
        attempt.Version++;

        job.CancellationPreviousStatus = job.Status;
        job.CancellationRequestedByAdminUserId = actorUserId;
        job.CancellationRequestedAtUtc ??= resolvedAtUtc;
        job.CancellationAcceptedAtUtc = resolvedAtUtc;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationLastErrorCode = null;
        job.Status = TemplateGenerationStatus.Cancelled;
        job.ProviderStatus = "SUBMISSION_CONFIRMED_NOT_FOUND";
        job.CancelledAtUtc = resolvedAtUtc;
        job.CompletedAtUtc = resolvedAtUtc;
        job.NextAttemptEarliestAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = resolvedAtUtc;
        return job.ChargedAtUtc is not null && job.RefundedAtUtc is null;
    }

    private static string? ResolveProviderAttemptModel(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage) => stage switch
        {
            TemplateGenerationProviderAttemptStage.ImageGeneration => job.UsedPreprocessingModel,
            TemplateGenerationProviderAttemptStage.VideoPreprocessing => job.UsedPreprocessingModel,
            TemplateGenerationProviderAttemptStage.VideoGeneration => job.UsedKlingModel,
            _ => null
        };

    private static string ResolveProviderStage(TemplateGenerationProviderAttemptStage stage) => stage switch
    {
        TemplateGenerationProviderAttemptStage.ImageGeneration => "image_generation",
        TemplateGenerationProviderAttemptStage.VideoPreprocessing => "video_preprocessing",
        TemplateGenerationProviderAttemptStage.VideoGeneration => "video_generation",
        _ => throw new ArgumentOutOfRangeException(nameof(stage), stage, "Unsupported provider attempt stage.")
    };

    private static bool HasProviderCorrelation(ResolveAdminTemplateProviderAttemptCommand command) =>
        !string.IsNullOrWhiteSpace(command.ProviderRequestId)
        || !string.IsNullOrWhiteSpace(command.ProviderStatusUrl)
        || !string.IsNullOrWhiteSpace(command.ProviderResponseUrl)
        || !string.IsNullOrWhiteSpace(command.ProviderCancelUrl);

    private static bool IsValidEvidenceReference(string? value)
    {
        return value is { Length: >= EvidenceReferenceMinLength and <= EvidenceReferenceMaxLength }
            && value.All(character => char.IsAsciiLetterOrDigit(character)
                || character is '-' or '_' or '.' or ':' or '/' or '#' or '@');
    }

    private static string CreateResolutionRequestHash(
        ResolveAdminTemplateProviderAttemptCommand command,
        string normalizedResolution,
        string normalizedReason,
        string normalizedEvidenceReference)
    {
        var canonical = string.Join(
            '|',
            command.ProviderAttemptId.ToString("N"),
            command.ExpectedAttemptVersion,
            normalizedResolution,
            normalizedReason.Length,
            normalizedReason,
            normalizedEvidenceReference,
            Normalize(command.ProviderRequestId) ?? string.Empty,
            Normalize(command.ProviderStatusUrl) ?? string.Empty,
            Normalize(command.ProviderResponseUrl) ?? string.Empty,
            Normalize(command.ProviderCancelUrl) ?? string.Empty);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }

    private static Guid CreateProviderAttemptResolutionReceiptId(Guid actorUserId, string idempotencyKey)
    {
        var raw = $"{ProviderAttemptResolutionReceiptScope}:{actorUserId:D}:{idempotencyKey}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(raw)).AsSpan(0, 16));
    }

    private static string CreateProviderAttemptResolutionScopedKey(string idempotencyKey)
    {
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(idempotencyKey)));
        return $"provider-attempt-resolution:{hash}";
    }

    private static string SerializeProviderAttemptResolutionAuditState(
        TemplateGenerationProviderAttempt attempt,
        TemplateGenerationJob job,
        string? providerRequestId) => JsonSerializer.Serialize(new
        {
            AttemptState = attempt.State.ToString(),
            attempt.Version,
            GenerationStatus = job.Status.ToString(),
            job.ProviderStatus,
            ProviderRequestIdHash = string.IsNullOrWhiteSpace(providerRequestId)
                ? null
                : SafeLogValues.StableHash(providerRequestId)
        }, JsonOptions);

    private static async Task RollbackIfNeededAsync(
        IDbContextTransaction? transaction,
        CancellationToken cancellationToken)
    {
        if (transaction is not null)
        {
            await transaction.RollbackAsync(cancellationToken);
        }
    }
}
