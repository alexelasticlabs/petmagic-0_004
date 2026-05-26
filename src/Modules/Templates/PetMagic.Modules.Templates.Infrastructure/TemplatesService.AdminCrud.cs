using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
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
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            ImageModel = command.ImageModel.Trim(),
            ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken)
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
        template.TokenCost = command.TokenCost;
        template.Status = statusResult.Value;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.ImageModel = command.ImageModel.Trim();
        template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Reload the entity from the database and reapply changes
            await dbContext.Entry(template).ReloadAsync(cancellationToken);
            template.Title = command.Title.Trim();
            template.ShortDescription = command.ShortDescription.Trim();
            template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
            template.Category = categoryResult.Value.Name;
            template.Tags = SerializeTags(command.Tags);
            template.IsPremium = command.IsPremium;
            template.TokenCost = command.TokenCost;
            template.Status = statusResult.Value;
            template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
            template.ImageModel = command.ImageModel.Trim();
            template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
            template.UpdatedAtUtc = DateTime.UtcNow;

            // Try to save again
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await PublishFeedInvalidatedAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
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
            TokenCost = command.TokenCost,
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
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);
        SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken)
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

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
        template.Category = categoryResult.Value.Name;
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
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
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset),
            SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Reload the entity from the database and reapply changes
            await dbContext.Entry(template).ReloadAsync(cancellationToken);
            template.Title = command.Title.Trim();
            template.ShortDescription = command.ShortDescription.Trim();
            template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
            template.Category = categoryResult.Value.Name;
            template.Tags = SerializeTags(command.Tags);
            template.IsPremium = command.IsPremium;
            template.TokenCost = command.TokenCost;
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
            template.UpdatedAtUtc = DateTime.UtcNow;

            // Try to save again
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await PublishFeedInvalidatedAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
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
        }

        template.Status = status;
        template.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        var assetUrls = CollectObsoleteAssetUrls(template.Assets.Select(asset => asset.Url));
        var cleanupResult = await DeleteTemplateAssetsAsync(assetUrls, cancellationToken);
        if (cleanupResult.IsFailure)
        {
            return cleanupResult;
        }

        dbContext.TemplateItems.Remove(template);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success();
    }
}

