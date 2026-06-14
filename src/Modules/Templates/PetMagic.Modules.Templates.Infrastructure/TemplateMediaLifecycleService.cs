using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateMediaLifecycleService(
    TemplatesDbContext dbContext,
    TemplatesOptions options) : ITemplateMediaLifecycleService
{
    public async Task RegisterTemporaryUploadAsync(TemplateAssetCommand asset, TemplateMediaRole role, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var record = await FindByUrlAsync(asset.Url, cancellationToken);

        if (record is null)
        {
            record = new TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                Url = asset.Url,
                UploadedAtUtc = now
            };

            dbContext.TemplateMediaRecords.Add(record);
        }

        ApplyAssetMetadata(record, asset, role);
        record.LifecycleState = TemplateMediaLifecycleState.Temporary;
        record.TemplateId = null;
        record.GenerationJobId = null;
        record.ExpiresAtUtc = now.AddMinutes(options.TemporaryUploadRetentionMinutes);
        record.AttachedAtUtc = null;
        record.DeletedAtUtc = null;
        record.LastCleanupAttemptAtUtc = null;
        record.FailureCode = null;
        record.FailureMessage = null;
    }

    public async Task ClaimTemplateAssetAsync(Guid templateId, TemplateAssetCommand? asset, TemplateMediaRole role, CancellationToken cancellationToken)
    {
        if (asset is null)
        {
            return;
        }

        var now = DateTime.UtcNow;
        var record = await FindByUrlAsync(asset.Url, cancellationToken);

        if (record is null)
        {
            record = new TemplateMediaRecord
            {
                Id = Guid.NewGuid(),
                Url = asset.Url,
                UploadedAtUtc = now
            };

            dbContext.TemplateMediaRecords.Add(record);
        }

        ApplyAssetMetadata(record, asset, role);
        record.LifecycleState = TemplateMediaLifecycleState.AttachedToTemplate;
        record.TemplateId = templateId;
        record.GenerationJobId = null;
        record.ExpiresAtUtc = null;
        record.AttachedAtUtc = now;
        record.DeletedAtUtc = null;
        record.LastCleanupAttemptAtUtc = null;
        record.FailureCode = null;
        record.FailureMessage = null;
    }

    public async Task MarkDeletedAsync(string url, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return;
        }

        var record = await FindByUrlAsync(url, cancellationToken);
        if (record is null)
        {
            return;
        }

        record.LifecycleState = TemplateMediaLifecycleState.Deleted;
        record.IsDeleted = true;
        record.TemplateId = null;
        record.GenerationJobId = null;
        record.ExpiresAtUtc = null;
        record.AttachedAtUtc = null;
        record.DeletedAtUtc = DateTime.UtcNow;
        record.LastCleanupAttemptAtUtc = record.DeletedAtUtc;
        record.FailureCode = null;
        record.FailureMessage = null;
    }

    public async Task MarkCleanupFailureAsync(string url, string errorCode, string errorMessage, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return;
        }

        var record = await FindByUrlAsync(url, cancellationToken);
        if (record is null)
        {
            return;
        }

        record.LifecycleState = TemplateMediaLifecycleState.CleanupFailed;
        record.TemplateId = null;
        record.GenerationJobId = null;
        record.AttachedAtUtc = null;
        record.ExpiresAtUtc ??= DateTime.UtcNow;
        record.LastCleanupAttemptAtUtc = DateTime.UtcNow;
        record.FailureCode = errorCode;
        record.FailureMessage = errorMessage;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        return dbContext.SaveChangesAsync(cancellationToken);
    }

    private Task<TemplateMediaRecord?> FindByUrlAsync(string url, CancellationToken cancellationToken)
    {
        return dbContext.TemplateMediaRecords
            .FirstOrDefaultAsync(x => x.Url == url, cancellationToken);
    }

    private void ApplyAssetMetadata(TemplateMediaRecord record, TemplateAssetCommand asset, TemplateMediaRole role)
    {
        record.Url = asset.Url;
        record.StoragePath = ResolveManagedStoragePath(asset.Url) ?? asset.Url;
        record.FileName = asset.FileName;
        record.ContentType = asset.ContentType;
        record.FileSizeBytes = asset.FileSizeBytes;
        record.Role = role;
        record.MediaType = asset.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase) ? "video" : "image";
        record.SourceType = role is TemplateMediaRole.GenerationOutputImage or TemplateMediaRole.GenerationOutputVideo
            ? "generation_result"
            : "user_upload";
    }

    private string? ResolveManagedStoragePath(string assetUrl)
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
            return relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase)
                ? relativePath
                : null;
        }

        if (!options.R2.IsConfigured)
        {
            return null;
        }

        var r2BaseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(r2BaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var storageKey = candidate[r2BaseUrl.Length..].TrimStart('/');
        var objectKeyPrefix = NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix);
        return storageKey.StartsWith($"{objectKeyPrefix}/", StringComparison.OrdinalIgnoreCase)
            ? storageKey
            : null;
    }

    private static string NormalizeObjectKeyPrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }
}
