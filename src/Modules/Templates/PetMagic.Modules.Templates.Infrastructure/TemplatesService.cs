using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatesService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IMediaMetadataReader metadataReader,
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService) : ITemplatesService
{
    private static readonly string[] FunnyKeywords = ["funny", "meme", "viral", "dance", "lol", "cute"];

    public async Task<Result<IReadOnlyList<AdminTemplateListItemResponse>>> ListAdminAsync(TemplateType? type, TemplateStatus? status, CancellationToken cancellationToken)
    {
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => !status.HasValue || x.Status == status.Value)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateListItemResponse>>(items.Select(MapAdminListItem).ToArray());
    }

    public async Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        return template is null
            ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken)
    {
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
            Category = command.Category.Trim(),
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
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

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.Category = command.Category.Trim();
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
        template.Status = statusResult.Value;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
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
        await dbContext.SaveChangesAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
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
            Category = command.Category.Trim(),
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
        template.Category = command.Category.Trim();
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
        await dbContext.SaveChangesAsync(cancellationToken);
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

        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => string.IsNullOrWhiteSpace(category) || string.Equals(x.Category, category.Trim(), StringComparison.OrdinalIgnoreCase))
            .Where(x => !premiumOnly.HasValue || !premiumOnly.Value || x.IsPremium)
            .OrderBy(x => x.IsPremium)
            .ThenBy(x => x.Title)
            .ToArrayAsync(cancellationToken);

        var filtered = items
            .Where(x => normalizedTags.Length == 0 || normalizedTags.All(tag => DeserializeTags(x.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
            .Select(MapPublicListItem)
            .ToArray();

        return Result.Success<IReadOnlyList<PublicTemplateListItemResponse>>(filtered);
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.Status != TemplateStatus.Active)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(template));
    }

    private Result ValidateVideoModels(string preprocessingModel, string klingModel)
    {
        if (!options.AllowedPreprocessingModels.Contains(preprocessingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidPreprocessingModel);
        }

        if (!options.AllowedKlingModels.Contains(klingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidKlingModel);
        }

        return Result.Success();
    }

    private Result ValidateActivation(TemplateItem template)
    {
        if (GetAsset(template, TemplateAssetKind.Preview) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (template.TemplateType == TemplateType.Video)
        {
            if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceMotion);
            }

            if (!template.ReferenceVideoDurationSeconds.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceDuration);
            }

            if (!template.CharacterOrientation.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingCharacterOrientation);
            }
        }

        return Result.Success();
    }

    private static Result<TemplateStatus> ResolveRequestedStatus(string? rawStatus, TemplateStatus fallback)
    {
        if (string.IsNullOrWhiteSpace(rawStatus))
        {
            return Result.Success(fallback);
        }

        return Enum.TryParse<TemplateStatus>(rawStatus, true, out var status)
            ? Result.Success(status)
            : Result.Failure<TemplateStatus>(TemplatesErrors.InvalidStatus);
    }

    private async Task<(double? duration, CharacterOrientation? orientation)> ResolveReferenceMetadataAsync(TemplateAssetCommand? asset, CancellationToken cancellationToken)
    {
        if (asset is null)
        {
            return (null, null);
        }

        var durationResult = await metadataReader.GetVideoDurationSecondsAsync(asset, cancellationToken);
        if (durationResult.IsFailure || !durationResult.Value.HasValue)
        {
            return (null, null);
        }

        var duration = Math.Round(durationResult.Value.Value, 2, MidpointRounding.AwayFromZero);
        var orientation = duration <= 10 ? CharacterOrientation.Image : CharacterOrientation.Video;
        return (duration, orientation);
    }

    private Task<TemplateItem?> FindTemplateAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return tags
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string SerializeTags(IEnumerable<string> tags)
    {
        return string.Join(',', NormalizeTags(tags));
    }

    private static string[] DeserializeTags(string tags)
    {
        return NormalizeTags(tags.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string ResolvePrompt(string prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    private async Task CleanupObsoleteMediaAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                await mediaLifecycleService.MarkCleanupFailureAsync(assetUrl, deleteResult.Error.Code, deleteResult.Error.Message, cancellationToken);
                continue;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);
    }

    private async Task<Result> DeleteTemplateAssetsAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                return deleteResult;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    private static string[] CollectObsoleteAssetUrls(IEnumerable<string?> assetUrls)
    {
        return assetUrls
            .Where(assetUrl => !string.IsNullOrWhiteSpace(assetUrl))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string? SetAsset(TemplateItem template, TemplateAssetKind assetKind, TemplateAssetCommand? asset)
    {
        var existing = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        if (asset is null)
        {
            if (existing is not null)
            {
                var removedUrl = existing.Url;
                template.Assets.Remove(existing);
                return removedUrl;
            }

            return null;
        }

        if (existing is null)
        {
            existing = new TemplateAsset
            {
                Id = Guid.NewGuid(),
                TemplateId = template.Id,
                AssetKind = assetKind
            };
            template.Assets.Add(existing);
        }

        var obsoleteUrl = !string.IsNullOrWhiteSpace(existing.Url)
            && !string.Equals(existing.Url, asset.Url, StringComparison.OrdinalIgnoreCase)
                ? existing.Url
                : null;

        existing.Url = asset.Url;
        existing.FileName = asset.FileName;
        existing.ContentType = asset.ContentType;
        existing.FileSizeBytes = asset.FileSizeBytes;
        existing.DurationSeconds = asset.DurationSeconds;

        return obsoleteUrl;
    }

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(asset.Url, asset.FileName, asset.ContentType, asset.FileSizeBytes, asset.DurationSeconds);
    }

    private static AdminTemplateListItemResponse MapAdminListItem(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }

    private static AdminTemplateResponse MapAdminResponse(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            GetAsset(template, TemplateAssetKind.ReferenceMotion),
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.PreprocessingModel,
            template.PreprocessingPrompt,
            template.KlingModel,
            template.KlingPrompt,
            template.KeepOriginalSound,
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }

    private static PublicTemplateListItemResponse MapPublicListItem(TemplateItem template)
    {
        return new PublicTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.ReferenceVideoDurationSeconds);
    }

    private static PublicTemplateResponse MapPublicResponse(TemplateItem template)
    {
        return new PublicTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds);
    }

    private static TemplatePromoBadgeMode ParsePromoBadgeMode(string raw)
    {
        return Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out var mode)
            ? mode
            : TemplatePromoBadgeMode.Auto;
    }

    private static string? ResolveEffectivePromoBadge(TemplateItem template, DateTime utcNow)
    {
        if (template.PromoBadgeMode != TemplatePromoBadgeMode.Auto)
        {
            return template.PromoBadgeMode.ToString();
        }

        if (template.CreatedAtUtc >= utcNow.AddDays(-30))
        {
            return TemplatePromoBadgeMode.New.ToString();
        }

        if (template.Status == TemplateStatus.Active && template.UpdatedAtUtc >= utcNow.AddDays(-14))
        {
            return TemplatePromoBadgeMode.Trending.ToString();
        }

        if (template.Status == TemplateStatus.Active && (template.IsPremium || template.TokenCost >= 60))
        {
            return TemplatePromoBadgeMode.Popular.ToString();
        }

        var searchText = string.Join(' ', [
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Tags,
            template.MusicDescription ?? string.Empty,
            template.KlingPrompt ?? string.Empty
        ]).ToLowerInvariant();

        return FunnyKeywords.Any(keyword => searchText.Contains(keyword, StringComparison.Ordinal))
            ? TemplatePromoBadgeMode.Funny.ToString()
            : null;
    }
}
