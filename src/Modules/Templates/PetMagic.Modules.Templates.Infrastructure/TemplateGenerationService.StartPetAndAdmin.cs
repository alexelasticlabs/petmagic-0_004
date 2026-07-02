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
    public async Task<Result<TemplateGenerationResponse>> StartFromPetAsync(
        StartTemplateGenerationFromPetCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
        var correlationId = NormalizeOptionalText(CorrelationContext.CurrentId, CorrelationContext.MaxLength);

        var templateLookup = await FindPublicGenerationTemplateAsync(
            command.TemplateId,
            new TemplateVisibilityContext(
                RequireGenerationAccess: true,
                HasPremiumAccess: command.HasPremiumAccess,
                ExpectedVersion: command.ExpectedTemplateVersion),
            command.UserId,
            cancellationToken);
        if (templateLookup.IsFailure)
        {
            return Result.Failure<TemplateGenerationResponse>(templateLookup.Error);
        }

        var template = templateLookup.Value;
        var readiness = ValidateTemplateReadiness(template);
        if (readiness is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(readiness);
        }

        var pet = await dbContext.Pets
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.Id == command.PetId
                    && x.UserId == command.UserId
                    && !x.IsDeleted
                    && x.Status == "active",
                cancellationToken);
        if (pet is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.PetNotFound);
        }

        var photo = await ResolvePetPhotoForGenerationAsync(command.UserId, pet, command.PetPhotoId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<TemplateGenerationResponse>(
                command.PetPhotoId is null ? TemplatesErrors.PetPhotoRequired : TemplatesErrors.PetPhotoNotFound);
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
            PetId = pet.Id,
            PetPhotoId = photo.Id,
            InputSourceType = "pet_photo",
            InputMediaAssetId = photo.MediaAssetId,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = queueTier,
            SourceImageUrl = string.IsNullOrWhiteSpace(photo.MediaAsset.StoragePath)
                ? photo.MediaAsset.Url
                : photo.MediaAsset.StoragePath,
            SourceImageFileName = photo.MediaAsset.FileName,
            SourceImageContentType = photo.MediaAsset.ContentType,
            SourceImageFileSizeBytes = photo.MediaAsset.FileSizeBytes,
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
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.GenerateWithPetClicked,
            petPhotoId: photo.Id,
            templateId: template.Id,
            generationId: job.Id,
            cancellationToken: cancellationToken);
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.GenerationStartedFromPet,
            petPhotoId: photo.Id,
            templateId: template.Id,
            generationId: job.Id,
            cancellationToken: cancellationToken);
        dbContext.TemplateGenerationBillingCommands.Add(CreateGenerationBillingCommand(job, now));
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

        return await SettleGenerationBillingAndMapAsync(job, null, cancellationToken);
    }

    public async Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(
        Guid templateId,
        TemplateAssetCommand sourceImageAsset,
        CancellationToken cancellationToken)
    {
        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.NotFound);
        }

        var readiness = ValidateTemplateReadiness(template);
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
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = TemplateGenerationQueue.TierAdmin,
            SourceImageUrl = ResolveManagedStoragePathOrUrl(sourceImageAsset.Url),
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
}
