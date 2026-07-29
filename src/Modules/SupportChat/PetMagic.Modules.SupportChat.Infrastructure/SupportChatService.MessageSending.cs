using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken)
    {
        return await SendMessageCoreAsync(
            command.ConversationId,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            [],
            command.ReplyToMessageId,
            command.Locale,
            command.IdempotencyKey,
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
            command.IdempotencyKey,
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
        string? idempotencyKey,
        CancellationToken cancellationToken)
    {
        await using var transaction = isAdmin
            ? await BeginSupportAdminActionTransactionAsync(cancellationToken)
            : null;
        if (transaction is not null)
        {
            await LockConversationRowForAdminActionAsync(conversationId, cancellationToken);
        }

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

        if (isAdmin)
        {
            var ownershipError = ValidateAdminOwnership(conversation, senderUserId);
            if (ownershipError is not null)
            {
                return Result.Failure<SupportMessageResponse>(ownershipError);
            }
        }

        string? normalizedIdempotencyKey = null;
        if (isAdmin && !SupportMessageIdempotency.TryNormalize(idempotencyKey, out normalizedIdempotencyKey))
        {
            return Result.Failure<SupportMessageResponse>(SupportChatErrors.InvalidIdempotencyKey);
        }
        var existingMessage = await FindExistingIdempotentAdminMessageAsync(
            conversationId,
            senderUserId,
            normalizedIdempotencyKey,
            cancellationToken);
        if (existingMessage is not null)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(await BuildMessageResponseAsync(
                existingMessage,
                cancellationToken,
                isIdempotencyReplay: true));
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
            updateAssignmentAndStatus: true,
            clientIdempotencyKey: normalizedIdempotencyKey);

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

        if (isAdmin)
        {
            await EnqueueUserMessageNotificationAsync(
                conversation,
                message.Id,
                normalizedAttachments.Count > 0,
                unreadCountDelta: 1,
                cancellationToken);
        }
        else
        {
            SupportChatPushNotificationOutbox.EnqueueAdminMessageNotification(
                supportChatDbContext,
                conversation.Id,
                message.Id,
                message.CreatedAtUtc);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        var response = await BuildMessageResponseAsync(message, cancellationToken);

        return Result.Success(response);
    }

    public async Task<Result<SupportMessageResponse>> CreateAttachmentMessageAsync(
        CreateSupportAttachmentMessageCommand command,
        CancellationToken cancellationToken)
    {
        await using var transaction = command.IsAdmin
            ? await BeginSupportAdminActionTransactionAsync(cancellationToken)
            : null;
        if (transaction is not null)
        {
            await LockConversationRowForAdminActionAsync(command.ConversationId, cancellationToken);
        }

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

        if (command.IsAdmin)
        {
            var ownershipError = ValidateAdminOwnership(conversation, command.SenderUserId);
            if (ownershipError is not null)
            {
                return Result.Failure<SupportMessageResponse>(ownershipError);
            }
        }

        string? normalizedIdempotencyKey = null;
        if (command.IsAdmin && !SupportMessageIdempotency.TryNormalize(command.IdempotencyKey, out normalizedIdempotencyKey))
        {
            return Result.Failure<SupportMessageResponse>(SupportChatErrors.InvalidIdempotencyKey);
        }
        var existingMessage = await FindExistingIdempotentAdminMessageAsync(
            command.ConversationId,
            command.SenderUserId,
            normalizedIdempotencyKey,
            cancellationToken);
        if (existingMessage is not null)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(await BuildMessageResponseAsync(
                existingMessage,
                cancellationToken,
                isIdempotencyReplay: true));
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
            updateAssignmentAndStatus: true,
            clientIdempotencyKey: normalizedIdempotencyKey);

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

        if (!command.IsAdmin)
        {
            SupportChatPushNotificationOutbox.EnqueueAdminMessageNotification(
                supportChatDbContext,
                conversation.Id,
                message.Id,
                message.CreatedAtUtc);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildMessageResponseAsync(message, cancellationToken));
    }
}
