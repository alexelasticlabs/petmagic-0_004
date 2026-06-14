using System.Globalization;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
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

        var parts = rawCursor.Trim().Split(':', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2
            || !long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks)
            || ticks < DateTime.MinValue.Ticks
            || ticks > DateTime.MaxValue.Ticks
            || !Guid.TryParseExact(parts[1], "N", out var templateId))
        {
            return null;
        }

        return new PublicFeedCursor(new DateTime(ticks, DateTimeKind.Utc), templateId);
    }

    private static string FormatPublicFeedCursor(TemplateItem template)
    {
        return FormatPublicFeedCursor(template.UpdatedAtUtc, template.Id);
    }

    private static string FormatPublicFeedCursor(DateTime updatedAtUtc, Guid templateId)
    {
        return string.Create(CultureInfo.InvariantCulture, $"{updatedAtUtc.Ticks}:{templateId:N}");
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return [.. tags
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
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(6)];
    }

    private static string NormalizeCategoryName(string rawCategoryName)
    {
        return rawCategoryName.Trim();
    }

    private static string NormalizeCategoryKey(string categoryName)
    {
        return categoryName.Trim().ToUpperInvariant();
    }

    private static string ResolvePrompt(string prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
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
        return [.. assetUrls
            .Where(assetUrl => !string.IsNullOrWhiteSpace(assetUrl))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)];
    }

    private ValueTask PublishFeedInvalidatedAsync(CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(cancellationToken);
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
}
