using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken)
    {
        var legacyAttachments = BuildLegacyAttachmentInputs(command);
        return await SendMessageCoreAsync(
            command.ConversationId,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            legacyAttachments,
            command.ReplyToMessageId,
            command.Locale,
            cancellationToken);
    }

    public async Task<Result<SupportMessageResponse>> SendMessageWithAttachmentsAsync(
        SendSupportAttachmentsCommand command,
        CancellationToken cancellationToken)
    {
        return await SendMessageCoreAsync(
            command.ConversationId,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            command.Attachments,
            command.ReplyToMessageId,
            command.Locale,
            cancellationToken);
    }

    private async Task<Result<SupportMessageResponse>> SendMessageCoreAsync(
        Guid conversationId,
        Guid senderUserId,
        string body,
        bool isAdmin,
        IReadOnlyList<SupportMessageAttachmentInput>? attachments,
        Guid? replyToMessageId,
        string? locale,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == conversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportMessageResponse>(ConversationNotFound);
        }

        if (!isAdmin && conversation.InitiatorUserId != senderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var canAppendError = ValidateConversationCanAcceptMessage(conversation, isAdmin, DateTime.UtcNow);
        if (canAppendError is not null)
        {
            return Result.Failure<SupportMessageResponse>(canAppendError);
        }

        var normalizedAttachments = NormalizeAttachmentInputs(attachments);
        if (normalizedAttachments.Count == 0 && string.IsNullOrWhiteSpace(body))
        {
            return Result.Failure<SupportMessageResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        var replyTargetResult = await ResolveReplyTargetAsync(conversationId, replyToMessageId, cancellationToken);
        if (replyTargetResult.IsFailure)
        {
            return Result.Failure<SupportMessageResponse>(replyTargetResult.Error);
        }
        var replyTarget = replyTargetResult.Value;

        var firstAttachment = normalizedAttachments.FirstOrDefault();
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var hasExistingUserOrBotMessage = isAdmin || await supportChatDbContext.ConversationMessages
            .AsNoTracking()
            .AnyAsync(
                message => message.ConversationId == conversationId
                    && (message.SenderType == SupportMessageSenderType.User
                        || message.SenderType == SupportMessageSenderType.Bot),
                cancellationToken);
        var shouldAppendAutomaticReply = !isAdmin && !hasExistingUserOrBotMessage;
        var shouldAppendReopenedEvent = !isAdmin && currentStatus == SupportConversationStatus.Closed;

        var message = await AppendMessageAsync(
            conversation,
            senderUserId,
            body,
            isAdmin,
            replyToMessageId: replyTarget?.MessageId,
            replyToPreview: replyTarget?.Preview,
            senderType: isAdmin ? SupportMessageSenderType.SupportAgent : SupportMessageSenderType.User,
            firstAttachment?.FileUrl,
            firstAttachment?.FileName,
            firstAttachment?.MimeType,
            firstAttachment?.SizeBytes,
            attachmentUploadStatus: normalizedAttachments.Count == 0 ? null : SupportAttachmentUploadStatus.Uploaded,
            attachmentUploadErrorCode: null,
            attachments: normalizedAttachments,
            markAsReadAtUtc: null,
            updateAssignmentAndStatus: true);

        if (shouldAppendAutomaticReply)
        {
            await AppendMessageAsync(
                conversation,
                AutomatedAssistantUserId,
                SupportChatAutoReplyLocalizer.BuildFirstReplyAcknowledgement(locale),
                isAdmin: true,
                replyToMessageId: null,
                replyToPreview: null,
                senderType: SupportMessageSenderType.Bot,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                attachments: [],
                markAsReadAtUtc: DateTime.UtcNow,
                updateAssignmentAndStatus: false);
        }

        var nextStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (shouldAppendReopenedEvent)
        {
            await AppendSystemEventAsync(conversation, "Ticket reopened by user message");
        }
        else if (!isAdmin && currentStatus == SupportConversationStatus.WaitingForUser)
        {
            await AppendSystemEventAsync(conversation, "User replied");
        }

        if (isAdmin)
        {
            await AppendSystemEventAsync(conversation, "Support replied");
        }

        if (currentStatus != nextStatus)
        {
            await AppendStatusChangedEventAsync(conversation, currentStatus, nextStatus);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        var response = await BuildMessageResponseAsync(message, cancellationToken);
        if (isAdmin)
        {
            await NotifyUserMessageAsync(conversation, response, cancellationToken);
        }

        return Result.Success(response);
    }

    public async Task<Result<SupportMessageResponse>> CreateAttachmentMessageAsync(CreateSupportAttachmentMessageCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportMessageResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var canAppendError = ValidateConversationCanAcceptMessage(conversation, command.IsAdmin, DateTime.UtcNow);
        if (canAppendError is not null)
        {
            return Result.Failure<SupportMessageResponse>(canAppendError);
        }

        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var shouldAppendReopenedEvent = !command.IsAdmin && currentStatus == SupportConversationStatus.Closed;
        var replyTargetResult = await ResolveReplyTargetAsync(command.ConversationId, command.ReplyToMessageId, cancellationToken);
        if (replyTargetResult.IsFailure)
        {
            return Result.Failure<SupportMessageResponse>(replyTargetResult.Error);
        }
        var replyTarget = replyTargetResult.Value;

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            replyToMessageId: replyTarget?.MessageId,
            replyToPreview: replyTarget?.Preview,
            senderType: command.IsAdmin ? SupportMessageSenderType.SupportAgent : SupportMessageSenderType.User,
            attachmentUrl: null,
            attachmentFileName: command.AttachmentFileName,
            attachmentContentType: command.AttachmentContentType,
            attachmentFileSizeBytes: null,
            attachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
            attachmentUploadErrorCode: null,
            attachments: [],
            markAsReadAtUtc: null,
            updateAssignmentAndStatus: true);

        var nextStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (shouldAppendReopenedEvent)
        {
            await AppendSystemEventAsync(conversation, "Ticket reopened by user message");
        }
        else if (!command.IsAdmin && currentStatus == SupportConversationStatus.WaitingForUser)
        {
            await AppendSystemEventAsync(conversation, "User replied");
        }

        if (command.IsAdmin)
        {
            await AppendSystemEventAsync(conversation, "Support replied");
        }

        if (currentStatus != nextStatus)
        {
            await AppendStatusChangedEventAsync(conversation, currentStatus, nextStatus);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildMessageResponseAsync(message, cancellationToken));
    }

    public async Task<Result<SupportMessageResponse>> UpdateAttachmentMessageAsync(UpdateSupportAttachmentMessageCommand command, CancellationToken cancellationToken)
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

    public async Task<Result> MarkConversationReadAsync(MarkSupportConversationReadCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure(Forbidden);
        }

        var markAdminMessages = !command.IsAdmin;
        var now = DateTime.UtcNow;
        var changed = false;

        var unreadMessages = await supportChatDbContext.ConversationMessages
            .Where(message => message.ConversationId == conversation.Id
                && message.IsFromAdmin == markAdminMessages
                && message.ReadAtUtc == null)
            .ToListAsync(cancellationToken);

        foreach (var message in unreadMessages)
        {
            message.ReadAtUtc = now;
            changed = true;
        }

        if (changed)
        {
            conversation.UpdatedAtUtc = now;
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success();
    }
}
