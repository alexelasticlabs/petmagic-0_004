using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private const int MaxSupportJsonRequestBodyBytes = 16 * 1024;
    private const long MaxSupportSingleAttachmentRequestBodyBytes = 51L * 1024 * 1024;
    private const long MaxSupportAttachmentBatchRequestBodyBytes = 255L * 1024 * 1024;

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
            .AddEndpointFilter(ApplyPrivateSupportResponseHeadersAsync)
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
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");
        userGroup.MapGet("/conversation", GetUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/messages", SendUserMessageAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/attachments", SendUserAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportAttachmentBatchRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/attachments", SendUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportSingleAttachmentRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportSingleAttachmentRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/read", MarkUserReadAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/resolve", ResolveUserConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/close", CloseUserConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/reopen", ReopenUserConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        userGroup.MapPost("/conversation/{conversationId:guid}/feedback", SubmitUserConversationFeedbackAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");
        userGroup.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");
        userGroup.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");

        return userGroup;
    }

    private static RouteGroupBuilder MapAdminRoutes(IEndpointRouteBuilder endpoints)
    {
        var adminGroup = endpoints.MapGroup("/api/admin/support")
            .WithTags("Admin.Support")
            .RequireRateLimiting("admin")
            .AddEndpointFilter(ApplyPrivateSupportResponseHeadersAsync)
            .RequireAuthorization("ModeratorOrAdmin");

        adminGroup.MapGet("/tickets", ListAdminInboxAsync);
        adminGroup.MapGet("/tickets/metrics", GetAdminInboxMetricsAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}", GetAdminConversationAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}/context", GetAdminTicketContextAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/assign-to-me", AssignConversationToMeAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/unassign", UnassignConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-waiting-for-user", MarkConversationWaitingForUserAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-in-progress", MarkConversationInProgressAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPut("/tickets/{conversationId:guid}/status", UpdateConversationStatusAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPut("/tickets/{conversationId:guid}/assignment", AssignConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPut("/tickets/{conversationId:guid}/metadata", UpdateConversationMetadataAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/close", CloseAdminConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/reopen", ReopenAdminConversationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages", SendAdminMessageAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes))
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages/attachments", SendAdminAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportAttachmentBatchRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/attachments", SendAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportSingleAttachmentRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat")
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportSingleAttachmentRequestBodyBytes));
        adminGroup.MapPost("/tickets/{conversationId:guid}/read", MarkAdminReadAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapGet("/templates", ListReplyTemplatesAsync);
        adminGroup.MapPost("/templates", CreateReplyTemplateAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapPut("/templates/{templateId:guid}", UpdateReplyTemplateAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));
        adminGroup.MapDelete("/templates/{templateId:guid}", DeleteReplyTemplateAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxSupportJsonRequestBodyBytes));

        return adminGroup;
    }

    private static async ValueTask<object?> ApplyPrivateSupportResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }
}
