using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private const string ProviderStageImageGeneration = "image_generation";
    private const string ProviderStageVideoPreprocessing = "video_preprocessing";
    private const string ProviderStageVideoGeneration = "video_generation";
    private const string ProviderReconciliationRequiredStatus = "RECONCILIATION_REQUIRED";
    private const string ProviderReadReconciliationRequiredCode = "templates.provider_read_reconciliation_required";

    public async Task<Result<FalProviderWebhookResponse>> ProcessFalWebhookAsync(
        FalProviderWebhookCommand command,
        CancellationToken cancellationToken)
    {
        var job = await FindJobByProviderRequestIdAsync(command.RequestId, cancellationToken);
        if (job is null)
        {
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, null, "ignored_not_found"));
        }

        if (job.Status is TemplateGenerationStatus.Completed
            or TemplateGenerationStatus.Failed
            or TemplateGenerationStatus.Cancelled)
        {
            job.WebhookReceivedAtUtc ??= command.ReceivedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, job.Id, "ignored_terminal"));
        }

        if (IsImportPendingDuplicateWebhook(job, command.RequestId))
        {
            job.WebhookReceivedAtUtc ??= command.ReceivedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, job.Id, "ignored_import_pending"));
        }

        var staleThreshold = DateTime.UtcNow.AddMilliseconds(-options.JobLockTimeoutMilliseconds);
        if (!string.IsNullOrWhiteSpace(job.LockedBy) && job.LockedAtUtc > staleThreshold)
        {
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, job.Id, "ignored_locked"));
        }

        job.LockedBy = WorkerInstanceId;
        job.LockedAtUtc = DateTime.UtcNow;
        job.WebhookReceivedAtUtc = command.ReceivedAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);

        if (job.Status == TemplateGenerationStatus.CancellationRequested
            && IsProviderTerminalWebhookStatus(command.Status))
        {
            ResumeAfterProviderCompletedDuringCancellation(job);
        }

        if (string.Equals(command.Status, "ERROR", StringComparison.OrdinalIgnoreCase))
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, job.Id, "failed"));
        }

        if (!string.Equals(command.Status, "OK", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(command.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            job.ProviderStatus = command.Status;
            job.ProviderStatusCheckedAtUtc = command.ReceivedAtUtc;
            job.UpdatedAtUtc = command.ReceivedAtUtc;
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            return Result.Success(new FalProviderWebhookResponse(command.RequestId, job.Id, "ignored_status"));
        }

        var handled = await CompleteProviderWebhookAsync(job, command, cancellationToken);
        return Result.Success(new FalProviderWebhookResponse(
            command.RequestId,
            job.Id,
            handled ? "processed" : "ignored_stage"));
    }

    private async Task<bool> TrySubmitImageGenerationAsync(
        TemplateGenerationJob job,
        IAsyncImageGenerationQueue asyncImageGenerator,
        string sourceImageUrl,
        string prompt,
        string model,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(job.PreprocessingProviderRequestId))
        {
            return false;
        }

        var reservation = await ReserveProviderSubmissionAsync(
            job,
            TemplateGenerationProviderAttemptStage.ImageGeneration,
            cancellationToken);
        if (reservation is null)
        {
            return true;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return true;
        }

        var submittedAt = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.SubmittingToProvider;
        job.CurrentProviderStage = ProviderStageImageGeneration;
        job.ProviderStatus = "SUBMITTING";
        job.ProviderSubmittedAtUtc = submittedAt;
        job.UpdatedAtUtc = submittedAt;
        job.UsedPreprocessingModel = model;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return true;
        }

        if (reservation.IsDurable)
        {
            await providerAttemptStore!.MarkSubmittingAsync(reservation.AttemptId, cancellationToken);
        }

        var submission = reservation.IsDurable
            ? await asyncImageGenerator.SubmitAsync(
                sourceImageUrl,
                prompt,
                model,
                job.GenerationSeed,
                reservation.CallbackToken!,
                cancellationToken)
            : await asyncImageGenerator.SubmitAsync(
                sourceImageUrl,
                prompt,
                model,
                job.GenerationSeed,
                cancellationToken);
        if (submission.IsFailure)
        {
            await HandleDurableProviderSubmitFailureAsync(job, reservation, submission.Error, cancellationToken);
            return true;
        }

        if (reservation.IsDurable)
        {
            await PersistAcceptedProviderSubmissionAsync(
                job,
                reservation,
                submission.Value,
                cancellationToken);
            return true;
        }

        ApplyPreprocessingSubmission(job, submission.Value, ProviderStageImageGeneration, submittedAt);
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return true;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> TrySubmitVideoPreprocessingAsync(
        TemplateGenerationJob job,
        IAsyncImagePreprocessingQueue asyncImagePreprocessor,
        string sourceImageUrl,
        string prompt,
        string model,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(job.PreprocessingProviderRequestId))
        {
            return false;
        }

        var reservation = await ReserveProviderSubmissionAsync(
            job,
            TemplateGenerationProviderAttemptStage.VideoPreprocessing,
            cancellationToken);
        if (reservation is null)
        {
            return true;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return true;
        }

        var submittedAt = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.SubmittingToProvider;
        job.CurrentProviderStage = ProviderStageVideoPreprocessing;
        job.ProviderStatus = "SUBMITTING";
        job.ProviderSubmittedAtUtc = submittedAt;
        job.UpdatedAtUtc = submittedAt;
        job.UsedPreprocessingModel = model;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return true;
        }

        if (reservation.IsDurable)
        {
            await providerAttemptStore!.MarkSubmittingAsync(reservation.AttemptId, cancellationToken);
        }

        var submission = reservation.IsDurable
            ? await asyncImagePreprocessor.SubmitAsync(
                sourceImageUrl,
                model,
                prompt,
                reservation.CallbackToken!,
                cancellationToken)
            : await asyncImagePreprocessor.SubmitAsync(
                sourceImageUrl,
                model,
                prompt,
                cancellationToken);
        if (submission.IsFailure)
        {
            await HandleDurableProviderSubmitFailureAsync(job, reservation, submission.Error, cancellationToken);
            return true;
        }

        if (reservation.IsDurable)
        {
            await PersistAcceptedProviderSubmissionAsync(
                job,
                reservation,
                submission.Value,
                cancellationToken);
            return true;
        }

        ApplyPreprocessingSubmission(job, submission.Value, ProviderStageVideoPreprocessing, submittedAt);
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return true;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> SubmitVideoGenerationAsync(
        TemplateGenerationJob job,
        IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(job.MotionProviderRequestId))
        {
            return false;
        }

        var reservation = await ReserveProviderSubmissionAsync(
            job,
            TemplateGenerationProviderAttemptStage.VideoGeneration,
            cancellationToken);
        if (reservation is null)
        {
            return true;
        }

        var referenceMotion = TemplateGenerationService.GetAsset(job.Template, TemplateAssetKind.ReferenceMotion)!;
        var motionModel = job.Template.KlingModel!;
        var motionPrompt = PreparePrompt(job, TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt));
        var submittedAt = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.SubmittingToProvider;
        job.CurrentProviderStage = ProviderStageVideoGeneration;
        job.ProviderStatus = "SUBMITTING";
        job.ProviderSubmittedAtUtc = submittedAt;
        job.UpdatedAtUtc = submittedAt;
        job.UsedKlingModel = motionModel;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return true;
        }

        if (reservation.IsDurable)
        {
            await providerAttemptStore!.MarkSubmittingAsync(reservation.AttemptId, cancellationToken);
        }

        var submission = reservation.IsDurable
            ? await asyncVideoMotionGenerator.SubmitAsync(
                job.NormalizedImageUrl!,
                referenceMotion.Url,
                job.Template.CharacterOrientation!.Value.ToString(),
                job.Template.KeepOriginalSound ?? true,
                motionPrompt,
                motionModel,
                job.GenerationSeed,
                reservation.CallbackToken!,
                cancellationToken)
            : await asyncVideoMotionGenerator.SubmitAsync(
                job.NormalizedImageUrl!,
                referenceMotion.Url,
                job.Template.CharacterOrientation!.Value.ToString(),
                job.Template.KeepOriginalSound ?? true,
                motionPrompt,
                motionModel,
                job.GenerationSeed,
                cancellationToken);
        if (submission.IsFailure)
        {
            await HandleDurableProviderSubmitFailureAsync(job, reservation, submission.Error, cancellationToken);
            return true;
        }

        if (reservation.IsDurable)
        {
            await PersistAcceptedProviderSubmissionAsync(
                job,
                reservation,
                submission.Value,
                cancellationToken);
            return true;
        }

        job.MotionProviderRequestId = submission.Value.RequestId;
        job.MotionProviderStatusUrl = submission.Value.StatusUrl;
        job.MotionProviderResponseUrl = submission.Value.ResponseUrl;
        job.MotionProviderCancelUrl = submission.Value.CancelUrl;
        job.Status = TemplateGenerationStatus.ProviderQueued;
        job.ProviderStatus = "IN_QUEUE";
        job.ProviderSubmittedAtUtc = submittedAt;
        job.ProviderStatusCheckedAtUtc = submittedAt;
        job.ProviderCompletedAtUtc = null;
        job.NextAttemptEarliestAtUtc = submittedAt.AddSeconds(5);
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = submittedAt;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return true;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<ProviderSubmissionReservation?> ReserveProviderSubmissionAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage,
        CancellationToken cancellationToken)
    {
        if (providerAttemptStore is null)
        {
            if (await IsLegacyProviderSubmissionBlockedAsync(cancellationToken))
            {
                await DeferClaimForProviderCapacityAsync(job, cancellationToken);
                return null;
            }

            return ProviderSubmissionReservation.Legacy;
        }

        var callbackToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var submissionTokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(callbackToken)));
        var now = DateTime.UtcNow;
        var processingSeconds = stage == TemplateGenerationProviderAttemptStage.VideoGeneration
            ? Math.Max(options.FreeVideoMaxEstimatedWaitSeconds, options.EstimatedVideoGenerationSeconds)
            : Math.Max(options.FreeImageMaxEstimatedWaitSeconds, options.EstimatedImageGenerationSeconds);
        var submissionDeadline = now.AddSeconds(Math.Max(180, options.Fal.StartTimeoutSeconds + 30));
        var processingDeadline = now.AddSeconds(processingSeconds);
        if (processingDeadline < submissionDeadline)
        {
            processingDeadline = submissionDeadline;
        }

        var attempt = await providerAttemptStore.TryReserveAsync(
            new TemplateGenerationProviderAttemptReservation(
                job.Id,
                stage,
                options.AiProvider,
                submissionTokenHash,
                submissionDeadline,
                processingDeadline,
                processingDeadline.AddMinutes(10)),
            cancellationToken);
        if (attempt is null)
        {
            await DeferClaimForProviderCapacityAsync(job, cancellationToken);
            return null;
        }

        if (!string.Equals(attempt.SubmissionTokenHash, submissionTokenHash, StringComparison.Ordinal))
        {
            await ReleaseClaimForExistingProviderAttemptAsync(job, attempt, cancellationToken);
            return null;
        }

        return new ProviderSubmissionReservation(attempt.Id, callbackToken, IsDurable: true);
    }

    private async Task<bool> IsLegacyProviderSubmissionBlockedAsync(CancellationToken cancellationToken)
    {
        if (runtimePolicyProvider is not null)
        {
            var runtimePolicy = await runtimePolicyProvider.GetRuntimePolicyAsync(cancellationToken);
            if (!runtimePolicy.AdmissionEnabled)
            {
                return true;
            }
        }

        if (!string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase)
            || providerRuntimeSnapshotService is null)
        {
            return false;
        }

        var snapshot = await providerRuntimeSnapshotService.GetSnapshotAsync(cancellationToken);
        return snapshot.BalanceState is TemplateProviderBalanceState.Critical
                or TemplateProviderBalanceState.Unknown
            || snapshot.CurrentBalanceUsd <= options.FalProviderBalanceCriticalThresholdUsd;
    }

    private async Task PersistAcceptedProviderSubmissionAsync(
        TemplateGenerationJob job,
        ProviderSubmissionReservation reservation,
        ProviderQueueSubmission submission,
        CancellationToken cancellationToken)
    {
        try
        {
            await providerAttemptStore!.MarkSubmissionAcceptedAsync(
                reservation.AttemptId,
                submission.RequestId,
                submission.StatusUrl,
                submission.ResponseUrl,
                submission.CancelUrl,
                DateTime.UtcNow.AddSeconds(5),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Provider accepted a generation submission but its response could not be persisted. GenerationIdHash={GenerationIdHash} AttemptIdHash={AttemptIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.Id),
                TemplateLogSanitizer.SafeId(reservation.AttemptId),
                SafeLogValues.ExceptionType(exception));

            try
            {
                await providerAttemptStore!.MarkSubmissionUnknownAsync(
                    reservation.AttemptId,
                    "templates.provider_submission_persistence_unknown",
                    DateTime.UtcNow.AddSeconds(30),
                    CancellationToken.None);
                if (!string.IsNullOrWhiteSpace(job.LockedBy))
                {
                    await SaveClaimedChangesAsync(job, CancellationToken.None, releaseLock: true);
                }

                await PublishStatusChangedAsync(job, CancellationToken.None);
            }
            catch (Exception recoveryException)
            {
                logger.LogCritical(
                    "Provider submission requires durable recovery after response persistence failed. GenerationIdHash={GenerationIdHash} AttemptIdHash={AttemptIdHash} ExceptionType={ExceptionType}",
                    TemplateLogSanitizer.SafeId(job.Id),
                    TemplateLogSanitizer.SafeId(reservation.AttemptId),
                    SafeLogValues.ExceptionType(recoveryException));
            }

            return;
        }

        if (await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            await PublishStatusChangedAsync(job, cancellationToken);
        }
    }

    private async Task HandleDurableProviderSubmitFailureAsync(
        TemplateGenerationJob job,
        ProviderSubmissionReservation reservation,
        Error error,
        CancellationToken cancellationToken)
    {
        if (!reservation.IsDurable)
        {
            await HandleProviderSubmitFailureAsync(job, error, cancellationToken);
            return;
        }

        if (IsProviderSubmissionAmbiguous(error))
        {
            await providerAttemptStore!.MarkSubmissionUnknownAsync(
                reservation.AttemptId,
                error.Code,
                DateTime.UtcNow.AddSeconds(30),
                cancellationToken);
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            await PublishStatusChangedAsync(job, cancellationToken);
            return;
        }

        await providerAttemptStore!.MarkSubmissionFailedAsync(
            reservation.AttemptId,
            error.Code,
            cancellationToken);
        await HandleProviderSubmitFailureAsync(job, error, cancellationToken);
    }

    private static bool IsProviderSubmissionAmbiguous(Error error) =>
        IsProviderTransientFailure(error)
        || string.Equals(error.Code, TemplatesErrors.AiProviderSubmissionUnknown.Code, StringComparison.Ordinal);

    private async Task DeferClaimForProviderCapacityAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Queued;
        job.AttemptCount = Math.Max(0, job.AttemptCount - 1);
        job.StartedAtUtc = null;
        job.LastAttemptAtUtc = null;
        job.NextAttemptEarliestAtUtc = now.AddSeconds(2 + Random.Shared.NextDouble() * 2);
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = now;
        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
    }

    private async Task ReleaseClaimForExistingProviderAttemptAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttempt attempt,
        CancellationToken cancellationToken)
    {
        job.Status = attempt.State switch
        {
            TemplateGenerationProviderAttemptState.ProviderQueued => TemplateGenerationStatus.ProviderQueued,
            TemplateGenerationProviderAttemptState.ProviderProcessing => TemplateGenerationStatus.ProviderProcessing,
            _ => TemplateGenerationStatus.SubmittingToProvider
        };
        job.CurrentProviderStage = attempt.Stage switch
        {
            TemplateGenerationProviderAttemptStage.ImageGeneration => ProviderStageImageGeneration,
            TemplateGenerationProviderAttemptStage.VideoPreprocessing => ProviderStageVideoPreprocessing,
            TemplateGenerationProviderAttemptStage.VideoGeneration => ProviderStageVideoGeneration,
            _ => job.CurrentProviderStage
        };
        job.ProviderStatus = attempt.State.ToString().ToUpperInvariant();
        job.NextAttemptEarliestAtUtc = attempt.NextPollAtUtc;
        job.UpdatedAtUtc = DateTime.UtcNow;
        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
    }

    private sealed record ProviderSubmissionReservation(Guid AttemptId, string? CallbackToken, bool IsDurable)
    {
        internal static readonly ProviderSubmissionReservation Legacy = new(Guid.Empty, null, IsDurable: false);
    }

    private static void ApplyPreprocessingSubmission(
        TemplateGenerationJob job,
        ProviderQueueSubmission submission,
        string providerStage,
        DateTime submittedAt)
    {
        job.PreprocessingProviderRequestId = submission.RequestId;
        job.PreprocessingProviderStatusUrl = submission.StatusUrl;
        job.PreprocessingProviderResponseUrl = submission.ResponseUrl;
        job.PreprocessingProviderCancelUrl = submission.CancelUrl;
        job.Status = TemplateGenerationStatus.ProviderQueued;
        job.CurrentProviderStage = providerStage;
        job.ProviderStatus = "IN_QUEUE";
        job.ProviderSubmittedAtUtc = submittedAt;
        job.ProviderStatusCheckedAtUtc = submittedAt;
        job.ProviderCompletedAtUtc = null;
        job.NextAttemptEarliestAtUtc = submittedAt.AddSeconds(5);
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = submittedAt;
    }

    private async Task<bool> AdvanceNextProviderJobAsync(CancellationToken cancellationToken)
    {
        if (await ProcessNextProviderReconciliationAsync(cancellationToken))
        {
            return true;
        }

        return await ProcessNextMediaImportAsync(cancellationToken);
    }

    public async Task<bool> ProcessNextProviderReconciliationAsync(CancellationToken cancellationToken)
    {
        if (providerAttemptStore is not null)
        {
            if (await ProcessNextProviderWebhookInboxAsync(cancellationToken))
            {
                return true;
            }

            if (await ProcessNextDurableProviderAttemptAsync(cancellationToken))
            {
                return true;
            }
        }

        return await AdvanceNextProviderJobAsync(importOnly: false, cancellationToken);
    }

    public Task<bool> ProcessNextMediaImportAsync(CancellationToken cancellationToken)
    {
        return AdvanceNextProviderJobAsync(importOnly: true, cancellationToken);
    }

    private async Task<bool> ProcessNextProviderWebhookInboxAsync(CancellationToken cancellationToken)
    {
        var inbox = await providerAttemptStore!.ClaimNextWebhookAsync(
            WorkerInstanceId,
            TimeSpan.FromMilliseconds(Math.Max(1_000, options.ProviderReconciliationClaimLeaseMilliseconds)),
            cancellationToken);
        if (inbox is null)
        {
            return false;
        }

        Guid? lockedAttemptId = null;
        string? attemptLockOwner = null;
        try
        {
            var webhook = JsonSerializer.Deserialize<TemplateGenerationProviderCallbackService.PersistedFalWebhook>(
                inbox.PayloadJson);
            if (webhook is null)
            {
                throw new JsonException("Persisted fal webhook payload is empty.");
            }

            TemplateGenerationProviderAttempt? attempt = null;
            if (inbox.ProviderAttemptId is Guid providerAttemptId)
            {
                attempt = await dbContext.TemplateGenerationProviderAttempts
                    .SingleOrDefaultAsync(x => x.Id == providerAttemptId, cancellationToken);
            }
            else if (inbox.CallbackTokenHash is null && !string.IsNullOrWhiteSpace(inbox.ProviderRequestId))
            {
                attempt = await dbContext.TemplateGenerationProviderAttempts
                    .Where(x => x.Provider == inbox.Provider && x.ProviderRequestId == inbox.ProviderRequestId)
                    .OrderByDescending(x => x.CreatedAtUtc)
                    .FirstOrDefaultAsync(cancellationToken);
            }

            if (attempt is null)
            {
                if (inbox.CallbackTokenHash is not null)
                {
                    logger.LogWarning(
                        "Provider webhook callback token did not correlate to a durable attempt. InboxIdHash={InboxIdHash} Provider={Provider}",
                        TemplateLogSanitizer.SafeId(inbox.InboxId),
                        inbox.Provider);
                    await providerAttemptStore.MarkWebhookProcessedAsync(
                        inbox.InboxId,
                        WorkerInstanceId,
                        cancellationToken);
                    return true;
                }

                var legacyResult = await ProcessFalWebhookAsync(
                    new FalProviderWebhookCommand(
                        webhook.RequestId,
                        webhook.Status,
                        webhook.Payload,
                        webhook.Error,
                        webhook.ReceivedAtUtc),
                    cancellationToken);
                if (legacyResult.IsFailure)
                {
                    throw new InvalidOperationException(legacyResult.Error.Code);
                }

                await providerAttemptStore.MarkWebhookProcessedAsync(
                    inbox.InboxId,
                    WorkerInstanceId,
                    cancellationToken);
                return true;
            }

            var correlationIsValid = string.Equals(attempt.Provider, inbox.Provider, StringComparison.Ordinal)
                && (inbox.CallbackTokenHash is null
                    || string.Equals(attempt.SubmissionTokenHash, inbox.CallbackTokenHash, StringComparison.Ordinal))
                && (inbox.ProviderRequestId is null
                    || string.Equals(inbox.ProviderRequestId, webhook.RequestId, StringComparison.Ordinal))
                && (attempt.ProviderRequestId is null
                    || string.Equals(attempt.ProviderRequestId, webhook.RequestId, StringComparison.Ordinal));
            if (!correlationIsValid)
            {
                logger.LogWarning(
                    "Provider webhook correlation was rejected. InboxIdHash={InboxIdHash} AttemptIdHash={AttemptIdHash} Provider={Provider}",
                    TemplateLogSanitizer.SafeId(inbox.InboxId),
                    TemplateLogSanitizer.SafeId(attempt.Id),
                    inbox.Provider);
                await providerAttemptStore.MarkWebhookProcessedAsync(
                    inbox.InboxId,
                    WorkerInstanceId,
                    cancellationToken);
                return true;
            }

            if (attempt.State is TemplateGenerationProviderAttemptState.Completed
                or TemplateGenerationProviderAttemptState.Failed
                or TemplateGenerationProviderAttemptState.Cancelled)
            {
                await providerAttemptStore.MarkWebhookProcessedAsync(
                    inbox.InboxId,
                    WorkerInstanceId,
                    cancellationToken);
                return true;
            }

            var staleAttemptLock = DateTime.UtcNow.AddMilliseconds(
                -options.ProviderReconciliationClaimLeaseMilliseconds);
            if (!string.IsNullOrWhiteSpace(attempt.LockedBy)
                && attempt.LockedAtUtc > staleAttemptLock)
            {
                await providerAttemptStore.DeferWebhookAsync(
                    inbox.InboxId,
                    WorkerInstanceId,
                    "templates.provider_attempt_locked",
                    DateTime.UtcNow.AddSeconds(2),
                    cancellationToken);
                return true;
            }

            attemptLockOwner = $"{WorkerInstanceId}:webhook:{inbox.InboxId:N}";
            attempt.LockedBy = attemptLockOwner;
            attempt.LockedAtUtc = DateTime.UtcNow;
            attempt.UpdatedAtUtc = DateTime.UtcNow;
            attempt.Version++;
            await dbContext.SaveChangesAsync(cancellationToken);
            lockedAttemptId = attempt.Id;

            var job = await TryClaimProviderAttemptJobAsync(attempt.GenerationJobId, cancellationToken);
            if (job is null)
            {
                attempt.LockedBy = null;
                attempt.LockedAtUtc = null;
                attempt.UpdatedAtUtc = DateTime.UtcNow;
                attempt.Version++;
                await dbContext.SaveChangesAsync(cancellationToken);
                lockedAttemptId = null;
                await providerAttemptStore.DeferWebhookAsync(
                    inbox.InboxId,
                    WorkerInstanceId,
                    "templates.provider_job_locked",
                    DateTime.UtcNow.AddSeconds(2),
                    cancellationToken);
                return true;
            }

            if (IsGenerationTerminal(job.Status))
            {
                await ReleaseProviderWebhookClaimAsync(
                    job,
                    attempt,
                    inbox,
                    ResolveAttemptTerminalState(job.Status),
                    nextPollAtUtc: null,
                    job.LastErrorCode,
                    providerCompleted: job.ProviderCompletedAtUtc is not null,
                    cancellationToken);
                return true;
            }

            if (IsAttemptStageAlreadyApplied(job, attempt.Stage))
            {
                await ReleaseProviderWebhookClaimAsync(
                    job,
                    attempt,
                    inbox,
                    TemplateGenerationProviderAttemptState.Completed,
                    nextPollAtUtc: null,
                    lastErrorCode: null,
                    providerCompleted: true,
                    cancellationToken);
                return true;
            }

            var expectedProviderStage = ResolveProviderStage(attempt.Stage);
            if ((!string.IsNullOrWhiteSpace(job.CurrentProviderStage)
                    && !string.Equals(job.CurrentProviderStage, expectedProviderStage, StringComparison.Ordinal))
                || !IsLegacyProviderRequestCompatible(job, attempt.Stage, webhook.RequestId))
            {
                logger.LogWarning(
                    "Provider webhook stage or request identity did not match the claimed job. GenerationIdHash={GenerationIdHash} AttemptIdHash={AttemptIdHash} ExpectedStage={ExpectedStage} ActualStage={ActualStage}",
                    TemplateLogSanitizer.SafeId(job.Id),
                    TemplateLogSanitizer.SafeId(attempt.Id),
                    expectedProviderStage,
                    job.CurrentProviderStage);
                await ReleaseProviderWebhookClaimAsync(
                    job,
                    attempt,
                    inbox,
                    attempt.State,
                    DateTime.UtcNow.AddMinutes(5),
                    "templates.provider_stage_mismatch",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            attempt.ProviderRequestId ??= webhook.RequestId;
            attempt.SubmittedAtUtc ??= webhook.ReceivedAtUtc;
            attempt.UpdatedAtUtc = DateTime.UtcNow;
            attempt.Version++;
            job.CurrentProviderStage = expectedProviderStage;
            ApplyWebhookRequestIdToLegacyJob(job, attempt.Stage, webhook.RequestId);

            if (job.Status == TemplateGenerationStatus.CancellationRequested
                && IsProviderTerminalWebhookStatus(webhook.Status))
            {
                ResumeAfterProviderCompletedDuringCancellation(job);
            }

            if (string.Equals(webhook.Status, "ERROR", StringComparison.OrdinalIgnoreCase))
            {
                await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
                attempt.State = TemplateGenerationProviderAttemptState.Failed;
                attempt.LastErrorCode = TemplatesErrors.AiProviderFailed.Code;
                attempt.NextPollAtUtc = null;
                attempt.ProviderCompletedAtUtc = webhook.ReceivedAtUtc;
                attempt.CompletedAtUtc = webhook.ReceivedAtUtc;
            }
            else if (string.Equals(webhook.Status, "OK", StringComparison.OrdinalIgnoreCase)
                || string.Equals(webhook.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
            {
                var handled = await CompleteProviderWebhookAsync(
                    job,
                    new FalProviderWebhookCommand(
                        webhook.RequestId,
                        webhook.Status,
                        webhook.Payload,
                        webhook.Error,
                        webhook.ReceivedAtUtc),
                    cancellationToken);
                if (!handled && job.Status != TemplateGenerationStatus.Failed)
                {
                    throw new InvalidOperationException("Provider webhook completion was not applied to the claimed stage.");
                }

                attempt.State = handled
                    ? TemplateGenerationProviderAttemptState.Completed
                    : TemplateGenerationProviderAttemptState.Failed;
                attempt.NextPollAtUtc = null;
                attempt.ProviderCompletedAtUtc = webhook.ReceivedAtUtc;
                attempt.CompletedAtUtc = webhook.ReceivedAtUtc;
                attempt.LastErrorCode = handled ? null : job.LastErrorCode;
            }
            else
            {
                var isKnownNonTerminal = string.Equals(webhook.Status, "IN_QUEUE", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(webhook.Status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase);
                var cancellationPending = job.Status == TemplateGenerationStatus.CancellationRequested;
                var isStale = attempt.State is not (TemplateGenerationProviderAttemptState.Submitting
                        or TemplateGenerationProviderAttemptState.SubmissionUnknown)
                    && job.ProviderStatusCheckedAtUtc is DateTime checkedAtUtc
                    && webhook.ReceivedAtUtc < checkedAtUtc;
                if (isKnownNonTerminal && !isStale)
                {
                    var inProgress = string.Equals(webhook.Status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase)
                        || attempt.State == TemplateGenerationProviderAttemptState.ProviderProcessing
                        || job.Status == TemplateGenerationStatus.ProviderProcessing;
                    if (!cancellationPending)
                    {
                        job.Status = inProgress
                            ? TemplateGenerationStatus.ProviderProcessing
                            : TemplateGenerationStatus.ProviderQueued;
                    }

                    job.ProviderStatus = inProgress ? "IN_PROGRESS" : "IN_QUEUE";
                    job.ProviderStatusCheckedAtUtc = webhook.ReceivedAtUtc;
                    if (cancellationPending)
                    {
                        job.NextAttemptEarliestAtUtc = null;
                    }
                    else
                    {
                        ScheduleNextProviderPoll(job, webhook.ReceivedAtUtc, inProgress);
                    }

                    job.UpdatedAtUtc = webhook.ReceivedAtUtc;
                    attempt.State = inProgress
                        ? TemplateGenerationProviderAttemptState.ProviderProcessing
                        : TemplateGenerationProviderAttemptState.ProviderQueued;
                    attempt.NextPollAtUtc = cancellationPending
                        ? job.CancellationNextAttemptAtUtc ?? DateTime.UtcNow.AddSeconds(30)
                        : job.NextAttemptEarliestAtUtc;
                }
                else
                {
                    attempt.NextPollAtUtc ??= DateTime.UtcNow.AddSeconds(5);
                }

                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            }

            attempt.LockedBy = null;
            attempt.LockedAtUtc = null;
            attempt.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
            lockedAttemptId = null;
            await providerAttemptStore.MarkWebhookProcessedAsync(
                inbox.InboxId,
                WorkerInstanceId,
                cancellationToken);
            return true;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Provider webhook inbox processing deferred. InboxIdHash={InboxIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(inbox.InboxId),
                SafeLogValues.ExceptionType(exception));
            var retryExponent = Math.Clamp(inbox.FailureCount, 0, 6);
            dbContext.ChangeTracker.Clear();
            if (lockedAttemptId is Guid attemptId && attemptLockOwner is not null)
            {
                if (string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
                {
                    await dbContext.TemplateGenerationProviderAttempts
                        .Where(x => x.Id == attemptId && x.LockedBy == attemptLockOwner)
                        .ExecuteUpdateAsync(
                            setters => setters
                                .SetProperty(x => x.LockedBy, (string?)null)
                                .SetProperty(x => x.LockedAtUtc, (DateTime?)null)
                                .SetProperty(x => x.UpdatedAtUtc, DateTime.UtcNow)
                                .SetProperty(x => x.Version, x => x.Version + 1),
                            CancellationToken.None);
                }
                else
                {
                    var lockedAttempt = await dbContext.TemplateGenerationProviderAttempts
                        .SingleOrDefaultAsync(
                            x => x.Id == attemptId && x.LockedBy == attemptLockOwner,
                            CancellationToken.None);
                    if (lockedAttempt is not null)
                    {
                        lockedAttempt.LockedBy = null;
                        lockedAttempt.LockedAtUtc = null;
                        lockedAttempt.UpdatedAtUtc = DateTime.UtcNow;
                        lockedAttempt.Version++;
                        await dbContext.SaveChangesAsync(CancellationToken.None);
                    }
                }
            }

            var deadLettered = await providerAttemptStore.MarkWebhookFailedAsync(
                inbox.InboxId,
                WorkerInstanceId,
                "templates.provider_webhook_reconciliation_failed",
                DateTime.UtcNow.AddSeconds(Math.Min(300, 2 * (1 << retryExponent))),
                CancellationToken.None);
            if (deadLettered)
            {
                TemplateGenerationMetrics.RecordProviderWebhookDeadLettered(
                    inbox.Provider,
                    "templates.provider_webhook_reconciliation_failed");
                logger.LogError(
                    "Provider webhook inbox reached its reconciliation retry limit and was dead-lettered. InboxIdHash={InboxIdHash} Provider={Provider} FailureCount={FailureCount}",
                    TemplateLogSanitizer.SafeId(inbox.InboxId),
                    inbox.Provider,
                    inbox.FailureCount + 1);
            }

            return true;
        }
    }

    private static void ApplyWebhookRequestIdToLegacyJob(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage,
        string requestId)
    {
        if (stage == TemplateGenerationProviderAttemptStage.VideoGeneration)
        {
            job.MotionProviderRequestId ??= requestId;
        }
        else
        {
            job.PreprocessingProviderRequestId ??= requestId;
        }
    }

    private async Task ReleaseProviderWebhookClaimAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttempt attempt,
        TemplateProviderWebhookInboxClaim inbox,
        TemplateGenerationProviderAttemptState state,
        DateTime? nextPollAtUtc,
        string? lastErrorCode,
        bool providerCompleted,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        attempt.State = state;
        attempt.NextPollAtUtc = nextPollAtUtc;
        attempt.LastErrorCode = lastErrorCode;
        if (providerCompleted)
        {
            attempt.ProviderCompletedAtUtc ??= job.ProviderCompletedAtUtc ?? now;
        }

        if (state is TemplateGenerationProviderAttemptState.Completed
            or TemplateGenerationProviderAttemptState.Failed
            or TemplateGenerationProviderAttemptState.Cancelled)
        {
            attempt.CompletedAtUtc ??= now;
        }

        attempt.LockedBy = null;
        attempt.LockedAtUtc = null;
        attempt.UpdatedAtUtc = now;
        attempt.Version++;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            throw new DbUpdateConcurrencyException("Provider webhook job claim changed before reconciliation completed.");
        }

        await providerAttemptStore!.MarkWebhookProcessedAsync(
            inbox.InboxId,
            WorkerInstanceId,
            cancellationToken);
    }

    private static bool IsGenerationTerminal(TemplateGenerationStatus status) =>
        status is TemplateGenerationStatus.Completed
            or TemplateGenerationStatus.Failed
            or TemplateGenerationStatus.Cancelled;

    private static bool IsProviderTerminalWebhookStatus(string status) =>
        string.Equals(status, "OK", StringComparison.OrdinalIgnoreCase)
        || string.Equals(status, "COMPLETED", StringComparison.OrdinalIgnoreCase)
        || string.Equals(status, "ERROR", StringComparison.OrdinalIgnoreCase);

    private static void ResumeAfterProviderCompletedDuringCancellation(TemplateGenerationJob job)
    {
        if (job.Status != TemplateGenerationStatus.CancellationRequested)
        {
            return;
        }

        job.Status = job.CancellationPreviousStatus is TemplateGenerationStatus.ProviderQueued
                or TemplateGenerationStatus.ProviderProcessing
            ? job.CancellationPreviousStatus.Value
            : TemplateGenerationStatus.ProviderProcessing;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationLastErrorCode = null;
    }

    private static TemplateGenerationProviderAttemptState ResolveAttemptTerminalState(
        TemplateGenerationStatus status) => status switch
        {
            TemplateGenerationStatus.Completed => TemplateGenerationProviderAttemptState.Completed,
            TemplateGenerationStatus.Failed => TemplateGenerationProviderAttemptState.Failed,
            TemplateGenerationStatus.Cancelled => TemplateGenerationProviderAttemptState.Cancelled,
            _ => throw new ArgumentOutOfRangeException(nameof(status), status, null)
        };

    private static bool IsAttemptStageAlreadyApplied(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage) => stage switch
        {
            TemplateGenerationProviderAttemptStage.ImageGeneration =>
                job.Status is TemplateGenerationStatus.ImportingMedia or TemplateGenerationStatus.Completed
                || job.MediaImportCompletedAtUtc is not null,
            TemplateGenerationProviderAttemptStage.VideoPreprocessing =>
                (job.PreprocessingCompletedAtUtc is not null && !string.IsNullOrWhiteSpace(job.NormalizedImageUrl))
                || string.Equals(job.CurrentProviderStage, ProviderStageVideoGeneration, StringComparison.Ordinal)
                || !string.IsNullOrWhiteSpace(job.MotionProviderRequestId)
                || job.Status is TemplateGenerationStatus.ImportingMedia or TemplateGenerationStatus.Completed,
            TemplateGenerationProviderAttemptStage.VideoGeneration =>
                job.MotionGenerationCompletedAtUtc is not null
                || job.Status is TemplateGenerationStatus.ImportingMedia or TemplateGenerationStatus.Completed,
            _ => false
        };

    private static bool IsLegacyProviderRequestCompatible(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage,
        string requestId)
    {
        var legacyRequestId = stage == TemplateGenerationProviderAttemptStage.VideoGeneration
            ? job.MotionProviderRequestId
            : job.PreprocessingProviderRequestId;
        return legacyRequestId is null || string.Equals(legacyRequestId, requestId, StringComparison.Ordinal);
    }

    private async Task<bool> ProcessNextDurableProviderAttemptAsync(CancellationToken cancellationToken)
    {
        var claim = await providerAttemptStore!.ClaimDueAsync(
            WorkerInstanceId,
            TimeSpan.FromMilliseconds(Math.Max(1_000, options.ProviderReconciliationClaimLeaseMilliseconds)),
            cancellationToken);
        if (claim is null)
        {
            return false;
        }

        var job = await TryClaimProviderAttemptJobAsync(claim.GenerationJobId, cancellationToken);
        if (job is null)
        {
            await providerAttemptStore.UpdateClaimedStateAsync(
                claim.AttemptId,
                WorkerInstanceId,
                claim.State,
                DateTime.UtcNow.AddSeconds(2),
                "templates.provider_job_locked",
                providerCompleted: false,
                cancellationToken);
            return true;
        }

        try
        {
            if (IsGenerationTerminal(job.Status))
            {
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    ResolveAttemptTerminalState(job.Status),
                    nextPollAtUtc: null,
                    job.LastErrorCode,
                    providerCompleted: job.ProviderCompletedAtUtc is not null,
                    cancellationToken);
                return true;
            }

            if (job.Status == TemplateGenerationStatus.CancellationRequested)
            {
                var cancellationState = claim.State == TemplateGenerationProviderAttemptState.SubmitReserved
                    ? TemplateGenerationProviderAttemptState.Cancelled
                    : claim.State;
                DateTime? cancellationPollAtUtc = cancellationState == TemplateGenerationProviderAttemptState.Cancelled
                    ? null
                    : job.CancellationNextAttemptAtUtc ?? DateTime.UtcNow.AddSeconds(30);
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    cancellationState,
                    cancellationPollAtUtc,
                    "templates.provider_cancellation_pending",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            if (IsAttemptStageAlreadyApplied(job, claim.Stage))
            {
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    TemplateGenerationProviderAttemptState.Completed,
                    nextPollAtUtc: null,
                    lastErrorCode: null,
                    providerCompleted: true,
                    cancellationToken);
                return true;
            }

            var expectedProviderStage = ResolveProviderStage(claim.Stage);
            if ((!string.IsNullOrWhiteSpace(job.CurrentProviderStage)
                    && !string.Equals(job.CurrentProviderStage, expectedProviderStage, StringComparison.Ordinal))
                || (claim.ProviderRequestId is not null
                    && !IsLegacyProviderRequestCompatible(job, claim.Stage, claim.ProviderRequestId)))
            {
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    claim.State,
                    DateTime.UtcNow.AddMinutes(5),
                    "templates.provider_stage_mismatch",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            if (claim.State == TemplateGenerationProviderAttemptState.SubmitReserved)
            {
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    TemplateGenerationProviderAttemptState.Failed,
                    nextPollAtUtc: null,
                    "templates.provider_submit_not_started",
                    providerCompleted: false,
                    cancellationToken);
                await DeferClaimForProviderCapacityAsync(job, cancellationToken);
                return true;
            }

            if (claim.State == TemplateGenerationProviderAttemptState.Submitting)
            {
                var nextReconciliationAt = MinUtc(
                    claim.ReconciliationDeadlineAtUtc,
                    DateTime.UtcNow.AddSeconds(30));
                job.Status = TemplateGenerationStatus.SubmittingToProvider;
                job.CurrentProviderStage = ResolveProviderStage(claim.Stage);
                job.ProviderStatus = "SUBMISSION_UNKNOWN";
                job.NextAttemptEarliestAtUtc = nextReconciliationAt;
                job.UpdatedAtUtc = DateTime.UtcNow;
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    TemplateGenerationProviderAttemptState.SubmissionUnknown,
                    nextReconciliationAt,
                    "templates.provider_submission_unknown",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            if (claim.State == TemplateGenerationProviderAttemptState.SubmissionUnknown)
            {
                var now = DateTime.UtcNow;
                var requiresManualReconciliation = now >= claim.ReconciliationDeadlineAtUtc;
                var nextReconciliationAt = requiresManualReconciliation
                    ? now.AddMinutes(5)
                    : MinUtc(claim.ReconciliationDeadlineAtUtc, now.AddSeconds(30));
                job.Status = TemplateGenerationStatus.SubmittingToProvider;
                job.ProviderStatus = requiresManualReconciliation
                    ? "RECONCILIATION_REQUIRED"
                    : "SUBMISSION_UNKNOWN";
                job.LastErrorCode = requiresManualReconciliation
                    ? "templates.provider_submission_reconciliation_required"
                    : "templates.provider_submission_unknown";
                job.NextAttemptEarliestAtUtc = nextReconciliationAt;
                job.UpdatedAtUtc = now;
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    TemplateGenerationProviderAttemptState.SubmissionUnknown,
                    nextReconciliationAt,
                    job.LastErrorCode,
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            await PollClaimedProviderAttemptAsync(job, claim, cancellationToken);

            // Provider polling can lose the job lease to an admin cancellation. In that case the
            // in-memory job may contain a completed stage even though SaveClaimedChangesAsync
            // rejected it on optimistic concurrency. Never terminalize the durable attempt from
            // that detached state: PostgreSQL is the source of truth at this boundary.
            var persistedJob = await ReloadProviderAttemptJobAsync(claim.GenerationJobId, cancellationToken);
            if (persistedJob is null)
            {
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    claim.State,
                    DateTime.UtcNow.AddSeconds(30),
                    "templates.provider_job_missing",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            if (persistedJob.Status == TemplateGenerationStatus.CancellationRequested)
            {
                await providerAttemptStore.UpdateClaimedStateAsync(
                    claim.AttemptId,
                    WorkerInstanceId,
                    claim.State,
                    persistedJob.CancellationNextAttemptAtUtc ?? DateTime.UtcNow.AddSeconds(30),
                    "templates.provider_cancellation_pending",
                    providerCompleted: false,
                    cancellationToken);
                return true;
            }

            if (persistedJob.Status is (TemplateGenerationStatus.ProviderQueued or TemplateGenerationStatus.ProviderProcessing)
                && DateTime.UtcNow >= claim.ProcessingDeadlineAtUtc)
            {
                var timeoutJob = await TryClaimProviderAttemptJobAsync(claim.GenerationJobId, cancellationToken);
                if (timeoutJob is null)
                {
                    await providerAttemptStore.UpdateClaimedStateAsync(
                        claim.AttemptId,
                        WorkerInstanceId,
                        claim.State,
                        DateTime.UtcNow.AddSeconds(2),
                        "templates.provider_job_locked",
                        providerCompleted: false,
                        cancellationToken);
                    return true;
                }

                await TryCancelTimedOutProviderAttemptAsync(timeoutJob, claim, cancellationToken);
                persistedJob = await ReloadProviderAttemptJobAsync(claim.GenerationJobId, cancellationToken);
                if (persistedJob is null)
                {
                    await providerAttemptStore.UpdateClaimedStateAsync(
                        claim.AttemptId,
                        WorkerInstanceId,
                        claim.State,
                        DateTime.UtcNow.AddSeconds(30),
                        "templates.provider_job_missing",
                        providerCompleted: false,
                        cancellationToken);
                    return true;
                }

                if (persistedJob.Status == TemplateGenerationStatus.CancellationRequested)
                {
                    await providerAttemptStore.UpdateClaimedStateAsync(
                        claim.AttemptId,
                        WorkerInstanceId,
                        claim.State,
                        persistedJob.CancellationNextAttemptAtUtc ?? DateTime.UtcNow.AddSeconds(30),
                        "templates.provider_cancellation_pending",
                        providerCompleted: false,
                        cancellationToken);
                    return true;
                }
            }

            var (state, nextPollAtUtc, providerCompleted) = ResolveAttemptState(persistedJob, claim);
            await providerAttemptStore.UpdateClaimedStateAsync(
                claim.AttemptId,
                WorkerInstanceId,
                state,
                nextPollAtUtc,
                persistedJob.LastErrorCode,
                providerCompleted,
                cancellationToken);
            return true;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            logger.LogInformation(
                "Durable provider attempt reconciliation yielded to a concurrent job or attempt transition. GenerationIdHash={GenerationIdHash} AttemptIdHash={AttemptIdHash}",
                TemplateLogSanitizer.SafeId(job.Id),
                TemplateLogSanitizer.SafeId(claim.AttemptId));
            dbContext.ChangeTracker.Clear();
            return true;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Durable provider attempt reconciliation failed. GenerationIdHash={GenerationIdHash} AttemptIdHash={AttemptIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.Id),
                TemplateLogSanitizer.SafeId(claim.AttemptId),
                SafeLogValues.ExceptionType(exception));
            if (!string.IsNullOrWhiteSpace(job.LockedBy))
            {
                await SaveClaimedChangesAsync(job, CancellationToken.None, releaseLock: true);
            }

            await providerAttemptStore.UpdateClaimedStateAsync(
                claim.AttemptId,
                WorkerInstanceId,
                claim.State,
                DateTime.UtcNow.AddSeconds(30),
                "templates.provider_reconciliation_failed",
                providerCompleted: false,
                CancellationToken.None);
            return true;
        }
    }

    private async Task<TemplateGenerationJob?> TryClaimProviderAttemptJobAsync(
        Guid generationJobId,
        CancellationToken cancellationToken)
    {
        var staleThreshold = DateTime.UtcNow.AddMilliseconds(
            -options.ProviderReconciliationClaimLeaseMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == generationJobId, cancellationToken);
        if (job is null
            || (!string.IsNullOrWhiteSpace(job.LockedBy) && job.LockedAtUtc > staleThreshold))
        {
            return null;
        }

        job.LockedBy = WorkerInstanceId;
        job.LockedAtUtc = DateTime.UtcNow;
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return job;
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            return null;
        }
    }

    private async Task<TemplateGenerationJob?> ReloadProviderAttemptJobAsync(
        Guid generationJobId,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();
        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationJobId, cancellationToken);
    }

    private Task PollClaimedProviderAttemptAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptClaim claim,
        CancellationToken cancellationToken)
    {
        ApplyAttemptSubmissionToLegacyJob(job, claim);
        return claim.Stage switch
        {
            TemplateGenerationProviderAttemptStage.ImageGeneration => PollImageGenerationAsync(
                job,
                cancellationToken,
                durableAttempt: true),
            TemplateGenerationProviderAttemptStage.VideoPreprocessing => PollVideoPreprocessingAsync(
                job,
                cancellationToken,
                durableAttempt: true),
            TemplateGenerationProviderAttemptStage.VideoGeneration => PollVideoGenerationAsync(
                job,
                cancellationToken,
                durableAttempt: true),
            _ => Task.CompletedTask
        };
    }

    private async Task TryCancelTimedOutProviderAttemptAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptClaim claim,
        CancellationToken cancellationToken)
    {
        if (falQueueClient is null
            || string.IsNullOrWhiteSpace(claim.ProviderRequestId))
        {
            await MarkProviderAttemptForManualReconciliationAsync(job, claim, cancellationToken);
            return;
        }

        if (string.IsNullOrWhiteSpace(job.LockedBy))
        {
            job.LockedBy = WorkerInstanceId;
            job.LockedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var model = ResolveAttemptModel(job, claim.Stage);
        var cancellationUri = falQueueClient.ResolveCancellationUri(
            model,
            claim.ProviderRequestId,
            claim.ProviderCancelUrl,
            claim.ProviderStatusUrl);
        if (cancellationUri is null)
        {
            await MarkProviderAttemptForManualReconciliationAsync(job, claim, cancellationToken);
            return;
        }

        var cancellation = await falQueueClient.CancelAsync(
            model,
            claim.ProviderRequestId,
            cancellationUri,
            cancellationToken);
        if (cancellation.Outcome is FalQueueCancellationOutcome.Accepted or FalQueueCancellationOutcome.NotFound)
        {
            if (cancellation.Outcome == FalQueueCancellationOutcome.Accepted)
            {
                job.ProviderStatus = "CANCELLATION_REQUESTED";
            }

            await MarkProviderAttemptForManualReconciliationAsync(job, claim, cancellationToken);
            return;
        }

        if (cancellation.Outcome == FalQueueCancellationOutcome.AlreadyCompleted)
        {
            job.NextAttemptEarliestAtUtc = DateTime.UtcNow.AddSeconds(2);
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            return;
        }

        await MarkProviderAttemptForManualReconciliationAsync(job, claim, cancellationToken);
    }

    private async Task MarkProviderAttemptForManualReconciliationAsync(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptClaim claim,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.LastErrorCode = now >= claim.ReconciliationDeadlineAtUtc
            ? "templates.provider_cancellation_reconciliation_required"
            : "templates.provider_cancellation_pending";
        job.NextAttemptEarliestAtUtc = now >= claim.ReconciliationDeadlineAtUtc
            ? now.AddMinutes(5)
            : MinUtc(claim.ReconciliationDeadlineAtUtc, now.AddSeconds(30));
        job.UpdatedAtUtc = now;
        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
    }

    private static (TemplateGenerationProviderAttemptState State, DateTime? NextPollAtUtc, bool ProviderCompleted)
        ResolveAttemptState(
            TemplateGenerationJob job,
            TemplateGenerationProviderAttemptClaim claim)
    {
        if (job.Status == TemplateGenerationStatus.Failed)
        {
            return (TemplateGenerationProviderAttemptState.Failed, null, job.ProviderCompletedAtUtc is not null);
        }

        if (job.Status == TemplateGenerationStatus.Cancelled)
        {
            return (TemplateGenerationProviderAttemptState.Cancelled, null, job.ProviderCompletedAtUtc is not null);
        }

        if (string.Equals(job.ProviderStatus, ProviderReconciliationRequiredStatus, StringComparison.Ordinal)
            || string.Equals(job.LastErrorCode, ProviderReadReconciliationRequiredCode, StringComparison.Ordinal))
        {
            return (
                TemplateGenerationProviderAttemptState.SubmissionUnknown,
                job.NextAttemptEarliestAtUtc,
                false);
        }

        if (job.Status == TemplateGenerationStatus.ImportingMedia
            || (claim.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing
                && job.ProviderCompletedAtUtc is not null
                && !string.IsNullOrWhiteSpace(job.NormalizedImageUrl)))
        {
            return (TemplateGenerationProviderAttemptState.Completed, null, true);
        }

        return job.Status == TemplateGenerationStatus.ProviderProcessing
            ? (TemplateGenerationProviderAttemptState.ProviderProcessing, job.NextAttemptEarliestAtUtc, false)
            : (TemplateGenerationProviderAttemptState.ProviderQueued, job.NextAttemptEarliestAtUtc, false);
    }

    private static void ApplyAttemptSubmissionToLegacyJob(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptClaim claim)
    {
        job.CurrentProviderStage = ResolveProviderStage(claim.Stage);
        if (claim.Stage == TemplateGenerationProviderAttemptStage.VideoGeneration)
        {
            job.MotionProviderRequestId ??= claim.ProviderRequestId;
            job.MotionProviderStatusUrl ??= claim.ProviderStatusUrl;
            job.MotionProviderResponseUrl ??= claim.ProviderResponseUrl;
            job.MotionProviderCancelUrl ??= claim.ProviderCancelUrl;
        }
        else
        {
            job.PreprocessingProviderRequestId ??= claim.ProviderRequestId;
            job.PreprocessingProviderStatusUrl ??= claim.ProviderStatusUrl;
            job.PreprocessingProviderResponseUrl ??= claim.ProviderResponseUrl;
            job.PreprocessingProviderCancelUrl ??= claim.ProviderCancelUrl;
        }
    }

    private static string ResolveAttemptModel(
        TemplateGenerationJob job,
        TemplateGenerationProviderAttemptStage stage) => stage switch
        {
            TemplateGenerationProviderAttemptStage.ImageGeneration => job.UsedPreprocessingModel ?? job.Template.ImageModel ?? string.Empty,
            TemplateGenerationProviderAttemptStage.VideoPreprocessing => job.UsedPreprocessingModel ?? job.Template.PreprocessingModel ?? string.Empty,
            TemplateGenerationProviderAttemptStage.VideoGeneration => job.UsedKlingModel ?? job.Template.KlingModel ?? string.Empty,
            _ => string.Empty
        };

    private static string ResolveProviderStage(TemplateGenerationProviderAttemptStage stage) => stage switch
    {
        TemplateGenerationProviderAttemptStage.ImageGeneration => ProviderStageImageGeneration,
        TemplateGenerationProviderAttemptStage.VideoPreprocessing => ProviderStageVideoPreprocessing,
        TemplateGenerationProviderAttemptStage.VideoGeneration => ProviderStageVideoGeneration,
        _ => throw new ArgumentOutOfRangeException(nameof(stage), stage, null)
    };

    private static DateTime MinUtc(DateTime left, DateTime right) => left <= right ? left : right;

    private async Task<bool> AdvanceNextProviderJobAsync(
        bool importOnly,
        CancellationToken cancellationToken)
    {
        var job = await ClaimNextProviderJobAsync(
            includePollingJobs: !importOnly && falQueueClient is not null,
            includeReconciliationJobs: !importOnly,
            includeImportJobs: importOnly,
            cancellationToken);
        if (job is null)
        {
            return false;
        }

        try
        {
            if (importOnly
                && job.Status == TemplateGenerationStatus.ImportingMedia
                && !string.IsNullOrWhiteSpace(job.LockedBy))
            {
                return await ImportStagedProviderMediaAsync(job, cancellationToken);
            }

            if (IsVideoPreprocessingReadyForMotionSubmit(job))
            {
                return await SubmitStagedVideoGenerationAsync(job, cancellationToken);
            }

            if (falQueueClient is null)
            {
                await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
                return false;
            }

            return job.CurrentProviderStage switch
            {
                ProviderStageImageGeneration => await PollImageGenerationAsync(job, cancellationToken),
                ProviderStageVideoPreprocessing => await PollVideoPreprocessingAsync(job, cancellationToken),
                ProviderStageVideoGeneration => await PollVideoGenerationAsync(job, cancellationToken),
                _ => await MarkUnknownProviderStageFailedAsync(job, cancellationToken)
            };
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Template generation provider pipeline step failed. GenerationIdHash={GenerationIdHash} ProviderStage={ProviderStage} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.Id),
                job.CurrentProviderStage,
                SafeLogValues.ExceptionType(exception));
            if (importOnly)
            {
                await DeferOrFailMediaImportAsync(
                    job,
                    TemplatesErrors.GeneratedMediaImportFailed,
                    CancellationToken.None);
            }
            else
            {
                await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
            }

            return true;
        }
    }

    private async Task<TemplateGenerationJob?> ClaimNextProviderJobAsync(
        bool includePollingJobs,
        bool includeReconciliationJobs,
        bool includeImportJobs,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var staleThreshold = now.AddMilliseconds(-options.JobLockTimeoutMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => ((includeImportJobs && x.Status == TemplateGenerationStatus.ImportingMedia)
                    || (includeReconciliationJobs
                        && ((includePollingJobs
                                && (x.Status == TemplateGenerationStatus.ProviderQueued
                                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                                && (providerAttemptStore == null || !x.ProviderAttempts.Any()))
                            || (x.Status == TemplateGenerationStatus.ProviderQueued
                                && x.CurrentProviderStage == ProviderStageVideoPreprocessing
                                && x.ProviderCompletedAtUtc != null
                                && x.NormalizedImageUrl != null
                                && x.MotionProviderRequestId == null))))
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
                && ((x.Status == TemplateGenerationStatus.ImportingMedia
                        && (x.MediaImportNextAttemptAtUtc == null || x.MediaImportNextAttemptAtUtc <= now))
                    || (x.Status != TemplateGenerationStatus.ImportingMedia
                        && (x.NextAttemptEarliestAtUtc == null || x.NextAttemptEarliestAtUtc <= now)))
                && (x.LockedAtUtc == null || x.LockedAtUtc <= staleThreshold))
            .OrderBy(x => x.ProviderStatusCheckedAtUtc ?? x.UpdatedAtUtc)
            .ThenBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return null;
        }

        job.LockedAtUtc = DateTime.UtcNow;
        job.LockedBy = WorkerInstanceId;
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return job;
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            return null;
        }
    }

    private Task<TemplateGenerationJob?> FindJobByProviderRequestIdAsync(string requestId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .FirstOrDefaultAsync(x => x.PreprocessingProviderRequestId == requestId
                || x.MotionProviderRequestId == requestId, cancellationToken);
    }

    private async Task<bool> CompleteProviderWebhookAsync(
        TemplateGenerationJob job,
        FalProviderWebhookCommand command,
        CancellationToken cancellationToken)
    {
        job.ProviderStatus = "WEBHOOK_OK";
        job.ProviderStatusCheckedAtUtc = command.ReceivedAtUtc;
        job.ProviderCompletedAtUtc = command.ReceivedAtUtc;
        job.NextAttemptEarliestAtUtc = null;
        job.UpdatedAtUtc = command.ReceivedAtUtc;

        if (string.Equals(job.PreprocessingProviderRequestId, command.RequestId, StringComparison.Ordinal)
            && string.Equals(job.CurrentProviderStage, ProviderStageImageGeneration, StringComparison.Ordinal))
        {
            return await CompleteImageGenerationFromProviderPayloadAsync(job, command.Payload, command.RequestId, null, cancellationToken);
        }

        if (string.Equals(job.PreprocessingProviderRequestId, command.RequestId, StringComparison.Ordinal)
            && string.Equals(job.CurrentProviderStage, ProviderStageVideoPreprocessing, StringComparison.Ordinal))
        {
            return await CompleteVideoPreprocessingFromProviderPayloadAsync(job, command.Payload, command.RequestId, null, cancellationToken);
        }

        if (string.Equals(job.MotionProviderRequestId, command.RequestId, StringComparison.Ordinal)
            && string.Equals(job.CurrentProviderStage, ProviderStageVideoGeneration, StringComparison.Ordinal))
        {
            return await CompleteVideoGenerationFromProviderPayloadAsync(job, command.Payload, command.RequestId, null, cancellationToken);
        }

        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
        return false;
    }

    private async Task<bool> PollImageGenerationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool durableAttempt = false)
    {
        if (imageGenerator is not IAsyncImageGenerationQueue asyncImageGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(
            job,
            job.PreprocessingProviderStatusUrl,
            job.UsedPreprocessingModel,
            cancellationToken,
            durableAttempt);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(
            job,
            job.PreprocessingProviderResponseUrl,
            job.UsedPreprocessingModel,
            cancellationToken,
            durableAttempt);
        if (response is null)
        {
            return true;
        }

        using (response)
        {
            await CompleteImageGenerationFromProviderPayloadAsync(
                job,
                response.RootElement,
                status.RequestId ?? job.PreprocessingProviderRequestId,
                status.InferenceTimeSeconds,
                cancellationToken);
        }

        return true;
    }

    private async Task<bool> PollVideoPreprocessingAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool durableAttempt = false)
    {
        if (imagePreprocessor is not IAsyncImagePreprocessingQueue asyncImagePreprocessor
            || videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(
            job,
            job.PreprocessingProviderStatusUrl,
            job.UsedPreprocessingModel,
            cancellationToken,
            durableAttempt);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(
            job,
            job.PreprocessingProviderResponseUrl,
            job.UsedPreprocessingModel,
            cancellationToken,
            durableAttempt);
        if (response is null)
        {
            return true;
        }

        using (response)
        {
            await CompleteVideoPreprocessingFromProviderPayloadAsync(
                job,
                response.RootElement,
                status.RequestId ?? job.PreprocessingProviderRequestId,
                status.InferenceTimeSeconds,
                cancellationToken);
        }

        return true;
    }

    private async Task<bool> PollVideoGenerationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool durableAttempt = false)
    {
        if (videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(
            job,
            job.MotionProviderStatusUrl,
            job.UsedKlingModel,
            cancellationToken,
            durableAttempt);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(
            job,
            job.MotionProviderResponseUrl,
            job.UsedKlingModel,
            cancellationToken,
            durableAttempt);
        if (response is null)
        {
            return true;
        }

        using (response)
        {
            await CompleteVideoGenerationFromProviderPayloadAsync(
                job,
                response.RootElement,
                status.RequestId ?? job.MotionProviderRequestId,
                status.InferenceTimeSeconds,
                cancellationToken);
        }

        return true;
    }

    private async Task<bool> CompleteImageGenerationFromProviderPayloadAsync(
        TemplateGenerationJob job,
        JsonElement payload,
        string? requestId,
        double? inferenceTimeSeconds,
        CancellationToken cancellationToken)
    {
        if (imageGenerator is not IAsyncImageGenerationQueue asyncImageGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return false;
        }

        var completed = asyncImageGenerator.Complete(payload, requestId, inferenceTimeSeconds);
        if (completed.IsFailure)
        {
            await MarkFailedAsync(job, completed.Error, cancellationToken);
            return false;
        }

        return await StageImageImportAsync(job, completed.Value, cancellationToken);
    }

    private async Task<bool> CompleteVideoPreprocessingFromProviderPayloadAsync(
        TemplateGenerationJob job,
        JsonElement payload,
        string? requestId,
        double? inferenceTimeSeconds,
        CancellationToken cancellationToken)
    {
        if (imagePreprocessor is not IAsyncImagePreprocessingQueue asyncImagePreprocessor)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return false;
        }

        var completed = asyncImagePreprocessor.Complete(payload, requestId, inferenceTimeSeconds);
        if (completed.IsFailure)
        {
            await MarkFailedAsync(job, completed.Error, cancellationToken);
            return false;
        }

        job.NormalizedImageUrl = completed.Value.ImageUrl;
        job.PreprocessingProviderRequestId = completed.Value.ProviderRequestId ?? job.PreprocessingProviderRequestId;
        job.PreprocessingInferenceTimeSeconds = completed.Value.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
        job.ProviderCompletedAtUtc ??= job.PreprocessingCompletedAtUtc;
        job.ProviderStatus = "COMPLETED";
        job.Status = TemplateGenerationStatus.ProviderQueued;
        job.NextAttemptEarliestAtUtc = null;
        job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> SubmitStagedVideoGenerationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        await SubmitVideoGenerationAsync(job, asyncVideoMotionGenerator, cancellationToken);
        return true;
    }

    private async Task<bool> CompleteVideoGenerationFromProviderPayloadAsync(
        TemplateGenerationJob job,
        JsonElement payload,
        string? requestId,
        double? inferenceTimeSeconds,
        CancellationToken cancellationToken)
    {
        if (videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return false;
        }

        var completed = asyncVideoMotionGenerator.Complete(payload, requestId, inferenceTimeSeconds);
        if (completed.IsFailure)
        {
            await MarkFailedAsync(job, completed.Error, cancellationToken);
            return false;
        }

        return await StageVideoImportAsync(job, completed.Value, cancellationToken);
    }

    private async Task<bool> StageImageImportAsync(
        TemplateGenerationJob job,
        ImageGenerationResult generated,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.ProviderStatus = "COMPLETED";
        job.PreprocessingProviderRequestId = generated.ProviderRequestId ?? job.PreprocessingProviderRequestId;
        job.PreprocessingInferenceTimeSeconds = generated.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc = now;
        job.ProviderCompletedAtUtc ??= now;
        job.ProviderResultUrl = generated.ImageUrl;
        job.ImportStartedAtUtc = null;
        ResetMediaImportState(job);
        job.NextAttemptEarliestAtUtc = null;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> StageVideoImportAsync(
        TemplateGenerationJob job,
        VideoMotionGenerationResult generated,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.ProviderStatus = "COMPLETED";
        job.MotionProviderRequestId = generated.ProviderRequestId ?? job.MotionProviderRequestId;
        job.MotionInferenceTimeSeconds = generated.InferenceTimeSeconds;
        job.MotionGenerationCompletedAtUtc = now;
        job.ProviderCompletedAtUtc ??= now;
        job.ProviderResultUrl = generated.VideoUrl;
        job.ImportStartedAtUtc = null;
        ResetMediaImportState(job);
        job.NextAttemptEarliestAtUtc = null;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> ImportStagedProviderMediaAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(job.ProviderResultUrl))
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        switch (job.CurrentProviderStage)
        {
            case ProviderStageImageGeneration:
                await ImportImageResultAsync(
                    job,
                    new ImageGenerationResult(
                        job.ProviderResultUrl,
                        job.PreprocessingProviderRequestId,
                        job.PreprocessingInferenceTimeSeconds),
                    cancellationToken);
                return true;
            case ProviderStageVideoGeneration:
                await ImportVideoResultAsync(
                    job,
                    new VideoMotionGenerationResult(
                        job.ProviderResultUrl,
                        job.MotionProviderRequestId,
                        job.MotionInferenceTimeSeconds),
                    cancellationToken);
                return true;
            default:
                return await MarkUnknownProviderStageFailedAsync(job, cancellationToken);
        }
    }

    private async Task<FalQueueStatusResult?> PollProviderStatusAsync(
        TemplateGenerationJob job,
        string? statusUrl,
        string? model,
        CancellationToken cancellationToken,
        bool durableAttempt)
    {
        if (!Uri.TryCreate(statusUrl, UriKind.Absolute, out var statusUri) || string.IsNullOrWhiteSpace(model))
        {
            await DeferProviderReadForManualReconciliationAsync(
                job,
                TemplatesErrors.AiProviderFailed,
                cancellationToken,
                durableAttempt);
            return null;
        }

        var statusResult = await falQueueClient!.GetStatusAsync(statusUri, model, cancellationToken);
        if (statusResult.IsFailure)
        {
            if (IsProviderTransientFailure(statusResult.Error))
            {
                await DeferProviderPollAfterTransientFailureAsync(job, statusResult.Error, cancellationToken);
            }
            else
            {
                await DeferProviderReadForManualReconciliationAsync(
                    job,
                    statusResult.Error,
                    cancellationToken,
                    durableAttempt);
            }

            return null;
        }

        var now = DateTime.UtcNow;
        var status = statusResult.Value.Status;
        job.ProviderStatus = status;
        job.ProviderStatusCheckedAtUtc = now;
        job.UpdatedAtUtc = now;

        if (string.Equals(status, "IN_QUEUE", StringComparison.OrdinalIgnoreCase))
        {
            job.Status = TemplateGenerationStatus.ProviderQueued;
            ScheduleNextProviderPoll(job, now, inProgress: false);
            TemplateGenerationMetrics.RecordFalProviderQueueWait(
                TemplateGenerationQueue.ResolveMediaType(job),
                job.CurrentProviderStage ?? "unknown",
                model,
                job.ProviderSubmittedAtUtc);
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            return statusResult.Value;
        }

        if (string.Equals(status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase))
        {
            job.Status = TemplateGenerationStatus.ProviderProcessing;
            ScheduleNextProviderPoll(job, now, inProgress: true);
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            await PublishStatusChangedAsync(job, cancellationToken);
            return statusResult.Value;
        }

        if (string.Equals(status, "COMPLETED", StringComparison.OrdinalIgnoreCase)
            && string.IsNullOrWhiteSpace(statusResult.Value.Error))
        {
            job.NextAttemptEarliestAtUtc = null;
            return statusResult.Value;
        }

        if (IsExplicitProviderTerminalFailure(status))
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
        }
        else
        {
            await DeferProviderReadForManualReconciliationAsync(
                job,
                TemplatesErrors.AiProviderFailed,
                cancellationToken,
                durableAttempt);
        }

        return null;
    }

    private async Task<JsonDocument?> FetchProviderResponseAsync(
        TemplateGenerationJob job,
        string? responseUrl,
        string? model,
        CancellationToken cancellationToken,
        bool durableAttempt)
    {
        if (!Uri.TryCreate(responseUrl, UriKind.Absolute, out var responseUri) || string.IsNullOrWhiteSpace(model))
        {
            await DeferProviderReadForManualReconciliationAsync(
                job,
                TemplatesErrors.AiProviderFailed,
                cancellationToken,
                durableAttempt);
            return null;
        }

        var response = await falQueueClient!.GetResponseAsync(responseUri, model, cancellationToken);
        if (response.IsFailure)
        {
            if (IsProviderTransientFailure(response.Error))
            {
                await DeferProviderPollAfterTransientFailureAsync(job, response.Error, cancellationToken);
            }
            else
            {
                await DeferProviderReadForManualReconciliationAsync(
                    job,
                    response.Error,
                    cancellationToken,
                    durableAttempt);
            }

            return null;
        }

        return response.Value;
    }

    private static void ScheduleNextProviderPoll(
        TemplateGenerationJob job,
        DateTime now,
        bool inProgress)
    {
        var elapsedSeconds = Math.Max(0, (now - (job.ProviderSubmittedAtUtc ?? now)).TotalSeconds);
        var baseDelaySeconds = inProgress
            ? Math.Min(30, 10 + (int)(elapsedSeconds / 60) * 5)
            : Math.Min(30, 5 + (int)(elapsedSeconds / 30) * 5);
        var jitterFactor = 0.9 + Random.Shared.NextDouble() * 0.2;
        job.NextAttemptEarliestAtUtc = now.AddSeconds(Math.Max(1, baseDelaySeconds * jitterFactor));
    }

    private async Task DeferProviderPollAfterTransientFailureAsync(
        TemplateGenerationJob job,
        Error error,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var backoffExponent = Math.Clamp(job.AttemptCount - 1, 0, 5);
        var delaySeconds = options.ProviderTransientRetryBaseDelaySeconds * (1 << backoffExponent);
        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(error.Code)
            ?? TemplatesErrors.AiProviderTransientFailure.Code;
        var safeErrorMessage = AdminFailureMessageSanitizer.Sanitize(error.Message);

        job.NextAttemptEarliestAtUtc = now.AddSeconds(delaySeconds);
        job.ProviderStatusCheckedAtUtc = now;
        job.LastErrorCode = safeErrorCode;
        job.LastErrorMessage = safeErrorMessage;
        job.UpdatedAtUtc = now;

        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
        TemplateGenerationMetrics.RecordRetryAttempt(job, "provider_poll_transient");
        logger.LogWarning(
            "Template generation provider polling deferred after transient failure. GenerationIdHash={GenerationIdHash} ErrorCode={ErrorCode} AttemptCount={AttemptCount} RetryDelaySeconds={RetryDelaySeconds}",
            TemplateLogSanitizer.SafeId(job.Id),
            safeErrorCode,
            job.AttemptCount,
            delaySeconds);
    }

    private async Task DeferProviderReadForManualReconciliationAsync(
        TemplateGenerationJob job,
        Error error,
        CancellationToken cancellationToken,
        bool durableAttempt)
    {
        var now = DateTime.UtcNow;
        if (durableAttempt)
        {
            job.Status = TemplateGenerationStatus.SubmittingToProvider;
        }

        job.ProviderStatus = ProviderReconciliationRequiredStatus;
        job.ProviderStatusCheckedAtUtc = now;
        job.NextAttemptEarliestAtUtc = now.AddMinutes(5);
        job.LastErrorCode = ProviderReadReconciliationRequiredCode;
        job.LastErrorMessage = AdminFailureMessageSanitizer.Sanitize(error.Message);
        job.UpdatedAtUtc = now;

        await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
        logger.LogWarning(
            "Template generation provider read requires durable reconciliation. GenerationIdHash={GenerationIdHash} ProviderStage={ProviderStage} ErrorCode={ErrorCode}",
            TemplateLogSanitizer.SafeId(job.Id),
            job.CurrentProviderStage,
            AdminFailureMessageSanitizer.SanitizeCode(error.Code));
    }

    private static bool IsProviderTransientFailure(Error error)
    {
        return string.Equals(error.Code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal);
    }

    private static bool IsExplicitProviderTerminalFailure(string? status) =>
        string.Equals(status, "ERROR", StringComparison.OrdinalIgnoreCase)
        || string.Equals(status, "FAILED", StringComparison.OrdinalIgnoreCase)
        || string.Equals(status, "CANCELLED", StringComparison.OrdinalIgnoreCase);

    private async Task<bool> ImportImageResultAsync(
        TemplateGenerationJob job,
        ImageGenerationResult generated,
        CancellationToken cancellationToken)
    {
        if (job.MediaImportAttemptCount >= options.MediaImportMaxAttempts)
        {
            await MarkFailedAsync(job, TemplatesErrors.GeneratedMediaImportFailed, cancellationToken);
            return true;
        }

        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.PreprocessingProviderRequestId = generated.ProviderRequestId ?? job.PreprocessingProviderRequestId;
        job.PreprocessingInferenceTimeSeconds ??= generated.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc ??= now;
        job.ProviderCompletedAtUtc ??= now;
        job.ImportStartedAtUtc ??= now;
        job.MediaImportAttemptCount++;
        job.MediaImportNextAttemptAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        var mediaRecord = await FindGenerationOutputMediaRecordAsync(job, TemplateType.Image, cancellationToken);
        var storedOutput = RestoreOriginalMediaCheckpoint(mediaRecord);
        if (storedOutput is null)
        {
            var imported = await generatedMediaImporter.ImportImageAsync(generated.ImageUrl, job.Id, cancellationToken);
            if (imported.IsFailure)
            {
                await DeferOrFailMediaImportAsync(job, imported.Error, cancellationToken);
                return true;
            }

            storedOutput = imported.Value;
            job.OriginalImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Image,
                preview: null,
                watermarkedPreview: null,
                cancellationToken,
                attachAsCompletedResult: false);
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }
        else
        {
            job.OriginalImportedAtUtc ??= DateTime.UtcNow;
        }

        var watermarkedOutput = RestoreWatermarkedMediaCheckpoint(mediaRecord, storedOutput);
        if (job.WatermarkImportedAtUtc is null)
        {
            watermarkedOutput ??= await ApplyWatermarkAsync(job, storedOutput, TemplateType.Image, cancellationToken);
            job.WatermarkImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Image,
                preview: null,
                watermarkedPreview: null,
                cancellationToken,
                attachAsCompletedResult: false);
            job.WatermarkedResultUrl = null;
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }

        var resultPreview = RestorePreviewMediaCheckpoint(
            mediaRecord?.PreviewUrl,
            $"generation-{job.Id:N}-result-preview.webp");
        var watermarkedPreview = RestorePreviewMediaCheckpoint(
            mediaRecord?.WatermarkedPreviewUrl,
            $"generation-{job.Id:N}-watermarked-result-preview.webp");
        if (job.PreviewImportedAtUtc is null)
        {
            if (resultPreview is null)
            {
                resultPreview = await imagePreviewGenerator.CreatePreviewAsync(
                    storedOutput,
                    $"generation-{job.Id:N}-result-preview.webp",
                    BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview"),
                    cancellationToken);
                if (resultPreview is not null)
                {
                    mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                        job,
                        storedOutput,
                        TemplateType.Image,
                        resultPreview,
                        watermarkedPreview,
                        cancellationToken,
                        attachAsCompletedResult: false);
                    if (!await SaveClaimedChangesAsync(job, cancellationToken))
                    {
                        return false;
                    }
                }
            }

            if (watermarkedOutput is not null && watermarkedPreview is null)
            {
                watermarkedPreview = await imagePreviewGenerator.CreatePreviewAsync(
                    watermarkedOutput,
                    $"generation-{job.Id:N}-watermarked-result-preview.webp",
                    BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked"),
                    cancellationToken);
            }

            job.PreviewImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Image,
                resultPreview,
                watermarkedPreview,
                cancellationToken,
                attachAsCompletedResult: false);
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }

        job.WatermarkedResultUrl = watermarkedOutput?.StorageKey;
        await CompleteImportedMediaAsync(job, storedOutput, TemplateType.Image, resultPreview, watermarkedPreview);
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        await CompleteGenerationSideEffectsAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> ImportVideoResultAsync(
        TemplateGenerationJob job,
        VideoMotionGenerationResult generated,
        CancellationToken cancellationToken)
    {
        if (job.MediaImportAttemptCount >= options.MediaImportMaxAttempts)
        {
            await MarkFailedAsync(job, TemplatesErrors.GeneratedMediaImportFailed, cancellationToken);
            return true;
        }

        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.MotionProviderRequestId = generated.ProviderRequestId ?? job.MotionProviderRequestId;
        job.MotionInferenceTimeSeconds ??= generated.InferenceTimeSeconds;
        job.MotionGenerationCompletedAtUtc ??= now;
        job.ProviderCompletedAtUtc ??= now;
        job.ImportStartedAtUtc ??= now;
        job.MediaImportAttemptCount++;
        job.MediaImportNextAttemptAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        var mediaRecord = await FindGenerationOutputMediaRecordAsync(job, TemplateType.Video, cancellationToken);
        var storedOutput = RestoreOriginalMediaCheckpoint(mediaRecord);
        if (storedOutput is null)
        {
            var imported = await generatedMediaImporter.ImportVideoAsync(generated.VideoUrl, job.Id, cancellationToken);
            if (imported.IsFailure)
            {
                await DeferOrFailMediaImportAsync(job, imported.Error, cancellationToken);
                return true;
            }

            storedOutput = imported.Value;
            job.OriginalImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Video,
                preview: null,
                watermarkedPreview: null,
                cancellationToken,
                attachAsCompletedResult: false);
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }
        else
        {
            job.OriginalImportedAtUtc ??= DateTime.UtcNow;
        }

        var durationResult = await mediaMetadataReader.GetVideoDurationSecondsAsync(storedOutput, cancellationToken);
        if (durationResult.IsFailure)
        {
            logger.LogWarning(
                "Generated template media duration could not be determined. GenerationIdHash={GenerationIdHash}",
                TemplateLogSanitizer.SafeId(job.Id));
        }
        else
        {
            job.OutputVideoDurationSeconds = durationResult.Value;
            job.MotionProviderCostUsd = FalModelPricing.TryCalculateMotionCostUsd(job.UsedKlingModel, durationResult.Value);
        }

        var watermarkedOutput = RestoreWatermarkedMediaCheckpoint(mediaRecord, storedOutput);
        if (job.WatermarkImportedAtUtc is null)
        {
            watermarkedOutput ??= await ApplyWatermarkAsync(job, storedOutput, TemplateType.Video, cancellationToken);
            job.WatermarkImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Video,
                preview: null,
                watermarkedPreview: null,
                cancellationToken,
                attachAsCompletedResult: false);
            job.WatermarkedResultUrl = null;
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }

        var resultPreview = RestorePreviewMediaCheckpoint(
            mediaRecord?.PreviewUrl,
            $"generation-{job.Id:N}-result-preview.jpg");
        var watermarkedPreview = RestorePreviewMediaCheckpoint(
            mediaRecord?.WatermarkedPreviewUrl,
            $"generation-{job.Id:N}-watermarked-result-preview.jpg");
        if (job.PreviewImportedAtUtc is null)
        {
            if (resultPreview is null)
            {
                resultPreview = await videoThumbnailGenerator.CreateThumbnailAsync(
                    storedOutput,
                    job.Id,
                    $"generation-{job.Id:N}-result-preview.jpg",
                    BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview", "jpg"),
                    cancellationToken);
                if (resultPreview is not null)
                {
                    mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                        job,
                        storedOutput,
                        TemplateType.Video,
                        resultPreview,
                        watermarkedPreview,
                        cancellationToken,
                        attachAsCompletedResult: false);
                    if (!await SaveClaimedChangesAsync(job, cancellationToken))
                    {
                        return false;
                    }
                }
            }

            if (watermarkedOutput is not null && watermarkedPreview is null)
            {
                watermarkedPreview = await videoThumbnailGenerator.CreateThumbnailAsync(
                    watermarkedOutput,
                    job.Id,
                    $"generation-{job.Id:N}-watermarked-result-preview.jpg",
                    BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked", "jpg"),
                    cancellationToken);
            }

            job.PreviewImportedAtUtc = DateTime.UtcNow;
            mediaRecord = await RegisterGenerationOutputMediaRecordAsync(
                job,
                storedOutput,
                TemplateType.Video,
                resultPreview,
                watermarkedPreview,
                cancellationToken,
                attachAsCompletedResult: false);
            if (!await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return false;
            }
        }

        job.WatermarkedResultUrl = watermarkedOutput?.StorageKey;
        await CompleteImportedMediaAsync(job, storedOutput, TemplateType.Video, resultPreview, watermarkedPreview);
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        await CompleteGenerationSideEffectsAsync(job, cancellationToken);
        return true;
    }

    private async Task CompleteImportedMediaAsync(
        TemplateGenerationJob job,
        StoredMediaResponse storedOutput,
        TemplateType mediaType,
        StoredMediaResponse? resultPreview,
        StoredMediaResponse? watermarkedPreview)
    {
        job.ResultUrl = storedOutput.StorageKey;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        job.OriginalImportedAtUtc ??= job.MediaImportCompletedAtUtc;
        job.WatermarkImportedAtUtc ??= job.MediaImportCompletedAtUtc;
        job.PreviewImportedAtUtc ??= job.MediaImportCompletedAtUtc;
        job.ProviderResultUrl = null;
        job.NextAttemptEarliestAtUtc = null;
        job.MediaImportNextAttemptAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        await RegisterGenerationOutputMediaRecordAsync(job, storedOutput, mediaType, resultPreview, watermarkedPreview);
        job.Status = TemplateGenerationStatus.Completed;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
    }

    private async Task CompleteGenerationSideEffectsAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationCompleted);
        if (job.GenerationMode == TemplateGenerationMode.Similar)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarCompleted);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await SyncGamificationAsync(job, cancellationToken);
        await PublishStatusChangedAsync(job, cancellationToken);
    }

    private async Task DeferOrFailMediaImportAsync(
        TemplateGenerationJob job,
        Error error,
        CancellationToken cancellationToken)
    {
        if (job.MediaImportAttemptCount >= options.MediaImportMaxAttempts)
        {
            await MarkFailedAsync(job, error, cancellationToken);
            return;
        }

        var now = DateTime.UtcNow;
        var delay = GetMediaImportRetryDelay(job.MediaImportAttemptCount);
        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(error.Code)
            ?? TemplatesErrors.GeneratedMediaImportFailed.Code;
        var safeErrorMessage = AdminFailureMessageSanitizer.Sanitize(error.Message);
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.ResultUrl = null;
        job.ResultMediaAssetId = null;
        job.WatermarkedResultUrl = null;
        job.MediaImportNextAttemptAtUtc = now.Add(delay);
        job.LastErrorCode = safeErrorCode;
        job.LastErrorMessage = safeErrorMessage;
        job.UpdatedAtUtc = now;

        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        TemplateGenerationMetrics.RecordRetryAttempt(job, "media_import");
        logger.LogWarning(
            "Template generation media import deferred. GenerationIdHash={GenerationIdHash} ErrorCode={ErrorCode} MediaImportAttemptCount={MediaImportAttemptCount} RetryDelaySeconds={RetryDelaySeconds}",
            TemplateLogSanitizer.SafeId(job.Id),
            safeErrorCode,
            job.MediaImportAttemptCount,
            delay.TotalSeconds);
    }

    private TimeSpan GetMediaImportRetryDelay(int attemptCount)
    {
        const int maxRetryDelaySeconds = 15 * 60;
        var exponent = Math.Clamp(attemptCount - 1, 0, 10);
        var delaySeconds = Math.Min(
            maxRetryDelaySeconds,
            (long)options.MediaImportRetryBaseDelaySeconds * (1L << exponent));
        return TimeSpan.FromSeconds(Math.Max(1, delaySeconds));
    }

    private static void ResetMediaImportState(TemplateGenerationJob job)
    {
        job.MediaImportAttemptCount = 0;
        job.MediaImportNextAttemptAtUtc = null;
        job.OriginalImportedAtUtc = null;
        job.WatermarkImportedAtUtc = null;
        job.PreviewImportedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.ResultMediaAssetId = null;
        job.IsWatermarkRequired = false;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
    }

    private async Task<bool> MarkUnknownProviderStageFailedAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
        return true;
    }

    private static bool IsImportPendingDuplicateWebhook(TemplateGenerationJob job, string requestId)
    {
        return job.Status == TemplateGenerationStatus.ImportingMedia
            && job.ProviderCompletedAtUtc is not null
            && IsCurrentProviderRequest(job, requestId);
    }

    private static bool IsVideoPreprocessingReadyForMotionSubmit(TemplateGenerationJob job)
    {
        return job.Status == TemplateGenerationStatus.ProviderQueued
            && string.Equals(job.CurrentProviderStage, ProviderStageVideoPreprocessing, StringComparison.Ordinal)
            && job.ProviderCompletedAtUtc is not null
            && !string.IsNullOrWhiteSpace(job.NormalizedImageUrl)
            && string.IsNullOrWhiteSpace(job.MotionProviderRequestId);
    }

    private static bool IsCurrentProviderRequest(TemplateGenerationJob job, string requestId)
    {
        return (string.Equals(job.PreprocessingProviderRequestId, requestId, StringComparison.Ordinal)
                && (string.Equals(job.CurrentProviderStage, ProviderStageImageGeneration, StringComparison.Ordinal)
                    || string.Equals(job.CurrentProviderStage, ProviderStageVideoPreprocessing, StringComparison.Ordinal)))
            || (string.Equals(job.MotionProviderRequestId, requestId, StringComparison.Ordinal)
                && string.Equals(job.CurrentProviderStage, ProviderStageVideoGeneration, StringComparison.Ordinal));
    }
}
