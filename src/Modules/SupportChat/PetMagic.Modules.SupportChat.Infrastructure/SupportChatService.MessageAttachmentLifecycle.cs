using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportMessageResponse>> UpdateAttachmentMessageAsync(
        UpdateSupportAttachmentMessageCommand command,
        CancellationToken cancellationToken)
    {
        var message = await supportChatDbContext.ConversationMessages
            .Include(x => x.Conversation)
            .FirstOrDefaultAsync(
                x => x.Id == command.MessageId && x.ConversationId == command.ConversationId,
                cancellationToken);
        if (message is null)
        {
            return Result.Failure<SupportMessageResponse>(MessageNotFound);
        }

        var conversation = message.Conversation;
        if (!command.IsAdmin && conversation.InitiatorUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        if (message.IsFromAdmin != command.IsAdmin)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        if (!command.IsAdmin && message.SenderUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var currentStatus = ParseAttachmentUploadStatus(message.AttachmentUploadStatus);
        if (command.AttachmentUploadStatus == SupportAttachmentUploadStatus.Retry
            && currentStatus != SupportAttachmentUploadStatus.Failed)
        {
            return Result.Failure<SupportMessageResponse>(SupportChatErrors.AttachmentRetryNotAllowed);
        }

        switch (command.AttachmentUploadStatus)
        {
            case SupportAttachmentUploadStatus.Uploading:
                message.AttachmentUrl = null;
                message.AttachmentUploadErrorCode = null;
                message.AttachmentFileSizeBytes = null;
                await ReplaceMessageAttachmentsAsync(message.Id, [], cancellationToken);
                if (!string.IsNullOrWhiteSpace(command.AttachmentFileName))
                {
                    message.AttachmentFileName = command.AttachmentFileName;
                }

                if (!string.IsNullOrWhiteSpace(command.AttachmentContentType))
                {
                    message.AttachmentContentType = command.AttachmentContentType;
                }

                break;

            case SupportAttachmentUploadStatus.Uploaded:
                if (string.IsNullOrWhiteSpace(command.AttachmentUrl)
                    || string.IsNullOrWhiteSpace(command.AttachmentFileName)
                    || string.IsNullOrWhiteSpace(command.AttachmentContentType)
                    || command.AttachmentFileSizeBytes is null or <= 0)
                {
                    return Result.Failure<SupportMessageResponse>(SupportChatErrors.InvalidAttachmentUpload);
                }

                message.AttachmentUrl = command.AttachmentUrl;
                message.AttachmentFileName = command.AttachmentFileName;
                message.AttachmentContentType = command.AttachmentContentType;
                message.AttachmentFileSizeBytes = command.AttachmentFileSizeBytes;
                message.AttachmentUploadErrorCode = null;
                await ReplaceMessageAttachmentsAsync(
                    message.Id,
                    [
                        new SupportMessageAttachmentInput(
                            command.AttachmentUrl,
                            command.AttachmentContentType,
                            command.AttachmentFileName,
                            command.AttachmentFileSizeBytes.Value,
                            StorageKey: command.AttachmentStorageKey,
                            ExpiresAtUtc: command.AttachmentExpiresAtUtc)
                    ],
                    cancellationToken);
                break;

            case SupportAttachmentUploadStatus.Failed:
                message.AttachmentUrl = null;
                message.AttachmentFileSizeBytes = null;
                message.AttachmentUploadErrorCode = string.IsNullOrWhiteSpace(command.AttachmentUploadErrorCode)
                    ? SupportChatErrors.AttachmentStorageFailed.Code
                    : command.AttachmentUploadErrorCode;
                await ReplaceMessageAttachmentsAsync(message.Id, [], cancellationToken);
                break;

            case SupportAttachmentUploadStatus.Retry:
                message.AttachmentUrl = null;
                message.AttachmentFileSizeBytes = null;
                message.AttachmentUploadErrorCode = null;
                await ReplaceMessageAttachmentsAsync(message.Id, [], cancellationToken);
                if (!string.IsNullOrWhiteSpace(command.AttachmentFileName))
                {
                    message.AttachmentFileName = command.AttachmentFileName;
                }

                if (!string.IsNullOrWhiteSpace(command.AttachmentContentType))
                {
                    message.AttachmentContentType = command.AttachmentContentType;
                }

                break;

            default:
                return Result.Failure<SupportMessageResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        message.AttachmentUploadStatus = (int)command.AttachmentUploadStatus;
        conversation.UpdatedAtUtc = DateTime.UtcNow;
        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await supportChatDbContext.Entry(message).Collection(x => x.Attachments).LoadAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        var response = await BuildMessageResponseAsync(message, cancellationToken);
        if (command.IsAdmin && command.AttachmentUploadStatus == SupportAttachmentUploadStatus.Uploaded)
        {
            await NotifyUserMessageAsync(conversation, response, cancellationToken);
        }

        return Result.Success(response);
    }

    private async Task ReplaceMessageAttachmentsAsync(
        Guid messageId,
        IReadOnlyList<SupportMessageAttachmentInput> attachments,
        CancellationToken cancellationToken)
    {
        var normalizedAttachments = NormalizeAttachmentInputs(attachments);
        var existingAttachments = await supportChatDbContext.SupportMessageAttachments
            .Where(attachment => attachment.MessageId == messageId)
            .ToListAsync(cancellationToken);
        var nextUrls = normalizedAttachments
            .Select(attachment => attachment.FileUrl)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var removedUrls = existingAttachments
            .Select(attachment => attachment.FileUrl)
            .Where(url => !string.IsNullOrWhiteSpace(url) && !nextUrls.Contains(url))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (existingAttachments.Count > 0)
        {
            supportChatDbContext.SupportMessageAttachments.RemoveRange(existingAttachments);
        }

        if (normalizedAttachments.Count == 0)
        {
            foreach (var removedUrl in removedUrls)
            {
                await attachmentStorage.DeleteAsync(removedUrl, cancellationToken);
            }

            return;
        }

        var now = DateTime.UtcNow;
        var retentionDays = Math.Max(1, attachmentStorageOptions.RetentionDays);
        for (var index = 0; index < normalizedAttachments.Count; index++)
        {
            var attachment = normalizedAttachments[index];
            supportChatDbContext.SupportMessageAttachments.Add(new SupportMessageAttachment
            {
                Id = Guid.NewGuid(),
                MessageId = messageId,
                FileUrl = attachment.FileUrl,
                FileName = attachment.FileName,
                MimeType = attachment.MimeType,
                SizeBytes = attachment.SizeBytes,
                StorageKey = ResolveStorageKey(attachment.FileUrl, attachment.StorageKey),
                ExpiresAtUtc = attachment.ExpiresAtUtc ?? now.AddDays(retentionDays),
                DeletedAtUtc = attachment.DeletedAtUtc,
                IsDeleted = attachment.IsDeleted,
                DurationSeconds = attachment.DurationSeconds,
                Width = attachment.Width,
                Height = attachment.Height,
                SortOrder = index,
                CreatedAtUtc = now,
            });
        }

        foreach (var removedUrl in removedUrls)
        {
            await attachmentStorage.DeleteAsync(removedUrl, cancellationToken);
        }
    }
}
