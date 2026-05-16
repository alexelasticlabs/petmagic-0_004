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

    private static void ApplyAssetMetadata(TemplateMediaRecord record, TemplateAssetCommand asset, TemplateMediaRole role)
    {
        record.Url = asset.Url;
        record.FileName = asset.FileName;
        record.ContentType = asset.ContentType;
        record.FileSizeBytes = asset.FileSizeBytes;
        record.Role = role;
    }
}
