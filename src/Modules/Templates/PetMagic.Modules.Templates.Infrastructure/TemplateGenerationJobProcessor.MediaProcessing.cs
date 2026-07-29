using System.Security.Cryptography;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using Npgsql;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private const string GenerationResultMediaIdentityIndex =
        "UX_tmr_GenerationResult_GenerationId_MediaType";

    private static string PreparePrompt(TemplateGenerationJob job, string basePrompt)
    {
        if (job.GenerationMode != TemplateGenerationMode.Similar)
        {
            return basePrompt;
        }

        job.GenerationSeed ??= RandomNumberGenerator.GetInt32(1, int.MaxValue);
        job.PromptBeforeVariation ??= basePrompt;

        var variation = NormalizeVariationStrength(job.VariationStrength) switch
        {
            "low" => "Create a close sibling variation: keep the same composition and style, with a subtle change in lighting, background detail, or pose.",
            "high" => "Create a clearly related variation: preserve the template style and pet identity, but vary the background, lighting, pose, and small scene details.",
            _ => "Create a similar but not identical variation: preserve the template style and pet identity, while gently varying background, lighting, pose, and small details."
        };

        job.PromptAfterVariation = $"{basePrompt}\n\n{variation} Seed: {job.GenerationSeed.Value}.";
        return job.PromptAfterVariation;
    }

    private static string NormalizeVariationStrength(string? value)
    {
        return string.Equals(value, "low", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "high", StringComparison.OrdinalIgnoreCase)
            ? value!.ToLowerInvariant()
            : "medium";
    }

    private async Task ProcessImageAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var imageModel = job.Template.ImageModel!;
        var imagePrompt = PreparePrompt(job, TemplateGenerationService.ResolvePrompt(job.Template.ImagePrompt, options.DefaultImagePrompt));

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        job.UsedPreprocessingModel = imageModel;

        var sourceImageUrl = await CreateProviderSourceImageReadUrlAsync(job, cancellationToken);
        if (sourceImageUrl is null)
        {
            await MarkFailedAsync(job, TemplatesErrors.MediaStorageFailed, cancellationToken);
            return;
        }

        if (imageGenerator is IAsyncImageGenerationQueue asyncImageGenerator
            && await TrySubmitImageGenerationAsync(
                job,
                asyncImageGenerator,
                sourceImageUrl,
                imagePrompt,
                imageModel,
                cancellationToken))
        {
            return;
        }

        var generated = await imageGenerator.CreateAsync(
            sourceImageUrl,
            imagePrompt,
            imageModel,
            job.GenerationSeed,
            cancellationToken);

        if (generated.IsFailure)
        {
            await MarkFailedAsync(job, generated.Error, cancellationToken);
            return;
        }

        job.PreprocessingProviderRequestId = generated.Value.ProviderRequestId;
        job.PreprocessingInferenceTimeSeconds = generated.Value.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
        job.MotionProviderCostUsd = FalModelPricing.TryGetImageGenerationCostUsd(imageModel);
        job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
        if (UsesFakeAiProvider())
        {
            var fakeStoredOutput = await generatedMediaImporter.ImportImageAsync(
                generated.Value.ImageUrl,
                job.Id,
                cancellationToken);
            if (fakeStoredOutput.IsFailure)
            {
                await MarkFailedAsync(job, fakeStoredOutput.Error, cancellationToken);
                return;
            }

            await CompleteFakeGeneratedMediaAsync(
                job,
                fakeStoredOutput.Value,
                TemplateType.Image,
                cancellationToken);
            return;
        }

        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        var storedOutput = await generatedMediaImporter.ImportImageAsync(generated.Value.ImageUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return;
        }

        var watermarkedOutput = await ApplyWatermarkAsync(job, storedOutput.Value, TemplateType.Image, cancellationToken);
        var resultPreview = await imagePreviewGenerator.CreatePreviewAsync(
            storedOutput.Value,
            $"generation-{job.Id:N}-result-preview.webp",
            BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview"),
            cancellationToken);
        var watermarkedPreview = watermarkedOutput is null
            ? null
            : await imagePreviewGenerator.CreatePreviewAsync(
                watermarkedOutput,
                $"generation-{job.Id:N}-watermarked-result-preview.webp",
                BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked"),
                cancellationToken);
        job.ResultUrl = storedOutput.Value.StorageKey;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        await RegisterGenerationOutputMediaRecordAsync(
            job,
            storedOutput.Value,
            TemplateType.Image,
            resultPreview,
            watermarkedPreview);
        job.Status = TemplateGenerationStatus.Completed;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationCompleted);
        if (job.GenerationMode == TemplateGenerationMode.Similar)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarCompleted);
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        logger.LogInformation(
            "Template generation result uploaded. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.MediaImportCompletedAtUtc));
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await SyncGamificationAsync(job, cancellationToken);
        await PublishStatusChangedAsync(job, cancellationToken);
        logger.LogInformation(
            "Template generation job completed. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));
    }

    private async Task ProcessVideoAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var referenceMotion = TemplateGenerationService.GetAsset(job.Template, TemplateAssetKind.ReferenceMotion)!;
        var preprocessingModel = job.Template.PreprocessingModel!;
        var preprocessingPrompt = PreparePrompt(job, TemplateGenerationService.ResolvePrompt(job.Template.PreprocessingPrompt, options.DefaultPreprocessingPrompt));
        var motionModel = job.Template.KlingModel!;
        var motionPrompt = PreparePrompt(job, TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt));

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        job.UsedPreprocessingModel = preprocessingModel;
        job.UsedKlingModel = motionModel;

        var normalizedImageUrl = job.NormalizedImageUrl;
        if (string.IsNullOrWhiteSpace(normalizedImageUrl))
        {
            var sourceImageUrl = await CreateProviderSourceImageReadUrlAsync(job, cancellationToken);
            if (sourceImageUrl is null)
            {
                await MarkFailedAsync(job, TemplatesErrors.MediaStorageFailed, cancellationToken);
                return;
            }

            if (imagePreprocessor is IAsyncImagePreprocessingQueue asyncImagePreprocessor
                && await TrySubmitVideoPreprocessingAsync(
                    job,
                    asyncImagePreprocessor,
                    sourceImageUrl,
                    preprocessingPrompt,
                    preprocessingModel,
                    cancellationToken))
            {
                return;
            }

            var normalized = await imagePreprocessor.NormalizeAsync(
                sourceImageUrl,
                preprocessingModel,
                preprocessingPrompt,
                cancellationToken);

            if (normalized.IsFailure)
            {
                await MarkFailedAsync(job, normalized.Error, cancellationToken);
                return;
            }

            normalizedImageUrl = normalized.Value.ImageUrl;
            job.NormalizedImageUrl = normalizedImageUrl;
            job.PreprocessingProviderRequestId = normalized.Value.ProviderRequestId;
            job.PreprocessingInferenceTimeSeconds = normalized.Value.InferenceTimeSeconds;
            job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
            job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
            if (!UsesFakeAiProvider() && !await SaveClaimedChangesAsync(job, cancellationToken))
            {
                return;
            }
        }
        else
        {
            job.PreprocessingCompletedAtUtc ??= DateTime.UtcNow;
            logger.LogInformation(
                "Template generation video preprocessing reused from durable normalized image. GenerationIdHash={GenerationIdHash}",
                TemplateLogSanitizer.SafeId(job.Id));
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        if (videoMotionGenerator is IAsyncVideoMotionGenerationQueue asyncVideoMotionGenerator
            && await SubmitVideoGenerationAsync(job, asyncVideoMotionGenerator, cancellationToken))
        {
            return;
        }

        var generated = await videoMotionGenerator.CreateAsync(
            normalizedImageUrl!,
            referenceMotion.Url,
            job.Template.CharacterOrientation!.Value.ToString(),
            job.Template.KeepOriginalSound ?? true,
            motionPrompt,
            motionModel,
            job.GenerationSeed,
            cancellationToken);

        if (generated.IsFailure)
        {
            await MarkFailedAsync(job, generated.Error, cancellationToken);
            return;
        }

        job.MotionProviderRequestId = generated.Value.ProviderRequestId;
        job.MotionInferenceTimeSeconds = generated.Value.InferenceTimeSeconds;
        job.MotionGenerationCompletedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.MotionGenerationCompletedAtUtc.Value;
        if (UsesFakeAiProvider())
        {
            var fakeStoredOutput = await generatedMediaImporter.ImportVideoAsync(
                generated.Value.VideoUrl,
                job.Id,
                cancellationToken);
            if (fakeStoredOutput.IsFailure)
            {
                await MarkFailedAsync(job, fakeStoredOutput.Error, cancellationToken);
                return;
            }

            await CompleteFakeGeneratedMediaAsync(
                job,
                fakeStoredOutput.Value,
                TemplateType.Video,
                cancellationToken);
            return;
        }

        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.Value.VideoUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return;
        }

        var durationResult = await mediaMetadataReader.GetVideoDurationSecondsAsync(storedOutput.Value, cancellationToken);
        if (durationResult.IsFailure)
        {
            logger.LogWarning(
                "Generated template media duration could not be determined. GenerationIdHash={GenerationIdHash}",
                TemplateLogSanitizer.SafeId(job.Id));
        }
        else
        {
            job.OutputVideoDurationSeconds = durationResult.Value;
            job.MotionProviderCostUsd = FalModelPricing.TryCalculateMotionCostUsd(motionModel, durationResult.Value);
        }

        var watermarkedOutput = await ApplyWatermarkAsync(job, storedOutput.Value, TemplateType.Video, cancellationToken);
        var resultPreview = await videoThumbnailGenerator.CreateThumbnailAsync(
            storedOutput.Value,
            job.Id,
            $"generation-{job.Id:N}-result-preview.jpg",
            BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview", "jpg"),
            cancellationToken);
        var watermarkedPreview = watermarkedOutput is null
            ? null
            : await videoThumbnailGenerator.CreateThumbnailAsync(
                watermarkedOutput,
                job.Id,
                $"generation-{job.Id:N}-watermarked-result-preview.jpg",
                BuildGenerationPreviewStorageKey(job.UserId, job.Id, "result-preview-watermarked", "jpg"),
                cancellationToken);
        job.ResultUrl = storedOutput.Value.StorageKey;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        await RegisterGenerationOutputMediaRecordAsync(job, storedOutput.Value, TemplateType.Video, resultPreview, watermarkedPreview);
        job.Status = TemplateGenerationStatus.Completed;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationCompleted);
        if (job.GenerationMode == TemplateGenerationMode.Similar)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarCompleted);
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        logger.LogInformation(
            "Template generation result uploaded. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.MediaImportCompletedAtUtc));
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await SyncGamificationAsync(job, cancellationToken);
        await PublishStatusChangedAsync(job, cancellationToken);
        logger.LogInformation(
            "Template generation job completed. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));
    }

    private async Task CompleteFakeGeneratedMediaAsync(
        TemplateGenerationJob job,
        StoredMediaResponse storedOutput,
        TemplateType mediaType,
        CancellationToken cancellationToken)
    {
        job.ResultUrl = storedOutput.StorageKey;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Completed;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationCompleted);
        if (job.GenerationMode == TemplateGenerationMode.Similar)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarCompleted);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        logger.LogInformation(
            "Template generation fake result recorded. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.MediaImportCompletedAtUtc));
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await SyncGamificationAsync(job, cancellationToken);
        await PublishStatusChangedAsync(job, cancellationToken);
        logger.LogInformation(
            "Template generation job completed. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));
    }

    private bool UsesFakeAiProvider() =>
        string.Equals(
            Environment.GetEnvironmentVariable("PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION"),
            "true",
            StringComparison.OrdinalIgnoreCase)
        && (string.Equals(options.AiProvider, TemplateAiProviders.Fake, StringComparison.OrdinalIgnoreCase)
            || imageGenerator is FakeImageGenerator
            || imagePreprocessor is FakeImagePreprocessor
            || videoMotionGenerator is FakeVideoMotionGenerator
            || generatedMediaImporter is FakeGeneratedMediaImporter);

    private async Task<bool> PublishProcessingStageAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        job.Status = TemplateGenerationStatus.Processing;
        job.UpdatedAtUtc = DateTime.UtcNow;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        TemplateGenerationMetrics.RecordJobStage(job, TemplateGenerationService.ResolveStage(job));
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<StoredMediaResponse?> ApplyWatermarkAsync(
        TemplateGenerationJob job,
        StoredMediaResponse storedOutput,
        TemplateType mediaType,
        CancellationToken cancellationToken)
    {
        var settings = watermarkSettings?.Current ?? new TemplateWatermarkSettingsStore(options).Current;
        var applies = settings.Enabled
            && ((mediaType == TemplateType.Image && settings.ApplyToImages)
                || (mediaType == TemplateType.Video && settings.ApplyToVideos))
            && watermarkRenderer is not null;
        job.IsWatermarkRequired = applies;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.WatermarkedResultUrl = null;

        if (!applies)
        {
            return null;
        }

        var watermarked = await watermarkRenderer!.CreateWatermarkedCopyAsync(
            storedOutput,
            mediaType,
            job.Id,
            cancellationToken);
        if (watermarked.IsSuccess)
        {
            job.WatermarkedResultUrl = watermarked.Value.StorageKey;
            return watermarked.Value;
        }

        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(watermarked.Error.Code);
        job.WatermarkFailureCode = safeErrorCode;
        logger.LogWarning(
            "Template generation watermark copy could not be prepared. GenerationIdHash={GenerationIdHash} ErrorCode={ErrorCode}",
            TemplateLogSanitizer.SafeId(job.Id),
            safeErrorCode);
        return null;
    }

    private async Task<TemplateMediaRecord> RegisterGenerationOutputMediaRecordAsync(
        TemplateGenerationJob job,
        StoredMediaResponse storedOutput,
        TemplateType mediaType,
        StoredMediaResponse? preview,
        StoredMediaResponse? watermarkedPreview,
        CancellationToken cancellationToken = default,
        bool attachAsCompletedResult = true)
    {
        var now = DateTime.UtcNow;
        var mediaTypeText = mediaType.ToString().ToLowerInvariant();
        var existing = await FindGenerationOutputMediaRecordAsync(job, mediaType, cancellationToken);

        if (existing is null)
        {
            existing = new TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                UploadedAtUtc = now
            };
            dbContext.TemplateMediaRecords.Add(existing);
            if (dbContext.Entry(job).Collection(x => x.MediaRecords).IsLoaded)
            {
                job.MediaRecords.Add(existing);
            }
        }

        existing.UserId = job.UserId;
        existing.MediaType = mediaTypeText;
        existing.StoragePath = storedOutput.StorageKey;
        existing.WatermarkedStoragePath = job.WatermarkedResultUrl ?? existing.WatermarkedStoragePath;
        existing.PreviewUrl = preview?.StorageKey ?? existing.PreviewUrl;
        existing.WatermarkedPreviewUrl = watermarkedPreview?.StorageKey ?? existing.WatermarkedPreviewUrl;
        existing.SourceType = "generation_result";
        existing.GenerationId = job.Id;
        existing.Url = storedOutput.Url;
        existing.FileName = storedOutput.FileName;
        existing.ContentType = storedOutput.ContentType;
        existing.FileSizeBytes = storedOutput.FileSizeBytes;
        existing.Role = mediaType == TemplateType.Video
            ? TemplateMediaRole.GenerationOutputVideo
            : TemplateMediaRole.GenerationOutputImage;
        existing.LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration;
        existing.GenerationJobId = job.Id;
        existing.ExpiresAtUtc = null;
        existing.AttachedAtUtc = now;
        existing.DeletedAtUtc = null;
        existing.IsDeleted = false;
        existing.FailureCode = null;
        existing.FailureMessage = null;
        if (attachAsCompletedResult)
        {
            job.ResultMediaAssetId = existing.Id;
        }

        return existing;
    }

    private async Task<TemplateMediaRecord?> FindGenerationOutputMediaRecordAsync(
        TemplateGenerationJob job,
        TemplateType mediaType,
        CancellationToken cancellationToken)
    {
        var mediaTypeText = mediaType.ToString().ToLowerInvariant();
        var existing = job.MediaRecords.FirstOrDefault(x =>
            x.GenerationId == job.Id
            && x.SourceType == "generation_result"
            && x.MediaType == mediaTypeText);

        return existing ?? await dbContext.TemplateMediaRecords
            .FirstOrDefaultAsync(
                x => x.GenerationId == job.Id
                    && x.SourceType == "generation_result"
                    && x.MediaType == mediaTypeText,
                cancellationToken);
    }

    internal async Task<bool> TryRecoverGenerationOutputMediaRecordInsertRaceAsync(
        TemplateGenerationJob job,
        DbUpdateException exception,
        CancellationToken cancellationToken)
    {
        if (!IsGenerationResultMediaIdentityViolation(exception))
        {
            return false;
        }

        var pendingEntry = dbContext.ChangeTracker
            .Entries<TemplateMediaRecord>()
            .FirstOrDefault(entry => entry.State == EntityState.Added
                && entry.Entity.GenerationId == job.Id
                && string.Equals(entry.Entity.SourceType, "generation_result", StringComparison.Ordinal)
                && (string.Equals(entry.Entity.MediaType, "image", StringComparison.Ordinal)
                    || string.Equals(entry.Entity.MediaType, "video", StringComparison.Ordinal)));
        if (pendingEntry is null)
        {
            return false;
        }

        var pending = pendingEntry.Entity;
        pendingEntry.State = EntityState.Detached;
        job.MediaRecords.Remove(pending);

        var persisted = await dbContext.TemplateMediaRecords
            .SingleOrDefaultAsync(
                record => record.GenerationId == pending.GenerationId
                    && record.SourceType == "generation_result"
                    && record.MediaType == pending.MediaType,
                cancellationToken);
        if (persisted is null)
        {
            return false;
        }

        MergeGenerationOutputCheckpoint(persisted, pending);
        if (job.ResultMediaAssetId == pending.Id)
        {
            job.ResultMediaAssetId = persisted.Id;
        }

        if (dbContext.Entry(job).Collection(x => x.MediaRecords).IsLoaded
            && job.MediaRecords.All(record => record.Id != persisted.Id))
        {
            job.MediaRecords.Add(persisted);
        }

        logger.LogInformation(
            "Template generation media checkpoint insert race resolved by reloading the durable record. GenerationIdHash={GenerationIdHash} MediaType={MediaType}",
            TemplateLogSanitizer.SafeId(job.Id),
            pending.MediaType);
        return true;
    }

    private static bool IsGenerationResultMediaIdentityViolation(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is PostgresException
                {
                    SqlState: PostgresErrorCodes.UniqueViolation,
                    ConstraintName: GenerationResultMediaIdentityIndex
                })
            {
                return true;
            }
        }

        return false;
    }

    private static void MergeGenerationOutputCheckpoint(
        TemplateMediaRecord persisted,
        TemplateMediaRecord pending)
    {
        persisted.UserId ??= pending.UserId;
        persisted.GenerationId ??= pending.GenerationId;
        persisted.GenerationJobId ??= pending.GenerationJobId;
        persisted.StoragePath = string.IsNullOrWhiteSpace(persisted.StoragePath)
            ? pending.StoragePath
            : persisted.StoragePath;
        persisted.Url = string.IsNullOrWhiteSpace(persisted.Url)
            ? pending.Url
            : persisted.Url;
        persisted.FileName = string.IsNullOrWhiteSpace(persisted.FileName)
            ? pending.FileName
            : persisted.FileName;
        persisted.ContentType = string.IsNullOrWhiteSpace(persisted.ContentType)
            ? pending.ContentType
            : persisted.ContentType;
        persisted.FileSizeBytes ??= pending.FileSizeBytes;
        persisted.WatermarkedStoragePath ??= pending.WatermarkedStoragePath;
        persisted.PreviewUrl ??= pending.PreviewUrl;
        persisted.WatermarkedPreviewUrl ??= pending.WatermarkedPreviewUrl;
        persisted.Role = pending.Role;
        persisted.LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration;
        persisted.AttachedAtUtc ??= pending.AttachedAtUtc;
        persisted.ExpiresAtUtc = null;
        persisted.DeletedAtUtc = null;
        persisted.IsDeleted = false;
        persisted.FailureCode = null;
        persisted.FailureMessage = null;
    }

    private static StoredMediaResponse? RestoreOriginalMediaCheckpoint(TemplateMediaRecord? mediaRecord)
    {
        if (mediaRecord is null
            || string.IsNullOrWhiteSpace(mediaRecord.StoragePath)
            || string.IsNullOrWhiteSpace(mediaRecord.FileName)
            || string.IsNullOrWhiteSpace(mediaRecord.ContentType))
        {
            return null;
        }

        return new StoredMediaResponse(
            string.IsNullOrWhiteSpace(mediaRecord.Url) ? mediaRecord.StoragePath : mediaRecord.Url,
            mediaRecord.StoragePath,
            mediaRecord.FileName,
            mediaRecord.ContentType,
            mediaRecord.FileSizeBytes,
            LocalPath: null);
    }

    private static StoredMediaResponse? RestoreWatermarkedMediaCheckpoint(
        TemplateMediaRecord? mediaRecord,
        StoredMediaResponse original)
    {
        if (string.IsNullOrWhiteSpace(mediaRecord?.WatermarkedStoragePath))
        {
            return null;
        }

        var storagePath = mediaRecord.WatermarkedStoragePath;
        return new StoredMediaResponse(
            storagePath,
            storagePath,
            ResolveCheckpointFileName(storagePath, original.FileName),
            original.ContentType,
            FileSizeBytes: null,
            LocalPath: null);
    }

    private static StoredMediaResponse? RestorePreviewMediaCheckpoint(
        string? storagePath,
        string fallbackFileName)
    {
        if (string.IsNullOrWhiteSpace(storagePath))
        {
            return null;
        }

        var extension = Path.GetExtension(storagePath);
        var contentType = string.Equals(extension, ".jpg", StringComparison.OrdinalIgnoreCase)
            || string.Equals(extension, ".jpeg", StringComparison.OrdinalIgnoreCase)
            ? "image/jpeg"
            : "image/webp";
        return new StoredMediaResponse(
            storagePath,
            storagePath,
            ResolveCheckpointFileName(storagePath, fallbackFileName),
            contentType,
            FileSizeBytes: null,
            LocalPath: null);
    }

    private static string ResolveCheckpointFileName(string storagePath, string fallback)
    {
        var fileName = Path.GetFileName(storagePath);
        return string.IsNullOrWhiteSpace(fileName) ? fallback : fileName;
    }

    private static string BuildGenerationPreviewStorageKey(Guid userId, Guid generationId, string fileName, string extension = "webp")
    {
        return $"users/{userId:N}/generations/{generationId:N}/{fileName}.{extension}";
    }

    private async Task<string?> CreateProviderReadUrlAsync(string assetUrl, CancellationToken cancellationToken)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private async Task<string?> CreateProviderSourceImageReadUrlAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var assetUrl = job.SourceImageUrl;
        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase)
            && job.InputMediaAssetId is Guid inputMediaAssetId)
        {
            var mediaRecord = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == inputMediaAssetId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && x.DeletedAtUtc == null
                        && x.MediaType == "image"
                        && x.SourceType == "generation_result",
                    cancellationToken);

            if (mediaRecord is null)
            {
                return null;
            }

            assetUrl = string.IsNullOrWhiteSpace(mediaRecord.StoragePath)
                ? mediaRecord.Url
                : mediaRecord.StoragePath;
        }

        return string.IsNullOrWhiteSpace(assetUrl)
            ? null
            : await CreateProviderReadUrlAsync(assetUrl, cancellationToken);
    }
}
