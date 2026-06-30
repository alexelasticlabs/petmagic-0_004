using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationInboxPageResponse>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken)
    {
        var conversationsQuery = supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AsQueryable();

        var requestedStatusFilters = (query.Statuses is { Count: > 0 }
                ? query.Statuses
                : string.IsNullOrWhiteSpace(query.Status) ? [] : [query.Status])
            .Where(status => !string.IsNullOrWhiteSpace(status))
            .Select(status => status.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (requestedStatusFilters.Length > 0)
        {
            var requestedStatuses = new HashSet<SupportConversationStatus>();
            foreach (var statusFilter in requestedStatusFilters)
            {
                if (!TryParseNamedEnum<SupportConversationStatus>(statusFilter, out var status))
                {
                    return Result.Failure<SupportConversationInboxPageResponse>(InvalidStatus);
                }

                requestedStatuses.Add(ToCanonicalStatus(status));
            }

            var includeNew = requestedStatuses.Contains(SupportConversationStatus.New);
            var includeInProgress = requestedStatuses.Contains(SupportConversationStatus.InProgress);
            var includeWaitingForUser = requestedStatuses.Contains(SupportConversationStatus.WaitingForUser);
            var includeClosed = requestedStatuses.Contains(SupportConversationStatus.Closed);

            conversationsQuery = conversationsQuery.Where(x =>
                (includeNew && x.Status == SupportConversationStatus.New)
                || (includeInProgress && x.Status == SupportConversationStatus.InProgress)
                || (includeWaitingForUser && x.Status == SupportConversationStatus.WaitingForUser)
                || (includeClosed && x.Status == SupportConversationStatus.Closed));
        }

        if (!string.IsNullOrWhiteSpace(query.Source))
        {
            if (!TryParseNamedEnum<SupportConversationSource>(query.Source, out var source))
            {
                return Result.Failure<SupportConversationInboxPageResponse>(InvalidSource);
            }

            var requestedSource = ToCanonicalSource(source);
            conversationsQuery = conversationsQuery.Where(x => x.Source == requestedSource);
        }

        if (!string.IsNullOrWhiteSpace(query.Priority))
        {
            if (!TryParseNamedEnum<SupportConversationPriority>(query.Priority, out var priority))
            {
                return Result.Failure<SupportConversationInboxPageResponse>(InvalidPriority);
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
        var pageSize = query.PageSize <= 0
            ? 50
            : Math.Clamp(query.PageSize, 1, 100);

        var normalizedSort = query.Sort?.Trim().ToLowerInvariant();
        if (normalizedSort is not (null or "" or "default" or "priority" or "waiting" or "updated" or "created"))
        {
            return Result.Failure<SupportConversationInboxPageResponse>(InvalidSort);
        }

        var totalCount = await conversationsQuery.LongCountAsync(cancellationToken);
        var boundedTotalCount = totalCount > int.MaxValue ? int.MaxValue : (int)totalCount;
        var offset = ((long)page - 1L) * pageSize;
        if (offset >= totalCount || offset > int.MaxValue)
        {
            return Result.Success(new SupportConversationInboxPageResponse(
                [],
                page,
                pageSize,
                boundedTotalCount,
                false));
        }

        var orderedConversationsQuery = normalizedSort switch
        {
            "priority" => conversationsQuery
                .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
                .ThenByDescending(x => x.Priority)
                .ThenBy(x => x.WaitingSinceUtc ?? x.LastMessageAtUtc ?? x.CreatedAtUtc)
                .ThenByDescending(x => x.UpdatedAtUtc)
                .ThenByDescending(x => x.Id),
            "waiting" => conversationsQuery
                .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
                .ThenBy(x => x.WaitingSinceUtc ?? x.LastMessageAtUtc ?? x.CreatedAtUtc)
                .ThenByDescending(x => x.Priority)
                .ThenByDescending(x => x.UpdatedAtUtc)
                .ThenByDescending(x => x.Id),
            "updated" => conversationsQuery
                .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
                .ThenByDescending(x => x.UpdatedAtUtc)
                .ThenByDescending(x => x.Id),
            "created" => conversationsQuery
                .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
                .ThenByDescending(x => x.CreatedAtUtc)
                .ThenByDescending(x => x.Id),
            _ => conversationsQuery
                .OrderBy(x => x.Status == SupportConversationStatus.Closed ? 1 : 0)
                .ThenBy(x => x.Status == SupportConversationStatus.New ? 0
                    : x.Status == SupportConversationStatus.InProgress ? 1
                    : x.Status == SupportConversationStatus.WaitingForUser ? 2
                    : 3)
                .ThenBy(x => x.WaitingSinceUtc ?? x.LastMessageAtUtc ?? x.CreatedAtUtc)
                .ThenByDescending(x => x.UpdatedAtUtc)
                .ThenByDescending(x => x.Id)
        };

        var conversationRows = await orderedConversationsQuery
            .Skip((int)offset)
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
                    .ThenByDescending(message => message.Id)
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
            boundedTotalCount,
            offset + summaries.Count < totalCount));
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
                    x.Status == SupportConversationStatus.Closed),
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
}
