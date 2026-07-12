using Microsoft.Extensions.Logging;

using Microsoft.EntityFrameworkCore;

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
    private const string GamificationShareSyncFailedCode = "templates.gamification_share_sync_failed";

    public async Task<Result<RemoveGenerationWatermarkResponse>> RemoveWatermarkAsync(
        RemoveGenerationWatermarkCommand command,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == command.GenerationId && x.UserId == command.UserId, cancellationToken);

        if (job is null || job.HiddenByUserAtUtc != null)
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (job.Status != TemplateGenerationStatus.Completed || string.IsNullOrWhiteSpace(job.ResultUrl))
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.InvalidStatus);
        }

        var existing = job.WatermarkUnlocks.FirstOrDefault(x => x.UserId == command.UserId);
        if (existing is not null)
        {
            var mediaUrl = await TryCreateReadUrlAsync(
                job.ResultUrl,
                TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
                cancellationToken);
            return Result.Success(new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl));
        }

        if (command.IsPremium)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.RemovedPremium, "premium", "premium", creditsSpent: 0);
            await dbContext.SaveChangesAsync(cancellationToken);
            var mediaUrl = await TryCreateReadUrlAsync(
                job.ResultUrl,
                TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
                cancellationToken);
            return Result.Success(new RemoveGenerationWatermarkResponse(true, 0, null, mediaUrl));
        }

        if (!string.Equals(command.PaymentMethod, "credit", StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.InvalidStatus);
        }

        var cost = Math.Max(1, (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current.CostCredits);
        var spend = await billing.SpendWatermarkUnlockAsync(command.UserId, command.GenerationId, cost, cancellationToken);
        if (spend.IsFailure)
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(spend.Error);
        }

        AddWatermarkUnlock(job, TemplateWatermarkUnlockMethod.Credit, cost, command.UserId);
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.RemovedCredit, "free", "credit", cost);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            var existingResponse = await TryResolveExistingWatermarkUnlockAsync(
                command.UserId,
                command.GenerationId,
                cancellationToken);
            if (existingResponse is not null)
            {
                return Result.Success(existingResponse);
            }

            throw;
        }

        var signedUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return Result.Success(new RemoveGenerationWatermarkResponse(true, cost, spend.Value, signedUrl));
    }

    public async Task<Result<GalleryDownloadResponse>> GetDownloadAsync(
        Guid userId,
        Guid generationId,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        var access = await GetMediaAccessAsync(
            userId,
            generationId,
            isPremium,
            TemplateAnalyticsEventTypes.DownloadWatermarked,
            TemplateAnalyticsEventTypes.DownloadClean,
            cancellationToken);
        return access.IsFailure
            ? Result.Failure<GalleryDownloadResponse>(access.Error)
            : Result.Success(new GalleryDownloadResponse(
                access.Value.SignedMediaUrl,
                access.Value.ExpiresAtUtc,
                access.Value.FileName,
                access.Value.ContentType,
                access.Value.HasWatermark));
    }

    public async Task<Result<GalleryShareResponse>> GetShareAsync(
        Guid userId,
        Guid generationId,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        var result = await GetMediaAccessAsync(
            userId,
            generationId,
            isPremium,
            TemplateAnalyticsEventTypes.ShareWatermarked,
            TemplateAnalyticsEventTypes.ShareClean,
            cancellationToken);

        if (result.IsSuccess)
        {
            await QueueCreationShareGamificationAsync(userId, generationId, cancellationToken);
        }

        return result.IsFailure
            ? Result.Failure<GalleryShareResponse>(result.Error)
            : BuildGalleryShareResponse(userId, generationId, result.Value);
    }

    public async Task<bool> ProcessNextPendingGamificationShareAsync(CancellationToken cancellationToken)
    {
        if (gamificationService is null)
        {
            return false;
        }

        var now = DateTime.UtcNow;
        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.GamificationShareRequestedAtUtc != null
                && x.GamificationShareProcessedAtUtc == null
                && (x.GamificationShareNextAttemptAtUtc == null || x.GamificationShareNextAttemptAtUtc <= now))
            .OrderBy(x => x.GamificationShareNextAttemptAtUtc)
            .ThenBy(x => x.GamificationShareRequestedAtUtc)
            .ThenBy(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (job is null)
        {
            return false;
        }

        await SyncCreationShareGamificationAsync(job, cancellationToken);
        return true;
    }

    private async Task QueueCreationShareGamificationAsync(
        Guid userId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(
                x => x.Id == generationId && x.UserId == userId,
                cancellationToken);
        if (job is null || job.GamificationShareProcessedAtUtc is not null)
        {
            return;
        }

        if (job.GamificationShareRequestedAtUtc is null)
        {
            job.GamificationShareRequestedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        if (gamificationService is not null
            && (job.GamificationShareNextAttemptAtUtc is null
                || job.GamificationShareNextAttemptAtUtc <= DateTime.UtcNow))
        {
            await SyncCreationShareGamificationAsync(job, cancellationToken);
        }
    }

    private async Task SyncCreationShareGamificationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (job.GamificationShareProcessedAtUtc is not null || gamificationService is null)
        {
            return;
        }

        var succeeded = false;
        try
        {
            await gamificationService.RecordCreationSharedAsync(
                job.Id,
                job.UserId,
                job.GamificationShareRequestedAtUtc ?? DateTime.UtcNow,
                cancellationToken);
            succeeded = true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Failed to record shared creation gamification progress. UserIdHash={UserIdHash} GenerationIdHash={GenerationIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.UserId),
                TemplateLogSanitizer.SafeId(job.Id),
                SafeLogValues.ExceptionType(ex));
        }

        var now = DateTime.UtcNow;
        if (succeeded)
        {
            job.GamificationShareProcessedAtUtc = now;
            job.GamificationShareNextAttemptAtUtc = null;
            job.GamificationShareLastErrorCode = null;
        }
        else
        {
            job.GamificationShareAttemptCount += 1;
            job.GamificationShareNextAttemptAtUtc = now.Add(
                GetGamificationShareRetryDelay(job.GamificationShareAttemptCount));
            job.GamificationShareLastErrorCode = GamificationShareSyncFailedCode;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static TimeSpan GetGamificationShareRetryDelay(int attemptCount)
    {
        var exponent = Math.Min(Math.Max(0, attemptCount - 1), 6);
        return TimeSpan.FromSeconds(Math.Min(300, 5 * (1 << exponent)));
    }

    private Result<GalleryShareResponse> BuildGalleryShareResponse(
        Guid userId,
        Guid generationId,
        GalleryMediaAccess access)
    {
        var shareToken = CreateGenerationShareToken(userId, generationId, cleanAccess: !access.HasWatermark);
        return Result.Success(new GalleryShareResponse(
            ShareUrl: BuildGenerationShareUrl(shareToken),
            ShareToken: shareToken,
            SignedMediaUrl: access.SignedMediaUrl,
            ExpiresAtUtc: access.ExpiresAtUtc,
            HasWatermark: access.HasWatermark,
            FileName: access.FileName,
            ContentType: access.ContentType,
            MediaState: GalleryMediaState.resultReady.ToString()));
    }

    private async Task<Result<GalleryMediaAccess>> GetMediaAccessAsync(
        Guid userId,
        Guid generationId,
        bool isPremium,
        string watermarkedEventType,
        string cleanEventType,
        CancellationToken cancellationToken)
    {
        var response = await GetAsync(userId, generationId, isPremium, cancellationToken);
        if (response.IsFailure)
        {
            return Result.Failure<GalleryMediaAccess>(response.Error);
        }

        if (string.IsNullOrWhiteSpace(response.Value.OutputUrl))
        {
            return Result.Failure<GalleryMediaAccess>(
                response.Value.HasWatermark || response.Value.CanRemoveWatermark
                    ? TemplatesErrors.WatermarkNotReady
                    : TemplatesErrors.InvalidStatus);
        }

        var extension = response.Value.TemplateType?.Equals("Video", StringComparison.OrdinalIgnoreCase) == true
            ? "mp4"
            : "png";
        await RecordMediaAccessAnalyticsAsync(
            userId,
            generationId,
            response.Value.HasWatermark ? watermarkedEventType : cleanEventType,
            response.Value.TemplateType,
            response.Value.UserPlan,
            cancellationToken);
        return Result.Success(new GalleryMediaAccess(
            response.Value.OutputUrl,
            DateTime.UtcNow.AddSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            $"petmagic-{response.Value.GenerationId:N}.{extension}",
            extension.Equals("mp4", StringComparison.OrdinalIgnoreCase) ? "video/mp4" : "image/png",
            response.Value.HasWatermark));
    }

    private sealed record GalleryMediaAccess(
        string SignedMediaUrl,
        DateTime? ExpiresAtUtc,
        string FileName,
        string ContentType,
        bool HasWatermark);
}
