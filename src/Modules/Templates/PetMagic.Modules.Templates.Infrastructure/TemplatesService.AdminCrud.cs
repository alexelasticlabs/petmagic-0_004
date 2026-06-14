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
            UpdatedAtUtc = now
        };

        template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
            template.Title,
            template.ShortDescription,
            DeserializeRequirements(template.PetPhotoRequirements),
            template.ImagePrompt,
            template.PreprocessingPrompt,
            template.KlingPrompt,
            options.SupportedLocalizationLocales,
            options.SourceLocalizationLocale,
            httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
            cancellationToken);

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
        await StampCatalogUpsertAsync(template, now, cancellationToken);
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
        await StampCatalogUpsertAsync(template, now, cancellationToken);

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
            template.SupportsGenerationResultInput = command.SupportsGenerationResultInput;
            template.RequiredInputMediaType = ParseInputMediaType(command.RequiredInputMediaType);
            template.RecommendedAfterImageGeneration = command.RecommendedAfterImageGeneration;
            template.SupportsGenerateSimilar = command.SupportsGenerateSimilar;
            template.DefaultVariationStrength = NormalizeVariationStrength(command.DefaultVariationStrength);
            template.Status = statusResult.Value;
            template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
            template.ImageModel = command.ImageModel.Trim();
            template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
            template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
                template.Title,
                template.ShortDescription,
                DeserializeRequirements(template.PetPhotoRequirements),
                template.ImagePrompt,
                template.PreprocessingPrompt,
                template.KlingPrompt,
                options.SupportedLocalizationLocales,
                options.SourceLocalizationLocale,
                httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
                cancellationToken);

            var staleChanges = dbContext.ChangeTracker
                .Entries<TemplateCatalogChange>()
                .Where(entry => entry.State == EntityState.Added)
                .ToArray();
            foreach (var staleChange in staleChanges)
            {
                staleChange.State = EntityState.Detached;
            }

            await StampCatalogUpsertAsync(template, DateTime.UtcNow, cancellationToken);

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
            UpdatedAtUtc = now
        };

        template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
            template.Title,
            template.ShortDescription,
            DeserializeRequirements(template.PetPhotoRequirements),
            template.ImagePrompt,
            template.PreprocessingPrompt,
            template.KlingPrompt,
            options.SupportedLocalizationLocales,
            options.SourceLocalizationLocale,
            httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
            cancellationToken);

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
        await StampCatalogUpsertAsync(template, now, cancellationToken);
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
        template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
            template.Title,
            template.ShortDescription,
            DeserializeRequirements(template.PetPhotoRequirements),
            template.ImagePrompt,
            template.PreprocessingPrompt,
            template.KlingPrompt,
            options.SupportedLocalizationLocales,
            options.SourceLocalizationLocale,
            httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
            cancellationToken);
        var now = DateTime.UtcNow;

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
        await StampCatalogUpsertAsync(template, now, cancellationToken);

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
            template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
                template.Title,
                template.ShortDescription,
                DeserializeRequirements(template.PetPhotoRequirements),
                template.ImagePrompt,
                template.PreprocessingPrompt,
                template.KlingPrompt,
                options.SupportedLocalizationLocales,
                options.SourceLocalizationLocale,
                httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
                cancellationToken);

            var staleChanges = dbContext.ChangeTracker
                .Entries<TemplateCatalogChange>()
                .Where(entry => entry.State == EntityState.Added)
                .ToArray();
            foreach (var staleChange in staleChanges)
            {
                staleChange.State = EntityState.Detached;
            }

            await StampCatalogUpsertAsync(template, DateTime.UtcNow, cancellationToken);

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

        var previousStatus = template.Status;
        template.Status = status;
        await StampCatalogUpsertAsync(template, DateTime.UtcNow, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteTemplateAuditAsync(
            ResolveTemplateStatusAuditAction(status),
            template.Id,
            previousStatus.ToString(),
            status.ToString(),
            cancellationToken);
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
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success();
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
