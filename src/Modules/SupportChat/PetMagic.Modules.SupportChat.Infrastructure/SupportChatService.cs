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
    ISupportChatRealtimeNotifier realtimeNotifier,
    ISupportChatPushNotificationSender pushNotificationSender) : ISupportChatService
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
                Status = SupportConversationStatus.New,
                Source = command.Source,
                AssistantScenario = command.AssistantScenario?.Trim(),
                RelatedGenerationId = command.RelatedGenerationId,
                RelatedPaymentId = command.RelatedPaymentId,
                RelatedSubscriptionId = command.RelatedSubscriptionId,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };

            supportChatDbContext.SupportConversations.Add(conversation);
            createdConversation = true;

            if (command.Source is SupportConversationSource.MobileChat or SupportConversationSource.Direct)
            {
                await AppendSystemEventAsync(
                    conversation,
                    "Ticket created from Mobile Chat");
            }

            if (command.Source == SupportConversationSource.MobileAssistant
                && !string.IsNullOrWhiteSpace(command.AssistantScenario))
            {
                var scenarioLabel = ResolveScenarioLabel(command.AssistantScenario);
                await AppendSystemEventAsync(
                    conversation,
                    $"User completed the \"{scenarioLabel}\" assistant flow and created a support ticket.");
            }
        }

        if (!string.IsNullOrWhiteSpace(command.InitialMessage))
        {
            var now = DateTime.UtcNow;
            if (ShouldReactivateConversationForUserMessage(conversation, now))
            {
                MarkActive(conversation, SupportConversationStatus.New, now);
            }

            var canAppendError = ValidateConversationCanAcceptMessage(conversation, isAdmin: false, now);
            if (canAppendError is not null)
            {
                return Result.Failure<SupportConversationDetailResponse>(canAppendError);
            }

            await AppendMessageAsync(
                conversation,
                command.UserId,
                command.InitialMessage,
                isAdmin: false,
                senderType: SupportMessageSenderType.User,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                markAsReadAtUtc: null,
                updateAssignmentAndStatus: true);
            appendedInitialMessage = true;

            if (createdConversation)
            {
                await AppendSystemEventAsync(
                    conversation,
                    "User sent first message");
            }
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
            var requestedStatus = ToCanonicalStatus(status);
            conversationsQuery = requestedStatus switch
            {
                SupportConversationStatus.New => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.New
                         || x.Status == SupportConversationStatus.WaitingForSupport),
                SupportConversationStatus.InProgress => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.InProgress),
                SupportConversationStatus.WaitingForUser => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.WaitingForUser),
                SupportConversationStatus.Closed => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.Closed
                         || x.Status == SupportConversationStatus.Resolved),
                _ => conversationsQuery
            };
        }

        if (!string.IsNullOrWhiteSpace(query.Source))
        {
            if (!Enum.TryParse<SupportConversationSource>(query.Source, true, out var source))
            {
                return Result.Failure<IReadOnlyList<SupportConversationSummaryResponse>>(InvalidStatus);
            }

            var requestedSource = ToCanonicalSource(source);
            conversationsQuery = requestedSource == SupportConversationSource.MobileChat
                ? conversationsQuery.Where(x => x.Source == SupportConversationSource.MobileChat || x.Source == SupportConversationSource.Direct)
                : conversationsQuery.Where(x => x.Source == requestedSource);
        }

        if (!string.IsNullOrWhiteSpace(query.Priority))
        {
            if (!Enum.TryParse<SupportConversationPriority>(query.Priority, true, out var priority))
            {
                return Result.Failure<IReadOnlyList<SupportConversationSummaryResponse>>(InvalidStatus);
            }

            conversationsQuery = conversationsQuery.Where(x => x.Priority == priority);
        }

        if (query.AssignedAdminId.HasValue)
        {
            conversationsQuery = conversationsQuery.Where(x => x.AssignedAdminId == query.AssignedAdminId.Value);
        }
        else if (query.UnassignedOnly)
        {
            conversationsQuery = conversationsQuery.Where(x => x.AssignedAdminId == null);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            conversationsQuery = conversationsQuery.Where(x =>
                x.LastMessagePreview != null && x.LastMessagePreview.Contains(search));
        }

        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);

        var conversationRows = await conversationsQuery
            .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
            .ThenBy(x => x.Status == SupportConversationStatus.New ? 0
                : x.Status == SupportConversationStatus.InProgress ? 1
                : x.Status == SupportConversationStatus.WaitingForUser ? 2
                : 3)
            .ThenBy(x => x.WaitingSinceUtc ?? x.LastMessageAtUtc ?? x.CreatedAtUtc)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(conversation => new
            {
                conversation.Id,
                conversation.InitiatorUserId,
                conversation.AssignedAdminId,
                conversation.Status,
                conversation.Priority,
                conversation.Source,
                conversation.AssistantScenario,
                conversation.LastMessageAtUtc,
                conversation.LastMessagePreview,
                conversation.LastMessageSenderType,
                conversation.WaitingSinceUtc,
                conversation.CreatedAtUtc,
                conversation.UpdatedAtUtc,
                conversation.ResolvedAtUtc,
                conversation.ReopenUntilUtc,
                conversation.ClosedAtUtc,
                conversation.ClosedByUserId,
                conversation.ReopenedAtUtc,
                conversation.ReopenedByUserId,
                conversation.FeedbackRating,
                LastMessage = conversation.Messages
                    .Where(message => message.SenderType != SupportMessageSenderType.System && !message.IsInternalNote)
                    .OrderByDescending(message => message.CreatedAtUtc)
                    .Select(message => new
                    {
                        message.Body,
                        message.CreatedAtUtc,
                        message.SenderType
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
        var now = DateTime.UtcNow;

        var summaries = conversationRows.Select(conversation =>
        {
            users.TryGetValue(conversation.InitiatorUserId, out var initiator);
            IdentityUserLookup? assignedAdmin = null;
            if (conversation.AssignedAdminId.HasValue)
            {
                users.TryGetValue(conversation.AssignedAdminId.Value, out assignedAdmin);
            }

            var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
            var normalizedSource = ToCanonicalSource(conversation.Source);

            return new SupportConversationSummaryResponse(
                conversation.Id,
                conversation.InitiatorUserId,
                initiator?.Email ?? string.Empty,
                initiator?.DisplayName,
                conversation.AssignedAdminId,
                ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName),
                normalizedStatus.ToString(),
                conversation.Priority.ToString(),
                normalizedSource.ToString(),
                conversation.AssistantScenario,
                conversation.LastMessagePreview ?? (conversation.LastMessage is null ? null : Truncate(conversation.LastMessage.Body, 140)),
                conversation.LastMessage?.CreatedAtUtc ?? conversation.LastMessageAtUtc,
                (conversation.LastMessageSenderType ?? conversation.LastMessage?.SenderType)?.ToString(),
                conversation.WaitingSinceUtc ?? ResolveWaitingSince(normalizedStatus, conversation.LastMessage?.CreatedAtUtc ?? conversation.LastMessageAtUtc, conversation.CreatedAtUtc),
                CalculateWaitingMinutes(conversation.WaitingSinceUtc ?? ResolveWaitingSince(normalizedStatus, conversation.LastMessage?.CreatedAtUtc ?? conversation.LastMessageAtUtc, conversation.CreatedAtUtc), now),
                conversation.UnreadAdminCount > 0,
                conversation.UnreadUserCount,
                conversation.UnreadAdminCount,
                conversation.CreatedAtUtc,
                conversation.UpdatedAtUtc,
                conversation.ResolvedAtUtc,
                ResolveReopenUntil(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc),
                conversation.ClosedAtUtc,
                conversation.ClosedByUserId,
                conversation.ReopenedAtUtc,
                conversation.ReopenedByUserId,
                conversation.FeedbackRating,
                IsConversationReadOnly(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, conversation.ClosedAtUtc, now),
                CanReopenConversation(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now));
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

    public async Task<Result<SupportTicketContextResponse>> GetAdminTicketContextAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .Where(x => x.Id == conversationId)
            .Select(x => new
            {
                x.RelatedGenerationId,
                x.RelatedPaymentId,
                x.RelatedSubscriptionId
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportTicketContextResponse>(ConversationNotFound);
        }

        return Result.Success(new SupportTicketContextResponse(
            TokenBalance: 0,
            Plan: "Free",
            PremiumStatus: "Inactive",
            LastPayment: null,
            LinkedGeneration: conversation.RelatedGenerationId,
            LastGeneration: null,
            LastGenerationError: null,
            GenerationErrorsCount: 0,
            RelatedPaymentId: conversation.RelatedPaymentId,
            RelatedSubscriptionId: conversation.RelatedSubscriptionId));
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

        var canAppendError = ValidateConversationCanAcceptMessage(conversation, command.IsAdmin, DateTime.UtcNow);
        if (canAppendError is not null)
        {
            return Result.Failure<SupportMessageResponse>(canAppendError);
        }

        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var shouldAppendAutomaticReply = !command.IsAdmin
            && !conversation.Messages.Any(message =>
                message.SenderType is SupportMessageSenderType.User or SupportMessageSenderType.Bot);
        var shouldAppendReopenedEvent = !command.IsAdmin && currentStatus == SupportConversationStatus.Closed;

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            senderType: command.IsAdmin ? SupportMessageSenderType.SupportAgent : SupportMessageSenderType.User,
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
                senderType: SupportMessageSenderType.Bot,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                markAsReadAtUtc: DateTime.UtcNow,
                updateAssignmentAndStatus: false);
        }

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
        var response = await BuildMessageResponseAsync(message, cancellationToken);
        if (command.IsAdmin)
        {
            await NotifyUserMessageAsync(conversation, response, cancellationToken);
        }

        return Result.Success(response);
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

        var canAppendError = ValidateConversationCanAcceptMessage(conversation, command.IsAdmin, DateTime.UtcNow);
        if (canAppendError is not null)
        {
            return Result.Failure<SupportMessageResponse>(canAppendError);
        }

        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var shouldAppendReopenedEvent = !command.IsAdmin && currentStatus == SupportConversationStatus.Closed;

        var message = await AppendMessageAsync(
            conversation,
            command.SenderUserId,
            command.Body,
            command.IsAdmin,
            senderType: command.IsAdmin ? SupportMessageSenderType.SupportAgent : SupportMessageSenderType.User,
            attachmentUrl: null,
            attachmentFileName: command.AttachmentFileName,
            attachmentContentType: command.AttachmentContentType,
            attachmentFileSizeBytes: null,
            attachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
            attachmentUploadErrorCode: null,
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
        var response = await BuildMessageResponseAsync(message, cancellationToken);
        if (command.IsAdmin && command.AttachmentUploadStatus == SupportAttachmentUploadStatus.Uploaded)
        {
            await NotifyUserMessageAsync(conversation, response, cancellationToken);
        }

        return Result.Success(response);
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

    public async Task<Result<SupportConversationDetailResponse>> ResolveConversationAsync(ResolveSupportConversationCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.ConversationReadOnly);
        }

        var now = DateTime.UtcNow;
        MarkClosed(conversation, now, command.UserId);
        await AppendSystemEventAsync(conversation, "Ticket closed by operator");

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> CloseConversationAsync(CloseSupportConversationCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        var now = DateTime.UtcNow;
        MarkClosed(conversation, now, command.UserId);
        await AppendSystemEventAsync(conversation, "Ticket closed by operator");

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> ReopenConversationAsync(ReopenSupportConversationCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        var now = DateTime.UtcNow;
        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed)
        {
            var reopenedStatus = command.IsAdmin ? SupportConversationStatus.InProgress : SupportConversationStatus.New;
            MarkActive(conversation, reopenedStatus, now, command.UserId);
            await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket reopened by operator" : "Ticket reopened by user message");
            await AppendStatusChangedEventAsync(conversation, SupportConversationStatus.Closed, reopenedStatus);
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> SubmitConversationFeedbackAsync(SubmitSupportConversationFeedbackCommand command, CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) != SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.FeedbackNotAllowed);
        }

        if (command.Rating is < 1 or > 5)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.InvalidFeedbackRating);
        }

        var now = DateTime.UtcNow;
        conversation.FeedbackRating = command.Rating;
        conversation.FeedbackComment = string.IsNullOrWhiteSpace(command.Comment)
            ? null
            : command.Comment.Trim();
        conversation.FeedbackSubmittedAtUtc = now;
        conversation.UpdatedAtUtc = now;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
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
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var nextStatus = ToCanonicalStatus(command.Status);

        if (currentStatus != nextStatus && !IsAllowedStatusTransition(currentStatus, nextStatus))
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        conversation.AssignedAdminId ??= command.AdminUserId;
        if (nextStatus == SupportConversationStatus.Closed)
        {
            MarkClosed(conversation, now, command.AdminUserId);
            await AppendSystemEventAsync(conversation, "Ticket closed by operator");
        }
        else
        {
            if (currentStatus == SupportConversationStatus.Closed && nextStatus == SupportConversationStatus.InProgress)
            {
                MarkActive(conversation, nextStatus, now, command.AdminUserId);
                await AppendSystemEventAsync(conversation, "Ticket reopened by operator");
            }
            else
            {
                MarkActive(conversation, nextStatus, now);
            }

            if (currentStatus == SupportConversationStatus.New && nextStatus == SupportConversationStatus.InProgress)
            {
                await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
            }
        }

        if (currentStatus != nextStatus)
        {
            await AppendStatusChangedEventAsync(conversation, currentStatus, nextStatus);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private static bool IsAllowedStatusTransition(SupportConversationStatus currentStatus, SupportConversationStatus nextStatus)
    {
        return currentStatus switch
        {
            SupportConversationStatus.New => nextStatus is SupportConversationStatus.InProgress or SupportConversationStatus.WaitingForUser or SupportConversationStatus.Closed,
            SupportConversationStatus.InProgress => nextStatus is SupportConversationStatus.WaitingForUser or SupportConversationStatus.Closed,
            SupportConversationStatus.WaitingForUser => nextStatus is SupportConversationStatus.InProgress or SupportConversationStatus.Closed,
            SupportConversationStatus.Closed => nextStatus is SupportConversationStatus.InProgress,
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
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (currentStatus == SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        conversation.AssignedAdminId = command.AssignedAdminId;
        conversation.UpdatedAtUtc = now;
        if (command.AssignedAdminId.HasValue && currentStatus == SupportConversationStatus.New)
        {
            MarkActive(conversation, SupportConversationStatus.InProgress, now);
            await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
            await AppendStatusChangedEventAsync(conversation, currentStatus, SupportConversationStatus.InProgress);
        }
        else if (command.AssignedAdminId.HasValue)
        {
            await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
        }
        else
        {
            await AppendSystemEventAsync(conversation, "Ticket unassigned");
        }

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

    private async Task NotifyUserMessageAsync(
        SupportConversation conversation,
        SupportMessageResponse message,
        CancellationToken cancellationToken)
    {
        try
        {
            await pushNotificationSender.NotifyUserAsync(
                new SupportChatPushNotification(
                    conversation.Id,
                    conversation.InitiatorUserId,
                    message.MessageId,
                    message.SenderDisplayName,
                    message.Body,
                    message.AttachmentUrl is not null),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Push delivery is best-effort and must not block support replies.
        }
    }

    private Task<ConversationMessage> AppendMessageAsync(
        SupportConversation conversation,
        Guid senderUserId,
        string body,
        bool isAdmin,
        SupportMessageSenderType senderType,
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

        if (isAdmin && updateAssignmentAndStatus)
        {
            conversation.AssignedAdminId ??= senderUserId;
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

        conversation.LastMessageAtUtc = now;
        conversation.LastMessagePreview = Truncate(trimmedBody, 280);
        conversation.LastMessageSenderType = senderType;
        conversation.WaitingSinceUtc = ResolveWaitingSince(
            ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId),
            now,
            conversation.CreatedAtUtc);
        supportChatDbContext.ConversationMessages.Add(message);
        return Task.FromResult(message);
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
            var resolvedSenderType = ResolveSenderDisplayType(message.SenderType, message.IsFromAdmin);
            messages.Add(new SupportMessageResponse(
                message.Id,
                message.ConversationId,
                message.SenderUserId,
                ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
                message.IsFromAdmin,
                resolvedSenderType,
                message.Body,
                message.AttachmentUrl,
                message.AttachmentFileName,
                message.AttachmentContentType,
                message.AttachmentFileSizeBytes,
                ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
                message.AttachmentUploadErrorCode,
                message.ReadAtUtc.HasValue,
                message.ReadAtUtc,
                message.DeliveredAtUtc,
                message.IsInternalNote,
                message.CreatedAtUtc));
        }

        var userUnreadCount = conversation.Messages.Count(x => x.IsFromAdmin && x.ReadAtUtc is null);
        var adminUnreadCount = conversation.Messages.Count(x => !x.IsFromAdmin && x.ReadAtUtc is null);
        var now = DateTime.UtcNow;
        var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var normalizedSource = ToCanonicalSource(conversation.Source);
        var lastVisibleMessage = visibleMessages.LastOrDefault(message =>
            message.SenderType != SupportMessageSenderType.System && !message.IsInternalNote);
        var waitingSince = conversation.WaitingSinceUtc
            ?? ResolveWaitingSince(
                normalizedStatus,
                conversation.LastMessageAtUtc ?? lastVisibleMessage?.CreatedAtUtc,
                conversation.CreatedAtUtc);

        return new SupportConversationDetailResponse(
            conversation.Id,
            conversation.InitiatorUserId,
            initiator?.Email ?? string.Empty,
            initiator?.DisplayName,
            conversation.AssignedAdminId,
            ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName, isAdminSender: true),
            normalizedStatus.ToString(),
            conversation.Priority.ToString(),
            normalizedSource.ToString(),
            conversation.AssistantScenario,
            conversation.RelatedGenerationId,
            conversation.RelatedPaymentId,
            conversation.RelatedSubscriptionId,
            userUnreadCount,
            adminUnreadCount,
            conversation.CreatedAtUtc,
            conversation.UpdatedAtUtc,
            conversation.LastMessageAtUtc ?? lastVisibleMessage?.CreatedAtUtc,
            conversation.LastMessagePreview ?? (lastVisibleMessage is null ? null : Truncate(lastVisibleMessage.Body, 280)),
            (conversation.LastMessageSenderType ?? lastVisibleMessage?.SenderType)?.ToString(),
            waitingSince,
            CalculateWaitingMinutes(waitingSince, now),
            conversation.ResolvedAtUtc,
            ResolveReopenUntil(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc),
            conversation.ClosedAtUtc,
            conversation.ClosedByUserId,
            conversation.ReopenedAtUtc,
            conversation.ReopenedByUserId,
            conversation.FeedbackRating,
            conversation.FeedbackComment,
            conversation.FeedbackSubmittedAtUtc,
            IsConversationReadOnly(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, conversation.ClosedAtUtc, now),
            CanReopenConversation(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now),
            ResolveAvailableActions(normalizedStatus, conversation.AssignedAdminId.HasValue),
            messages);
    }

    private async Task<SupportMessageResponse> BuildMessageResponseAsync(ConversationMessage message, CancellationToken cancellationToken)
    {
        var sender = await identityUserLookupService.GetUserByIdAsync(message.SenderUserId, cancellationToken);

        return new SupportMessageResponse(
            message.Id,
            message.ConversationId,
            message.SenderUserId,
            ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
            message.IsFromAdmin,
            ResolveSenderDisplayType(message.SenderType, message.IsFromAdmin),
            message.Body,
            message.AttachmentUrl,
            message.AttachmentFileName,
            message.AttachmentContentType,
            message.AttachmentFileSizeBytes,
            ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
            message.AttachmentUploadErrorCode,
            message.ReadAtUtc.HasValue,
            message.ReadAtUtc,
            message.DeliveredAtUtc,
            message.IsInternalNote,
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

    private static Error? ValidateConversationCanAcceptMessage(SupportConversation conversation, bool isAdmin, DateTime now)
    {
        var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (normalizedStatus == SupportConversationStatus.Closed)
        {
            return isAdmin ? SupportChatErrors.ConversationReadOnly : null;
        }
        return null;
    }

    private static bool ShouldReactivateConversationForUserMessage(SupportConversation conversation, DateTime now)
    {
        return ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
    }

    private static void MarkResolved(SupportConversation conversation, DateTime now)
    {
        MarkClosed(conversation, now, closedByUserId: null);
    }

    private static void MarkClosed(SupportConversation conversation, DateTime now, Guid? closedByUserId)
    {
        conversation.Status = SupportConversationStatus.Closed;
        conversation.ResolvedAtUtc ??= now;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = now;
        conversation.ClosedByUserId = closedByUserId;
        conversation.WaitingSinceUtc = null;
        conversation.UpdatedAtUtc = now;
    }

    private static void MarkActive(SupportConversation conversation, SupportConversationStatus status, DateTime now, Guid? reopenedByUserId = null)
    {
        var wasClosed = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
        conversation.Status = status;
        conversation.ResolvedAtUtc = null;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = null;
        conversation.ClosedByUserId = null;
        if (wasClosed || reopenedByUserId.HasValue)
        {
            conversation.ReopenedAtUtc = now;
            conversation.ReopenedByUserId = reopenedByUserId;
        }

        conversation.WaitingSinceUtc = ResolveWaitingSince(status, conversation.LastMessageAtUtc, conversation.CreatedAtUtc);
        conversation.UpdatedAtUtc = now;
    }

    private Task AppendStatusChangedEventAsync(
        SupportConversation conversation,
        SupportConversationStatus currentStatus,
        SupportConversationStatus nextStatus)
    {
        return AppendSystemEventAsync(conversation, $"Status changed: {currentStatus} -> {nextStatus}");
    }

    private static DateTime? ResolveWaitingSince(
        SupportConversationStatus status,
        DateTime? lastMessageAtUtc,
        DateTime createdAtUtc)
    {
        return status switch
        {
            SupportConversationStatus.New or SupportConversationStatus.InProgress => lastMessageAtUtc ?? createdAtUtc,
            _ => null
        };
    }

    private static int CalculateWaitingMinutes(DateTime? waitingSinceUtc, DateTime now)
    {
        if (!waitingSinceUtc.HasValue)
        {
            return 0;
        }

        return Math.Max(0, (int)Math.Floor((now - waitingSinceUtc.Value).TotalMinutes));
    }

    private static IReadOnlyList<string> ResolveAvailableActions(SupportConversationStatus status, bool hasAssignment)
    {
        return status switch
        {
            SupportConversationStatus.New => ["assign-to-me", "close"],
            SupportConversationStatus.InProgress => hasAssignment
                ? ["mark-waiting-for-user", "close", "unassign"]
                : ["assign-to-me", "mark-waiting-for-user", "close"],
            SupportConversationStatus.WaitingForUser => ["mark-in-progress", "close"],
            SupportConversationStatus.Closed => ["reopen"],
            _ => []
        };
    }

    private static DateTime? ResolveReopenUntil(SupportConversation conversation)
    {
        return ResolveReopenUntil(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc);
    }

    private static DateTime? ResolveReopenUntil(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc)
    {
        return null;
    }

    private static bool CanReopenConversation(SupportConversation conversation, DateTime now)
    {
        return CanReopenConversation(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now);
    }

    private static bool CanReopenConversation(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static bool IsConversationReadOnly(SupportConversation conversation, DateTime now)
    {
        return IsConversationReadOnly(
            conversation.Status,
            conversation.ResolvedAtUtc,
            conversation.ReopenUntilUtc,
            conversation.ClosedAtUtc,
            now);
    }

    private static bool IsConversationReadOnly(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime? closedAtUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static SupportConversationStatus ToCanonicalStatus(
        SupportConversationStatus status,
        Guid? assignedAdminId = null)
    {
        return status switch
        {
            SupportConversationStatus.Resolved => SupportConversationStatus.Closed,
            SupportConversationStatus.WaitingForSupport => assignedAdminId.HasValue
                ? SupportConversationStatus.InProgress
                : SupportConversationStatus.New,
            SupportConversationStatus.Open => SupportConversationStatus.New,
            _ => status
        };
    }

    private static SupportConversationSource ToCanonicalSource(SupportConversationSource source)
    {
        return source switch
        {
            SupportConversationSource.Direct => SupportConversationSource.MobileChat,
            _ => source
        };
    }

    private static string ResolveSenderDisplayType(SupportMessageSenderType senderType, bool isFromAdmin) =>
        senderType.ToString();

    private static string ResolveMessageSenderDisplayName(
        SupportMessageSenderType senderType,
        string? email,
        string? displayName,
        bool isFromAdmin) => senderType switch
        {
            SupportMessageSenderType.System => "System",
            SupportMessageSenderType.Bot => "PetMagic Support",
            _ => ResolveDisplayName(email, displayName, isFromAdmin),
        };

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
