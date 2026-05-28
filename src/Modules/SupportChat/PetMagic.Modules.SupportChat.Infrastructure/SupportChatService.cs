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
    ISupportChatPushNotificationSender pushNotificationSender,
    ISupportAttachmentStorage attachmentStorage,
    SupportAttachmentStorageOptions attachmentStorageOptions) : ISupportChatService
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
                replyToMessageId: null,
                replyToPreview: null,
                senderType: SupportMessageSenderType.User,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                attachments: [],
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
            .Include(x => x.Messages)
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
        var shouldAppendAutomaticReply = !isAdmin
            && !conversation.Messages.Any(message =>
                message.SenderType is SupportMessageSenderType.User or SupportMessageSenderType.Bot);
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
        await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket closed by operator" : "Ticket closed by user");

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
        await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket closed by operator" : "Ticket closed by user");

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
            var snapshot = await supportChatDbContext.SupportConversations
                .AsNoTracking()
                .Where(x => x.Id == conversation.Id)
                .Select(x => new
                {
                    x.Id,
                    x.InitiatorUserId,
                    x.UpdatedAtUtc,
                    x.LastMessagePreview,
                    x.LastMessageAtUtc,
                    x.LastMessageSenderType,
                    AdminUnreadCount = x.Messages.Count(message => !message.IsFromAdmin && message.ReadAtUtc == null),
                    UserUnreadCount = x.Messages.Count(message => message.IsFromAdmin && message.ReadAtUtc == null)
                })
                .FirstOrDefaultAsync(cancellationToken);

            if (snapshot is null)
            {
                return;
            }

            await realtimeNotifier.NotifyConversationUpdatedAsync(
                new SupportConversationRealtimeEvent(
                    snapshot.Id,
                    snapshot.InitiatorUserId,
                    snapshot.UpdatedAtUtc,
                    snapshot.LastMessagePreview,
                    snapshot.LastMessageAtUtc,
                    snapshot.LastMessageSenderType?.ToString(),
                    snapshot.AdminUnreadCount,
                    snapshot.UserUnreadCount),
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
                    message.Attachments.Count > 0 || message.AttachmentUrl is not null,
                    await supportChatDbContext.ConversationMessages.CountAsync(
                        x => x.ConversationId == conversation.Id && x.IsFromAdmin && x.ReadAtUtc == null,
                        cancellationToken)),
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
        bool updateAssignmentAndStatus)
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
            .Include(x => x.Messages)
                .ThenInclude(message => message.Attachments)
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
            var messageAttachments = BuildAttachmentResponses(message);
            messages.Add(new SupportMessageResponse(
                message.Id,
                message.ConversationId,
                message.SenderUserId,
                ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
                message.IsFromAdmin,
                resolvedSenderType,
                message.Body,
                message.ReplyToMessageId,
                message.ReplyToPreview,
                message.AttachmentUrl,
                message.AttachmentFileName,
                message.AttachmentContentType,
                message.AttachmentFileSizeBytes,
                ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
                message.AttachmentUploadErrorCode,
                messageAttachments,
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
        var messageAttachments = BuildAttachmentResponses(message);

        return new SupportMessageResponse(
            message.Id,
            message.ConversationId,
            message.SenderUserId,
            ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
            message.IsFromAdmin,
            ResolveSenderDisplayType(message.SenderType, message.IsFromAdmin),
            message.Body,
            message.ReplyToMessageId,
            message.ReplyToPreview,
            message.AttachmentUrl,
            message.AttachmentFileName,
            message.AttachmentContentType,
            message.AttachmentFileSizeBytes,
            ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
            message.AttachmentUploadErrorCode,
            messageAttachments,
            message.ReadAtUtc.HasValue,
            message.ReadAtUtc,
            message.DeliveredAtUtc,
            message.IsInternalNote,
            message.CreatedAtUtc);
    }

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
        var trimmedBody = sourceMessage.Body.Trim();
        var orderedAttachments = sourceMessage.Attachments
            .OrderBy(attachment => attachment.SortOrder)
            .ToList();
        if (orderedAttachments.Count > 0)
        {
            if (!string.IsNullOrWhiteSpace(trimmedBody)
                && !orderedAttachments.Any(attachment => string.Equals(
                    attachment.FileName.Trim(),
                    trimmedBody,
                    StringComparison.OrdinalIgnoreCase)))
            {
                return Truncate(trimmedBody, 160);
            }

            if (orderedAttachments.Count > 1)
            {
                return $"Attachments ({orderedAttachments.Count})";
            }

            var attachment = orderedAttachments[0];
            if (attachment.IsDeleted)
            {
                return "Attachment deleted";
            }

            if (attachment.MimeType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                return "Photo";
            }

            if (attachment.MimeType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
            {
                return "Video";
            }

            return attachment.FileName;
        }

        if (!string.IsNullOrWhiteSpace(trimmedBody))
        {
            return Truncate(trimmedBody, 160);
        }

        if (!string.IsNullOrWhiteSpace(sourceMessage.AttachmentFileName))
        {
            return sourceMessage.AttachmentFileName;
        }

        return "Message";
    }

    private sealed record ResolvedReplyTarget(Guid MessageId, string Preview);

    private static IReadOnlyList<SupportMessageAttachmentInput> BuildLegacyAttachmentInputs(SendSupportMessageCommand command)
    {
        if (string.IsNullOrWhiteSpace(command.AttachmentUrl)
            || string.IsNullOrWhiteSpace(command.AttachmentFileName)
            || string.IsNullOrWhiteSpace(command.AttachmentContentType)
            || command.AttachmentFileSizeBytes is null or <= 0)
        {
            return [];
        }

        return
        [
            new SupportMessageAttachmentInput(
                command.AttachmentUrl,
                command.AttachmentContentType,
                command.AttachmentFileName,
                command.AttachmentFileSizeBytes.Value)
        ];
    }

    private static IReadOnlyList<SupportMessageAttachmentInput> NormalizeAttachmentInputs(
        IReadOnlyList<SupportMessageAttachmentInput>? attachments)
    {
        if (attachments is null || attachments.Count == 0)
        {
            return [];
        }

        return attachments
            .Where(attachment =>
                !string.IsNullOrWhiteSpace(attachment.FileUrl)
                && !string.IsNullOrWhiteSpace(attachment.FileName)
                && !string.IsNullOrWhiteSpace(attachment.MimeType)
                && attachment.SizeBytes > 0)
            .ToList();
    }

    private string? ResolveStorageKey(string fileUrl, string? explicitStorageKey)
    {
        if (!string.IsNullOrWhiteSpace(explicitStorageKey))
        {
            return explicitStorageKey.Trim();
        }

        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return null;
        }

        var baseUrl = attachmentStorageOptions.PublicBaseUrl.TrimEnd('/');
        if (!fileUrl.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = fileUrl[baseUrl.Length..].TrimStart('/');
        return string.IsNullOrWhiteSpace(relativePath)
            ? null
            : relativePath.Replace('\\', '/');
    }

    private static IReadOnlyList<SupportMessageAttachmentResponse> BuildAttachmentResponses(ConversationMessage message)
    {
        if (message.Attachments.Count > 0)
        {
            return message.Attachments
                .OrderBy(attachment => attachment.SortOrder)
                .Select(attachment => new SupportMessageAttachmentResponse(
                    attachment.IsDeleted ? string.Empty : attachment.FileUrl,
                    ResolveAttachmentType(attachment.MimeType),
                    attachment.MimeType,
                    attachment.FileName,
                    attachment.SizeBytes,
                    attachment.DurationSeconds,
                    attachment.Width,
                    attachment.Height,
                    attachment.IsDeleted,
                    attachment.ExpiresAtUtc,
                    attachment.DeletedAtUtc))
                .ToList();
        }

        if (string.IsNullOrWhiteSpace(message.AttachmentUrl)
            || string.IsNullOrWhiteSpace(message.AttachmentFileName)
            || string.IsNullOrWhiteSpace(message.AttachmentContentType)
            || message.AttachmentFileSizeBytes is null or <= 0)
        {
            return [];
        }

        return
        [
            new SupportMessageAttachmentResponse(
                message.AttachmentUrl,
                ResolveAttachmentType(message.AttachmentContentType),
                message.AttachmentContentType,
                message.AttachmentFileName,
                message.AttachmentFileSizeBytes.Value,
                DurationSeconds: null,
                Width: null,
                Height: null,
                IsDeleted: false,
                ExpiresAtUtc: null,
                DeletedAtUtc: null)
        ];
    }

    private static string ResolveAttachmentType(string mimeType)
    {
        if (mimeType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return "image";
        }

        if (mimeType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            return "video";
        }

        return "file";
    }

    private static string BuildMessagePreview(
        string trimmedBody,
        IReadOnlyList<SupportMessageAttachmentInput> attachments)
    {
        if (!string.IsNullOrWhiteSpace(trimmedBody))
        {
            return trimmedBody;
        }

        if (attachments.Count == 0)
        {
            return string.Empty;
        }

        if (attachments.Count == 1)
        {
            return attachments[0].FileName;
        }

        return $"{attachments.Count} attachments";
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
