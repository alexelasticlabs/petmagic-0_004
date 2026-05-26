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
            record.FailureCode = deleteResult.Error.Code;
            record.FailureMessage = deleteResult.Error.Message;
            await dbContext.SaveChangesAsync(cancellationToken);
            logger.LogWarning("Temporary upload cleanup failed for media record {MediaRecordId}: {ErrorCode}", record.Id, deleteResult.Error.Code);
            return true;
        }

        record.LifecycleState = TemplateMediaLifecycleState.Deleted;
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

        var urls = new[]
            {
                job.SourceImageUrl,
                job.NormalizedImageUrl,
                job.OutputUrl
            }
            .Where(url => !string.IsNullOrWhiteSpace(url))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        foreach (var url in urls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(url, cancellationToken);
            if (deleteResult.IsFailure)
            {
                job.LastUserMediaCleanupAttemptAtUtc = now;
                job.UserMediaCleanupFailureCode = deleteResult.Error.Code;
                await dbContext.SaveChangesAsync(cancellationToken);
                logger.LogWarning("Generation media cleanup failed for job {GenerationId}: {ErrorCode}", job.Id, deleteResult.Error.Code);
                return true;
            }
        }

        job.SourceImageUrl = string.Empty;
        job.NormalizedImageUrl = null;
        job.OutputUrl = null;
        job.UserMediaDeletedAtUtc = now;
        job.LastUserMediaCleanupAttemptAtUtc = now;
        job.UserMediaCleanupFailureCode = null;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public Task<bool> CleanupNextExpiredMetadataTempFileAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(TemplateMediaTempFiles.CleanupNextExpiredAsync(TimeSpan.FromHours(options.MetadataTempRetentionHours)));
    }
}
