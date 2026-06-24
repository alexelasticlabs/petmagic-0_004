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
        var sourceImageStoragePath = ResolveManagedStoragePathOrUrl(command.SourceImageAsset.Url);
        var sourceImagePreviewStoragePath = command.SourceImagePreviewAsset is null
            ? null
            : ResolveManagedStoragePathOrUrl(command.SourceImagePreviewAsset.Url);
        var generationId = Guid.NewGuid();
        var inputMediaAssetId = Guid.NewGuid();
        var job = new TemplateGenerationJob
        {
            Id = generationId,
            UserId = command.UserId,
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            InputSourceType = "user_upload",
            InputMediaAssetId = inputMediaAssetId,
            SourceImageUrl = sourceImageStoragePath,
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

        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = inputMediaAssetId,
            UserId = command.UserId,
            MediaType = "image",
            StoragePath = sourceImageStoragePath,
            PreviewUrl = sourceImagePreviewStoragePath,
            SourceType = "user_upload",
            GenerationId = generationId,
            Url = command.SourceImageAsset.Url,
            FileName = command.SourceImageAsset.FileName,
            ContentType = command.SourceImageAsset.ContentType,
            FileSizeBytes = command.SourceImageAsset.FileSizeBytes,
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            GenerationJobId = generationId,
            UploadedAtUtc = now,
            AttachedAtUtc = now,
            ExpiresAtUtc = null,
            DeletedAtUtc = null,
            IsDeleted = false
        });
        dbContext.TemplateGenerationJobs.Add(job);
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.TemplateSelected);
        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationStarted);
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
            ParentGenerationId = parent.Id,
            ParentGenerationResultId = parent.Id,
            InputSourceType = "generation_result",
            InputMediaAssetId = mediaRecord.Id,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
            SourceImageUrl = string.IsNullOrWhiteSpace(mediaRecord.StoragePath) ? mediaRecord.Url : mediaRecord.StoragePath,
            SourceImageFileName = mediaRecord.FileName,
            SourceImageContentType = mediaRecord.ContentType,
            SourceImageFileSizeBytes = mediaRecord.FileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            IdempotencyKey = normalizedIdempotencyKey,
            CorrelationId = correlationId,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
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
            SourceImageUrl = source.SourceImageUrl,
            SourceImageFileName = source.SourceImageFileName,
            SourceImageContentType = source.SourceImageContentType,
            SourceImageFileSizeBytes = source.SourceImageFileSizeBytes,
            ReferenceMotionUrl = GetAsset(template, TemplateAssetKind.ReferenceMotion)?.Url,
            IdempotencyKey = normalizedIdempotencyKey,
            CorrelationId = correlationId,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
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

    public async Task<Result<TemplateGenerationResponse>> StartFromPetAsync(
        StartTemplateGenerationFromPetCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
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
            PetId = pet.Id,
            PetPhotoId = photo.Id,
            InputSourceType = "pet_photo",
            InputMediaAssetId = photo.MediaAssetId,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = template.TokenCost,
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
