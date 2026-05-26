using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportChatService(
    SupportChatDbContext supportChatDbContext,
    IIdentityUserLookupService identityUserLookupService,
    ISupportChatRealtimeNotifier realtimeNotifier) : ISupportChatService
{
    private static readonly Guid AutomatedAssistantUserId = Guid.Parse("2F1E3B3B-8A2E-4A8E-9EE5-97BF31B33218");
    private static readonly Error ConversationNotFound = new("support.conversation_not_found", "Support conversation was not found.");
    private static readonly Error MessageNotFound = new("support.message_not_found", "Support message was not found.");
    private static readonly Error Forbidden = new("support.forbidden", "You do not have access to this support conversation.");
    private static readonly Error InvalidStatus = new("support.status_invalid", "Support conversation status is not supported.");
    private static readonly Error InvalidStatusTransition = new("support.status_transition_invalid", "Support conversation status transition is not allowed.");

    public async Task<Result<SupportConversationDetailResponse>> OpenConversationAsync(OpenSupportConversationCommand command, CancellationToken cancellationToken)
    {
        var createdConversation = false;
        var appendedInitialMessage = false;
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
            .FirstOrDefaultAsync(x => x.InitiatorUserId == command.UserId, cancellationToken);

        if (conversation is null)
        {
            var now = DateTime.UtcNow;
            conversation = new SupportConversation
            {
                Id = Guid.NewGuid(),
                InitiatorUserId = command.UserId,
                Priority = command.Priority,
                Status = SupportConversationStatus.Open,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };

            supportChatDbContext.SupportConversations.Add(conversation);
            createdConversation = true;
        }

        if (!string.IsNullOrWhiteSpace(command.InitialMessage))
        {
            await AppendMessageAsync(
                conversation,
                command.UserId,
                command.InitialMessage,
                isAdmin: false,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                markAsReadAtUtc: null,
                updateAssignmentAndStatus: true);
            appendedInitialMessage = true;
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        if (createdConversation || appendedInitialMessage)
        {
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(Guid userId, CancellationToken cancellationToken)
    {
        var conversationId = await supportChatDbContext.SupportConversations
            .Where(x => x.InitiatorUserId == userId)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (conversationId is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId.Value, cancellationToken));
    }

    public async Task<Result<IReadOnlyList<SupportConversationSummaryResponse>>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken)
    {
        var conversationsQuery = supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            if (!Enum.TryParse<SupportConversationStatus>(query.Status, true, out var status))
            {
                return Result.Failure<IReadOnlyList<SupportConversationSummaryResponse>>(InvalidStatus);
            }

            conversationsQuery = conversationsQuery.Where(x => x.Status == status);
        }

        if (query.AssignedAdminId.HasValue)
        {
            conversationsQuery = conversationsQuery.Where(x => x.AssignedAdminId == query.AssignedAdminId.Value);
        }
        else if (query.UnassignedOnly)
        {
            conversationsQuery = conversationsQuery.Where(x => x.AssignedAdminId == null);
        }

        var conversationRows = await conversationsQuery
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.LastMessageAtUtc ?? x.CreatedAtUtc)
            .Select(conversation => new
            {
                conversation.Id,
                conversation.InitiatorUserId,
                conversation.AssignedAdminId,
                conversation.Status,
                conversation.Priority,
                conversation.LastMessageAtUtc,
                conversation.CreatedAtUtc,
                conversation.UpdatedAtUtc,
                LastMessage = conversation.Messages
                    .OrderByDescending(message => message.CreatedAtUtc)
                    .Select(message => new
                    {
                        message.Body,
                        message.CreatedAtUtc
                    })
                    .FirstOrDefault(),
                UnreadAdminCount = conversation.Messages.Count(message => !message.IsFromAdmin && message.ReadAtUtc == null),
                UnreadUserCount = conversation.Messages.Count(message => message.IsFromAdmin && message.ReadAtUtc == null)
            })
            .ToListAsync(cancellationToken);

        var relatedUserIds = conversationRows
            .Select(x => x.InitiatorUserId)
            .Concat(conversationRows.Where(x => x.AssignedAdminId.HasValue).Select(x => x.AssignedAdminId!.Value))
            .Distinct()
            .ToList();

        var users = await identityUserLookupService.GetUsersByIdsAsync(relatedUserIds, cancellationToken);

        var summaries = conversationRows.Select(conversation =>
        {
            users.TryGetValue(conversation.InitiatorUserId, out var initiator);
            IdentityUserLookup? assignedAdmin = null;
            if (conversation.AssignedAdminId.HasValue)
            {
                users.TryGetValue(conversation.AssignedAdminId.Value, out assignedAdmin);
            }

            return new SupportConversationSummaryResponse(
                conversation.Id,
                conversation.InitiatorUserId,
                initiator?.Email ?? string.Empty,
                initiator?.DisplayName,
                conversation.AssignedAdminId,
                ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName),
                conversation.Status.ToString(),
                conversation.Priority.ToString(),
                conversation.LastMessage is null ? null : Truncate(conversation.LastMessage.Body, 140),
                conversation.LastMessage?.CreatedAtUtc ?? conversation.LastMessageAtUtc,
                conversation.UnreadUserCount,
                conversation.UnreadAdminCount,
                conversation.CreatedAtUtc,
                conversation.UpdatedAtUtc);
        }).ToList();

        return Result.Success<IReadOnlyList<SupportConversationSummaryResponse>>(summaries);
    }

    public async Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        var exists = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AnyAsync(x => x.Id == conversationId, cancellationToken);
        if (!exists)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId, cancellationToken));
    }

    public async Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportMessageResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var shouldAppendAutomaticReply = !command.IsAdmin && conversation.Messages.Count == 0;

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            command.AttachmentUrl,
            command.AttachmentFileName,
            command.AttachmentContentType,
            command.AttachmentFileSizeBytes,
            attachmentUploadStatus: command.AttachmentUrl is null ? null : SupportAttachmentUploadStatus.Uploaded,
            attachmentUploadErrorCode: null,
            markAsReadAtUtc: null,
            updateAssignmentAndStatus: true);

        if (shouldAppendAutomaticReply)
        {
            await AppendMessageAsync(
                conversation,
                AutomatedAssistantUserId,
                SupportChatAutoReplyLocalizer.BuildFirstReplyAcknowledgement(command.Locale),
                isAdmin: true,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                markAsReadAtUtc: DateTime.UtcNow,
                updateAssignmentAndStatus: false);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildMessageResponseAsync(message, cancellationToken));
    }

    public async Task<Result<SupportMessageResponse>> CreateAttachmentMessageAsync(CreateSupportAttachmentMessageCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportMessageResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            attachmentUrl: null,
            attachmentFileName: command.AttachmentFileName,
            attachmentContentType: command.AttachmentContentType,
            attachmentFileSizeBytes: null,
            attachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
            attachmentUploadErrorCode: null,
            markAsReadAtUtc: null,
            updateAssignmentAndStatus: true);

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildMessageResponseAsync(message, cancellationToken));
    }

    public async Task<Result<SupportMessageResponse>> UpdateAttachmentMessageAsync(UpdateSupportAttachmentMessageCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportMessageResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.SenderUserId)
        {
            return Result.Failure<SupportMessageResponse>(Forbidden);
        }

        var message = conversation.Messages.FirstOrDefault(x => x.Id == command.MessageId);
        if (message is null)
        {
            return Result.Failure<SupportMessageResponse>(MessageNotFound);
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
                break;

            case SupportAttachmentUploadStatus.Failed:
                message.AttachmentUrl = null;
                message.AttachmentFileSizeBytes = null;
                message.AttachmentUploadErrorCode = string.IsNullOrWhiteSpace(command.AttachmentUploadErrorCode)
                    ? SupportChatErrors.AttachmentStorageFailed.Code
                    : command.AttachmentUploadErrorCode;
                break;

            case SupportAttachmentUploadStatus.Retry:
                message.AttachmentUrl = null;
                message.AttachmentFileSizeBytes = null;
                message.AttachmentUploadErrorCode = null;
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
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildMessageResponseAsync(message, cancellationToken));
    }

    public async Task<Result> MarkConversationReadAsync(MarkSupportConversationReadCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
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

        foreach (var message in conversation.Messages.Where(x => x.IsFromAdmin == markAdminMessages && x.ReadAtUtc is null))
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

    public async Task<Result<SupportConversationDetailResponse>> UpdateConversationStatusAsync(UpdateSupportConversationStatusCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        var now = DateTime.UtcNow;

        if (conversation.Status != command.Status && !IsAllowedStatusTransition(conversation.Status, command.Status))
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        conversation.Status = command.Status;
        conversation.AssignedAdminId ??= command.AdminUserId;
        conversation.UpdatedAtUtc = now;
        conversation.ResolvedAtUtc = command.Status is SupportConversationStatus.Resolved or SupportConversationStatus.Closed
            ? now
            : null;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private static bool IsAllowedStatusTransition(SupportConversationStatus currentStatus, SupportConversationStatus nextStatus)
    {
        return currentStatus switch
        {
            SupportConversationStatus.Open => nextStatus is SupportConversationStatus.InProgress or SupportConversationStatus.Resolved or SupportConversationStatus.Closed,
            SupportConversationStatus.InProgress => nextStatus is SupportConversationStatus.Open or SupportConversationStatus.Resolved or SupportConversationStatus.Closed,
            SupportConversationStatus.Resolved => nextStatus is SupportConversationStatus.Open or SupportConversationStatus.Closed,
            SupportConversationStatus.Closed => nextStatus is SupportConversationStatus.Open,
            _ => false
        };
    }

    public async Task<Result<SupportConversationDetailResponse>> AssignConversationAsync(AssignSupportConversationCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        var now = DateTime.UtcNow;

        conversation.AssignedAdminId = command.AssignedAdminId;
        conversation.UpdatedAtUtc = now;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private async Task NotifyConversationUpdatedAsync(SupportConversation conversation, CancellationToken cancellationToken)
    {
        try
        {
            await realtimeNotifier.NotifyConversationUpdatedAsync(
                new SupportConversationRealtimeEvent(
                    conversation.Id,
                    conversation.InitiatorUserId,
                    conversation.UpdatedAtUtc),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Realtime fan-out is best-effort and must not break the primary support flow.
        }
    }

    private Task<ConversationMessage> AppendMessageAsync(
        SupportConversation conversation,
        Guid senderUserId,
        string body,
        bool isAdmin,
        string? attachmentUrl,
        string? attachmentFileName,
        string? attachmentContentType,
        long? attachmentFileSizeBytes,
        SupportAttachmentUploadStatus? attachmentUploadStatus,
        string? attachmentUploadErrorCode,
        DateTime? markAsReadAtUtc,
        bool updateAssignmentAndStatus)
    {
        var now = DateTime.UtcNow;
        var trimmedBody = body.Trim();
        var message = new ConversationMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conversation.Id,
            SenderUserId = senderUserId,
            Body = trimmedBody,
            IsFromAdmin = isAdmin,
            AttachmentUrl = attachmentUrl,
            AttachmentFileName = attachmentFileName,
            AttachmentContentType = attachmentContentType,
            AttachmentFileSizeBytes = attachmentFileSizeBytes,
            AttachmentUploadStatus = attachmentUploadStatus.HasValue ? (int)attachmentUploadStatus.Value : null,
            AttachmentUploadErrorCode = attachmentUploadErrorCode,
            ReadAtUtc = markAsReadAtUtc,
            CreatedAtUtc = now
        };

        if (isAdmin && updateAssignmentAndStatus)
        {
            conversation.AssignedAdminId ??= senderUserId;
            conversation.Status = SupportConversationStatus.InProgress;
        }
        else if (!isAdmin && (conversation.Status is SupportConversationStatus.Resolved or SupportConversationStatus.Closed))
        {
            conversation.Status = SupportConversationStatus.Open;
            conversation.ResolvedAtUtc = null;
        }

        conversation.LastMessageAtUtc = now;

        conversation.UpdatedAtUtc = now;
        supportChatDbContext.ConversationMessages.Add(message);
        return Task.FromResult(message);
    }

    private async Task<SupportConversationDetailResponse> BuildConversationDetailAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .Include(x => x.Messages.OrderBy(message => message.CreatedAtUtc))
            .FirstAsync(x => x.Id == conversationId, cancellationToken);

        var visibleMessages = conversation.Messages.OrderBy(x => x.CreatedAtUtc).ToList();

        var userIds = visibleMessages
            .Select(x => x.SenderUserId)
            .Append(conversation.InitiatorUserId)
            .Concat(conversation.AssignedAdminId.HasValue ? [conversation.AssignedAdminId.Value] : [])
            .Distinct()
            .ToList();

        var users = await identityUserLookupService.GetUsersByIdsAsync(userIds, cancellationToken);

        users.TryGetValue(conversation.InitiatorUserId, out var initiator);
        IdentityUserLookup? assignedAdmin = null;
        if (conversation.AssignedAdminId.HasValue)
        {
            users.TryGetValue(conversation.AssignedAdminId.Value, out assignedAdmin);
        }

        var messages = new List<SupportMessageResponse>(visibleMessages.Count);
        foreach (var message in visibleMessages)
        {
            users.TryGetValue(message.SenderUserId, out var sender);
            messages.Add(new SupportMessageResponse(
                message.Id,
                message.ConversationId,
                message.SenderUserId,
                ResolveDisplayName(sender?.Email, sender?.DisplayName, message.IsFromAdmin),
                message.IsFromAdmin,
                message.Body,
                message.AttachmentUrl,
                message.AttachmentFileName,
                message.AttachmentContentType,
                message.AttachmentFileSizeBytes,
                ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
                message.AttachmentUploadErrorCode,
                message.ReadAtUtc.HasValue,
                message.ReadAtUtc,
                message.CreatedAtUtc));
        }

        var userUnreadCount = conversation.Messages.Count(x => x.IsFromAdmin && x.ReadAtUtc is null);
        var adminUnreadCount = conversation.Messages.Count(x => !x.IsFromAdmin && x.ReadAtUtc is null);

        return new SupportConversationDetailResponse(
            conversation.Id,
            conversation.InitiatorUserId,
            initiator?.Email ?? string.Empty,
            initiator?.DisplayName,
            conversation.AssignedAdminId,
            ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName, isAdminSender: true),
            conversation.Status.ToString(),
            conversation.Priority.ToString(),
            userUnreadCount,
            adminUnreadCount,
            conversation.CreatedAtUtc,
            conversation.UpdatedAtUtc,
            conversation.LastMessageAtUtc ?? visibleMessages.LastOrDefault()?.CreatedAtUtc,
            messages);
    }

    private async Task<SupportMessageResponse> BuildMessageResponseAsync(ConversationMessage message, CancellationToken cancellationToken)
    {
        var sender = await identityUserLookupService.GetUserByIdAsync(message.SenderUserId, cancellationToken);

        return new SupportMessageResponse(
            message.Id,
            message.ConversationId,
            message.SenderUserId,
            ResolveDisplayName(sender?.Email, sender?.DisplayName, message.IsFromAdmin),
            message.IsFromAdmin,
            message.Body,
            message.AttachmentUrl,
            message.AttachmentFileName,
            message.AttachmentContentType,
            message.AttachmentFileSizeBytes,
            ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
            message.AttachmentUploadErrorCode,
            message.ReadAtUtc.HasValue,
            message.ReadAtUtc,
            message.CreatedAtUtc);
    }

    private static SupportAttachmentUploadStatus? ParseAttachmentUploadStatus(int? rawValue)
    {
        if (!rawValue.HasValue)
        {
            return null;
        }

        return Enum.IsDefined(typeof(SupportAttachmentUploadStatus), rawValue.Value)
            ? (SupportAttachmentUploadStatus)rawValue.Value
            : null;
    }

    private static string ResolveDisplayName(string? email, string? displayName, bool isAdminSender = false)
    {
        if (!string.IsNullOrWhiteSpace(displayName))
        {
            return displayName;
        }

        if (!string.IsNullOrWhiteSpace(email))
        {
            return email;
        }

        return isAdminSender ? "PetMagic Support" : "PetMagic User";
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length <= maxLength)
        {
            return value;
        }

        return string.Concat(value.AsSpan(0, maxLength), "...");
    }
}
