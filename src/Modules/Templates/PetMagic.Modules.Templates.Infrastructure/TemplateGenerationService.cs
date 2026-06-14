using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationService(
    TemplatesDbContext dbContext,
    ITemplateGenerationBilling billing,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    TemplateWatermarkSettingsStore? watermarkSettings = null) : ITemplateGenerationService
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
                && x.SupportsGenerationResultInput
                && x.RequiredInputMediaType == inputMediaType.Value)
            .OrderByDescending(x => x.TemplateType == TemplateType.Video)
            .ThenByDescending(x => x.RecommendedAfterImageGeneration)
            .ThenBy(x => x.Title)
            .Select(x => new CompatibleGenerationTemplateResponse(
                x.Id,
                x.Title,
                x.TemplateType.ToString(),
                x.Assets
                    .Where(asset => asset.AssetKind == TemplateAssetKind.Preview)
                    .Select(asset => asset.Url)
                    .FirstOrDefault(),
                x.IsPremium,
                x.RecommendedAfterImageGeneration,
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

    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        return await GetAsync(userId, generationId, isPremium: false, cancellationToken);
    }

    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken, isPremium));
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, bool isPremium, CancellationToken cancellationToken)
    {
        var skip = Math.Clamp(query.Skip ?? 0, 0, 10_000);
        var take = Math.Clamp(query.Take ?? 30, 1, 100);

        var generationsQuery = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Where(x => x.UserId == userId && x.HiddenByUserAtUtc == null);

        generationsQuery = ApplyStatusFilter(generationsQuery, query.Status);

        var jobs = await generationsQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(skip)
            .Take(take)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(
            await MapResponsesWithQueueMetricsAsync(jobs, cancellationToken, isPremium));
    }

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

    public async Task<Result<GenerationDownloadResponse>> GetDownloadAsync(
        Guid userId,
        Guid generationId,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        return await GetMediaAccessAsync(
            userId,
            generationId,
            isPremium,
            TemplateAnalyticsEventTypes.DownloadWatermarked,
            TemplateAnalyticsEventTypes.DownloadClean,
            cancellationToken);
    }

    public async Task<Result<GenerationDownloadResponse>> GetShareAsync(
        Guid userId,
        Guid generationId,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        return await GetMediaAccessAsync(
            userId,
            generationId,
            isPremium,
            TemplateAnalyticsEventTypes.ShareWatermarked,
            TemplateAnalyticsEventTypes.ShareClean,
            cancellationToken);
    }

    private async Task<Result<GenerationDownloadResponse>> GetMediaAccessAsync(
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
            return Result.Failure<GenerationDownloadResponse>(response.Error);
        }

        if (string.IsNullOrWhiteSpace(response.Value.OutputUrl))
        {
            return Result.Failure<GenerationDownloadResponse>(
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
        return Result.Success(new GenerationDownloadResponse(
            response.Value.OutputUrl,
            response.Value.HasWatermark,
            $"petmagic-{response.Value.GenerationId:N}.{extension}"));
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

    public async Task<Result> MarkReadAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var now = DateTime.UtcNow;
        if (job.ResultViewedAtUtc is null)
        {
            job.ResultViewedAtUtc = now;
            AddAnalyticsEvent(
                job,
                TemplateAnalyticsEventTypes.ResultViewed,
                isPremium ? "premium" : "free");
        }

        job.UpdatedAtUtc = now;
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
            Type = "GenerationResult",
            Category = reasons.FirstOrDefault() ?? (command.Rating == 3 ? "good" : command.Rating == 2 ? "okay" : "bad"),
            TemplateId = job.TemplateId,
            Rating = command.Rating switch
            {
                3 => 1,
                2 => 0,
                _ => -1
            },
            Message = NormalizeOptionalText(command.Comment, 2000),
            PetId = job.PetId,
            SourceScreen = "generation_status",
            ErrorCode = job.LastErrorCode,
            ProviderName = ResolveProviderRequestId(job) is null ? null : "fal",
            Status = "New",
            Priority = command.Rating == 1 ? "Medium" : "Low",
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

    public async Task<Result<RemoveGenerationWatermarkResponse>> GrantAdminCleanDownloadAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        var existing = job.WatermarkUnlocks.FirstOrDefault(x => x.UserId == job.UserId);
        if (existing is null)
        {
            existing = AddWatermarkUnlock(job, TemplateWatermarkUnlockMethod.Admin, creditsSpent: 0, adminUserId);
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.RemovedPremium, "admin", "admin", creditsSpent: 0);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return Result.Success(new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl));
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
            GenerationId: job.Id,
            UserId: job.UserId,
            TemplateId: job.TemplateId,
            Status: ResolveApiStatus(job.Status),
            TokenCost: job.TokenCost,
            SourceImageAsset: MapSourceImageAsset(job),
            NormalizedImageUrl: job.NormalizedImageUrl,
            ReferenceMotionUrl: job.ReferenceMotionUrl,
            OutputUrl: ResolveDefaultOutputUrl(job),
            AttemptCount: job.AttemptCount,
            UsedPreprocessingModel: job.UsedPreprocessingModel,
            UsedKlingModel: job.UsedKlingModel,
            PreprocessingProviderRequestId: job.PreprocessingProviderRequestId,
            PreprocessingInferenceTimeSeconds: job.PreprocessingInferenceTimeSeconds,
            MotionProviderRequestId: job.MotionProviderRequestId,
            MotionInferenceTimeSeconds: job.MotionInferenceTimeSeconds,
            OutputVideoDurationSeconds: job.OutputVideoDurationSeconds,
            MotionProviderCostUsd: job.MotionProviderCostUsd,
            FailureCode: job.LastErrorCode,
            FailureMessage: job.LastErrorMessage,
            CreatedAtUtc: job.CreatedAtUtc,
            UpdatedAtUtc: job.UpdatedAtUtc,
            StartedAtUtc: job.StartedAtUtc,
            PreprocessingCompletedAtUtc: job.PreprocessingCompletedAtUtc,
            MotionGenerationCompletedAtUtc: job.MotionGenerationCompletedAtUtc,
            MediaImportCompletedAtUtc: job.MediaImportCompletedAtUtc,
            CompletedAtUtc: job.CompletedAtUtc,
            UserMediaExpired: job.UserMediaDeletedAtUtc != null,
            TemplateTitle: job.Template?.Title,
            TemplateType: job.Template?.TemplateType.ToString(),
            Stage: ResolveStage(job),
            ProgressPercent: ResolveProgressPercent(job),
            EstimatedDurationLabel: ResolveEstimatedDurationLabel(job.Template?.TemplateType),
            ChargedAtUtc: job.ChargedAtUtc,
            RefundedAtUtc: job.RefundedAtUtc,
            IsUnread: job.Status == TemplateGenerationStatus.Completed && job.ResultViewedAtUtc == null,
            QueuePosition: queuePosition,
            EstimatedWaitSeconds: estimatedWaitSeconds,
            HasWatermark: HasWatermark(job, hasCleanAccess: false),
            CanRemoveWatermark: CanRemoveWatermark(job, hasCleanAccess: false),
            IsWatermarkRemoved: job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits: 1,
            UserPlan: "free",
            WatermarkMessage: ResolveWatermarkMessage(job, hasCleanAccess: false),
            SupportsGenerateSimilar: job.Template?.SupportsGenerateSimilar == true,
            ParentGenerationId: job.ParentGenerationId,
            ParentGenerationResultId: job.ParentGenerationResultId,
            SimilarToGenerationId: job.SimilarToGenerationId,
            GenerationMode: job.GenerationMode.ToString().ToLowerInvariant(),
            VariationStrength: job.VariationStrength,
            GenerationSeed: job.GenerationSeed,
            PromptBeforeVariation: job.PromptBeforeVariation,
            PromptAfterVariation: job.PromptAfterVariation,
            InputSourceType: string.IsNullOrWhiteSpace(job.InputSourceType) ? "user_upload" : job.InputSourceType,
            InputMediaAssetId: job.InputMediaAssetId,
            ResultMediaAssetId: job.ResultMediaAssetId,
            InputPreviewUrl: null,
            ResultPreviewUrl: null,
            CanCompareBeforeAfter: false,
            PetId: job.PetId,
            PetPhotoId: job.PetPhotoId);
    }

    private Task<PetPhoto?> ResolvePetPhotoForGenerationAsync(
        Guid userId,
        Pet pet,
        Guid? petPhotoId,
        CancellationToken cancellationToken)
    {
        var query = dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId
                && x.PetId == pet.Id
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted);

        if (petPhotoId is not null)
        {
            return query.FirstOrDefaultAsync(x => x.Id == petPhotoId.Value, cancellationToken);
        }

        return query
            .OrderByDescending(x => x.IsFavorite)
            .ThenByDescending(x => x.MediaAssetId == pet.AvatarMediaAssetId)
            .ThenByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<TemplateGenerationResponse> MapResponseWithQueueMetricsAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return await SignUserMediaUrlsAsync(
                await ApplyCompareAccessAsync(
                    ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                    job,
                    hasCleanAccess,
                    cancellationToken),
                cancellationToken);
        }

        var queuePosition = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc < job.QueuedAtUtc,
                cancellationToken) + 1;

        return await SignUserMediaUrlsAsync(
            await ApplyCompareAccessAsync(
                ApplyWatermarkAccess(MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)), job, isPremium, hasUnlock),
                job,
                hasCleanAccess,
                cancellationToken),
            cancellationToken);
    }

    private async Task<IReadOnlyList<TemplateGenerationResponse>> MapResponsesWithQueueMetricsAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        if (jobs.Count == 0)
        {
            return [];
        }

        var compareAccessContext = await BuildCompareAccessContextAsync(jobs, cancellationToken);
        var queuedJobs = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
            .ToArray();
        if (queuedJobs.Length == 0)
        {
            var mapped = new List<TemplateGenerationResponse>(jobs.Count);
            foreach (var job in jobs)
            {
                var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
                var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
                mapped.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
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
            var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
            var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
            if (job.Status != TemplateGenerationStatus.Queued)
            {
                items.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
                continue;
            }

            var queuePosition = positionByQueuedAtUtc.GetValueOrDefault(job.QueuedAtUtc, 1);
            items.Add(await SignUserMediaUrlsAsync(
                ApplyCompareAccess(
                    ApplyWatermarkAccess(
                        MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)),
                        job,
                        isPremium,
                        hasUnlock),
                    job,
                    hasCleanAccess,
                    compareAccessContext),
                cancellationToken));
        }

        return items;
    }

    private async Task<TemplateGenerationResponse> ApplyCompareAccessAsync(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        CancellationToken cancellationToken)
    {
        if (job.Status != TemplateGenerationStatus.Completed
            || job.Template?.TemplateType != TemplateType.Image)
        {
            return response with
            {
                ResultMediaAssetId = job.ResultMediaAssetId,
                InputPreviewUrl = null,
                ResultPreviewUrl = null,
                CanCompareBeforeAfter = false
            };
        }

        var inputPreviewUrl = await ResolveInputComparePreviewUrlAsync(job, cancellationToken);
        var resultMediaRecord = await ResolveResultMediaRecordAsync(job, cancellationToken);
        return ApplyCompareAccess(response, job, hasCleanAccess, inputPreviewUrl, resultMediaRecord);
    }

    private static TemplateGenerationResponse ApplyCompareAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        CompareAccessContext compareAccessContext)
    {
        if (job.Status != TemplateGenerationStatus.Completed
            || job.Template?.TemplateType != TemplateType.Image)
        {
            return response with
            {
                ResultMediaAssetId = job.ResultMediaAssetId,
                InputPreviewUrl = null,
                ResultPreviewUrl = null,
                CanCompareBeforeAfter = false
            };
        }

        compareAccessContext.InputPreviewUrlsByGenerationId.TryGetValue(job.Id, out var inputPreviewUrl);
        compareAccessContext.ResultMediaRecordsByGenerationId.TryGetValue(job.Id, out var resultMediaRecord);
        return ApplyCompareAccess(response, job, hasCleanAccess, inputPreviewUrl, resultMediaRecord);
    }

    private static TemplateGenerationResponse ApplyCompareAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        string? inputPreviewUrl,
        TemplateMediaRecord? resultMediaRecord)
    {
        var resultPreviewUrl = ResolveResultComparePreviewUrl(job, resultMediaRecord, hasCleanAccess);
        var canCompare = !string.IsNullOrWhiteSpace(inputPreviewUrl)
            && !string.IsNullOrWhiteSpace(resultPreviewUrl);

        return response with
        {
            ResultMediaAssetId = resultMediaRecord?.Id ?? job.ResultMediaAssetId,
            InputPreviewUrl = canCompare ? inputPreviewUrl : null,
            ResultPreviewUrl = canCompare ? resultPreviewUrl : null,
            CanCompareBeforeAfter = canCompare
        };
    }

    private async Task<CompareAccessContext> BuildCompareAccessContextAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken)
    {
        var compareJobs = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Completed
                && x.Template?.TemplateType == TemplateType.Image)
            .ToArray();

        if (compareJobs.Length == 0)
        {
            return CompareAccessContext.Empty;
        }

        var inputMediaAssetIds = compareJobs
            .Select(x => x.InputMediaAssetId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var petPhotoIds = compareJobs
            .Select(x => x.PetPhotoId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var resultMediaAssetIds = compareJobs
            .Select(x => x.ResultMediaAssetId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var generationIds = compareJobs
            .Select(x => x.Id)
            .Distinct()
            .ToArray();
        var userIds = compareJobs
            .Select(x => x.UserId)
            .Distinct()
            .ToArray();

        var inputMediaRecordsById = inputMediaAssetIds.Length == 0
            ? new Dictionary<Guid, TemplateMediaRecord>()
            : await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .Where(x => inputMediaAssetIds.Contains(x.Id)
                    && x.UserId.HasValue
                    && userIds.Contains(x.UserId.Value)
                    && !x.IsDeleted
                    && x.MediaType == "image")
                .ToDictionaryAsync(x => x.Id, cancellationToken);

        var petPhotosById = petPhotoIds.Length == 0
            ? new Dictionary<Guid, PetPhoto>()
            : await dbContext.PetPhotos
                .AsNoTracking()
                .Include(x => x.MediaAsset)
                .Where(x => petPhotoIds.Contains(x.Id)
                    && userIds.Contains(x.UserId)
                    && !x.IsDeleted
                    && !x.MediaAsset.IsDeleted)
                .ToDictionaryAsync(x => x.Id, cancellationToken);

        var resultMediaRecords = await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .Where(x => x.UserId.HasValue
                && userIds.Contains(x.UserId.Value)
                && !x.IsDeleted
                && x.MediaType == "image"
                && (resultMediaAssetIds.Contains(x.Id)
                    || (x.GenerationId.HasValue
                        && generationIds.Contains(x.GenerationId.Value)
                        && x.SourceType == "generation_result")))
            .ToArrayAsync(cancellationToken);

        var resultMediaRecordsById = resultMediaRecords
            .Where(x => resultMediaAssetIds.Contains(x.Id))
            .ToDictionary(x => x.Id);
        var resultMediaRecordsByGenerationId = resultMediaRecords
            .Where(x => x.GenerationId.HasValue && x.SourceType == "generation_result")
            .GroupBy(x => x.GenerationId!.Value)
            .ToDictionary(
                x => x.Key,
                x => x.OrderByDescending(record => record.UploadedAtUtc).First());

        var inputPreviewUrlsByGenerationId = new Dictionary<Guid, string>();
        var finalResultMediaRecordsByGenerationId = new Dictionary<Guid, TemplateMediaRecord>();
        foreach (var job in compareJobs)
        {
            var inputPreviewUrl = ResolveInputComparePreviewUrl(job, petPhotosById, inputMediaRecordsById);
            if (!string.IsNullOrWhiteSpace(inputPreviewUrl))
            {
                inputPreviewUrlsByGenerationId[job.Id] = inputPreviewUrl;
            }

            TemplateMediaRecord? resultMediaRecord = null;
            if (job.ResultMediaAssetId is Guid resultMediaAssetId)
            {
                resultMediaRecordsById.TryGetValue(resultMediaAssetId, out resultMediaRecord);
            }

            resultMediaRecord ??= resultMediaRecordsByGenerationId.GetValueOrDefault(job.Id);
            if (resultMediaRecord is not null)
            {
                finalResultMediaRecordsByGenerationId[job.Id] = resultMediaRecord;
            }
        }

        return new CompareAccessContext(inputPreviewUrlsByGenerationId, finalResultMediaRecordsByGenerationId);
    }

    private static string? ResolveInputComparePreviewUrl(
        TemplateGenerationJob job,
        IReadOnlyDictionary<Guid, PetPhoto> petPhotosById,
        IReadOnlyDictionary<Guid, TemplateMediaRecord> inputMediaRecordsById)
    {
        if (string.Equals(job.InputSourceType, "pet_photo", StringComparison.OrdinalIgnoreCase)
            && job.PetPhotoId is Guid petPhotoId
            && petPhotosById.TryGetValue(petPhotoId, out var petPhoto))
        {
            return petPhoto.ThumbnailUrl
                ?? petPhoto.MediaAsset.PreviewUrl
                ?? petPhoto.MediaAsset.Url;
        }

        if (job.InputMediaAssetId is Guid inputMediaAssetId
            && inputMediaRecordsById.TryGetValue(inputMediaAssetId, out var inputMediaRecord))
        {
            return inputMediaRecord.PreviewUrl ?? inputMediaRecord.Url;
        }

        return job.SourceImageContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            ? job.SourceImageUrl
            : null;
    }

    private async Task<string?> ResolveInputComparePreviewUrlAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (string.Equals(job.InputSourceType, "pet_photo", StringComparison.OrdinalIgnoreCase)
            && job.PetPhotoId is Guid petPhotoId)
        {
            var petPhoto = await dbContext.PetPhotos
                .AsNoTracking()
                .Include(x => x.MediaAsset)
                .FirstOrDefaultAsync(
                    x => x.Id == petPhotoId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && !x.MediaAsset.IsDeleted,
                    cancellationToken);

            if (petPhoto is not null)
            {
                return petPhoto.ThumbnailUrl
                    ?? petPhoto.MediaAsset.PreviewUrl
                    ?? petPhoto.MediaAsset.Url;
            }
        }

        if (job.InputMediaAssetId is Guid inputMediaAssetId)
        {
            var inputMediaRecord = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == inputMediaAssetId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && x.MediaType == "image",
                    cancellationToken);

            if (inputMediaRecord is not null)
            {
                return inputMediaRecord.PreviewUrl ?? inputMediaRecord.Url;
            }
        }

        return job.SourceImageContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            ? job.SourceImageUrl
            : null;
    }

    private async Task<TemplateMediaRecord?> ResolveResultMediaRecordAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (job.ResultMediaAssetId is Guid resultMediaAssetId)
        {
            var resultMediaRecord = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == resultMediaAssetId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && x.MediaType == "image",
                    cancellationToken);
            if (resultMediaRecord is not null)
            {
                return resultMediaRecord;
            }
        }

        return await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.GenerationId == job.Id
                    && x.UserId == job.UserId
                    && x.SourceType == "generation_result"
                    && x.MediaType == "image"
                    && !x.IsDeleted,
                cancellationToken);
    }

    private static string? ResolveResultComparePreviewUrl(
        TemplateGenerationJob job,
        TemplateMediaRecord? resultMediaRecord,
        bool hasCleanAccess)
    {
        if (hasCleanAccess)
        {
            return resultMediaRecord?.PreviewUrl
                ?? resultMediaRecord?.Url
                ?? job.ResultUrl;
        }

        return resultMediaRecord?.WatermarkedPreviewUrl
            ?? resultMediaRecord?.WatermarkedStoragePath
            ?? job.WatermarkedResultUrl;
    }

    internal TemplateGenerationResponse ApplyWatermarkAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool isPremium,
        bool hasUnlock)
    {
        return ApplyWatermarkAccess(
            response,
            job,
            isPremium,
            hasUnlock,
            Math.Max(1, (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current.CostCredits));
    }

    internal static TemplateGenerationResponse ApplyWatermarkAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool isPremium,
        bool hasUnlock,
        int removeWatermarkCostCredits)
    {
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
        return response with
        {
            OutputUrl = ResolveAccessibleOutputUrl(job, hasCleanAccess),
            HasWatermark = HasWatermark(job, hasCleanAccess),
            CanRemoveWatermark = CanRemoveWatermark(job, hasCleanAccess),
            IsWatermarkRemoved = hasUnlock || job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits = Math.Max(1, removeWatermarkCostCredits),
            UserPlan = isPremium ? "premium" : "free",
            WatermarkMessage = ResolveWatermarkMessage(job, hasCleanAccess)
        };
    }

    private static string? ResolveAccessibleOutputUrl(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (job.Status != TemplateGenerationStatus.Completed)
        {
            return job.ResultUrl;
        }

        if (hasCleanAccess)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static string? ResolveDefaultOutputUrl(TemplateGenerationJob job)
    {
        if (job.Status != TemplateGenerationStatus.Completed || !job.IsWatermarkRequired)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static bool HasWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.WatermarkedResultUrl);
    }

    private static bool CanRemoveWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.ResultUrl);
    }

    private static string? ResolveWatermarkMessage(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (hasCleanAccess && job.IsWatermarkRequired)
        {
            return "Watermark removed";
        }

        if (job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && string.IsNullOrWhiteSpace(job.WatermarkedResultUrl))
        {
            return "Preparing result...";
        }

        return job.IsWatermarkRequired && !hasCleanAccess
            ? "Watermark added on the free plan"
            : null;
    }

    private TemplateGenerationWatermarkUnlock AddWatermarkUnlock(
        TemplateGenerationJob job,
        TemplateWatermarkUnlockMethod unlockMethod,
        int creditsSpent,
        Guid? unlockedByUserId)
    {
        var unlock = new TemplateGenerationWatermarkUnlock
        {
            Id = Guid.NewGuid(),
            UserId = job.UserId,
            GenerationJobId = job.Id,
            UnlockedByUserId = unlockedByUserId,
            UnlockMethod = unlockMethod,
            CreditsSpent = creditsSpent,
            CreatedAtUtc = DateTime.UtcNow
        };
        job.IsWatermarkRemoved = true;
        job.UpdatedAtUtc = unlock.CreatedAtUtc;
        dbContext.TemplateGenerationWatermarkUnlocks.Add(unlock);
        return unlock;
    }

    private async Task<RemoveGenerationWatermarkResponse?> TryResolveExistingWatermarkUnlockAsync(
        Guid userId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();

        var existing = await dbContext.TemplateGenerationWatermarkUnlocks
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.GenerationJobId == generationId)
            .Select(x => new { x.CreditsSpent })
            .FirstOrDefaultAsync(cancellationToken);
        if (existing is null)
        {
            return null;
        }

        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);
        if (job is null || string.IsNullOrWhiteSpace(job.ResultUrl))
        {
            return null;
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl);
    }

    private async Task RecordMediaAccessAnalyticsAsync(
        Guid userId,
        Guid generationId,
        string eventType,
        string? mediaType,
        string? userPlan,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);
        if (job is null)
        {
            return;
        }

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = userId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(job.Id, job.TemplateId, mediaType, userPlan),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private void AddAnalyticsEvent(
        TemplateGenerationJob job,
        string eventType,
        string? userPlan = null,
        string? unlockMethod = null,
        int? creditsSpent = null)
    {
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = job.UserId,
            GenerationId = job.Id,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(
                job.Id,
                job.TemplateId,
                job.Template?.TemplateType.ToString(),
                userPlan,
                unlockMethod,
                creditsSpent,
                job.ParentGenerationId,
                job.Template?.TemplateType.ToString(),
                ResolveAnalyticsInputMediaType(job),
                job.TokenCost),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid petPhotoId,
        Guid templateId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            UserId = pet.UserId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = JsonSerializer.Serialize(new
            {
                generationId,
                templateId,
                mediaType = "image",
                petId = pet.Id,
                petPhotoId
            }),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
        return Task.CompletedTask;
    }

    private static string BuildAnalyticsMetadata(
        Guid generationId,
        Guid templateId,
        string? mediaType,
        string? userPlan,
        string? unlockMethod = null,
        int? creditsSpent = null,
        Guid? parentGenerationId = null,
        string? newTemplateType = null,
        string? inputMediaType = null,
        int? creditsCost = null)
    {
        return JsonSerializer.Serialize(new
        {
            generationId,
            templateId,
            parentGenerationId,
            newTemplateId = templateId,
            newTemplateType = NormalizeAnalyticsMediaType(newTemplateType),
            mediaType = string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant(),
            inputMediaType = NormalizeAnalyticsMediaType(inputMediaType),
            userPlan,
            unlockMethod,
            creditsSpent,
            creditsCost
        });
    }

    private static string? ResolveAnalyticsInputMediaType(TemplateGenerationJob job)
    {
        if (job.InputSourceType is null)
        {
            return null;
        }

        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return job.Template?.RequiredInputMediaType?.ToString();
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? "image"
            : null;
    }

    private static string NormalizeAnalyticsMediaType(string? mediaType)
    {
        return string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant();
    }

    private async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        return await SignUserMediaUrlsAsync(mediaStorage, options, response, cancellationToken);
    }

    internal static async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        IMediaStorage mediaStorage,
        TemplatesOptions options,
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var sourceImageAsset = response.SourceImageAsset;
        if (sourceImageAsset is not null)
        {
            var signedSourceUrl = await TryCreateReadUrlAsync(mediaStorage, sourceImageAsset.Url, ttl, cancellationToken);
            sourceImageAsset = signedSourceUrl is null
                ? null
                : sourceImageAsset with { Url = signedSourceUrl };
        }

        return response with
        {
            SourceImageAsset = sourceImageAsset,
            NormalizedImageUrl = await TryCreateReadUrlAsync(mediaStorage, response.NormalizedImageUrl, ttl, cancellationToken),
            OutputUrl = await TryCreateReadUrlAsync(mediaStorage, response.OutputUrl, ttl, cancellationToken),
            InputPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.InputPreviewUrl, ttl, cancellationToken),
            ResultPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.ResultPreviewUrl, ttl, cancellationToken)
        };
    }

    private async Task<string?> TryCreateReadUrlAsync(string? assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        return await TryCreateReadUrlAsync(mediaStorage, assetUrl, ttl, cancellationToken);
    }

    private static async Task<string?> TryCreateReadUrlAsync(
        IMediaStorage mediaStorage,
        string? assetUrl,
        TimeSpan ttl,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return null;
        }

        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private string ResolveManagedStoragePathOrUrl(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        if (candidate.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return candidate;
        }

        var localBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(localBaseUrl)
            && candidate.StartsWith(localBaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            var relativePath = candidate[localBaseUrl.Length..].TrimStart('/');
            if (relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
            {
                return relativePath;
            }
        }

        if (!options.R2.IsConfigured)
        {
            return assetUrl;
        }

        var r2BaseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(r2BaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return assetUrl;
        }

        var storageKey = candidate[r2BaseUrl.Length..].TrimStart('/');
        var objectKeyPrefix = NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix);
        return storageKey.StartsWith($"{objectKeyPrefix}/", StringComparison.OrdinalIgnoreCase)
            ? storageKey
            : assetUrl;
    }

    private static string NormalizeObjectKeyPrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
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

    private static TemplateType? ResolveCompletedResultMediaType(TemplateGenerationJob? job)
    {
        if (job?.Template is null)
        {
            return null;
        }

        // MVP supports image result as input only. Video result chaining is intentionally blocked.
        return job.Template.TemplateType == TemplateType.Image ? TemplateType.Image : null;
    }

    private static bool IsCompletedResultUsable(TemplateGenerationJob job)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.UserMediaDeletedAtUtc == null
            && !string.IsNullOrWhiteSpace(job.ResultUrl);
    }

    private async Task<TemplateMediaRecord?> GetOrCreateGenerationOutputMediaRecordAsync(
        TemplateGenerationJob job,
        TemplateType mediaType,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(job.ResultUrl))
        {
            return null;
        }

        var mediaTypeText = mediaType.ToString().ToLowerInvariant();
        var existing = await dbContext.TemplateMediaRecords
            .FirstOrDefaultAsync(
                x => x.GenerationId == job.Id
                    && x.SourceType == "generation_result"
                    && x.MediaType == mediaTypeText
                    && !x.IsDeleted,
                cancellationToken);

        if (existing is not null)
        {
            if (job.ResultMediaAssetId != existing.Id)
            {
                job.ResultMediaAssetId = existing.Id;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            return existing;
        }

        existing = await dbContext.TemplateMediaRecords
            .FirstOrDefaultAsync(x => x.Url == job.ResultUrl, cancellationToken);

        if (existing is null)
        {
            existing = new TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                Url = job.ResultUrl,
                UploadedAtUtc = job.MediaImportCompletedAtUtc ?? job.CompletedAtUtc ?? DateTime.UtcNow
            };
            dbContext.TemplateMediaRecords.Add(existing);
        }

        existing.UserId = job.UserId;
        existing.MediaType = mediaTypeText;
        existing.StoragePath = job.ResultUrl;
        existing.WatermarkedStoragePath = job.WatermarkedResultUrl;
        existing.SourceType = "generation_result";
        existing.GenerationId = job.Id;
        existing.FileName = string.IsNullOrWhiteSpace(existing.FileName)
            ? $"generated-{job.Id:N}.{(mediaType == TemplateType.Video ? "mp4" : "png")}"
            : existing.FileName;
        existing.ContentType = string.IsNullOrWhiteSpace(existing.ContentType)
            ? (mediaType == TemplateType.Video ? "video/mp4" : "image/png")
            : existing.ContentType;
        existing.Role = mediaType == TemplateType.Video
            ? TemplateMediaRole.GenerationOutputVideo
            : TemplateMediaRole.GenerationOutputImage;
        existing.LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration;
        existing.GenerationJobId = job.Id;
        existing.AttachedAtUtc ??= DateTime.UtcNow;
        existing.ExpiresAtUtc = null;
        existing.DeletedAtUtc = null;
        existing.IsDeleted = false;
        job.ResultMediaAssetId = existing.Id;

        await dbContext.SaveChangesAsync(cancellationToken);
        return existing;
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

    private static string NormalizeVariationStrength(string? value)
    {
        return string.Equals(value, "low", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "high", StringComparison.OrdinalIgnoreCase)
            ? value!.ToLowerInvariant()
            : "medium";
    }

    private async Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid? petPhotoId = null,
        Guid? templateId = null,
        Guid? generationId = null,
        string userPlan = "unknown",
        string sourceScreen = "api",
        CancellationToken cancellationToken = default)
    {
        var photosCount = await dbContext.PetPhotos.CountAsync(
            x => x.UserId == pet.UserId && x.PetId == pet.Id && !x.IsDeleted,
            cancellationToken);

        dbContext.PetAnalyticsEvents.Add(new PetAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            UserId = pet.UserId,
            PetId = pet.Id,
            PetPhotoId = petPhotoId,
            TemplateId = templateId,
            GenerationId = generationId,
            EventType = eventType,
            PetType = pet.Type,
            PhotosCount = photosCount,
            UserPlan = userPlan,
            SourceScreen = sourceScreen,
            CreatedAtUtc = DateTime.UtcNow
        });
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
        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

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

    private sealed record CompareAccessContext(
        IReadOnlyDictionary<Guid, string> InputPreviewUrlsByGenerationId,
        IReadOnlyDictionary<Guid, TemplateMediaRecord> ResultMediaRecordsByGenerationId)
    {
        public static CompareAccessContext Empty { get; } = new(
            new Dictionary<Guid, string>(),
            new Dictionary<Guid, TemplateMediaRecord>());
    }
}
