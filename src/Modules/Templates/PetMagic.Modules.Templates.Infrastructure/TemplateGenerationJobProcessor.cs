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
    IMediaStorage mediaStorage,
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
                "FailureCode" = NULL,
                "FailureMessage" = NULL
            WHERE "Id" = (
                SELECT "Id"
                FROM templates_generation_jobs
                WHERE "Status" = {0} AND "ChargedAtUtc" IS NOT NULL AND "AttemptCount" < {3}
                ORDER BY "QueuedAtUtc"
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING "Id" AS "Value";
            """,
            (int)TemplateGenerationStatus.Queued,
            (int)TemplateGenerationStatus.Processing,
            now,
            options.MaxGenerationAttempts)
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
                && x.ChargedAtUtc != null
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
                && (x.Status == TemplateGenerationStatus.Completed
                    || (x.Status == TemplateGenerationStatus.Failed
                        && (x.ChargedAtUtc == null || x.RefundedAtUtc != null))))
            .OrderBy(x => x.CompletedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        var mediaDeleted = await DeleteGenerationMediaAsync(job, cancellationToken);
        if (!mediaDeleted)
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
                && x.ChargedAtUtc != null
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
            var normalized = await imagePreprocessor.NormalizeAsync(
                job.SourceImageUrl,
                job.Template.PreprocessingModel!,
                TemplateGenerationService.ResolvePrompt(job.Template.PreprocessingPrompt, options.DefaultPreprocessingPrompt),
                cancellationToken);

            if (normalized.IsFailure)
            {
                await MarkFailedAsync(job, normalized.Error, cancellationToken);
                return;
            }

            job.NormalizedImageUrl = normalized.Value;
            job.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            var generated = await videoMotionGenerator.CreateAsync(
                normalized.Value,
                referenceMotion.Url,
                job.Template.CharacterOrientation!.Value.ToString(),
                job.Template.KeepOriginalSound ?? true,
                TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt),
                job.Template.KlingModel!,
                cancellationToken);

            if (generated.IsFailure)
            {
                await MarkFailedAsync(job, generated.Error, cancellationToken);
                return;
            }

            var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.Value, job.Id, cancellationToken);
            if (storedOutput.IsFailure)
            {
                await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
                return;
            }

            job.OutputUrl = storedOutput.Value.Url;
            job.Status = TemplateGenerationStatus.Completed;
            job.UpdatedAtUtc = DateTime.UtcNow;
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

    private async Task<bool> DeleteGenerationMediaAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var urls = new[]
            {
                job.SourceImageUrl,
                job.NormalizedImageUrl,
                job.OutputUrl
            }
            .Where(url => !string.IsNullOrWhiteSpace(url))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var url in urls)
        {
            var deleted = await mediaStorage.DeleteAsync(url, cancellationToken);
            if (deleted.IsFailure)
            {
                logger.LogWarning("Template generation media cleanup failed for job {GenerationId}: {ErrorCode}", job.Id, deleted.Error.Code);
                return false;
            }
        }

        return true;
    }
}
