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

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private const string ProviderStageImageGeneration = "image_generation";
    private const string ProviderStageVideoPreprocessing = "video_preprocessing";
    private const string ProviderStageVideoGeneration = "video_generation";

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
            or TemplateGenerationStatus.Cancelled
            or TemplateGenerationStatus.CancellationRequested)
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

        var submission = await asyncImageGenerator.SubmitAsync(
            sourceImageUrl,
            prompt,
            model,
            job.GenerationSeed,
            cancellationToken);
        if (submission.IsFailure)
        {
            await HandleProviderSubmitFailureAsync(job, submission.Error, cancellationToken);
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

        var submission = await asyncImagePreprocessor.SubmitAsync(
            sourceImageUrl,
            model,
            prompt,
            cancellationToken);
        if (submission.IsFailure)
        {
            await HandleProviderSubmitFailureAsync(job, submission.Error, cancellationToken);
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

        var submission = await asyncVideoMotionGenerator.SubmitAsync(
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
            await HandleProviderSubmitFailureAsync(job, submission.Error, cancellationToken);
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
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.UpdatedAtUtc = submittedAt;
    }

    private async Task<bool> AdvanceNextProviderJobAsync(CancellationToken cancellationToken)
    {
        var job = await ClaimNextProviderJobAsync(
            includePollingJobs: falQueueClient is not null,
            cancellationToken);
        if (job is null)
        {
            return false;
        }

        try
        {
            if (job.Status == TemplateGenerationStatus.ImportingMedia)
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
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
            return true;
        }
    }

    private async Task<TemplateGenerationJob?> ClaimNextProviderJobAsync(
        bool includePollingJobs,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var staleThreshold = now.AddMilliseconds(-options.JobLockTimeoutMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => ((includePollingJobs
                        && (x.Status == TemplateGenerationStatus.ProviderQueued
                            || x.Status == TemplateGenerationStatus.ProviderProcessing))
                    || (x.Status == TemplateGenerationStatus.ProviderQueued
                        && x.CurrentProviderStage == ProviderStageVideoPreprocessing
                        && x.ProviderCompletedAtUtc != null
                        && x.NormalizedImageUrl != null
                        && x.MotionProviderRequestId == null)
                    || x.Status == TemplateGenerationStatus.ImportingMedia)
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
                && (x.NextAttemptEarliestAtUtc == null || x.NextAttemptEarliestAtUtc <= now)
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

    private async Task<bool> PollImageGenerationAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        if (imageGenerator is not IAsyncImageGenerationQueue asyncImageGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(job, job.PreprocessingProviderStatusUrl, job.UsedPreprocessingModel, cancellationToken);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(job, job.PreprocessingProviderResponseUrl, job.UsedPreprocessingModel, cancellationToken);
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

    private async Task<bool> PollVideoPreprocessingAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        if (imagePreprocessor is not IAsyncImagePreprocessingQueue asyncImagePreprocessor
            || videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(job, job.PreprocessingProviderStatusUrl, job.UsedPreprocessingModel, cancellationToken);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(job, job.PreprocessingProviderResponseUrl, job.UsedPreprocessingModel, cancellationToken);
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

    private async Task<bool> PollVideoGenerationAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        if (videoMotionGenerator is not IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator)
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
            return true;
        }

        var status = await PollProviderStatusAsync(job, job.MotionProviderStatusUrl, job.UsedKlingModel, cancellationToken);
        if (status is null || !string.Equals(status.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var response = await FetchProviderResponseAsync(job, job.MotionProviderResponseUrl, job.UsedKlingModel, cancellationToken);
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
        CancellationToken cancellationToken)
    {
        if (!Uri.TryCreate(statusUrl, UriKind.Absolute, out var statusUri) || string.IsNullOrWhiteSpace(model))
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
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
                await MarkFailedAsync(job, statusResult.Error, cancellationToken);
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
            await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true);
            await PublishStatusChangedAsync(job, cancellationToken);
            return statusResult.Value;
        }

        if (string.Equals(status, "COMPLETED", StringComparison.OrdinalIgnoreCase)
            && string.IsNullOrWhiteSpace(statusResult.Value.Error))
        {
            return statusResult.Value;
        }

        await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
        return null;
    }

    private async Task<JsonDocument?> FetchProviderResponseAsync(
        TemplateGenerationJob job,
        string? responseUrl,
        string? model,
        CancellationToken cancellationToken)
    {
        if (!Uri.TryCreate(responseUrl, UriKind.Absolute, out var responseUri) || string.IsNullOrWhiteSpace(model))
        {
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, cancellationToken);
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
                await MarkFailedAsync(job, response.Error, cancellationToken);
            }

            return null;
        }

        return response.Value;
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

    private static bool IsProviderTransientFailure(Error error)
    {
        return string.Equals(error.Code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal);
    }

    private async Task<bool> ImportImageResultAsync(
        TemplateGenerationJob job,
        ImageGenerationResult generated,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.PreprocessingProviderRequestId = generated.ProviderRequestId ?? job.PreprocessingProviderRequestId;
        job.PreprocessingInferenceTimeSeconds ??= generated.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc ??= now;
        job.ProviderCompletedAtUtc ??= now;
        job.ImportStartedAtUtc ??= now;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        var storedOutput = await generatedMediaImporter.ImportImageAsync(generated.ImageUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return true;
        }

        var watermarkedOutput = await ApplyWatermarkAsync(job, storedOutput.Value, TemplateType.Image, cancellationToken);
        var resultPreview = await imagePreviewGenerator.CreatePreviewAsync(
            storedOutput.Value,
            $"generation-{job.Id:N}-result-preview.webp",
            BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview"),
            cancellationToken);
        var watermarkedPreview = watermarkedOutput is null
            ? null
            : await imagePreviewGenerator.CreatePreviewAsync(
                watermarkedOutput,
                $"generation-{job.Id:N}-watermarked-result-preview.webp",
                BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked"),
                cancellationToken);
        await CompleteImportedMediaAsync(job, storedOutput.Value, TemplateType.Image, resultPreview, watermarkedPreview);
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
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.ImportingMedia;
        job.MotionProviderRequestId = generated.ProviderRequestId ?? job.MotionProviderRequestId;
        job.MotionInferenceTimeSeconds ??= generated.InferenceTimeSeconds;
        job.MotionGenerationCompletedAtUtc ??= now;
        job.ProviderCompletedAtUtc ??= now;
        job.ImportStartedAtUtc ??= now;
        job.UpdatedAtUtc = now;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.VideoUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return true;
        }

        var durationResult = await mediaMetadataReader.GetVideoDurationSecondsAsync(storedOutput.Value, cancellationToken);
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

        var watermarkedOutput = await ApplyWatermarkAsync(job, storedOutput.Value, TemplateType.Video, cancellationToken);
        var resultPreview = await videoThumbnailGenerator.CreateThumbnailAsync(
            storedOutput.Value,
            job.Id,
            $"generation-{job.Id:N}-result-preview.jpg",
            BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview", "jpg"),
            cancellationToken);
        var watermarkedPreview = watermarkedOutput is null
            ? null
            : await videoThumbnailGenerator.CreateThumbnailAsync(
                watermarkedOutput,
                job.Id,
                $"generation-{job.Id:N}-watermarked-result-preview.jpg",
                BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked", "jpg"),
                cancellationToken);
        await CompleteImportedMediaAsync(job, storedOutput.Value, TemplateType.Video, resultPreview, watermarkedPreview);
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
        job.ProviderResultUrl = null;
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
