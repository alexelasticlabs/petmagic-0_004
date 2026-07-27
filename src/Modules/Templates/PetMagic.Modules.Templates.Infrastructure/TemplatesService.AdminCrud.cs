using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, null, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateImageModel(command.ImageModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements),
            Category = categoryResult.Value.Name,
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            IsQaOnly = command.IsQaOnly,
            TokenCost = command.TokenCost,
            SupportsGenerationResultInput = command.SupportsGenerationResultInput,
            RequiredInputMediaType = ParseInputMediaType(command.RequiredInputMediaType),
            RecommendedAfterImageGeneration = command.RecommendedAfterImageGeneration,
            SupportsGenerateSimilar = command.SupportsGenerateSimilar,
            DefaultVariationStrength = NormalizeVariationStrength(command.DefaultVariationStrength),
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            ImageModel = command.ImageModel.Trim(),
            ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt),
            CreatedAtUtc = now,
            PublishedAtUtc = statusResult.Value == TemplateStatus.Active ? now : null,
            UpdatedAtUtc = now
        };

        template.LocalizedTextsJson = null;

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);
        SetPublicMediaAssets(
            template,
            command.PreviewAsset,
            command.ThumbnailAsset,
            command.AnimatedPreviewAsset,
            command.FeedLoopLowAsset,
            command.FeedLoopMediumAsset,
            command.DetailPreviewAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }

            StampFirstPublicationIfNeeded(template, now);
            LogIncompletePublicMediaSet(template);
        }

        dbContext.TemplateItems.Add(template);
        await ClaimTemplateAssetsAfterUpdateAsync(
            template.Id,
            cancellationToken,
            PreviewAssetsForLifecycle(
                command.PreviewAsset,
                command.ThumbnailAsset,
                command.AnimatedPreviewAsset,
                command.FeedLoopLowAsset,
                command.FeedLoopMediumAsset,
                command.DetailPreviewAsset));
        await StampCatalogUpsertAsync(template, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishTemplateInvalidatedAsync(template, "created", isCritical: false, mediaChanged: true, cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        return UpdateImageAsync(command, cancellationToken, retryOnConcurrency: true);
    }

    private async Task<Result<AdminTemplateResponse>> UpdateImageAsync(
        UpdateImageTemplateCommand command,
        CancellationToken cancellationToken,
        bool retryOnConcurrency)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Image)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, template.Category, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateImageModel(command.ImageModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
        template.Category = categoryResult.Value.Name;
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        if (command.IsQaOnly.HasValue)
        {
            template.IsQaOnly = command.IsQaOnly.Value;
        }
        template.TokenCost = command.TokenCost;
        template.SupportsGenerationResultInput = command.SupportsGenerationResultInput;
        template.RequiredInputMediaType = ParseInputMediaType(command.RequiredInputMediaType);
        template.RecommendedAfterImageGeneration = command.RecommendedAfterImageGeneration;
        template.SupportsGenerateSimilar = command.SupportsGenerateSimilar;
        template.DefaultVariationStrength = NormalizeVariationStrength(command.DefaultVariationStrength);
        template.Status = statusResult.Value;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.ImageModel = command.ImageModel.Trim();
        template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
        var now = DateTime.UtcNow;
        var effectivePreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.Preview,
            command.PreviewAsset,
            command.KeepPreviewAsset);
        var effectiveThumbnailAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.Thumbnail,
            command.ThumbnailAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;
        var effectiveAnimatedPreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.AnimatedPreview,
            command.AnimatedPreviewAsset,
            command.KeepPreviewAsset);
        var effectiveFeedLoopLowAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.FeedLoopLow,
            command.FeedLoopLowAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;
        var effectiveFeedLoopMediumAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.FeedLoopMedium,
            command.FeedLoopMediumAsset,
            command.KeepPreviewAsset);
        var effectiveDetailPreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.DetailPreview,
            command.DetailPreviewAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, effectivePreviewAsset),
            SetAsset(template, TemplateAssetKind.Thumbnail, effectiveThumbnailAsset),
            SetAsset(template, TemplateAssetKind.AnimatedPreview, effectiveAnimatedPreviewAsset),
            SetAsset(template, TemplateAssetKind.FeedLoopLow, effectiveFeedLoopLowAsset),
            SetAsset(template, TemplateAssetKind.FeedLoopMedium, effectiveFeedLoopMediumAsset),
            SetAsset(template, TemplateAssetKind.DetailPreview, effectiveDetailPreviewAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }

            StampFirstPublicationIfNeeded(template, now);
            LogIncompletePublicMediaSet(template);
        }

        await StampCatalogUpsertAsync(template, now, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException) when (retryOnConcurrency)
        {
            dbContext.ChangeTracker.Clear();
            return await UpdateImageAsync(command, cancellationToken, retryOnConcurrency: false);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            var recovered = await TryRecoverUpdatedTemplateAsync(command.TemplateId, effectivePreviewAsset, cancellationToken);
            return recovered is null
                ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.UpdateConflict)
                : Result.Success(recovered);
        }

        await ClaimTemplateAssetsAfterUpdateAsync(
            template.Id,
            cancellationToken,
            PreviewAssetsForLifecycle(
                effectivePreviewAsset,
                effectiveThumbnailAsset,
                effectiveAnimatedPreviewAsset,
                effectiveFeedLoopLowAsset,
                effectiveFeedLoopMediumAsset,
                effectiveDetailPreviewAsset));
        await PublishTemplateInvalidatedAsync(
            template,
            "updated",
            isCritical: false,
            mediaChanged: obsoleteAssetUrls.Length > 0,
            cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(await MapUpdatedTemplateResponseAsync(command.TemplateId, template, cancellationToken));
    }

    public async Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, null, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);
        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Video,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements),
            Category = categoryResult.Value.Name,
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            IsQaOnly = command.IsQaOnly,
            TokenCost = command.TokenCost,
            SupportsGenerationResultInput = command.SupportsGenerationResultInput,
            RequiredInputMediaType = ParseInputMediaType(command.RequiredInputMediaType),
            RecommendedAfterImageGeneration = command.RecommendedAfterImageGeneration,
            SupportsGenerateSimilar = command.SupportsGenerateSimilar,
            DefaultVariationStrength = NormalizeVariationStrength(command.DefaultVariationStrength),
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim(),
            ReferenceVideoDurationSeconds = duration,
            CharacterOrientation = orientation,
            PreprocessingModel = command.PreprocessingModel.Trim(),
            PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt),
            KlingModel = command.KlingModel.Trim(),
            KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt),
            KeepOriginalSound = command.KeepOriginalSound,
            CreatedAtUtc = now,
            PublishedAtUtc = statusResult.Value == TemplateStatus.Active ? now : null,
            UpdatedAtUtc = now
        };

        template.LocalizedTextsJson = null;

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);
        SetPublicMediaAssets(
            template,
            command.PreviewAsset,
            command.ThumbnailAsset,
            command.AnimatedPreviewAsset,
            command.FeedLoopLowAsset,
            command.FeedLoopMediumAsset,
            command.DetailPreviewAsset);
        SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }

            StampFirstPublicationIfNeeded(template, now);
            LogIncompletePublicMediaSet(template);
        }

        dbContext.TemplateItems.Add(template);
        await ClaimTemplateAssetsAfterUpdateAsync(
            template.Id,
            cancellationToken,
            PreviewAssetsForLifecycle(
                command.PreviewAsset,
                command.ThumbnailAsset,
                command.AnimatedPreviewAsset,
                command.FeedLoopLowAsset,
                command.FeedLoopMediumAsset,
                command.DetailPreviewAsset));
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);
        await StampCatalogUpsertAsync(template, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishTemplateInvalidatedAsync(template, "created", isCritical: false, mediaChanged: true, cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        return UpdateVideoAsync(command, cancellationToken, retryOnConcurrency: true);
    }

    private async Task<Result<AdminTemplateResponse>> UpdateVideoAsync(
        UpdateVideoTemplateCommand command,
        CancellationToken cancellationToken,
        bool retryOnConcurrency)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, template.Category, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var effectivePreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.Preview,
            command.PreviewAsset,
            command.KeepPreviewAsset);
        var effectiveThumbnailAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.Thumbnail,
            command.ThumbnailAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;
        var effectiveAnimatedPreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.AnimatedPreview,
            command.AnimatedPreviewAsset,
            command.KeepPreviewAsset);
        var effectiveFeedLoopLowAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.FeedLoopLow,
            command.FeedLoopLowAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;
        var effectiveFeedLoopMediumAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.FeedLoopMedium,
            command.FeedLoopMediumAsset,
            command.KeepPreviewAsset);
        var effectiveDetailPreviewAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.DetailPreview,
            command.DetailPreviewAsset,
            command.KeepPreviewAsset) ?? effectivePreviewAsset;
        var effectiveReferenceMotionAsset = ResolveEffectiveTemplateAsset(
            template,
            TemplateAssetKind.ReferenceMotion,
            command.ReferenceMotionAsset,
            command.KeepReferenceMotionAsset);
        var (duration, orientation) = await ResolveReferenceMetadataAsync(effectiveReferenceMotionAsset, cancellationToken);

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
        template.Category = categoryResult.Value.Name;
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        if (command.IsQaOnly.HasValue)
        {
            template.IsQaOnly = command.IsQaOnly.Value;
        }
        template.TokenCost = command.TokenCost;
        template.SupportsGenerationResultInput = command.SupportsGenerationResultInput;
        template.RequiredInputMediaType = ParseInputMediaType(command.RequiredInputMediaType);
        template.RecommendedAfterImageGeneration = command.RecommendedAfterImageGeneration;
        template.SupportsGenerateSimilar = command.SupportsGenerateSimilar;
        template.DefaultVariationStrength = NormalizeVariationStrength(command.DefaultVariationStrength);
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim();
        template.ReferenceVideoDurationSeconds = duration;
        template.CharacterOrientation = orientation;
        template.PreprocessingModel = command.PreprocessingModel.Trim();
        template.PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
        template.KlingModel = command.KlingModel.Trim();
        template.KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt);
        template.KeepOriginalSound = command.KeepOriginalSound;
        template.Status = statusResult.Value;
        template.LocalizedTextsJson = null;
        var now = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, effectivePreviewAsset),
            SetAsset(template, TemplateAssetKind.Thumbnail, effectiveThumbnailAsset),
            SetAsset(template, TemplateAssetKind.AnimatedPreview, effectiveAnimatedPreviewAsset),
            SetAsset(template, TemplateAssetKind.FeedLoopLow, effectiveFeedLoopLowAsset),
            SetAsset(template, TemplateAssetKind.FeedLoopMedium, effectiveFeedLoopMediumAsset),
            SetAsset(template, TemplateAssetKind.DetailPreview, effectiveDetailPreviewAsset),
            SetAsset(template, TemplateAssetKind.ReferenceMotion, effectiveReferenceMotionAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }

            StampFirstPublicationIfNeeded(template, now);
            LogIncompletePublicMediaSet(template);
        }

        await StampCatalogUpsertAsync(template, now, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException) when (retryOnConcurrency)
        {
            dbContext.ChangeTracker.Clear();
            return await UpdateVideoAsync(command, cancellationToken, retryOnConcurrency: false);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            var recovered = await TryRecoverUpdatedTemplateAsync(command.TemplateId, effectivePreviewAsset, cancellationToken);
            return recovered is null
                ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.UpdateConflict)
                : Result.Success(recovered);
        }

        await ClaimTemplateAssetsAfterUpdateAsync(
            template.Id,
            cancellationToken,
            PreviewAssetsForLifecycle(
                effectivePreviewAsset,
                effectiveThumbnailAsset,
                effectiveAnimatedPreviewAsset,
                effectiveFeedLoopLowAsset,
                effectiveFeedLoopMediumAsset,
                effectiveDetailPreviewAsset));
        await ClaimTemplateAssetsAfterUpdateAsync(
            template.Id,
            cancellationToken,
            (effectiveReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset));
        await PublishTemplateInvalidatedAsync(
            template,
            "updated",
            isCritical: false,
            mediaChanged: obsoleteAssetUrls.Length > 0,
            cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(await MapUpdatedTemplateResponseAsync(command.TemplateId, template, cancellationToken));
    }

    public async Task<Result<AdminTemplateResponse>> ChangeStatusAsync(ChangeTemplateStatusCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (!Enum.TryParse<TemplateStatus>(command.Status, true, out var status))
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.InvalidStatus);
        }

        if (status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }

            LogIncompletePublicMediaSet(template);
        }

        var previousStatus = template.Status;
        var now = DateTime.UtcNow;
        template.Status = status;
        StampFirstPublicationIfNeeded(template, now);
        await StampCatalogUpsertAsync(template, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteTemplateAuditAsync(
            ResolveTemplateStatusAuditAction(status),
            template.Id,
            previousStatus.ToString(),
            status.ToString(),
            cancellationToken);
        await PublishTemplateInvalidatedAsync(template, "status_changed", isCritical: previousStatus != status, mediaChanged: false, cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        if (template.DeletedAtUtc is not null)
        {
            return Result.Success();
        }

        var assetUrls = CollectObsoleteAssetUrls(template.Assets.Select(asset => asset.Url));
        var cleanupResult = await DeleteTemplateAssetsAsync(assetUrls, cancellationToken);
        if (cleanupResult.IsFailure)
        {
            return cleanupResult;
        }

        var previousStatus = template.Status;
        template.Status = TemplateStatus.Archived;
        await StampCatalogDeleteAsync(template, DateTime.UtcNow, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteTemplateAuditAsync(
            "admin.content.deleted",
            template.Id,
            previousStatus.ToString(),
            TemplateStatus.Archived.ToString(),
            cancellationToken);
        await PublishTemplateInvalidatedAsync(template, "deleted", isCritical: true, mediaChanged: false, cancellationToken);

        return Result.Success();
    }

    private async Task ClaimTemplateAssetsAfterUpdateAsync(
        Guid templateId,
        CancellationToken cancellationToken,
        params (TemplateAssetCommand? Asset, TemplateMediaRole Role)[] assets)
    {
        var claimableAssets = assets
            .Where(asset => asset.Asset is not null)
            .ToArray();
        if (claimableAssets.Length == 0)
        {
            return;
        }

        const int maxAttempts = 3;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                foreach (var (asset, role) in claimableAssets)
                {
                    await mediaLifecycleService.ClaimTemplateAssetAsync(templateId, asset, role, cancellationToken);
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                return;
            }
            catch (DbUpdateConcurrencyException) when (attempt < maxAttempts)
            {
                dbContext.ChangeTracker.Clear();
            }
            catch (DbUpdateConcurrencyException)
            {
                dbContext.ChangeTracker.Clear();
                return;
            }
        }
    }

    private async Task<AdminTemplateResponse> MapUpdatedTemplateResponseAsync(
        Guid templateId,
        TemplateItem updatedTemplate,
        CancellationToken cancellationToken)
    {
        if (dbContext.Entry(updatedTemplate).State != EntityState.Detached)
        {
            return MapAdminResponse(updatedTemplate);
        }

        var reloaded = await FindTemplateAsync(templateId, cancellationToken);
        return reloaded is null ? MapAdminResponse(updatedTemplate) : MapAdminResponse(reloaded);
    }

    private async Task<AdminTemplateResponse?> TryRecoverUpdatedTemplateAsync(
        Guid templateId,
        TemplateAssetCommand? expectedPreviewAsset,
        CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.DeletedAtUtc is not null)
        {
            return null;
        }

        var preview = GetAsset(template, TemplateAssetKind.Preview);
        var expectedPreviewUrl = expectedPreviewAsset?.Url.Trim();
        if (expectedPreviewUrl is null)
        {
            return preview is null ? MapAdminResponse(template) : null;
        }

        return preview is not null
            && string.Equals(preview.Url, expectedPreviewUrl, StringComparison.OrdinalIgnoreCase)
                ? MapAdminResponse(template)
                : null;
    }

    private async Task WriteTemplateAuditAsync(
        string action,
        Guid templateId,
        string? oldValue,
        string? newValue,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null)
        {
            return;
        }

        await adminAuditLog.WriteAsync(
            new AdminAuditEntry(
                action,
                "template",
                templateId.ToString("D"),
                oldValue,
                newValue),
            cancellationToken);
    }

    private static string ResolveTemplateStatusAuditAction(TemplateStatus status)
    {
        return status switch
        {
            TemplateStatus.Active => "admin.content.approved",
            TemplateStatus.Archived => "admin.content.rejected",
            _ => "admin.content.status_changed"
        };
    }

    private static TemplateType? ParseInputMediaType(string? raw)
    {
        return Enum.TryParse<TemplateType>(raw, true, out var value) ? value : null;
    }
}
