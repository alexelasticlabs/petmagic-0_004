using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportChatService(
    SupportChatDbContext supportChatDbContext,
    IdentityDbContext identityDbContext,
    ISupportChatRealtimeNotifier realtimeNotifier) : ISupportChatService
{
    private static readonly Guid AutomatedAssistantUserId = Guid.Parse("2F1E3B3B-8A2E-4A8E-9EE5-97BF31B33218");
    private static readonly Error ConversationNotFound = new("support.conversation_not_found", "Support conversation was not found.");
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
            .Include(x => x.Messages)
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

        var conversations = await conversationsQuery
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.LastMessageAtUtc ?? x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var relatedUserIds = conversations
            .Select(x => x.InitiatorUserId)
            .Concat(conversations.Where(x => x.AssignedAdminId.HasValue).Select(x => x.AssignedAdminId!.Value))
            .Distinct()
            .ToList();

        var users = await identityDbContext.Users
            .AsNoTracking()
            .Where(x => relatedUserIds.Contains(x.Id))
            .Select(x => new UserLookup(x.Id, x.Email!, x.DisplayName))
            .ToDictionaryAsync(x => x.Id, cancellationToken);

        var summaries = conversations.Select(conversation =>
        {
            users.TryGetValue(conversation.InitiatorUserId, out var initiator);
            UserLookup? assignedAdmin = null;
            if (conversation.AssignedAdminId.HasValue)
            {
                users.TryGetValue(conversation.AssignedAdminId.Value, out assignedAdmin);
            }

            var lastMessage = conversation.Messages.OrderByDescending(x => x.CreatedAtUtc).FirstOrDefault();
            var unreadAdminCount = conversation.Messages.Count(x => !x.IsFromAdmin && x.ReadAtUtc is null);
            var unreadUserCount = conversation.Messages.Count(x => x.IsFromAdmin && x.ReadAtUtc is null);

            return new SupportConversationSummaryResponse(
                conversation.Id,
                conversation.InitiatorUserId,
                initiator?.Email ?? string.Empty,
                initiator?.DisplayName,
                conversation.AssignedAdminId,
                ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName),
                conversation.Status.ToString(),
                conversation.Priority.ToString(),
                lastMessage is null ? null : Truncate(lastMessage.Body, 140),
                lastMessage?.CreatedAtUtc ?? conversation.LastMessageAtUtc,
                unreadUserCount,
                unreadAdminCount,
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

        var shouldAppendAutomaticReply = !command.IsAdmin && !conversation.Messages.Any();

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            command.AttachmentUrl,
            command.AttachmentFileName,
            command.AttachmentContentType,
            command.AttachmentFileSizeBytes,
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
                markAsReadAtUtc: DateTime.UtcNow,
                updateAssignmentAndStatus: false);
        }

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

        var users = await identityDbContext.Users
            .AsNoTracking()
            .Where(x => userIds.Contains(x.Id))
            .Select(x => new UserLookup(x.Id, x.Email!, x.DisplayName))
            .ToDictionaryAsync(x => x.Id, cancellationToken);

        users.TryGetValue(conversation.InitiatorUserId, out var initiator);
        UserLookup? assignedAdmin = null;
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
        var sender = await identityDbContext.Users
            .AsNoTracking()
            .Where(x => x.Id == message.SenderUserId)
            .Select(x => new UserLookup(x.Id, x.Email!, x.DisplayName))
            .FirstOrDefaultAsync(cancellationToken);

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
            message.ReadAtUtc.HasValue,
            message.ReadAtUtc,
            message.CreatedAtUtc);
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

    private sealed record UserLookup(Guid Id, string Email, string? DisplayName);
}
