using System.Globalization;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private const int TemplateAssetFileNameMaxLength = 256;
    private const int TemplateAssetContentTypeMaxLength = 128;

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

    private Result ValidateImageModel(string imageModel)
    {
        if (!options.AllowedImageModels.Contains(imageModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidImageModel);
        }

        return Result.Success();
    }

    private Result ValidateActivation(TemplateItem template)
    {
        if (string.IsNullOrWhiteSpace(template.Title)
            || string.IsNullOrWhiteSpace(template.ShortDescription)
            || string.IsNullOrWhiteSpace(template.Category)
            || template.TokenCost <= 0
            || DeserializeRequirements(template.PetPhotoRequirements).Length == 0)
        {
            return Result.Failure(TemplatesErrors.MissingActivationMetadata);
        }

        if (GetAsset(template, TemplateAssetKind.Preview) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (GetAsset(template, TemplateAssetKind.Thumbnail) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (GetAsset(template, TemplateAssetKind.AnimatedPreview) is null
            && GetAsset(template, TemplateAssetKind.FeedLoopLow) is null
            && GetAsset(template, TemplateAssetKind.FeedLoopMedium) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (template.TemplateType == TemplateType.Video)
        {
            var modelCheck = ValidateVideoModels(template.PreprocessingModel, template.KlingModel);
            if (modelCheck.IsFailure)
            {
                return modelCheck;
            }

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

            return Result.Success();
        }

        if (string.IsNullOrWhiteSpace(template.ImageModel))
        {
            return Result.Failure(TemplatesErrors.MissingImageModel);
        }

        if (!options.AllowedImageModels.Contains(template.ImageModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidImageModel);
        }

        return Result.Success();
    }

    private void LogIncompletePublicMediaSet(TemplateItem template)
    {
        if (logger is null)
        {
            return;
        }

        var missing = new List<string>();
        if (GetAsset(template, TemplateAssetKind.AnimatedPreview) is null)
        {
            missing.Add("animatedPreview");
        }

        if (GetAsset(template, TemplateAssetKind.FeedLoopMedium) is null)
        {
            missing.Add("feedLoopMedium");
        }

        if (GetAsset(template, TemplateAssetKind.DetailPreview) is null)
        {
            missing.Add("detailPreview");
        }

        if (missing.Count == 0)
        {
            return;
        }

        logger.LogWarning(
            "Template activated with incomplete public media variants. TemplateIdHash={TemplateIdHash} MissingMediaVariants={MissingMediaVariants}",
            TemplateLogSanitizer.SafeId(template.Id),
            string.Join(",", missing));
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

    private static void SetPublicMediaAssets(
        TemplateItem template,
        TemplateAssetCommand? previewAsset,
        TemplateAssetCommand? thumbnailAsset,
        TemplateAssetCommand? animatedPreviewAsset,
        TemplateAssetCommand? feedLoopLowAsset,
        TemplateAssetCommand? feedLoopMediumAsset,
        TemplateAssetCommand? detailPreviewAsset)
    {
        SetAsset(template, TemplateAssetKind.Thumbnail, thumbnailAsset ?? previewAsset);
        SetAsset(template, TemplateAssetKind.AnimatedPreview, animatedPreviewAsset);
        SetAsset(template, TemplateAssetKind.FeedLoopLow, feedLoopLowAsset ?? previewAsset);
        SetAsset(template, TemplateAssetKind.FeedLoopMedium, feedLoopMediumAsset);
        SetAsset(template, TemplateAssetKind.DetailPreview, detailPreviewAsset ?? previewAsset);
    }

    private static (TemplateAssetCommand? Asset, TemplateMediaRole Role)[] PreviewAssetsForLifecycle(
        TemplateAssetCommand? previewAsset,
        TemplateAssetCommand? thumbnailAsset,
        TemplateAssetCommand? animatedPreviewAsset,
        TemplateAssetCommand? feedLoopLowAsset,
        TemplateAssetCommand? feedLoopMediumAsset,
        TemplateAssetCommand? detailPreviewAsset)
    {
        var assets = new[]
        {
            previewAsset,
            thumbnailAsset ?? previewAsset,
            animatedPreviewAsset,
            feedLoopLowAsset ?? previewAsset,
            feedLoopMediumAsset,
            detailPreviewAsset ?? previewAsset
        };

        return assets
            .Where(asset => asset is not null)
            .DistinctBy(asset => asset!.Url.Trim())
            .Select(asset => (asset, TemplateMediaRole.PreviewAsset))
            .ToArray();
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

    private async Task<Result<TemplateCategory>> EnsureTemplateCategoryAsync(string rawCategoryName, string? currentCategoryName, CancellationToken cancellationToken)
    {
        var categoryName = NormalizeCategoryName(rawCategoryName);
        var normalizedName = NormalizeCategoryKey(categoryName);

        var category = await dbContext.TemplateCategories
            .FirstOrDefaultAsync(x => x.NormalizedName == normalizedName, cancellationToken);

        if (category is null)
        {
            var now = DateTime.UtcNow;
            category = new TemplateCategory
            {
                Id = Guid.NewGuid(),
                Name = categoryName,
                NormalizedName = normalizedName,
                IsArchived = false,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };

            dbContext.TemplateCategories.Add(category);
            return Result.Success(category);
        }

        if (category.IsArchived && !string.Equals(category.Name, currentCategoryName, StringComparison.Ordinal))
        {
            return Result.Failure<TemplateCategory>(TemplatesErrors.CategoryArchived);
        }

        return Result.Success(category);
    }

    private async Task<Result<string>> ResolveTemplateCategoryNameAsync(
        string rawCategoryName,
        string? currentCategoryName,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(rawCategoryName))
        {
            return Result.Success(string.Empty);
        }

        var categoryResult = await EnsureTemplateCategoryAsync(rawCategoryName, currentCategoryName, cancellationToken);
        return categoryResult.IsFailure
            ? Result.Failure<string>(categoryResult.Error)
            : Result.Success(categoryResult.Value.Name);
    }

    private Task<TemplateItem?> FindTemplateAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);
    }

    private static int NormalizePublicFeedTake(int? take)
    {
        if (!take.HasValue || take.Value <= 0)
        {
            return PublicFeedDefaultTake;
        }

        return Math.Min(take.Value, PublicFeedMaxTake);
    }

    private static int NormalizePublicCatalogPage(int? page)
    {
        if (!page.HasValue || page.Value <= 0)
        {
            return PublicCatalogDefaultPage;
        }

        return page.Value;
    }

    private static int NormalizePublicCatalogPageSize(int? pageSize)
    {
        if (!pageSize.HasValue || pageSize.Value <= 0)
        {
            return PublicCatalogDefaultPageSize;
        }

        return Math.Min(pageSize.Value, PublicCatalogMaxPageSize);
    }

    private static string? NormalizePublicCategoryFilter(string? category)
    {
        return NormalizePublicTextFilter(category, PublicCategoryFilterMaxLength);
    }

    private static string? NormalizePublicSearchFilter(string? search)
    {
        return NormalizePublicTextFilter(search, PublicSearchFilterMaxLength);
    }

    private static string? NormalizePublicRandomAccess(string? access)
    {
        if (string.IsNullOrWhiteSpace(access))
        {
            return null;
        }

        var normalized = access.Trim().ToLowerInvariant();
        return normalized is "all" or "free" or "premium"
            ? normalized
            : null;
    }

    private static string? NormalizePublicTextFilter(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }

    private static string[] NormalizePublicTagFilters(IEnumerable<string>? tags)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        if (normalizedTags.Length > PublicTagFilterMaxCount
            || normalizedTags.Any(tag => tag.Length > PublicTagFilterMaxLength))
        {
            return [PublicImpossibleTagFilter];
        }

        return normalizedTags;
    }

    private async Task<long> GetCurrentCatalogVersionAsync(CancellationToken cancellationToken)
    {
        var snapshot = await GetCurrentCatalogVersionSnapshotAsync(cancellationToken);
        return snapshot.Version;
    }

    private async Task<CatalogVersionSnapshot> GetCurrentCatalogVersionSnapshotAsync(CancellationToken cancellationToken)
    {
        var latestChange = await dbContext.TemplateCatalogChanges
            .AsNoTracking()
            .OrderByDescending(change => change.Version)
            .Select(change => new CatalogVersionSnapshot(change.Version, change.UpdatedAtUtc))
            .FirstOrDefaultAsync(cancellationToken);

        if (latestChange is not null)
        {
            return latestChange;
        }

        var latestTemplate = await dbContext.TemplateItems
            .AsNoTracking()
            .OrderByDescending(template => template.Version)
            .Select(template => new CatalogVersionSnapshot(template.Version, null))
            .FirstOrDefaultAsync(cancellationToken);

        return latestTemplate ?? new CatalogVersionSnapshot(0L, null);
    }

    private sealed record CatalogVersionSnapshot(long Version, DateTime? UpdatedAtUtc);

    private async Task<long> GetNextCatalogVersionAsync(CancellationToken cancellationToken)
    {
        var currentVersion = await GetCurrentCatalogVersionAsync(cancellationToken);
        return currentVersion + 1;
    }

    private async Task StampCatalogUpsertAsync(TemplateItem template, DateTime updatedAtUtc, CancellationToken cancellationToken)
    {
        var nextVersion = await GetNextCatalogVersionAsync(cancellationToken);
        template.Version = nextVersion;
        template.UpdatedAtUtc = updatedAtUtc;
        dbContext.TemplateCatalogChanges.Add(new TemplateCatalogChange
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            Version = nextVersion,
            ChangeType = TemplateCatalogChangeType.Upsert,
            UpdatedAtUtc = updatedAtUtc,
        });
    }

    private static void StampFirstPublicationIfNeeded(TemplateItem template, DateTime publishedAtUtc)
    {
        if (template.Status == TemplateStatus.Active && template.PublishedAtUtc is null)
        {
            template.PublishedAtUtc = publishedAtUtc;
        }
    }

    private static DateTime ResolvePublicFeedSortAtUtc(DateTime? publishedAtUtc, DateTime createdAtUtc)
    {
        return publishedAtUtc ?? createdAtUtc;
    }

    private async Task StampCatalogDeleteAsync(TemplateItem template, DateTime updatedAtUtc, CancellationToken cancellationToken)
    {
        var nextVersion = await GetNextCatalogVersionAsync(cancellationToken);
        template.Version = nextVersion;
        template.UpdatedAtUtc = updatedAtUtc;
        template.DeletedAtUtc = updatedAtUtc;
        dbContext.TemplateCatalogChanges.Add(new TemplateCatalogChange
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            Version = nextVersion,
            ChangeType = TemplateCatalogChangeType.Delete,
            UpdatedAtUtc = updatedAtUtc,
        });
    }

    private static PublicFeedCursor? TryParsePublicFeedCursor(string? rawCursor)
    {
        if (string.IsNullOrWhiteSpace(rawCursor))
        {
            return null;
        }

        var parts = rawCursor.Trim().Split(':', 3, StringSplitOptions.TrimEntries);
        if (parts.Length is not (2 or 3)
            || !long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks)
            || ticks < DateTime.MinValue.Ticks
            || ticks > DateTime.MaxValue.Ticks
            || !Guid.TryParseExact(parts[^1], "N", out var templateId))
        {
            return null;
        }

        if (parts.Length == 3)
        {
            if (!long.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedVersion)
                || parsedVersion < 0)
            {
                return null;
            }
        }

        return new PublicFeedCursor(new DateTime(ticks, DateTimeKind.Utc), templateId);
    }

    private static string FormatPublicFeedCursor(TemplateItem template)
    {
        return FormatPublicFeedCursor(ResolvePublicFeedSortAtUtc(template.PublishedAtUtc, template.CreatedAtUtc), template.Id);
    }

    private static string FormatPublicFeedCursor(DateTime publishedAtUtc, Guid templateId)
    {
        return string.Create(CultureInfo.InvariantCulture, $"{publishedAtUtc.Ticks}:{templateId:N}");
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return [.. tags
            .SelectMany(tag => tag.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private static string SerializeTags(IEnumerable<string> tags)
    {
        return string.Join(',', NormalizeTags(tags));
    }

    private static string[] DeserializeTags(string? tags)
    {
        if (string.IsNullOrWhiteSpace(tags))
        {
            return [];
        }

        return NormalizeTags(tags.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string? SerializeRequirements(IEnumerable<string>? requirements)
    {
        var normalized = NormalizeRequirements(requirements ?? []);
        return normalized.Length == 0 ? null : string.Join('\n', normalized);
    }

    private static string[] DeserializeRequirements(string? requirements)
    {
        if (string.IsNullOrWhiteSpace(requirements))
        {
            return [];
        }

        return NormalizeRequirements(requirements.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string[] NormalizeRequirements(IEnumerable<string> requirements)
    {
        return [.. requirements
            .Select(requirement => requirement.Trim())
            .Where(requirement => !string.IsNullOrWhiteSpace(requirement))
            .Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private static string NormalizeCategoryName(string rawCategoryName)
    {
        return CollapseWhitespace(rawCategoryName);
    }

    private static string NormalizeCategoryKey(string categoryName)
    {
        return CollapseWhitespace(categoryName).ToUpperInvariant();
    }

    private static string CollapseWhitespace(string value)
    {
        return string.Join(' ', value
            .Trim()
            .Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries));
    }

    private static string ResolvePrompt(string prompt, string fallback)
    {
        var resolved = string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
        return resolved;
    }

    private static string NormalizeAssetText(string value, int maxLength, string fallback)
    {
        var normalized = string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static long? NormalizeFileSizeBytes(long? value)
    {
        return value is > 0 ? value : null;
    }

    private static string NormalizeVariationStrength(string? raw)
    {
        return string.Equals(raw, "low", StringComparison.OrdinalIgnoreCase)
            || string.Equals(raw, "high", StringComparison.OrdinalIgnoreCase)
            ? raw!.ToLowerInvariant()
            : "medium";
    }

    private async Task CleanupObsoleteMediaAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            if (await IsAssetUrlReferencedByLiveTemplateAsync(assetUrl, excludedTemplateId: null, cancellationToken))
            {
                continue;
            }

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

    private async Task<Result> DeleteTemplateAssetsAsync(
        string[] assetUrls,
        Guid deletedTemplateId,
        CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            if (await IsAssetUrlReferencedByLiveTemplateAsync(assetUrl, deletedTemplateId, cancellationToken))
            {
                continue;
            }

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
        return [.. assetUrls
            .Where(assetUrl => !string.IsNullOrWhiteSpace(assetUrl))
            .Cast<string>()
            .Select(NormalizeAssetUrl)
            .Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private Task<bool> IsAssetUrlReferencedByLiveTemplateAsync(
        string assetUrl,
        Guid? excludedTemplateId,
        CancellationToken cancellationToken)
    {
        var normalizedUrl = NormalizeAssetUrl(assetUrl);
        return dbContext.TemplateAssets
            .AsNoTracking()
            .AnyAsync(
                asset => asset.Template.DeletedAtUtc == null
                    && (!excludedTemplateId.HasValue || asset.TemplateId != excludedTemplateId.Value)
                    && asset.Url.Trim() == normalizedUrl,
                cancellationToken);
    }

    private static string NormalizeAssetUrl(string assetUrl)
    {
        return assetUrl.Trim();
    }

    private static TemplateAssetCommand? ResolveEffectiveTemplateAsset(
        TemplateItem template,
        TemplateAssetKind assetKind,
        TemplateAssetCommand? requestedAsset,
        bool keepExistingAsset)
    {
        if (requestedAsset is not null)
        {
            return requestedAsset;
        }

        return keepExistingAsset
            ? ToTemplateAssetCommand(template.Assets.FirstOrDefault(asset => asset.AssetKind == assetKind))
            : null;
    }

    private static TemplateAssetCommand? ToTemplateAssetCommand(TemplateAsset? asset)
    {
        return asset is null
            ? null
            : new TemplateAssetCommand(
                asset.Url,
                asset.FileName ?? string.Empty,
                asset.ContentType ?? string.Empty,
                asset.FileSizeBytes,
                asset.DurationSeconds);
    }

    private ValueTask PublishFeedInvalidatedAsync(CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(cancellationToken);
    }

    private async ValueTask PublishTemplateInvalidatedAsync(
        TemplateItem template,
        string reason,
        bool isCritical,
        bool mediaChanged,
        CancellationToken cancellationToken)
    {
        var decision = await _visibilityPolicy.EvaluatePublicAsync(
            template,
            new TemplateVisibilityContext(),
            cancellationToken);

        await templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(
            new TemplateFeedInvalidationPayload(
                TemplateFeedInvalidationScopes.Template,
                TemplateId: template.Id,
                Category: template.Category,
                MediaVersion: mediaChanged ? template.Version : null,
                TemplateType: template.TemplateType.ToString(),
                IsPubliclyVisible: decision.IsVisible,
                IsCritical: isCritical || !decision.IsVisible,
                Reason: reason),
            cancellationToken);
    }

    private ValueTask PublishTemplateOfTheDayInvalidatedAsync(
        string reason,
        CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(
            new TemplateFeedInvalidationPayload(
                TemplateFeedInvalidationScopes.TemplateOfTheDay,
                Reason: reason),
            cancellationToken);
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

        var normalizedAssetUrl = NormalizeAssetUrl(asset.Url);
        var obsoleteUrl = !string.IsNullOrWhiteSpace(existing.Url)
            && !string.Equals(NormalizeAssetUrl(existing.Url), normalizedAssetUrl, StringComparison.OrdinalIgnoreCase)
                ? existing.Url
                : null;

        existing.Url = normalizedAssetUrl;
        existing.FileName = NormalizeAssetText(asset.FileName, TemplateAssetFileNameMaxLength, "asset");
        existing.ContentType = NormalizeAssetText(asset.ContentType, TemplateAssetContentTypeMaxLength, "application/octet-stream");
        existing.FileSizeBytes = NormalizeFileSizeBytes(asset.FileSizeBytes);
        existing.DurationSeconds = asset.DurationSeconds;

        return obsoleteUrl;
    }
}
