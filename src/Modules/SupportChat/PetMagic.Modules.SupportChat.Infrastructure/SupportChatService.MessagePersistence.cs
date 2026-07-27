using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private Task<ConversationMessage> AppendMessageAsync(
        SupportConversation conversation,
        Guid senderUserId,
        string body,
        bool isAdmin,
        Guid? replyToMessageId,
        string? replyToPreview,
        SupportMessageSenderType senderType,
        string? attachmentUrl,
        string? attachmentFileName,
        string? attachmentContentType,
        long? attachmentFileSizeBytes,
        SupportAttachmentUploadStatus? attachmentUploadStatus,
        string? attachmentUploadErrorCode,
        IReadOnlyList<SupportMessageAttachmentInput> attachments,
        DateTime? markAsReadAtUtc,
        bool updateAssignmentAndStatus,
        string? clientIdempotencyKey = null)
    {
        var now = DateTime.UtcNow;
        var retentionDays = Math.Max(1, attachmentStorageOptions.RetentionDays);
        var trimmedBody = body.Trim();
        var orderedAttachments = NormalizeAttachmentInputs(attachments);
        var message = new ConversationMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conversation.Id,
            SenderUserId = senderUserId,
            Body = trimmedBody,
            ReplyToMessageId = replyToMessageId,
            ReplyToPreview = replyToPreview,
            ClientIdempotencyKey = clientIdempotencyKey,
            IsFromAdmin = isAdmin,
            SenderType = senderType,
            AttachmentUrl = attachmentUrl,
            AttachmentFileName = attachmentFileName,
            AttachmentContentType = attachmentContentType,
            AttachmentFileSizeBytes = attachmentFileSizeBytes,
            AttachmentUploadStatus = attachmentUploadStatus.HasValue ? (int)attachmentUploadStatus.Value : null,
            AttachmentUploadErrorCode = attachmentUploadErrorCode,
            ReadAtUtc = markAsReadAtUtc,
            DeliveredAtUtc = now,
            CreatedAtUtc = now
        };

        if (orderedAttachments.Count > 0)
        {
            for (var index = 0; index < orderedAttachments.Count; index++)
            {
                var attachment = orderedAttachments[index];
                message.Attachments.Add(new SupportMessageAttachment
                {
                    Id = Guid.NewGuid(),
                    MessageId = message.Id,
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
        }

        if (isAdmin && updateAssignmentAndStatus)
        {
            conversation.AssignedAdminId ??= senderUserId;
            conversation.FirstResponseAtUtc ??= now;
            MarkActive(conversation, SupportConversationStatus.WaitingForUser, now);
        }
        else if (!isAdmin && updateAssignmentAndStatus)
        {
            var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
            var nextStatus = currentStatus switch
            {
                SupportConversationStatus.Closed => SupportConversationStatus.New,
                SupportConversationStatus.WaitingForUser => SupportConversationStatus.InProgress,
                SupportConversationStatus.New => SupportConversationStatus.New,
                _ => SupportConversationStatus.InProgress
            };
            MarkActive(conversation, nextStatus, now);
        }

        var messagePreview = BuildMessagePreview(trimmedBody, orderedAttachments);
        conversation.LastMessageAtUtc = now;
        conversation.LastMessagePreview = string.IsNullOrWhiteSpace(messagePreview)
            ? null
            : Truncate(messagePreview, 280);
        conversation.LastMessageSenderType = senderType;
        conversation.WaitingSinceUtc = ResolveWaitingSince(
            ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId),
            now,
            conversation.CreatedAtUtc);
        supportChatDbContext.ConversationMessages.Add(message);
        return Task.FromResult(message);
    }

    private async Task<ConversationMessage?> FindExistingIdempotentAdminMessageAsync(
        Guid conversationId,
        Guid senderUserId,
        string? clientIdempotencyKey,
        CancellationToken cancellationToken)
    {
        if (clientIdempotencyKey is null)
        {
            return null;
        }

        return await supportChatDbContext.ConversationMessages
            .AsNoTracking()
            .Include(message => message.Attachments)
            .FirstOrDefaultAsync(
                message => message.ConversationId == conversationId
                    && message.SenderUserId == senderUserId
                    && message.ClientIdempotencyKey == clientIdempotencyKey,
                cancellationToken);
    }

    private Task AppendSystemEventAsync(SupportConversation conversation, string body)
    {
        var now = DateTime.UtcNow;
        var message = new ConversationMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conversation.Id,
            SenderUserId = AutomatedAssistantUserId,
            Body = body,
            IsFromAdmin = true,
            SenderType = SupportMessageSenderType.System,
            ReadAtUtc = now,
            CreatedAtUtc = now
        };

        supportChatDbContext.ConversationMessages.Add(message);
        return Task.CompletedTask;
    }

    private static string ResolveScenarioLabel(string scenario) => scenario switch
    {
        "GenerationIssue" => "Generation issue",
        "GenerationTooLong" => "Generation takes too long",
        "TokensNotArrived" => "Tokens did not arrive",
        "PremiumIssue" => "Premium issue",
        "PaymentRefund" => "Payment / Refund",
        "Other" => "Other",
        _ => scenario,
    };
}
