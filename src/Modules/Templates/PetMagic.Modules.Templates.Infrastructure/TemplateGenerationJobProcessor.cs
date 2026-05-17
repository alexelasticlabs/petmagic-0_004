using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationJobProcessor(
    TemplatesDbContext dbContext,
    IImagePreprocessor imagePreprocessor,
    IVideoMotionGenerator videoMotionGenerator,
    IGeneratedMediaImporter generatedMediaImporter,
    IMediaMetadataReader mediaMetadataReader,
    ITemplateGenerationBilling billing,
    TemplatesOptions options,
    ILogger<TemplateGenerationJobProcessor> logger)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var job = await ClaimNextAsync(cancellationToken);

        if (job is null)
        {
            return await FailNextExhaustedQueuedJobAsync(cancellationToken);
        }

        await ProcessAsync(job, cancellationToken);
        return true;
    }

    private Task<TemplateGenerationJob?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? ClaimNextPostgresAsync(cancellationToken)
            : ClaimNextTrackedAsync(cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextPostgresAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var claimedIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE templates_generation_jobs
            SET "Status" = {1},
                "AttemptCount" = "AttemptCount" + 1,
                "LastAttemptAtUtc" = {2},
                "StartedAtUtc" = COALESCE("StartedAtUtc", {2}),
                "UpdatedAtUtc" = {2},
                "NormalizedImageUrl" = NULL,
                "OutputUrl" = NULL,
                "UsedPreprocessingModel" = NULL,
                "UsedKlingModel" = NULL,
                "PreprocessingProviderRequestId" = NULL,
                "PreprocessingInferenceTimeSeconds" = NULL,
                "MotionProviderRequestId" = NULL,
                "MotionInferenceTimeSeconds" = NULL,
                "OutputVideoDurationSeconds" = NULL,
                "MotionProviderCostUsd" = NULL,
                "PreprocessingCompletedAtUtc" = NULL,
                "MotionGenerationCompletedAtUtc" = NULL,
                "MediaImportCompletedAtUtc" = NULL,
                "FailureCode" = NULL,
                "FailureMessage" = NULL
            WHERE "Id" = (
                SELECT "Id"
                FROM templates_generation_jobs
                WHERE "Status" = {0} AND ("ChargedAtUtc" IS NOT NULL OR "UserId" = {4}) AND "AttemptCount" < {3}
                ORDER BY "QueuedAtUtc"
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING "Id" AS "Value";
            """,
            (int)TemplateGenerationStatus.Queued,
            (int)TemplateGenerationStatus.Processing,
            now,
            options.MaxGenerationAttempts,
            TemplateGenerationService.AdminTestUserId)
            .ToListAsync(cancellationToken);

        var claimedId = claimedIds.FirstOrDefault();
        if (claimedId == Guid.Empty)
        {
            return null;
        }

        return await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .SingleAsync(x => x.Id == claimedId, cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.AttemptCount < options.MaxGenerationAttempts)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return null;
        }

        MarkProcessing(job, DateTime.UtcNow);
        await dbContext.SaveChangesAsync(cancellationToken);
        return job;
    }

    private static void MarkProcessing(TemplateGenerationJob job, DateTime now)
    {
        job.Status = TemplateGenerationStatus.Processing;
        job.AttemptCount++;
        job.LastAttemptAtUtc = now;
        job.StartedAtUtc ??= now;
        job.UpdatedAtUtc = now;
        job.NormalizedImageUrl = null;
        job.OutputUrl = null;
        job.UsedPreprocessingModel = null;
        job.UsedKlingModel = null;
        job.PreprocessingProviderRequestId = null;
        job.PreprocessingInferenceTimeSeconds = null;
        job.MotionProviderRequestId = null;
        job.MotionInferenceTimeSeconds = null;
        job.OutputVideoDurationSeconds = null;
        job.MotionProviderCostUsd = null;
        job.PreprocessingCompletedAtUtc = null;
        job.MotionGenerationCompletedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.FailureCode = null;
        job.FailureMessage = null;
    }

    public async Task<bool> RetryNextRefundAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.RefundRetryDelayMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.Status == TemplateGenerationStatus.Failed
                && x.ChargedAtUtc != null
                && x.RefundedAtUtc == null
                && x.RefundAttemptCount < options.MaxRefundAttempts
                && (x.RefundLastAttemptedAtUtc == null || x.RefundLastAttemptedAtUtc <= retryThreshold))
            .OrderBy(x => x.RefundLastAttemptedAtUtc ?? x.CompletedAtUtc ?? x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        await TryRefundAsync(job, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> CleanupNextExpiredGenerationAsync(CancellationToken cancellationToken)
    {
        if (options.GenerationRetentionDaysAfterCompletion < 0)
        {
            return false;
        }

        var cutoff = DateTime.UtcNow.AddDays(-options.GenerationRetentionDaysAfterCompletion);
        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.CompletedAtUtc != null
                && x.CompletedAtUtc <= cutoff
                && x.UserMediaDeletedAtUtc != null
                && (x.Status == TemplateGenerationStatus.Completed
                    || (x.Status == TemplateGenerationStatus.Failed
                        && (x.ChargedAtUtc == null || x.RefundedAtUtc != null))))
            .OrderBy(x => x.CompletedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        dbContext.TemplateGenerationJobs.Remove(job);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<bool> FailNextExhaustedQueuedJobAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.AttemptCount >= options.MaxGenerationAttempts)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        await MarkFailedAsync(job, TemplatesErrors.GenerationAttemptsExceeded, cancellationToken);
        return true;
    }

    private async Task ProcessAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        try
        {
            var readiness = TemplateGenerationService.ValidateTemplate(job.Template);
            if (readiness is not null)
            {
                await MarkFailedAsync(job, readiness, cancellationToken);
                return;
            }

            var referenceMotion = TemplateGenerationService.GetAsset(job.Template, TemplateAssetKind.ReferenceMotion)!;
            var preprocessingModel = job.Template.PreprocessingModel!;
            var preprocessingPrompt = TemplateGenerationService.ResolvePrompt(job.Template.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
            var motionModel = job.Template.KlingModel!;
            var motionPrompt = TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt);

            job.UsedPreprocessingModel = preprocessingModel;
            job.UsedKlingModel = motionModel;

            var normalized = await imagePreprocessor.NormalizeAsync(
                job.SourceImageUrl,
                preprocessingModel,
                preprocessingPrompt,
                cancellationToken);

            if (normalized.IsFailure)
            {
                await MarkFailedAsync(job, normalized.Error, cancellationToken);
                return;
            }

            job.NormalizedImageUrl = normalized.Value.ImageUrl;
            job.PreprocessingProviderRequestId = normalized.Value.ProviderRequestId;
            job.PreprocessingInferenceTimeSeconds = normalized.Value.InferenceTimeSeconds;
            job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);

            var generated = await videoMotionGenerator.CreateAsync(
                normalized.Value.ImageUrl,
                referenceMotion.Url,
                job.Template.CharacterOrientation!.Value.ToString(),
                job.Template.KeepOriginalSound ?? true,
                motionPrompt,
                motionModel,
                cancellationToken);

            if (generated.IsFailure)
            {
                await MarkFailedAsync(job, generated.Error, cancellationToken);
                return;
            }

            job.MotionProviderRequestId = generated.Value.ProviderRequestId;
            job.MotionInferenceTimeSeconds = generated.Value.InferenceTimeSeconds;
            job.MotionGenerationCompletedAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = job.MotionGenerationCompletedAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);

            var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.Value.VideoUrl, job.Id, cancellationToken);
            if (storedOutput.IsFailure)
            {
                await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
                return;
            }

            var durationResult = await mediaMetadataReader.GetVideoDurationSecondsAsync(storedOutput.Value, cancellationToken);
            if (durationResult.IsFailure)
            {
                logger.LogWarning("Generated template media duration could not be determined for job {GenerationId}.", job.Id);
            }
            else
            {
                job.OutputVideoDurationSeconds = durationResult.Value;
                job.MotionProviderCostUsd = FalModelPricing.TryCalculateMotionCostUsd(motionModel, durationResult.Value);
            }

            job.OutputUrl = storedOutput.Value.Url;
            job.MediaImportCompletedAtUtc = DateTime.UtcNow;
            job.Status = TemplateGenerationStatus.Completed;
            job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
            job.CompletedAtUtc = job.UpdatedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Template generation job {GenerationId} failed.", job.Id);
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
        }
    }

    private async Task MarkFailedAsync(TemplateGenerationJob job, Error error, CancellationToken cancellationToken)
    {
        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            await TryRefundAsync(job, cancellationToken);
        }

        job.Status = TemplateGenerationStatus.Failed;
        job.FailureCode = error.Code;
        job.FailureMessage = error.Message;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<bool> TryRefundAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var attemptedAt = DateTime.UtcNow;
        job.RefundAttemptCount++;
        job.RefundLastAttemptedAtUtc = attemptedAt;

        var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (refund.IsSuccess)
        {
            job.RefundedAtUtc = DateTime.UtcNow;
            job.RefundLastErrorCode = null;
            return true;
        }

        job.RefundLastErrorCode = refund.Error.Code;
        logger.LogWarning("Template generation refund failed for job {GenerationId}: {ErrorCode}", job.Id, refund.Error.Code);

        if (job.RefundAttemptCount >= options.MaxRefundAttempts)
        {
            logger.LogError("Template generation refund exhausted {RefundAttemptCount} attempts for job {GenerationId}.", job.RefundAttemptCount, job.Id);
        }

        return false;
    }
}
