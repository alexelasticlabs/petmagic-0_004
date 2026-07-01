using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Security.Cryptography;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
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
            await CompleteFakeGeneratedMediaAsync(
                job,
                new StoredMediaResponse(
                    generated.Value.ImageUrl,
                    generated.Value.ImageUrl,
                    $"generation-{job.Id:N}.png",
                    "image/png",
                    null,
                    null),
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
        RegisterGenerationOutputMediaRecord(
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
        await NotifyGamificationAsync(job, cancellationToken);
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
                "Template generation video preprocessing reused from durable normalized image. GenerationId={GenerationId}",
                job.Id);
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
            await CompleteFakeGeneratedMediaAsync(
                job,
                new StoredMediaResponse(
                    generated.Value.VideoUrl,
                    generated.Value.VideoUrl,
                    $"generation-{job.Id:N}.mp4",
                    "video/mp4",
                    null,
                    null),
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
                "Generated template media duration could not be determined. GenerationId={GenerationId}",
                job.Id);
        }
        else
        {
            job.OutputVideoDurationSeconds = durationResult.Value;
            job.MotionProviderCostUsd = FalModelPricing.TryCalculateMotionCostUsd(motionModel, durationResult.Value);
        }

        await ApplyWatermarkAsync(job, storedOutput.Value, TemplateType.Video, cancellationToken);
        job.ResultUrl = storedOutput.Value.StorageKey;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        RegisterGenerationOutputMediaRecord(job, storedOutput.Value, TemplateType.Video, null, null);
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
        await NotifyGamificationAsync(job, cancellationToken);
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
        await NotifyGamificationAsync(job, cancellationToken);
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

        job.WatermarkFailureCode = watermarked.Error.Code;
        logger.LogWarning(
            "Template generation watermark copy could not be prepared. GenerationId={GenerationId} ErrorCode={ErrorCode}",
            job.Id,
            watermarked.Error.Code);
        return null;
    }

    private void RegisterGenerationOutputMediaRecord(
        TemplateGenerationJob job,
        StoredMediaResponse storedOutput,
        TemplateType mediaType,
        StoredMediaResponse? preview,
        StoredMediaResponse? watermarkedPreview)
    {
        var now = DateTime.UtcNow;
        var mediaTypeText = mediaType.ToString().ToLowerInvariant();
        var existing = job.MediaRecords.FirstOrDefault(x =>
            x.GenerationId == job.Id
            && x.SourceType == "generation_result"
            && x.MediaType == mediaTypeText);

        if (existing is null)
        {
            existing = new TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                UploadedAtUtc = now
            };
            job.MediaRecords.Add(existing);
        }

        existing.UserId = job.UserId;
        existing.MediaType = mediaTypeText;
        existing.StoragePath = storedOutput.StorageKey;
        existing.WatermarkedStoragePath = job.WatermarkedResultUrl;
        existing.PreviewUrl = preview?.StorageKey;
        existing.WatermarkedPreviewUrl = watermarkedPreview?.StorageKey;
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
        job.ResultMediaAssetId = existing.Id;
    }

    private static string BuildGenerationPreviewStorageKey(Guid userId, Guid generationId, string fileName)
    {
        return $"users/{userId:N}/generations/{generationId:N}/{fileName}.webp";
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
