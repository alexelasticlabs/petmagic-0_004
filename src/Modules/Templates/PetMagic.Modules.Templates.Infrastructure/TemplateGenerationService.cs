using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationService(
    TemplatesDbContext dbContext,
    ITemplateGenerationBilling billing,
    IMediaStorage mediaStorage,
    TemplatesOptions options) : ITemplateGenerationService
{
    internal static readonly Guid AdminTestUserId = Guid.Empty;

    public async Task<Result<TemplateGenerationResponse>> StartAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
        var normalizedRequestHash = NormalizeOptionalText(command.RequestHash, 128);
        var correlationId = NormalizeOptionalText(CorrelationContext.CurrentId, CorrelationContext.MaxLength);

        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == command.TemplateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound);
        }

        var readiness = ValidateTemplate(template, requireActiveStatus: true);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        var duplicate = await FindActiveDuplicateAsync(
            command.UserId,
            normalizedIdempotencyKey,
            normalizedRequestHash,
            cancellationToken);
        if (duplicate is not null)
        {
            return Result.Success(await MapResponseWithQueueMetricsAsync(duplicate, cancellationToken));
        }

        var activeLimit = Math.Max(1, command.ActiveGenerationLimit ?? options.FreeUserMaxActiveGenerations);
        var activeCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == command.UserId
                && TemplateGenerationJobStatusSets.Active.Contains(x.Status),
                cancellationToken);
        if (activeCount >= activeLimit)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.ActiveGenerationLimitReached);
        }

        if (options.QueueMaxSize > 0)
        {
            var queueSize = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .CountAsync(x => TemplateGenerationJobStatusSets.Active.Contains(x.Status), cancellationToken);
            if (queueSize >= options.QueueMaxSize)
            {
                return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationQueueOverloaded);
            }
        }

        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = command.SourceImageAsset.Url,
            SourceImageFileName = command.SourceImageAsset.FileName,
            SourceImageContentType = command.SourceImageAsset.ContentType,
            SourceImageFileSizeBytes = command.SourceImageAsset.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            IdempotencyKey = normalizedIdempotencyKey,
            RequestHash = normalizedRequestHash,
            CorrelationId = correlationId,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateGenerationJobs.Add(job);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobQueued(job);
        }
        catch (DbUpdateException) when (normalizedIdempotencyKey is not null || normalizedRequestHash is not null)
        {
            dbContext.ChangeTracker.Clear();
            duplicate = await FindActiveDuplicateAsync(
                command.UserId,
                normalizedIdempotencyKey,
                normalizedRequestHash,
                cancellationToken);
            if (duplicate is not null)
            {
                return Result.Success(await MapResponseWithQueueMetricsAsync(duplicate, cancellationToken));
            }

            throw;
        }

        var charge = await billing.ChargeAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (charge.IsFailure)
        {
            var previousStatus = job.Status;
            job.Status = TemplateGenerationStatus.Failed;
            job.LastErrorCode = charge.Error.Code;
            job.LastErrorMessage = charge.Error.Message;
            job.UpdatedAtUtc = DateTime.UtcNow;
            job.CompletedAtUtc = job.UpdatedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, charge.Error.Code);
            return Result.Failure<TemplateGenerationResponse>(charge.Error);
        }

        job.ChargedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.ChargedAtUtc.Value;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    public async Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(Guid templateId, TemplateAssetCommand sourceImageAsset, CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound);
        }

        var readiness = ValidateTemplate(template, requireActiveStatus: false);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        var now = DateTime.UtcNow;
        var correlationId = NormalizeOptionalText(CorrelationContext.CurrentId, CorrelationContext.MaxLength);
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = AdminTestUserId,
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = sourceImageAsset.Url,
            SourceImageFileName = sourceImageAsset.FileName,
            SourceImageContentType = sourceImageAsset.ContentType,
            SourceImageFileSizeBytes = sourceImageAsset.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            CorrelationId = correlationId,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordJobQueued(job);

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, CancellationToken cancellationToken)
    {
        var skip = Math.Clamp(query.Skip ?? 0, 0, 10_000);
        var take = Math.Clamp(query.Take ?? 30, 1, 100);

        var generationsQuery = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Where(x => x.UserId == userId && x.HiddenByUserAtUtc == null);

        generationsQuery = ApplyStatusFilter(generationsQuery, query.Status);

        var jobs = await generationsQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip(skip)
            .Take(take)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(
            await MapResponsesWithQueueMetricsAsync(jobs, cancellationToken));
    }

    public async Task<Result<TemplateGenerationUnreadCountResponse>> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken)
    {
        var count = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == userId
                && x.HiddenByUserAtUtc == null
                && x.Status == TemplateGenerationStatus.Completed
                && x.ResultViewedAtUtc == null,
                cancellationToken);

        return Result.Success(new TemplateGenerationUnreadCountResponse(count));
    }

    public async Task<Result> MarkReadAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        job.ResultViewedAtUtc ??= DateTime.UtcNow;
        job.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> DeleteAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        if (job is null || job.HiddenByUserAtUtc != null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var now = DateTime.UtcNow;
        job.HiddenByUserAtUtc = now;
        job.UpdatedAtUtc = now;
        job.ResultViewedAtUtc ??= now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RecordFeedbackAsync(RecordTemplateGenerationFeedbackCommand command, CancellationToken cancellationToken)
    {
        if (command.Rating is < 1 or > 3)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == command.GenerationId && x.UserId == command.UserId, cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var reasons = NormalizeFeedbackReasons(command.SelectedReasons);
        if (reasons.Length > 8)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        dbContext.TemplateGenerationFeedback.Add(new TemplateGenerationFeedback
        {
            Id = Guid.NewGuid(),
            GenerationId = job.Id,
            UserId = job.UserId,
            TemplateId = job.TemplateId,
            Rating = command.Rating,
            SelectedReasons = JsonSerializer.Serialize(reasons),
            Comment = NormalizeOptionalText(command.Comment, 2000),
            InputPhotoQualityScore = command.InputPhotoQualityScore,
            ModelUsed = ResolveFeedbackModel(job),
            GenerationDurationSeconds = ResolveGenerationDurationSeconds(job),
            ProviderRequestId = ResolveProviderRequestId(job),
            CreatedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

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

    internal static Error? ValidateTemplate(TemplateItem template, bool requireActiveStatus)
    {
        if (requireActiveStatus && template.Status != TemplateStatus.Active)
        {
            return TemplatesErrors.InvalidStatus;
        }

        if (template.TemplateType == TemplateType.Image)
        {
            return string.IsNullOrWhiteSpace(template.ImageModel)
                ? TemplatesErrors.MissingImageModel
                : null;
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return TemplatesErrors.TypeMismatch;
        }

        if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
        {
            return TemplatesErrors.MissingReferenceMotion;
        }

        if (template.CharacterOrientation is null)
        {
            return TemplatesErrors.MissingCharacterOrientation;
        }

        if (string.IsNullOrWhiteSpace(template.PreprocessingModel))
        {
            return TemplatesErrors.InvalidPreprocessingModel;
        }

        if (string.IsNullOrWhiteSpace(template.KlingModel))
        {
            return TemplatesErrors.InvalidKlingModel;
        }

        return null;
    }

    internal static TemplateAsset? GetAsset(TemplateItem template, TemplateAssetKind kind)
    {
        return template.Assets.FirstOrDefault(x => x.AssetKind == kind);
    }

    internal static string ResolvePrompt(string? prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    internal static TemplateGenerationResponse MapResponse(
        TemplateGenerationJob job,
        int? queuePosition = null,
        int? estimatedWaitSeconds = null)
    {
        return new TemplateGenerationResponse(
            job.Id,
            job.UserId,
            job.TemplateId,
            ResolveApiStatus(job.Status),
            job.TokenCost,
            MapSourceImageAsset(job),
            job.NormalizedImageUrl,
            job.ReferenceMotionUrl,
            job.ResultUrl,
            job.AttemptCount,
            job.UsedPreprocessingModel,
            job.UsedKlingModel,
            job.PreprocessingProviderRequestId,
            job.PreprocessingInferenceTimeSeconds,
            job.MotionProviderRequestId,
            job.MotionInferenceTimeSeconds,
            job.OutputVideoDurationSeconds,
            job.MotionProviderCostUsd,
            job.LastErrorCode,
            job.LastErrorMessage,
            job.CreatedAtUtc,
            job.UpdatedAtUtc,
            job.StartedAtUtc,
            job.PreprocessingCompletedAtUtc,
            job.MotionGenerationCompletedAtUtc,
            job.MediaImportCompletedAtUtc,
            job.CompletedAtUtc,
            job.UserMediaDeletedAtUtc != null,
            job.Template?.Title,
            job.Template?.TemplateType.ToString(),
            ResolveStage(job),
            ResolveProgressPercent(job),
            ResolveEstimatedDurationLabel(job.Template?.TemplateType),
            job.ChargedAtUtc,
            job.RefundedAtUtc,
            job.Status == TemplateGenerationStatus.Completed && job.ResultViewedAtUtc == null,
            queuePosition,
            estimatedWaitSeconds);
    }

    private async Task<TemplateGenerationResponse> MapResponseWithQueueMetricsAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return await SignUserMediaUrlsAsync(MapResponse(job), cancellationToken);
        }

        var queuePosition = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc < job.QueuedAtUtc,
                cancellationToken) + 1;

        return await SignUserMediaUrlsAsync(
            MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)),
            cancellationToken);
    }

    private async Task<IReadOnlyList<TemplateGenerationResponse>> MapResponsesWithQueueMetricsAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken)
    {
        if (jobs.Count == 0)
        {
            return [];
        }

        var queuedJobs = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
            .ToArray();
        if (queuedJobs.Length == 0)
        {
            var mapped = new List<TemplateGenerationResponse>(jobs.Count);
            foreach (var job in jobs)
            {
                mapped.Add(await SignUserMediaUrlsAsync(MapResponse(job), cancellationToken));
            }

            return mapped;
        }

        var latestQueuedAtUtc = queuedJobs.Max(x => x.QueuedAtUtc);
        var queuedAtUtcValues = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc <= latestQueuedAtUtc)
            .Select(x => x.QueuedAtUtc)
            .ToArrayAsync(cancellationToken);

        var positionByQueuedAtUtc = new Dictionary<DateTime, int>();
        var olderQueuedCount = 0;
        foreach (var group in queuedAtUtcValues.GroupBy(x => x).OrderBy(x => x.Key))
        {
            positionByQueuedAtUtc[group.Key] = olderQueuedCount + 1;
            olderQueuedCount += group.Count();
        }

        var items = new List<TemplateGenerationResponse>(jobs.Count);
        foreach (var job in jobs)
        {
            if (job.Status != TemplateGenerationStatus.Queued)
            {
                items.Add(await SignUserMediaUrlsAsync(MapResponse(job), cancellationToken));
                continue;
            }

            var queuePosition = positionByQueuedAtUtc.GetValueOrDefault(job.QueuedAtUtc, 1);
            items.Add(await SignUserMediaUrlsAsync(
                MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)),
                cancellationToken));
        }

        return items;
    }

    private async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var sourceImageAsset = response.SourceImageAsset;
        if (sourceImageAsset is not null)
        {
            var signedSourceUrl = await TryCreateReadUrlAsync(sourceImageAsset.Url, ttl, cancellationToken);
            sourceImageAsset = signedSourceUrl is null
                ? null
                : sourceImageAsset with { Url = signedSourceUrl };
        }

        return response with
        {
            SourceImageAsset = sourceImageAsset,
            NormalizedImageUrl = await TryCreateReadUrlAsync(response.NormalizedImageUrl, ttl, cancellationToken),
            OutputUrl = await TryCreateReadUrlAsync(response.OutputUrl, ttl, cancellationToken)
        };
    }

    private async Task<string?> TryCreateReadUrlAsync(string? assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return null;
        }

        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private int EstimateWaitSeconds(TemplateGenerationJob job, int queuePosition)
    {
        var averageGenerationSeconds = job.Template?.TemplateType == TemplateType.Video
            ? options.EstimatedVideoGenerationSeconds
            : options.EstimatedImageGenerationSeconds;
        var globalConcurrency = Math.Max(1, options.GlobalMaxConcurrentGenerations);
        return (int)Math.Ceiling(queuePosition * averageGenerationSeconds / (double)globalConcurrency);
    }

    private Task<TemplateGenerationJob?> FindActiveDuplicateAsync(
        Guid userId,
        string? idempotencyKey,
        string? requestHash,
        CancellationToken cancellationToken)
    {
        if (idempotencyKey is null && requestHash is null)
        {
            return Task.FromResult<TemplateGenerationJob?>(null);
        }

        return dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Where(x => x.UserId == userId
                && TemplateGenerationJobStatusSets.Active.Contains(x.Status)
                && ((idempotencyKey != null && x.IdempotencyKey == idempotencyKey)
                    || (requestHash != null && x.RequestHash == requestHash)))
            .OrderBy(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private static IQueryable<TemplateGenerationJob> ApplyStatusFilter(
        IQueryable<TemplateGenerationJob> query,
        string? rawStatus)
    {
        return rawStatus?.Trim().ToLowerInvariant() switch
        {
            null or "" or "all" => query,
            "active" or "in_progress" or "processing" => query.Where(x => TemplateGenerationJobStatusSets.Active.Contains(x.Status)),
            "ready" or "succeeded" or "completed" => query.Where(x => x.Status == TemplateGenerationStatus.Completed),
            "error" or "failed" => query.Where(x => x.Status == TemplateGenerationStatus.Failed),
            "cancelled" or "canceled" => query.Where(x => x.Status == TemplateGenerationStatus.Cancelled),
            "retrying" => query.Where(x => x.Status == TemplateGenerationStatus.Retrying),
            "queued" => query.Where(x => x.Status == TemplateGenerationStatus.Queued),
            "preprocessing" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
                && x.StartedAtUtc != null
                && x.PreprocessingCompletedAtUtc == null),
            "generating" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
                && x.PreprocessingCompletedAtUtc != null
                && x.MotionGenerationCompletedAtUtc == null
                && x.Template.TemplateType == TemplateType.Video),
            "finalizing" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
                && ((x.Template.TemplateType == TemplateType.Image && x.PreprocessingCompletedAtUtc != null)
                    || x.MotionGenerationCompletedAtUtc != null)),
            _ => query
        };
    }

    private static string[] NormalizeFeedbackReasons(IReadOnlyCollection<string> rawReasons)
    {
        return [.. rawReasons
            .Select(x => NormalizeOptionalText(x, 120))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Cast<string>()];
    }

    private static string? ResolveFeedbackModel(TemplateGenerationJob job)
    {
        return string.IsNullOrWhiteSpace(job.UsedKlingModel)
            ? job.UsedPreprocessingModel
            : job.UsedKlingModel;
    }

    private static double? ResolveGenerationDurationSeconds(TemplateGenerationJob job)
    {
        if (job.StartedAtUtc is null || job.CompletedAtUtc is null)
        {
            return null;
        }

        return Math.Max(0, (job.CompletedAtUtc.Value - job.StartedAtUtc.Value).TotalSeconds);
    }

    private static string? ResolveProviderRequestId(TemplateGenerationJob job)
    {
        return string.IsNullOrWhiteSpace(job.MotionProviderRequestId)
            ? job.PreprocessingProviderRequestId
            : job.MotionProviderRequestId;
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    internal static string ResolveApiStatus(TemplateGenerationStatus status)
    {
        return status == TemplateGenerationStatus.Completed
            ? TemplateGenerationStatus.Succeeded.ToString()
            : status.ToString();
    }

    internal static string ResolveStage(TemplateGenerationJob job)
    {
        if (job.Status == TemplateGenerationStatus.Failed)
        {
            return "failed";
        }

        if (job.Status == TemplateGenerationStatus.Cancelled)
        {
            return "cancelled";
        }

        if (job.Status == TemplateGenerationStatus.Retrying)
        {
            return "retrying";
        }

        if (job.Status == TemplateGenerationStatus.Completed)
        {
            return "succeeded";
        }

        if (job.Status == TemplateGenerationStatus.Queued)
        {
            return "queued";
        }

        if (job.Status != TemplateGenerationStatus.Processing)
        {
            return "processing";
        }

        if (job.MediaImportCompletedAtUtc is not null
            || job.MotionGenerationCompletedAtUtc is not null
            || (job.Template?.TemplateType == TemplateType.Image && job.PreprocessingCompletedAtUtc is not null))
        {
            return "finalizing";
        }

        if (job.Template?.TemplateType == TemplateType.Video && job.PreprocessingCompletedAtUtc is not null)
        {
            return "generating";
        }

        if (job.StartedAtUtc is not null)
        {
            return "preprocessing";
        }

        return "processing";
    }

    internal static int ResolveProgressPercent(TemplateGenerationJob job)
    {
        return ResolveStage(job) switch
        {
            "succeeded" => 100,
            "failed" => 100,
            "finalizing" => 90,
            "generating" => 65,
            "preprocessing" => 30,
            "uploading" => 15,
            _ => 10
        };
    }

    private static string ResolveEstimatedDurationLabel(TemplateType? templateType)
    {
        return templateType == TemplateType.Video
            ? "Usually 1-3 minutes"
            : "Usually under 1 minute";
    }

    private static TemplateAssetResponse? MapSourceImageAsset(TemplateGenerationJob job)
    {
        if (string.IsNullOrWhiteSpace(job.SourceImageUrl))
        {
            return null;
        }

        return new TemplateAssetResponse(
            job.SourceImageUrl,
            job.SourceImageFileName,
            job.SourceImageContentType,
            job.SourceImageFileSizeBytes,
            null);
    }
}
