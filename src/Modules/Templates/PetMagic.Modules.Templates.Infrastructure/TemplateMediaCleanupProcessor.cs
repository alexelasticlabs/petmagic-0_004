using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateMediaCleanupProcessor(
    TemplatesDbContext dbContext,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    ILogger<TemplateMediaCleanupProcessor> logger)
{
    public async Task<bool> CleanupNextExpiredTemporaryUploadAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.MediaCleanupRetryDelayMilliseconds);

        var record = await dbContext.TemplateMediaRecords
            .Where(x =>
                (x.LifecycleState == TemplateMediaLifecycleState.Temporary
                    && x.ExpiresAtUtc != null
                    && x.ExpiresAtUtc <= now)
                || (x.LifecycleState == TemplateMediaLifecycleState.CleanupFailed
                    && x.TemplateId == null
                    && x.GenerationJobId == null
                    && x.ExpiresAtUtc != null
                    && x.ExpiresAtUtc <= now
                    && (x.LastCleanupAttemptAtUtc == null || x.LastCleanupAttemptAtUtc <= retryThreshold)))
            .OrderBy(x => x.ExpiresAtUtc ?? x.UploadedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (record is null)
        {
            return false;
        }

        var deleteResult = await mediaStorage.DeleteAsync(record.Url, cancellationToken);
        if (deleteResult.IsFailure)
        {
            record.LifecycleState = TemplateMediaLifecycleState.CleanupFailed;
            record.LastCleanupAttemptAtUtc = now;
            record.FailureCode = AdminFailureMessageSanitizer.SanitizeCode(deleteResult.Error.Code);
            record.FailureMessage = AdminFailureMessageSanitizer.Sanitize(deleteResult.Error.Message);
            await dbContext.SaveChangesAsync(cancellationToken);
            logger.LogWarning(
                "Temporary upload cleanup failed. MediaRecordIdHash={MediaRecordIdHash} ErrorCode={ErrorCode}",
                TemplateLogSanitizer.SafeId(record.Id),
                record.FailureCode);
            return true;
        }

        record.LifecycleState = TemplateMediaLifecycleState.Deleted;
        record.IsDeleted = true;
        record.DeletedAtUtc = now;
        record.LastCleanupAttemptAtUtc = now;
        record.FailureCode = null;
        record.FailureMessage = null;
        record.TemplateId = null;
        record.GenerationJobId = null;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool> CleanupNextExpiredGenerationMediaAsync(CancellationToken cancellationToken)
    {
        if (!options.CleanupExpiredGenerationMediaWhileRefundPending || options.GenerationRetentionDaysAfterCompletion < 0)
        {
            return false;
        }

        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.MediaCleanupRetryDelayMilliseconds);
        var cutoff = now.AddDays(-options.GenerationRetentionDaysAfterCompletion);

        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.CompletedAtUtc != null
                && x.CompletedAtUtc <= cutoff
                && x.UserMediaDeletedAtUtc == null
                && (x.LastUserMediaCleanupAttemptAtUtc == null || x.LastUserMediaCleanupAttemptAtUtc <= retryThreshold))
            .OrderBy(x => x.CompletedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        var mediaRecords = await dbContext.TemplateMediaRecords
            .Where(record => record.GenerationJobId == job.Id || record.GenerationId == job.Id)
            .ToArrayAsync(cancellationToken);

        var urls = new[]
            {
                job.SourceImageUrl,
                job.NormalizedImageUrl,
                job.ResultUrl,
                job.WatermarkedResultUrl
            }
            .Concat(mediaRecords.SelectMany(record => new[]
            {
                record.StoragePath,
                record.WatermarkedStoragePath,
                record.PreviewUrl,
                record.WatermarkedPreviewUrl
            }))
            .Where(url => !string.IsNullOrWhiteSpace(url))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        foreach (var url in urls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(url, cancellationToken);
            if (deleteResult.IsFailure)
            {
                var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(deleteResult.Error.Code);
                job.LastUserMediaCleanupAttemptAtUtc = now;
                job.UserMediaCleanupFailureCode = safeErrorCode;
                await dbContext.SaveChangesAsync(cancellationToken);
                logger.LogWarning(
                    "Generation media cleanup failed. GenerationIdHash={GenerationIdHash} ErrorCode={ErrorCode}",
                    TemplateLogSanitizer.SafeId(job.Id),
                    safeErrorCode);
                return true;
            }
        }

        job.SourceImageUrl = string.Empty;
        job.NormalizedImageUrl = null;
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.UserMediaDeletedAtUtc = now;
        job.LastUserMediaCleanupAttemptAtUtc = now;
        job.UserMediaCleanupFailureCode = null;
        foreach (var record in mediaRecords)
        {
            record.IsDeleted = true;
            record.DeletedAtUtc = now;
            record.LifecycleState = TemplateMediaLifecycleState.Deleted;
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public Task<bool> CleanupNextExpiredMetadataTempFileAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(
            TemplateMediaTempFiles.CleanupNextExpiredAsync(
                TimeSpan.FromHours(options.MetadataTempRetentionHours),
                logger));
    }
}
