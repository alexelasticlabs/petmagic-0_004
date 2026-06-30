using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
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
            return TypedResults.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "support.assignment_invalid",
                detail: "Support inbox assignment filter is not supported.");
        }

        var requestedPage = page is null or <= 0 ? 1 : page.Value;
        var requestedPageSize = pageSize is null or <= 0 ? 50 : pageSize.Value;
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
                Statuses: status),
            "unassigned" => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                UnassignedOnly: true,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status),
            _ => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                AssignedAdminId: assignedTo,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status)
        };

        var result = await service.ListAdminInboxAsync(query, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminSupportInboxMetricsResponse>> GetAdminInboxMetricsAsync(
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminInboxMetricsAsync(cancellationToken);
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
                Take: take ?? 60,
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
}
