using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

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
                logger.LogWarning(
                    "Support attachment cleanup failed. AttachmentId={AttachmentId} ErrorCode={ErrorCode}",
                    attachment.Id,
                    deleteResult.Error.Code);
                continue;
            }

            attachment.IsDeleted = true;
            attachment.DeletedAtUtc = now;
            attachment.FileUrl = string.Empty;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}

