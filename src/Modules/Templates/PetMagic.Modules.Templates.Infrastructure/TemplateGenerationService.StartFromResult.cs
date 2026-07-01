using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    public async Task<Result<CompatibleGenerationTemplatesResponse>> GetCompatibleTemplatesAsync(
        Guid userId,
        Guid resultId,
        CancellationToken cancellationToken)
    {
        var parent = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(
                x => x.Id == resultId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        var inputMediaType = ResolveCompletedResultMediaType(parent);
        if (parent is null || inputMediaType is null || !IsCompletedResultUsable(parent))
        {
            return Result.Failure<CompatibleGenerationTemplatesResponse>(TemplatesErrors.GenerationResultInputUnavailable);
        }

        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.DeletedAtUtc == null
                && x.Status == TemplateStatus.Active
                && x.TemplateType == TemplateType.Video
                && x.SupportsGenerationResultInput
                && x.RequiredInputMediaType == inputMediaType.Value)
            .OrderBy(x => x.Title)
            .ThenBy(x => x.Id)
            .Select(x => new CompatibleGenerationTemplateResponse(
                x.Id,
                x.Title,
                x.TemplateType.ToString(),
                x.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => asset.Url)
                    .FirstOrDefault(),
                x.IsPremium,
                false,
                x.TokenCost))
            .ToArrayAsync(cancellationToken);

        return Result.Success(new CompatibleGenerationTemplatesResponse(
            resultId,
            inputMediaType.Value.ToString().ToLowerInvariant(),
            templates));
    }

    public async Task<Result<TemplateGenerationResponse>> StartFromResultAsync(
        StartTemplateGenerationFromResultCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
        var correlationId = NormalizeOptionalText(CorrelationContext.CurrentId, CorrelationContext.MaxLength);

        var parent = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(
                x => x.Id == command.ParentGenerationResultId
                    && x.UserId == command.UserId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        var inputMediaType = ResolveCompletedResultMediaType(parent);
        if (parent is null || inputMediaType is null || !IsCompletedResultUsable(parent))
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationResultInputUnavailable);
        }

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

        if (!template.SupportsGenerationResultInput || template.RequiredInputMediaType != inputMediaType.Value)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationResultInputUnsupported);
        }

        var mediaRecord = await GetOrCreateGenerationOutputMediaRecordAsync(parent, inputMediaType.Value, cancellationToken);
        if (mediaRecord is null || mediaRecord.IsDeleted || mediaRecord.DeletedAtUtc is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationResultInputUnavailable);
        }

        var duplicate = await FindActiveDuplicateAsync(
            command.UserId,
            normalizedIdempotencyKey,
            requestHash: null,
            cancellationToken);
        if (duplicate is not null)
        {
            return Result.Success(await MapResponseWithQueueMetricsAsync(duplicate, cancellationToken));
        }

        var activeLimit = Math.Max(1, command.ActiveGenerationLimit ?? options.FreeUserMaxActiveGenerations);
        var activeCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == command.UserId
                && TemplateGenerationJobStatusSets.Active.Contains(x.Status)
                && (x.Status != TemplateGenerationStatus.Queued || x.ChargedAtUtc != null),
                cancellationToken);
        if (activeCount >= activeLimit)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.ActiveGenerationLimitReached);
        }

        if (options.QueueMaxSize > 0)
        {
            var queueSize = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .CountAsync(x => TemplateGenerationJobStatusSets.Active.Contains(x.Status)
                    && (x.Status != TemplateGenerationStatus.Queued
                        || x.ChargedAtUtc != null
                        || x.UserId == AdminTestUserId),
                    cancellationToken);
            if (queueSize >= options.QueueMaxSize)
            {
                return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationQueueOverloaded);
            }
        }

        var queueTier = TemplateGenerationQueue.NormalizeTier(command.QueueTier);
        var admission = await EnsureQueueCanAcceptAsync(template, queueTier, cancellationToken);
        if (admission.IsFailure)
        {
            return Result.Failure<TemplateGenerationResponse>(admission.Error);
        }

        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            TemplateId = template.Id,
            Template = template,
            ParentGenerationId = parent.Id,
            ParentGenerationResultId = parent.Id,
            InputSourceType = "generation_result",
            InputMediaAssetId = mediaRecord.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = queueTier,
            SourceImageUrl = string.IsNullOrWhiteSpace(mediaRecord.StoragePath) ? mediaRecord.Url : mediaRecord.StoragePath,
            SourceImageFileName = mediaRecord.FileName,
            SourceImageContentType = mediaRecord.ContentType,
            SourceImageFileSizeBytes = mediaRecord.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            IdempotencyKey = normalizedIdempotencyKey,
            CorrelationId = correlationId,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            EstimatedWaitSecondsAtQueue = admission.Value.EstimatedWaitSeconds,
            EstimatedCompletionAtQueueUtc = admission.Value.EstimatedCompletionAtUtc,
            UpdatedAtUtc = now
        };

        dbContext.TemplateGenerationJobs.Add(job);
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.TemplateSelected);
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationStarted);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobQueued(job);
        }
        catch (DbUpdateException) when (normalizedIdempotencyKey is not null)
        {
            dbContext.ChangeTracker.Clear();
            duplicate = await FindActiveDuplicateAsync(command.UserId, normalizedIdempotencyKey, null, cancellationToken);
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
}
