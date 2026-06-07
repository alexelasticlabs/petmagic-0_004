using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService(
    SupportChatDbContext supportChatDbContext,
    IIdentityUserLookupService identityUserLookupService,
    ISupportChatRealtimeNotifier realtimeNotifier,
    ISupportChatPushNotificationSender pushNotificationSender,
    ISupportAttachmentStorage attachmentStorage,
    SupportAttachmentStorageOptions attachmentStorageOptions) : ISupportChatService
{
    private const int DefaultConversationMessagesTake = 60;
    private const int MaxConversationMessagesTake = 120;
    private static readonly Guid AutomatedAssistantUserId = Guid.Parse("2F1E3B3B-8A2E-4A8E-9EE5-97BF31B33218");
    private const int LegacyDirectSourceValue = 0;
    private const int LegacyResolvedStatusValue = 2;
    private const int LegacyWaitingForSupportStatusValue = 4;
    private static readonly Error ConversationNotFound = new("support.conversation_not_found", "Support conversation was not found.");
    private static readonly Error MessageNotFound = new("support.message_not_found", "Support message was not found.");
    private static readonly Error Forbidden = new("support.forbidden", "You do not have access to this support conversation.");
    private static readonly Error InvalidStatus = new("support.status_invalid", "Support conversation status is not supported.");
    private static readonly Error InvalidStatusTransition = new("support.status_transition_invalid", "Support conversation status transition is not allowed.");
    private static readonly Error InvalidTags = new("support.tags_invalid", "Support conversation tags are invalid.");

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

            if (ToCanonicalSource(command.Source) == SupportConversationSource.MobileChat)
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

    public async Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(
        Guid userId,
        SupportConversationMessagesQuery query,
        CancellationToken cancellationToken)
    {
        var conversationId = await supportChatDbContext.SupportConversations
            .Where(x => x.InitiatorUserId == userId)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (conversationId is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId.Value, query, cancellationToken));
    }

    public Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(
        Guid userId,
        CancellationToken cancellationToken)
        => GetUserConversationAsync(userId, new SupportConversationMessagesQuery(), cancellationToken);

    public async Task<Result<SupportConversationInboxPageResponse>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken)
    {
        var conversationsQuery = supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            if (!Enum.TryParse<SupportConversationStatus>(query.Status, true, out var status))
            {
                return Result.Failure<SupportConversationInboxPageResponse>(InvalidStatus);
            }
            var requestedStatus = ToCanonicalStatus(status);
            conversationsQuery = requestedStatus switch
            {
                SupportConversationStatus.New => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.New
                         || (int)x.Status == LegacyWaitingForSupportStatusValue),
                SupportConversationStatus.InProgress => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.InProgress),
                SupportConversationStatus.WaitingForUser => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.WaitingForUser),
                SupportConversationStatus.Closed => conversationsQuery.Where(
                    x => x.Status == SupportConversationStatus.Closed
                         || (int)x.Status == LegacyResolvedStatusValue),
                _ => conversationsQuery
            };
        }

        if (!string.IsNullOrWhiteSpace(query.Source))
        {
            if (!Enum.TryParse<SupportConversationSource>(query.Source, true, out var source))
            {
                return Result.Failure<SupportConversationInboxPageResponse>(InvalidStatus);
            }

            var requestedSource = ToCanonicalSource(source);
            conversationsQuery = requestedSource == SupportConversationSource.MobileChat
                ? conversationsQuery.Where(x => x.Source == SupportConversationSource.MobileChat || (int)x.Source == LegacyDirectSourceValue)
                : conversationsQuery.Where(x => x.Source == requestedSource);
        }

        if (!string.IsNullOrWhiteSpace(query.Priority))
        {
            if (!Enum.TryParse<SupportConversationPriority>(query.Priority, true, out var priority))
            {
                return Result.Failure<SupportConversationInboxPageResponse>(InvalidStatus);
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
            var searchLower = search.ToLowerInvariant();
            conversationsQuery = conversationsQuery.Where(x =>
                (x.LastMessagePreview != null && x.LastMessagePreview.ToLower().Contains(searchLower))
                || (x.TagsJson != null && x.TagsJson.ToLower().Contains(searchLower)));
        }

        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        var totalCount = await conversationsQuery.CountAsync(cancellationToken);

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
                conversation.TagsJson,
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
                ParseTags(conversation.TagsJson),
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

        return Result.Success(new SupportConversationInboxPageResponse(
            summaries,
            page,
            pageSize,
            totalCount,
            page * pageSize < totalCount));
    }

    public async Task<Result<AdminSupportInboxMetricsResponse>> GetAdminInboxMetricsAsync(CancellationToken cancellationToken)
    {
        var metrics = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalConversations = group.Count(),
                ClosedConversations = group.Count(x =>
                    x.Status == SupportConversationStatus.Closed ||
                    (int)x.Status == LegacyResolvedStatusValue),
                UnassignedConversations = group.Count(x => x.AssignedAdminId == null),
                UnreadForAdminConversations = group.Count(x =>
                    x.Messages.Any(message => !message.IsFromAdmin && message.ReadAtUtc == null))
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (metrics is null)
        {
            return Result.Success(new AdminSupportInboxMetricsResponse(0, 0, 0, 0, 0));
        }

        return Result.Success(new AdminSupportInboxMetricsResponse(
            metrics.TotalConversations,
            Math.Max(0, metrics.TotalConversations - metrics.ClosedConversations),
            metrics.ClosedConversations,
            metrics.UnassignedConversations,
            metrics.UnreadForAdminConversations));
    }

    public async Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        SupportConversationMessagesQuery query,
        CancellationToken cancellationToken)
    {
        var exists = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AnyAsync(x => x.Id == conversationId, cancellationToken);
        if (!exists)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId, query, cancellationToken));
    }

    public Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
        => GetAdminConversationAsync(conversationId, new SupportConversationMessagesQuery(), cancellationToken);

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

        if (currentStatus == SupportConversationStatus.New && nextStatus == SupportConversationStatus.InProgress)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

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
            SupportConversationStatus.New => nextStatus is SupportConversationStatus.Closed,
            SupportConversationStatus.InProgress => nextStatus is SupportConversationStatus.Closed,
            SupportConversationStatus.WaitingForUser => nextStatus is SupportConversationStatus.Closed,
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
        if (currentStatus == SupportConversationStatus.New && command.AssignedAdminId.HasValue)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

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

    public async Task<Result<SupportConversationDetailResponse>> UpdateConversationMetadataAsync(
        UpdateSupportConversationMetadataCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        var normalizedTags = NormalizeTags(command.Tags);
        if (normalizedTags is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidTags);
        }

        conversation.Priority = command.Priority;
        conversation.TagsJson = SerializeTags(normalizedTags);
        conversation.UpdatedAtUtc = DateTime.UtcNow;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
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

}
