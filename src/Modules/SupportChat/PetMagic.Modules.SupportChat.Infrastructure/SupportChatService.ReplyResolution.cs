using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private async Task<Result<ResolvedReplyTarget?>> ResolveReplyTargetAsync(
        Guid conversationId,
        Guid? replyToMessageId,
        CancellationToken cancellationToken)
    {
        if (!replyToMessageId.HasValue)
        {
            return Result.Success<ResolvedReplyTarget?>(null);
        }

        var sourceMessage = await supportChatDbContext.ConversationMessages
            .AsNoTracking()
            .Include(message => message.Attachments)
            .FirstOrDefaultAsync(
                message => message.Id == replyToMessageId.Value && message.ConversationId == conversationId,
                cancellationToken);
        if (sourceMessage is null)
        {
            return Result.Failure<ResolvedReplyTarget?>(MessageNotFound);
        }

        return Result.Success<ResolvedReplyTarget?>(
            new ResolvedReplyTarget(
                sourceMessage.Id,
                BuildReplyPreview(sourceMessage)));
    }

    private static string BuildReplyPreview(ConversationMessage sourceMessage)
    {
        var trimmedBody = sourceMessage.Body?.Trim() ?? string.Empty;
        var orderedAttachments = sourceMessage.Attachments
            .OrderBy(attachment => attachment.SortOrder)
            .ToList();
        if (orderedAttachments.Count > 0)
        {
            if (!string.IsNullOrWhiteSpace(trimmedBody)
                && !orderedAttachments.Any(attachment => string.Equals(
                    attachment.FileName?.Trim(),
                    trimmedBody,
                    StringComparison.OrdinalIgnoreCase)))
            {
                return Truncate(trimmedBody, 160) ?? trimmedBody;
            }

            if (orderedAttachments.Count > 1)
            {
                return $"Attachments ({orderedAttachments.Count})";
            }

            var attachment = orderedAttachments[0];
            var attachmentMimeType = attachment.MimeType?.Trim() ?? string.Empty;
            if (attachment.IsDeleted)
            {
                return "Attachment deleted";
            }

            if (attachmentMimeType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                return "Photo";
            }

            if (attachmentMimeType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
            {
                return "Video";
            }

            return string.IsNullOrWhiteSpace(attachment.FileName) ? "Attachment" : attachment.FileName;
        }

        if (!string.IsNullOrWhiteSpace(trimmedBody))
        {
            return Truncate(trimmedBody, 160) ?? trimmedBody;
        }

        if (!string.IsNullOrWhiteSpace(sourceMessage.AttachmentFileName))
        {
            return sourceMessage.AttachmentFileName;
        }

        return "Message";
    }

    private sealed record ResolvedReplyTarget(Guid MessageId, string Preview);
}
