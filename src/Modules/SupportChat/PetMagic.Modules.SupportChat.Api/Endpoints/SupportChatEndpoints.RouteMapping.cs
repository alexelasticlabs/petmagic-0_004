using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    public static IEndpointRouteBuilder MapSupportChatEndpoints(this IEndpointRouteBuilder endpoints)
    {
        MapUserRoutes(endpoints);
        MapAdminRoutes(endpoints);

        return endpoints;
    }

    private static RouteGroupBuilder MapUserRoutes(IEndpointRouteBuilder endpoints)
    {
        var userGroup = endpoints.MapGroup("/api/support")
            .WithTags("Support")
            .RequireRateLimiting("support-chat")
            .RequireAuthorization(policy => policy
                .RequireAuthenticatedUser()
                .RequireAssertion(context =>
                    context.User.IsInRole("Admin")
                    || context.User.IsInRole("Moderator")
                    || !context.User.HasClaim(c => c.Type == "account_status")
                    || string.Equals(
                        context.User.FindFirst("account_status")?.Value,
                        "Active",
                        StringComparison.Ordinal)));

        userGroup.MapPost("/conversation/open", OpenConversationAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapGet("/conversation", GetUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/messages", SendUserMessageAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/attachments", SendUserAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/attachments", SendUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/read", MarkUserReadAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/resolve", ResolveUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/close", CloseUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/reopen", ReopenUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/feedback", SubmitUserConversationFeedbackAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireRateLimiting("support-chat");

        return userGroup;
    }

    private static RouteGroupBuilder MapAdminRoutes(IEndpointRouteBuilder endpoints)
    {
        var adminGroup = endpoints.MapGroup("/api/admin/support")
            .WithTags("Admin.Support")
            .RequireRateLimiting("admin")
            .RequireAuthorization("ModeratorOrAdmin");

        adminGroup.MapGet("/tickets", ListAdminInboxAsync);
        adminGroup.MapGet("/tickets/metrics", GetAdminInboxMetricsAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}", GetAdminConversationAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}/context", GetAdminTicketContextAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/assign-to-me", AssignConversationToMeAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/unassign", UnassignConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-waiting-for-user", MarkConversationWaitingForUserAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-in-progress", MarkConversationInProgressAsync);
        adminGroup.MapPut("/tickets/{conversationId:guid}/status", UpdateConversationStatusAsync);
        adminGroup.MapPut("/tickets/{conversationId:guid}/assignment", AssignConversationAsync);
        adminGroup.MapPut("/tickets/{conversationId:guid}/metadata", UpdateConversationMetadataAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/close", CloseAdminConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/reopen", ReopenAdminConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages", SendAdminMessageAsync)
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages/attachments", SendAdminAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/attachments", SendAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/read", MarkAdminReadAsync);
        adminGroup.MapGet("/templates", ListReplyTemplatesAsync);
        adminGroup.MapPost("/templates", CreateReplyTemplateAsync);
        adminGroup.MapPut("/templates/{templateId:guid}", UpdateReplyTemplateAsync);
        adminGroup.MapDelete("/templates/{templateId:guid}", DeleteReplyTemplateAsync);

        return adminGroup;
    }
}
