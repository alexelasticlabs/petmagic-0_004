using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private const int DefaultConversationMessagesTake = 60;
    private const int MaxConversationMessagesTake = 120;
    private const int DefaultAdminInboxPageSize = 50;
    private const int MaxAdminInboxPageSize = 100;

    private static async Task<Results<Ok<SupportConversationInboxPageResponse>, ProblemHttpResult>> ListAdminInboxAsync(
        HttpContext httpContext,
        [FromQuery] string[]? status,
        [FromQuery] string? assignment,
        [FromQuery] Guid? assignedTo,
        [FromQuery] string? source,
        [FromQuery] string? priority,
        [FromQuery] string? search,
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] string? sort,
        [FromQuery] string? queue,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var normalizedAssignment = assignment?.Trim().ToLowerInvariant();
        if (normalizedAssignment is not null && normalizedAssignment is not ("all" or "mine" or "unassigned"))
        {
            return ToProblem(new Error(
                "support.assignment_invalid",
                "Support inbox assignment filter is invalid."));
        }

        var requestedPage = page is null or <= 0 ? 1 : page.Value;
        var requestedPageSize = NormalizeAdminInboxPageSize(pageSize);
        var query = normalizedAssignment switch
        {
            "mine" => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                AssignedAdminId: userId,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status,
                Queue: queue),
            "unassigned" => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                UnassignedOnly: true,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status,
                Queue: queue),
            _ => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                AssignedAdminId: assignedTo,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status,
                Queue: queue)
        };

        var result = await service.ListAdminInboxAsync(query, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationInboxPageResponse>, ProblemHttpResult>> ListAdminUserTicketsAsync(
        [FromRoute] Guid userId,
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var requestedPage = page is null or <= 0 ? 1 : page.Value;
        var requestedPageSize = NormalizeAdminInboxPageSize(pageSize);
        var result = await service.ListAdminInboxAsync(
            new ListAdminSupportInboxQuery(
                Status: null,
                Page: requestedPage,
                PageSize: requestedPageSize,
                InitiatorUserId: userId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminSupportInboxMetricsResponse>, ProblemHttpResult>> GetAdminInboxMetricsAsync(
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminInboxMetricsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> GetAdminConversationAsync(
        [FromRoute] Guid conversationId,
        [FromQuery] int? take,
        [FromQuery] DateTime? beforeMessageCreatedAtUtc,
        [FromQuery] Guid? beforeMessageId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminConversationAsync(
            conversationId,
            new SupportConversationMessagesQuery(
                Take: NormalizeConversationMessagesTake(take),
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc,
                BeforeMessageId: beforeMessageId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportTicketContextResponse>, ProblemHttpResult>> GetAdminTicketContextAsync(
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTicketContextAsync(conversationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static int NormalizeAdminInboxPageSize(int? pageSize)
        => Math.Clamp(pageSize ?? DefaultAdminInboxPageSize, 1, MaxAdminInboxPageSize);

    private static int NormalizeConversationMessagesTake(int? take)
        => Math.Clamp(take ?? DefaultConversationMessagesTake, 1, MaxConversationMessagesTake);
}
