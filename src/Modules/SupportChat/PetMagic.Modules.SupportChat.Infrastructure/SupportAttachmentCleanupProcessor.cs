using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportAttachmentCleanupProcessor(
    SupportChatDbContext dbContext,
    ISupportAttachmentStorage attachmentStorage,
    SupportAttachmentStorageOptions options,
    ILogger<SupportAttachmentCleanupProcessor> logger)
{
    public async Task<bool> CleanupExpiredBatchAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var batchSize = Math.Max(1, options.CleanupBatchSize);
        var attachments = await dbContext.SupportMessageAttachments
            .Where(attachment => !attachment.IsDeleted && attachment.ExpiresAtUtc <= now)
            .OrderBy(attachment => attachment.ExpiresAtUtc)
            .Take(batchSize)
            .ToListAsync(cancellationToken);
        if (attachments.Count == 0)
        {
            return false;
        }

        foreach (var attachment in attachments)
        {
            var deleteResult = await attachmentStorage.DeleteAsync(attachment.FileUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                var safeErrorCode = SafeCleanupErrorCode(deleteResult.Error.Code);
                logger.LogWarning(
                    "Support attachment cleanup failed. AttachmentIdHash={AttachmentIdHash} ErrorCode={ErrorCode}",
                    SafeLogValues.StableHash(attachment.Id.ToString("D")),
                    safeErrorCode);
                continue;
            }

            attachment.IsDeleted = true;
            attachment.DeletedAtUtc = now;
            attachment.FileUrl = string.Empty;
            attachment.FileName = "attachment";
            attachment.MimeType = string.Empty;
            attachment.SizeBytes = 0;
            attachment.DurationSeconds = null;
            attachment.Width = null;
            attachment.Height = null;
            attachment.StorageKey = null;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private static string SafeCleanupErrorCode(string? code)
    {
        var trimmed = code?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return SupportChatErrors.AttachmentStorageFailed.Code;
        }

        var sanitized = SafeLogValues.SanitizeText(trimmed, 128);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized
            : SupportChatErrors.AttachmentStorageFailed.Code;
    }
}
