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
    public async Task<Result<TemplateGenerationResponse>> StartAsync(
        StartTemplateGenerationCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = NormalizeOptionalText(command.IdempotencyKey, 256);
        var normalizedRequestHash = NormalizeOptionalText(command.RequestHash, 128);
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
            QueueMediaType = TemplateGenerationQueue.ResolveMediaType(template.TemplateType),
            QueueTier = queueTier,
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
            EstimatedWaitSecondsAtQueue = admission.Value.EstimatedWaitSeconds,
            EstimatedCompletionAtQueueUtc = admission.Value.EstimatedCompletionAtUtc,
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
        dbContext.TemplateGenerationBillingCommands.Add(
            CreateGenerationBillingCommand(job, now, reserveForImmediateSettlement: true));
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

        return await SettleGenerationBillingAndMapAsync(job, null, cancellationToken);
    }
}
