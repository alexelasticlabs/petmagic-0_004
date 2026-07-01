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
    public async Task<Result<TemplateGenerationResponse>> StartSimilarAsync(
        StartSimilarTemplateGenerationCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
        var correlationId = NormalizeOptionalText(CorrelationContext.CurrentId, CorrelationContext.MaxLength);
        var variationStrength = NormalizeVariationStrength(command.VariationStrength);

        var source = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .FirstOrDefaultAsync(
                x => x.Id == command.SourceGenerationId
                    && x.UserId == command.UserId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (source is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (source.Status != TemplateGenerationStatus.Completed || source.UserMediaDeletedAtUtc != null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.InvalidStatus);
        }

        if (string.IsNullOrWhiteSpace(source.SourceImageUrl))
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.SourceMediaUnavailable);
        }

        var template = source.Template;
        var readiness = ValidateTemplate(template, requireActiveStatus: true);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        if (!template.SupportsGenerateSimilar)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerateSimilarUnsupported);
        }

        if (source.PetId is not null)
        {
            var petExists = await dbContext.Pets
                .AsNoTracking()
                .AnyAsync(x => x.Id == source.PetId.Value
                    && x.UserId == command.UserId
                    && !x.IsDeleted
                    && x.Status == "active",
                    cancellationToken);
            if (!petExists)
            {
                return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.PetNotFound);
            }
        }

        if (source.PetPhotoId is not null)
        {
            var photoExists = await dbContext.PetPhotos
                .AsNoTracking()
                .Include(x => x.MediaAsset)
                .AnyAsync(x => x.Id == source.PetPhotoId.Value
                    && x.UserId == command.UserId
                    && !x.IsDeleted
                    && x.Status == "active"
                    && !x.MediaAsset.IsDeleted,
                    cancellationToken);
            if (!photoExists)
            {
                return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.PetPhotoNotFound);
            }
        }

        if (source.InputMediaAssetId is not null)
        {
            var inputExists = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .AnyAsync(x => x.Id == source.InputMediaAssetId.Value && !x.IsDeleted, cancellationToken);
            if (!inputExists && string.Equals(source.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
            {
                return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.SourceMediaUnavailable);
            }
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
            ParentGenerationId = source.ParentGenerationId,
            ParentGenerationResultId = source.ParentGenerationResultId,
            SimilarToGenerationId = source.Id,
            GenerationMode = TemplateGenerationMode.Similar,
            VariationStrength = variationStrength,
            PetId = source.PetId,
            PetPhotoId = source.PetPhotoId,
            InputSourceType = source.InputSourceType,
            InputMediaAssetId = source.InputMediaAssetId,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = queueTier,
            SourceImageUrl = source.SourceImageUrl,
            SourceImageFileName = source.SourceImageFileName,
            SourceImageContentType = source.SourceImageContentType,
            SourceImageFileSizeBytes = source.SourceImageFileSizeBytes,
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
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarStarted);
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
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarInsufficientCredits);
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
