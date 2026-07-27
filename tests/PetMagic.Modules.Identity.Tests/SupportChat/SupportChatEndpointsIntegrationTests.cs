using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;

using FluentValidation;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed partial class SupportChatEndpointsIntegrationTests
{
    private static readonly Guid UserId = Guid.Parse("A61F6697-8254-45F0-9C24-B6941A92D8E1");
    private static readonly Guid OtherUserId = Guid.Parse("6C0F443A-BAFC-4D80-A7F2-130839E95C35");
    private static readonly Guid ModeratorId = Guid.Parse("1CEAF6B8-E3BA-4CF7-B6E0-5F0B0F480D34");
    private static readonly Guid AdminId = Guid.Parse("7B8B172E-3308-4B7F-9F49-D98B6629A6AA");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task UserConversationEndpoints_ShouldRequireAuthentication_AndEnforceOwnership()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        using var anonymousResponse = await application.AnonymousClient.GetAsync("/api/support/conversation");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousResponse.StatusCode);

        var openResponse = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with premium", SupportConversationPriority.Normal));

        Assert.Equal("New", openResponse.Status);
        Assert.Equal("Normal", openResponse.Priority);
        Assert.Contains(
            openResponse.Messages,
            message => message.SenderType == "User" && message.Body == "Need help with premium");

        using var fetchedResponse = await application.CreateClient(UserId, "User").GetAsync("/api/support/conversation");
        await AssertSuccessAsync(fetchedResponse);
        AssertPrivateSupportResponseHeaders(fetchedResponse);
        var fetched = (await fetchedResponse.Content.ReadFromJsonAsync<SupportConversationDetailResponse>(JsonOptions))!;

        Assert.Equal(openResponse.ConversationId, fetched.ConversationId);
        Assert.Contains(
            fetched.Messages,
            message => message.SenderType == "User" && message.Body == "Need help with premium");

        using var hiddenConversationResponse = await application.CreateClient(OtherUserId, "User").PostAsJsonAsync(
            $"/api/support/conversation/{openResponse.ConversationId}/messages",
            new SendSupportMessageRequest("I should not be here"));

        Assert.Equal(HttpStatusCode.NotFound, hiddenConversationResponse.StatusCode);
    }

    [Fact]
    public async Task OpenConversationEndpoint_ShouldRejectUnownedRelatedContextLinks()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var generationId = Guid.NewGuid();
        var paymentId = Guid.NewGuid();
        var subscriptionId = Guid.NewGuid();

        using var response = await application.CreateClient(UserId, "User").PostAsJsonAsync(
            "/api/support/conversation/open",
            new OpenConversationWithPaymentLinksRequest(
                "Billing issue",
                SupportConversationPriority.Normal,
                RelatedGenerationId: generationId,
                RelatedPaymentId: paymentId,
                RelatedSubscriptionId: subscriptionId));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("support.related_resource_not_found", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task OpenConversationEndpoint_ShouldRejectUserForgedPriorityAndInternalSource()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var client = application.CreateClient(UserId, "User");

        using var priorityResponse = await client.PostAsJsonAsync(
            "/api/support/conversation/open",
            new OpenConversationRequest("Urgent", SupportConversationPriority.High));
        using var sourceResponse = await client.PostAsJsonAsync(
            "/api/support/conversation/open",
            new
            {
                initialMessage = "Internal source",
                priority = SupportConversationPriority.Normal,
                source = SupportConversationSource.AdminCreated
            });

        Assert.Equal(HttpStatusCode.BadRequest, priorityResponse.StatusCode);
        Assert.Contains(
            "support.conversation_priority_invalid",
            await priorityResponse.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);
        Assert.Equal(HttpStatusCode.BadRequest, sourceResponse.StatusCode);
        Assert.Contains(
            "support.conversation_source_invalid",
            await sourceResponse.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);
    }

    [Fact]
    public async Task AdminEndpoints_ShouldRejectRegularUser_AndAllowModeratorInboxAccess()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("I need billing help", SupportConversationPriority.Normal));

        using var regularUserInbox = await application.CreateClient(UserId, "User").GetAsync("/api/admin/support/tickets");
        Assert.Equal(HttpStatusCode.Forbidden, regularUserInbox.StatusCode);

        using var moderatorInboxResponse = await application.CreateClient(ModeratorId, "Moderator").GetAsync("/api/admin/support/tickets");
        await AssertSuccessAsync(moderatorInboxResponse);
        AssertPrivateSupportResponseHeaders(moderatorInboxResponse);
        var moderatorInbox = (await moderatorInboxResponse.Content.ReadFromJsonAsync<SupportConversationInboxPageResponse>(JsonOptions))!;

        Assert.Equal(1, moderatorInbox.TotalCount);
        Assert.False(moderatorInbox.HasMore);
        var conversation = Assert.Single(moderatorInbox.Items);
        Assert.Equal(created.ConversationId, conversation.ConversationId);
        Assert.Equal("New", conversation.Status);
        Assert.Equal("user@petmagic.test", conversation.UserEmail);
    }

    [Fact]
    public async Task AdminTicketEndpoints_ShouldExposeQueueActionsAndContext()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Queue action case", SupportConversationPriority.Normal));

        Assert.Empty(created.AvailableActions);

        var tickets = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            adminClient,
            "/api/admin/support/tickets?status=New&source=MobileChat&page=1&pageSize=10");

        Assert.Equal(1, tickets.Page);
        Assert.Equal(10, tickets.PageSize);
        Assert.Equal(1, tickets.TotalCount);
        Assert.False(tickets.HasMore);
        var ticket = Assert.Single(tickets.Items);
        Assert.Equal(created.ConversationId, ticket.ConversationId);
        Assert.Equal("MobileChat", ticket.Source);
        Assert.Equal("Queue action case", ticket.LastMessagePreview);
        Assert.Equal("User", ticket.LastMessageSenderType);
        Assert.True(ticket.UnreadForAdmin);

        var assigned = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");

        Assert.Equal("InProgress", assigned.Status);
        Assert.Equal(AdminId, assigned.AssignedAdminId);
        Assert.Equal(new[] { "close", "unassign" }, assigned.AvailableActions);
        Assert.Contains(
            assigned.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket assigned to operator");
        Assert.Contains(
            assigned.Messages,
            message => message.SenderType == "System" && message.Body == "Status changed: New -> InProgress");

        using var waitingBlockedResponse = await adminClient.PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/mark-waiting-for-user",
            content: null);

        Assert.Equal(HttpStatusCode.BadRequest, waitingBlockedResponse.StatusCode);
        var waitingBlockedBody = await waitingBlockedResponse.Content.ReadAsStringAsync();
        Assert.Contains("support.status_transition_invalid", waitingBlockedBody);

        var closed = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/close");

        Assert.Equal("Closed", closed.Status);
        Assert.True(closed.IsReadOnly);
        Assert.Equal(new[] { "reopen" }, closed.AvailableActions);

        using var blockedReply = await adminClient.PostAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Reply while closed"));
        Assert.Equal(HttpStatusCode.Conflict, blockedReply.StatusCode);

        var reopened = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/reopen");

        Assert.Equal("InProgress", reopened.Status);
        Assert.Equal(new[] { "close", "unassign" }, reopened.AvailableActions);
        Assert.Contains(reopened.Messages, message => message.SenderType == "System" && message.Body == "Ticket reopened by operator");

        var unassigned = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/unassign");

        Assert.Equal("InProgress", unassigned.Status);
        Assert.Null(unassigned.AssignedAdminId);
        Assert.Empty(unassigned.AvailableActions);

        var context = await GetFromJsonAsync<SupportTicketContextResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/context");

        Assert.Equal("Free", context.Plan);
        Assert.Equal("Inactive", context.PremiumStatus);
    }

    [Fact]
    public async Task SupportAssignment_ShouldBeIdempotentAndRejectStealOrForeignUnassign()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Ownership case", SupportConversationPriority.Normal));
        var adminClient = application.CreateClient(AdminId, "Admin");
        var moderatorClient = application.CreateClient(ModeratorId, "Moderator");
        var claimPath = $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me";
        var unassignPath = $"/api/admin/support/tickets/{created.ConversationId}/unassign";

        _ = await PostEmptyAsync<SupportConversationDetailResponse>(adminClient, claimPath);
        var repeatedClaim = await PostEmptyAsync<SupportConversationDetailResponse>(adminClient, claimPath);
        Assert.Equal(AdminId, repeatedClaim.AssignedAdminId);
        Assert.Single(
            repeatedClaim.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket assigned to operator");

        using var stealResponse = await moderatorClient.PostAsJsonAsync(
            claimPath,
            new
            {
                reason = "Moderator attempts to take an owned ticket.",
                expectedVersion = repeatedClaim.Version,
            });
        Assert.Equal(HttpStatusCode.Conflict, stealResponse.StatusCode);
        Assert.Contains(
            "support.conversation_already_assigned",
            await stealResponse.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);

        using var foreignUnassignResponse = await moderatorClient.PostAsJsonAsync(
            unassignPath,
            new
            {
                reason = "Moderator attempts to release another operator's ticket.",
                expectedVersion = repeatedClaim.Version,
            });
        Assert.Equal(HttpStatusCode.Conflict, foreignUnassignResponse.StatusCode);
        Assert.Contains(
            "support.conversation_not_owned",
            await foreignUnassignResponse.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);

        _ = await PostEmptyAsync<SupportConversationDetailResponse>(adminClient, unassignPath);
        var repeatedUnassign = await PostEmptyAsync<SupportConversationDetailResponse>(adminClient, unassignPath);
        Assert.Null(repeatedUnassign.AssignedAdminId);
        Assert.Single(
            repeatedUnassign.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket unassigned");

        var auditEvents = await application.GetAuditEventsAsync(created.ConversationId);
        Assert.Contains(auditEvents, audit => audit.Action == "admin.support.ticket.assigned" && audit.ActorUserId == AdminId);
        Assert.Contains(auditEvents, audit => audit.Action == "admin.support.ticket.unassigned" && audit.ActorUserId == AdminId);
    }

    [Fact]
    public async Task AdminReplyStatusAndReadEndpoints_ShouldRoundTripConversationState()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("App crashes on startup", SupportConversationPriority.Normal));

        _ = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");

        var replied = await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/messages",
            new SendSupportMessageRequest("We have started investigating"));

        Assert.True(replied.IsFromAdmin);
        Assert.Equal("System Admin", replied.SenderDisplayName);

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(
                AdminId,
                "Confirm current assignment.",
                created.Version));

        Assert.Equal(AdminId, assigned.AssignedAdminId);

        var updated = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", updated.Status);
        Assert.Equal(AdminId, updated.AssignedAdminId);

        using var markAdminReadResponse = await adminClient.PostAsync($"/api/admin/support/tickets/{created.ConversationId}/read", content: null);
        Assert.Equal(HttpStatusCode.NoContent, markAdminReadResponse.StatusCode);

        var beforeUserRead = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation");

        Assert.Equal(1, beforeUserRead.UserUnreadCount);
        Assert.Equal(0, beforeUserRead.AdminUnreadCount);

        using var markUserReadResponse = await userClient.PostAsync($"/api/support/conversation/{created.ConversationId}/read", content: null);
        Assert.Equal(HttpStatusCode.NoContent, markUserReadResponse.StatusCode);

        var reopenedMessage = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Still broken after update"));

        Assert.False(reopenedMessage.IsFromAdmin);

        var afterReopen = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}");

        Assert.Equal("New", afterReopen.Status);
        Assert.Equal(1, afterReopen.AdminUnreadCount);
        Assert.Equal(0, afterReopen.UserUnreadCount);
        Assert.Contains(
            afterReopen.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket reopened by user message");
    }

    [Fact]
    public async Task AdminMessageEndpoint_ShouldReplaySameIdempotencyKeyWithoutDuplicateReply()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need idempotent reply", SupportConversationPriority.Normal));
        _ = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");

        const string idempotencyKey = "admin-support-message-endpoint-retry";
        var path = $"/api/admin/support/tickets/{created.ConversationId}/messages";

        using var firstRequest = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(new SendSupportMessageRequest("We are investigating"))
        };
        firstRequest.Headers.TryAddWithoutValidation(SupportMessageIdempotency.HeaderName, idempotencyKey);
        using var firstResponse = await adminClient.SendAsync(firstRequest);
        await AssertSuccessAsync(firstResponse);
        var firstMessage = (await firstResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;

        using var replayRequest = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(new SendSupportMessageRequest("We are investigating"))
        };
        replayRequest.Headers.TryAddWithoutValidation(SupportMessageIdempotency.HeaderName, idempotencyKey);
        using var replayResponse = await adminClient.SendAsync(replayRequest);
        await AssertSuccessAsync(replayResponse);
        var replayMessage = (await replayResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;

        Assert.False(firstMessage.IsIdempotencyReplay);
        Assert.True(replayMessage.IsIdempotencyReplay);
        Assert.Equal(firstMessage.MessageId, replayMessage.MessageId);

        var detail = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}");
        Assert.Single(detail.Messages, message => message.SenderType == "SupportAgent" && message.Body == "We are investigating");
        Assert.Single(detail.Messages, message => message.SenderType == "System" && message.Body == "Support replied");
    }

    [Theory]
    [InlineData("assign-to-me")]
    [InlineData("unassign")]
    public async Task LegacyAssignmentEndpoints_ShouldRejectMissingSafetyContext(string action)
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Validate assignment safety", SupportConversationPriority.Normal));

        using var response = await application.CreateClient(AdminId, "Admin").PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/{action}",
            content: null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>(JsonOptions);
        Assert.NotNull(problem);
        Assert.Contains(nameof(AssignSupportConversationCommand.Reason), problem.Errors.Keys);
        Assert.Contains(nameof(AssignSupportConversationCommand.ExpectedVersion), problem.Errors.Keys);
    }

    [Fact]
    public async Task AdminAssignmentEndpoint_ShouldAssignNewConversationAndMoveToInProgress()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Please assign this case", SupportConversationPriority.Normal));

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(
                AdminId,
                "Assign support operator.",
                created.Version));

        Assert.Equal("InProgress", assigned.Status);
        Assert.Equal(AdminId, assigned.AssignedAdminId);
        Assert.Contains(
            assigned.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket assigned to operator");
        Assert.Contains(
            assigned.Messages,
            message => message.SenderType == "System" && message.Body == "Status changed: New -> InProgress");
    }

    [Fact]
    public async Task AdminAssignmentEndpoint_ShouldRejectEmptyAssignedAdminId()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Please validate assignment", SupportConversationPriority.Normal));

        using var response = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(
                Guid.Empty,
                "Validate empty support operator.",
                created.Version));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>(JsonOptions);
        Assert.NotNull(problem);
        Assert.Contains(nameof(AssignSupportConversationRequest.AssignedAdminId), problem.Errors.Keys);
    }

    [Fact]
    public async Task AdminAssignmentEndpoint_ShouldRejectRegularUserAssignee()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Please validate support assignee", SupportConversationPriority.Normal));

        using var response = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(
                OtherUserId,
                "Validate support operator role.",
                created.Version));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>(JsonOptions);
        Assert.NotNull(problem);
        Assert.Equal("support.assigned_admin_invalid", problem.Title);
    }

    [Fact]
    public async Task AdminStatusEndpoint_ShouldRejectInvalidStatusTransition()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help", SupportConversationPriority.Normal));

        _ = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");

        var closed = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", closed.Status);

        using var invalidTransitionResponse = await adminClient.PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("WaitingForUser"));

        Assert.Equal(HttpStatusCode.BadRequest, invalidTransitionResponse.StatusCode);

        var body = await invalidTransitionResponse.Content.ReadAsStringAsync();
        Assert.Contains("support.status_transition_invalid", body);
    }

    [Fact]
    public async Task UserMessageEndpoint_ShouldReopenClosedConversation_AndAppendSystemEvent()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help", SupportConversationPriority.Normal));

        _ = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");

        var closed = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", closed.Status);

        var reopenedMessage = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Still broken after the last update"));

        Assert.False(reopenedMessage.IsFromAdmin);
        Assert.Equal("User", reopenedMessage.SenderType);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}");

        Assert.Equal("New", conversation.Status);
        var reopenedEvent = Assert.Single(
            conversation.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket reopened by user message");
        Assert.Equal("Ticket reopened by user message", reopenedEvent.Body);
    }

    [Fact]
    public async Task UserConversationEndpoint_ShouldSupportMessagePagingByTakeAndBeforeCursor()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Seed message", SupportConversationPriority.Normal));

        for (var i = 1; i <= 8; i++)
        {
            _ = await PostAsJsonAsync<SupportMessageResponse>(
                userClient,
                $"/api/support/conversation/{created.ConversationId}/messages",
                new SendSupportMessageRequest($"Paged message {i}"));

            await Task.Delay(3);
        }

        var firstPage = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation?take=3");

        Assert.Equal(3, firstPage.Messages.Count);
        Assert.True(firstPage.HasOlderMessages);
        Assert.NotNull(firstPage.OldestLoadedMessageCreatedAtUtc);

        var beforeFirstPage = Uri.EscapeDataString(firstPage.OldestLoadedMessageCreatedAtUtc!.Value.ToString("O"));
        var secondPage = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            $"/api/support/conversation?take=3&beforeMessageCreatedAtUtc={beforeFirstPage}");

        Assert.Equal(3, secondPage.Messages.Count);
        Assert.True(secondPage.HasOlderMessages);
        Assert.NotNull(secondPage.OldestLoadedMessageCreatedAtUtc);

        var overlap = firstPage.Messages
            .Select(x => x.MessageId)
            .Intersect(secondPage.Messages.Select(x => x.MessageId))
            .ToList();
        Assert.Empty(overlap);

        var beforeSecondPage = Uri.EscapeDataString(secondPage.OldestLoadedMessageCreatedAtUtc!.Value.ToString("O"));
        var thirdPage = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            $"/api/support/conversation?take=10&beforeMessageCreatedAtUtc={beforeSecondPage}");

        Assert.NotEmpty(thirdPage.Messages);
        Assert.False(thirdPage.HasOlderMessages);
    }

    [Fact]
    public async Task AdminConversationEndpoint_ShouldSupportMessagePagingByTakeAndBeforeCursor()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Admin paging seed", SupportConversationPriority.Normal));

        for (var i = 1; i <= 6; i++)
        {
            _ = await PostAsJsonAsync<SupportMessageResponse>(
                userClient,
                $"/api/support/conversation/{created.ConversationId}/messages",
                new SendSupportMessageRequest($"Admin paged message {i}"));

            await Task.Delay(3);
        }

        var firstPage = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}?take=2");

        Assert.Equal(2, firstPage.Messages.Count);
        Assert.True(firstPage.HasOlderMessages);
        Assert.NotNull(firstPage.OldestLoadedMessageCreatedAtUtc);

        var beforeFirstPage = Uri.EscapeDataString(firstPage.OldestLoadedMessageCreatedAtUtc!.Value.ToString("O"));
        var secondPage = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}?take=2&beforeMessageCreatedAtUtc={beforeFirstPage}");

        Assert.Equal(2, secondPage.Messages.Count);
        Assert.NotNull(secondPage.OldestLoadedMessageCreatedAtUtc);

        var overlap = firstPage.Messages
            .Select(x => x.MessageId)
            .Intersect(secondPage.Messages.Select(x => x.MessageId))
            .ToList();
        Assert.Empty(overlap);
    }

    private static async Task<TResponse> GetFromJsonAsync<TResponse>(HttpClient client, string url)
    {
        using var response = await client.GetAsync(url);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static async Task<TResponse> PostAsJsonAsync<TResponse>(HttpClient client, string url, object payload)
    {
        using var response = await client.PostAsJsonAsync(url, payload);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static async Task<TResponse> PostEmptyAsync<TResponse>(HttpClient client, string url)
    {
        HttpResponseMessage response;
        if (url.EndsWith("/assign-to-me", StringComparison.Ordinal)
            || url.EndsWith("/unassign", StringComparison.Ordinal))
        {
            var ticketUrl = url[..url.LastIndexOf('/')];
            var current = await GetFromJsonAsync<SupportConversationDetailResponse>(client, ticketUrl);
            response = await client.PostAsJsonAsync(
                url,
                new
                {
                    reason = "Test support assignment transition.",
                    expectedVersion = current.Version,
                });
        }
        else
        {
            response = await client.PostAsync(url, content: null);
        }

        using (response)
        {
            await AssertSuccessAsync(response);
            return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
        }
    }

    private static async Task<TResponse> PutAsJsonAsync<TResponse>(HttpClient client, string url, object payload)
    {
        using var response = await client.PutAsJsonAsync(url, payload);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static void AssertPrivateSupportResponseHeaders(HttpResponseMessage response)
    {
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.Contains(response.Headers.Pragma, value => string.Equals(value.Name, "no-cache", StringComparison.OrdinalIgnoreCase));
        Assert.True(response.Headers.TryGetValues("X-Content-Type-Options", out var contentTypeOptions));
        Assert.Contains("nosniff", contentTypeOptions);
    }

    private static async Task AssertSuccessAsync(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var body = await response.Content.ReadAsStringAsync();
        throw new Xunit.Sdk.XunitException($"Expected success status code but got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
    }

    private static void AssertSignedSupportAttachmentUrl(string fileUrl)
    {
        var uri = new Uri(fileUrl);
        Assert.StartsWith("/support-attachments/", uri.AbsolutePath, StringComparison.OrdinalIgnoreCase);

        var query = Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(uri.Query);
        Assert.True(query.TryGetValue("pmexp", out var expiresAt));
        Assert.True(query.TryGetValue("pmsig", out var signature));
        Assert.False(string.IsNullOrWhiteSpace(expiresAt.ToString()));
        Assert.False(string.IsNullOrWhiteSpace(signature.ToString()));
    }

    private sealed class SupportChatTestApplication : IAsyncDisposable
    {
        private const string TestJwtIssuer = "petmagic-support-chat-tests";
        private const string TestJwtAudience = "petmagic-support-chat-tests";
        private const string TestJwtSigningKey = "support-chat-tests-jwt-signing-key-64-bytes-minimum-secret-value";
        private const string LocalSupportAttachmentPublicBaseUrl = "http://localhost:5000";

        private readonly WebApplication app;

        private SupportChatTestApplication(WebApplication app, HttpClient anonymousClient)
        {
            this.app = app;
            AnonymousClient = anonymousClient;
        }

        public HttpClient AnonymousClient { get; }

        public TestServer Server => app.GetTestServer();

        public FakeSupportAttachmentStorage AttachmentStorage =>
            (FakeSupportAttachmentStorage)app.Services.GetRequiredService<ISupportAttachmentStorage>();

        public static async Task<SupportChatTestApplication> CreateAsync(Action<IServiceCollection>? configureServices = null)
        {
            var supportDatabaseRoot = new InMemoryDatabaseRoot();
            var identityDatabaseRoot = new InMemoryDatabaseRoot();
            var supportDatabaseName = $"support-chat-api-tests-{Guid.NewGuid():N}";
            var identityDatabaseName = $"support-chat-identity-api-tests-{Guid.NewGuid():N}";

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(SupportChatEndpointsIntegrationTests).Assembly.FullName,
            });

            // The default Windows EventLog provider can throw for the unprivileged test host,
            // masking the HTTP response that an integration test is meant to assert.
            builder.Logging.ClearProviders();

            builder.WebHost.UseTestServer();
            builder.Configuration["AllowedHosts"] = "*";
            builder.Configuration["Jwt:Issuer"] = TestJwtIssuer;
            builder.Configuration["Jwt:Audience"] = TestJwtAudience;
            builder.Configuration["Jwt:SigningKey"] = TestJwtSigningKey;
            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AdminWeb", policy =>
                {
                    policy
                        .AllowAnyHeader()
                        .AllowAnyMethod()
                        .SetIsOriginAllowed(_ => true)
                        .AllowCredentials();
                });
            });

            builder.Services.AddAuthentication(SupportChatTestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, SupportChatTestAuthHandler>(SupportChatTestAuthHandler.SchemeName, _ => { });

            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
                options.AddPolicy("AdminOnly", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin");
                });
            });

            builder.Services.AddProblemDetails();
            builder.Services.AddHttpContextAccessor();
            builder.Services.AddMemoryCache();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddFixedWindowLimiter("support-chat", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
                options.AddFixedWindowLimiter("admin", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
            });

            builder.Services.AddDbContext<SupportChatDbContext>(options =>
                options.UseInMemoryDatabase(supportDatabaseName, supportDatabaseRoot));

            builder.Services.AddDbContext<IdentityDbContext>(options =>
                options.UseInMemoryDatabase(identityDatabaseName, identityDatabaseRoot));

            builder.Services.AddScoped<IIdentityUserLookupService, TestIdentityUserLookupService>();
            builder.Services.AddScoped<IAdminAuditLog, IdentityAdminAuditLog>();
            builder.Services.AddSingleton<ISupportAttachmentStorage, FakeSupportAttachmentStorage>();
            builder.Services.AddSingleton(new SupportAttachmentReadUrlSigningOptions
            {
                SigningKey = new string('t', 64),
                ReadUrlTtlMinutes = 60,
            });
            builder.Services.AddSingleton<ISupportAttachmentReadUrlSigner, SupportAttachmentReadUrlSigner>();
            builder.Services.AddSingleton<ISupportChatPushNotificationSender, NoopSupportChatPushNotificationSender>();
            builder.Services.AddSingleton(new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = LocalSupportAttachmentPublicBaseUrl
            });
            builder.Services.AddScoped<SupportChatService>();
            builder.Services.AddScoped<ISupportChatService>(serviceProvider => serviceProvider.GetRequiredService<SupportChatService>());
            builder.Services.AddScoped<ISupportReplyTemplateCatalogService, SupportReplyTemplateCatalogService>();
            builder.Services.AddSupportChatApiModule();
            configureServices?.Invoke(builder.Services);

            var app = builder.Build();
            if (string.IsNullOrWhiteSpace(app.Configuration["Jwt:SigningKey"]))
            {
                throw new InvalidOperationException("SupportChat test fixture must configure a non-empty Jwt:SigningKey.");
            }

            app.UseRateLimiter();
            app.UseCors();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapSupportChatApiModule();

            await SeedUsersAsync(app.Services);
            await app.StartAsync();

            var anonymousClient = app.GetTestClient();
            anonymousClient.BaseAddress = new Uri("http://localhost");

            return new SupportChatTestApplication(app, anonymousClient);
        }

        public HttpClient CreateClient(Guid userId, params string[] roles)
        {
            var client = app.GetTestClient();
            client.BaseAddress = new Uri("http://localhost");
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(SupportChatTestAuthHandler.SchemeName);
            client.DefaultRequestHeaders.Add(SupportChatTestAuthHandler.UserIdHeaderName, userId.ToString());
            if (roles.Length > 0)
            {
                client.DefaultRequestHeaders.Add(SupportChatTestAuthHandler.RolesHeaderName, string.Join(',', roles));
            }

            return client;
        }

        public HubConnection CreateHubConnection(Guid? userId = null, params string[] roles)
        {
            return new HubConnectionBuilder()
                .WithUrl(new Uri(new Uri("http://localhost"), "/hubs/support-chat"), options =>
                {
                    options.HttpMessageHandlerFactory = _ => Server.CreateHandler();
                    options.Transports = HttpTransportType.LongPolling;
                    if (userId.HasValue)
                    {
                        options.AccessTokenProvider = () => Task.FromResult<string?>(EncodeHubAccessToken(userId.Value, roles));
                    }
                })
                .Build();
        }

        public async Task<IReadOnlyList<AuditEvent>> GetAuditEventsAsync(Guid conversationId)
        {
            using var scope = app.Services.CreateScope();
            return await scope.ServiceProvider.GetRequiredService<IdentityDbContext>()
                .AuditEvents
                .AsNoTracking()
                .Where(audit => audit.TargetId == conversationId.ToString("D"))
                .OrderBy(audit => audit.CreatedAtUtc)
                .ToListAsync();
        }

        public async Task SetConversationPriorityAsync(
            Guid conversationId,
            SupportConversationPriority priority)
        {
            using var scope = app.Services.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<SupportChatDbContext>();
            var conversation = await dbContext.SupportConversations
                .SingleAsync(x => x.Id == conversationId);
            conversation.Priority = priority;
            conversation.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync();
        }

        public async ValueTask DisposeAsync()
        {
            AnonymousClient.Dispose();
            await app.StopAsync();
            await app.DisposeAsync();
        }

        private static async Task SeedUsersAsync(IServiceProvider services)
        {
            using var scope = services.CreateScope();
            var identityDbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            await identityDbContext.Database.EnsureCreatedAsync();

            identityDbContext.Users.AddRange(
                CreateUser(UserId, "user@petmagic.test", "Pet User"),
                CreateUser(OtherUserId, "other@petmagic.test", "Other User"),
                CreateUser(ModeratorId, "moderator@petmagic.test", "Moderator Jane"),
                CreateUser(AdminId, "admin@petmagic.test", "System Admin"));

            await identityDbContext.SaveChangesAsync();

            var adminRole = new IdentityRole<Guid>(SystemRoles.Admin)
            {
                NormalizedName = SystemRoles.Admin.ToUpperInvariant(),
            };
            var moderatorRole = new IdentityRole<Guid>(SystemRoles.Moderator)
            {
                NormalizedName = SystemRoles.Moderator.ToUpperInvariant(),
            };
            var userRole = new IdentityRole<Guid>(SystemRoles.User)
            {
                NormalizedName = SystemRoles.User.ToUpperInvariant(),
            };

            identityDbContext.Roles.AddRange(adminRole, moderatorRole, userRole);
            await identityDbContext.SaveChangesAsync();

            identityDbContext.UserRoles.AddRange(
                new IdentityUserRole<Guid> { UserId = UserId, RoleId = userRole.Id },
                new IdentityUserRole<Guid> { UserId = OtherUserId, RoleId = userRole.Id },
                new IdentityUserRole<Guid> { UserId = ModeratorId, RoleId = moderatorRole.Id },
                new IdentityUserRole<Guid> { UserId = AdminId, RoleId = adminRole.Id });

            await identityDbContext.SaveChangesAsync();

            var supportChatDbContext = scope.ServiceProvider.GetRequiredService<SupportChatDbContext>();
            await supportChatDbContext.Database.EnsureCreatedAsync();
        }

        private static AppUser CreateUser(Guid id, string email, string displayName)
        {
            return new AppUser
            {
                Id = id,
                UserName = email,
                NormalizedUserName = email.ToUpperInvariant(),
                Email = email,
                NormalizedEmail = email.ToUpperInvariant(),
                EmailConfirmed = true,
                DisplayName = displayName,
                IsActive = true,
            };
        }

        private sealed class TestIdentityUserLookupService(IdentityDbContext identityDbContext) : IIdentityUserLookupService
        {
            public async Task<IReadOnlyList<Guid>> GetActiveUserIdsInRolesAsync(
                IReadOnlyCollection<string> roles,
                CancellationToken cancellationToken)
            {
                if (roles.Count == 0)
                {
                    return [];
                }

                var activeRoleUserIds = identityDbContext.UserRoles
                    .AsNoTracking()
                    .Join(
                        identityDbContext.Roles.AsNoTracking(),
                        userRole => userRole.RoleId,
                        role => role.Id,
                        (userRole, role) => new
                        {
                            userRole.UserId,
                            RoleName = role.Name
                        })
                    .Where(x => x.RoleName != null && roles.Contains(x.RoleName));

                return await activeRoleUserIds
                    .Join(
                        identityDbContext.Users.AsNoTracking().Where(user => user.IsActive),
                        roleUser => roleUser.UserId,
                        user => user.Id,
                        (roleUser, _) => roleUser.UserId)
                    .Distinct()
                    .ToListAsync(cancellationToken);
            }

            public async Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
                IReadOnlyCollection<Guid> userIds,
                CancellationToken cancellationToken)
            {
                if (userIds.Count == 0)
                {
                    return new Dictionary<Guid, IdentityUserLookup>();
                }

                var distinctUserIds = userIds.Distinct().ToArray();
                var users = await identityDbContext.Users
                    .AsNoTracking()
                    .Where(x => distinctUserIds.Contains(x.Id))
                    .ToListAsync(cancellationToken);

                var rolesByUserId = await LoadRolesByUserIdAsync(distinctUserIds, cancellationToken);

                return users.ToDictionary(
                    x => x.Id,
                    x => new IdentityUserLookup(
                        x.Id,
                        x.Email ?? string.Empty,
                        x.DisplayName,
                        rolesByUserId.TryGetValue(x.Id, out var roles) ? roles : []));
            }

            public async Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
            {
                var user = await identityDbContext.Users
                    .AsNoTracking()
                    .Where(x => x.Id == userId)
                    .FirstOrDefaultAsync(cancellationToken);

                if (user is null)
                {
                    return null;
                }

                var rolesByUserId = await LoadRolesByUserIdAsync([userId], cancellationToken);
                return new IdentityUserLookup(
                    user.Id,
                    user.Email ?? string.Empty,
                    user.DisplayName,
                    rolesByUserId.TryGetValue(user.Id, out var roles) ? roles : []);
            }

            private async Task<IReadOnlyDictionary<Guid, IReadOnlyList<string>>> LoadRolesByUserIdAsync(
                IReadOnlyCollection<Guid> userIds,
                CancellationToken cancellationToken)
            {
                var roleRows = await identityDbContext.UserRoles
                    .AsNoTracking()
                    .Where(x => userIds.Contains(x.UserId))
                    .Join(
                        identityDbContext.Roles.AsNoTracking(),
                        userRole => userRole.RoleId,
                        role => role.Id,
                        (userRole, role) => new
                        {
                            userRole.UserId,
                            RoleName = role.Name
                        })
                    .Where(x => !string.IsNullOrWhiteSpace(x.RoleName))
                    .ToListAsync(cancellationToken);

                return roleRows
                    .GroupBy(x => x.UserId)
                    .ToDictionary(
                        group => group.Key,
                        group => (IReadOnlyList<string>)group
                            .Select(x => x.RoleName!)
                            .Distinct(StringComparer.Ordinal)
                            .OrderBy(x => x, StringComparer.Ordinal)
                            .ToArray());
            }
        }
    }

    private sealed class SupportChatTestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";
        public const string UserIdHeaderName = "X-Test-UserId";
        public const string RolesHeaderName = "X-Test-Roles";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (TryCreatePrincipalFromBearerToken(Request.Headers.Authorization, out var bearerPrincipal))
            {
                return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(bearerPrincipal, Scheme.Name)));
            }

            if (TryCreatePrincipalFromBearerToken(Request.Query["access_token"], out bearerPrincipal))
            {
                return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(bearerPrincipal, Scheme.Name)));
            }

            if (!Request.Headers.TryGetValue("Authorization", out var authorizationHeader) ||
                !string.Equals(authorizationHeader.ToString(), SchemeName, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            var userId = Request.Headers.TryGetValue(UserIdHeaderName, out var userIdHeader) && Guid.TryParse(userIdHeader, out var parsedUserId)
                ? parsedUserId
                : UserId;

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId.ToString()),
                new("sub", userId.ToString()),
                new(ClaimTypes.Name, $"test-user-{userId:N}"),
            };

            if (Request.Headers.TryGetValue(RolesHeaderName, out var rolesHeader))
            {
                foreach (var role in rolesHeader.ToString().Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                {
                    claims.Add(new Claim(ClaimTypes.Role, role));
                }
            }

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }

        private static bool TryCreatePrincipalFromBearerToken(string? rawHeader, out ClaimsPrincipal principal)
        {
            principal = null!;
            if (string.IsNullOrWhiteSpace(rawHeader))
            {
                return false;
            }

            var token = rawHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? rawHeader[7..]
                : rawHeader;

            var parts = token.Split(';', 2, StringSplitOptions.TrimEntries);
            if (parts.Length == 0 || !Guid.TryParse(parts[0], out var userId))
            {
                return false;
            }

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId.ToString()),
                new("sub", userId.ToString()),
                new(ClaimTypes.Name, $"signalr-user-{userId:N}"),
            };

            if (parts.Length == 2 && parts[1].StartsWith("roles=", StringComparison.OrdinalIgnoreCase))
            {
                foreach (var role in parts[1][6..].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                {
                    claims.Add(new Claim(ClaimTypes.Role, role));
                }
            }

            principal = new ClaimsPrincipal(new ClaimsIdentity(claims, SchemeName));
            return true;
        }
    }

    private sealed record OpenConversationRequest(string? InitialMessage, SupportConversationPriority Priority);

    private sealed record OpenConversationWithPaymentLinksRequest(
        string? InitialMessage,
        SupportConversationPriority Priority,
        Guid? RelatedGenerationId = null,
        Guid? RelatedPaymentId = null,
        Guid? RelatedSubscriptionId = null);

    private sealed record SendSupportMessageRequest(string Body, string? Locale = null);

    private sealed record UpdateSupportConversationStatusRequest(string Status);

    private sealed record AssignSupportConversationRequest(
        Guid? AssignedAdminId,
        string Reason,
        long ExpectedVersion);

    private sealed record UpsertSupportReplyTemplateRequest(string Title, string Body, bool IsEnabled, int SortOrder);

    private sealed record SupportConversationUpdatedEvent(Guid ConversationId, Guid InitiatorUserId, DateTime UpdatedAtUtc);

    private sealed class FakeSupportAttachmentStorage : ISupportAttachmentStorage
    {
        private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp",
            "video/mp4",
            "video/quicktime"
        };

        public int StoreCallCount { get; private set; }
        public int DeleteCallCount { get; private set; }
        private string? nextStoreFailureCode;

        public void FailNextStore(string errorCode)
        {
            nextStoreFailureCode = errorCode;
        }

        public long? ResolveMaxFileSizeBytes(string declaredContentType)
        {
            var normalizedContentType = NormalizeContentType(declaredContentType);
            if (normalizedContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
            {
                return 50L * 1024 * 1024;
            }

            if (normalizedContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                return 10L * 1024 * 1024;
            }

            return null;
        }

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            DeleteCallCount++;
            return Task.FromResult(Result.Success());
        }

        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken)
        {
            StoreCallCount++;
            if (!string.IsNullOrWhiteSpace(nextStoreFailureCode))
            {
                var failureCode = nextStoreFailureCode;
                nextStoreFailureCode = null;
                return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                    new Error(failureCode, "Storage failed.")));
            }

            var normalizedContentType = NormalizeContentType(attachment.ContentType);
            if (!AllowedContentTypes.Contains(normalizedContentType))
            {
                return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                    new Error("support.attachment_content_type_not_allowed", "Content type is not allowed.")));
            }

            var payload = ResolvePayload(attachment);
            if (!MatchesFileSignature(normalizedContentType, payload))
            {
                return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                    new Error("support.attachment_mime_mismatch", "MIME type does not match file signature.")));
            }

            if (string.Equals(normalizedContentType, "image/jpg", StringComparison.OrdinalIgnoreCase))
            {
                normalizedContentType = "image/jpeg";
            }

            var url = $"http://localhost:5000/support-attachments/test/{Guid.NewGuid():N}-{attachment.FileName}";
            return Task.FromResult(Result.Success(new StoredSupportAttachmentResponse(
                url,
                url,
                attachment.FileName,
                normalizedContentType,
                attachment.Content?.LongLength ?? attachment.ContentLengthBytes ?? payload.LongLength,
                null)));
        }

        private static byte[] ResolvePayload(SupportAttachmentUploadCommand attachment)
        {
            if (attachment.Content is { Length: > 0 })
            {
                return attachment.Content;
            }

            if (attachment.ContentStream is null)
            {
                return [];
            }

            if (attachment.ContentStream.CanSeek)
            {
                attachment.ContentStream.Position = 0;
            }

            using var memoryStream = new MemoryStream();
            attachment.ContentStream.CopyTo(memoryStream);

            if (attachment.ContentStream.CanSeek)
            {
                attachment.ContentStream.Position = 0;
            }

            return memoryStream.ToArray();
        }

        private static string NormalizeContentType(string contentType)
        {
            if (string.IsNullOrWhiteSpace(contentType))
            {
                return string.Empty;
            }

            var separatorIndex = contentType.IndexOf(';');
            return (separatorIndex >= 0 ? contentType[..separatorIndex] : contentType).Trim();
        }

        private static bool MatchesFileSignature(string normalizedContentType, byte[] payload)
        {
            return normalizedContentType switch
            {
                "image/jpeg" or "image/jpg" => payload.Length >= 3
                    && payload[0] == 0xFF
                    && payload[1] == 0xD8
                    && payload[2] == 0xFF,
                "image/png" => payload.Length >= 8
                    && payload[0] == 0x89
                    && payload[1] == 0x50
                    && payload[2] == 0x4E
                    && payload[3] == 0x47
                    && payload[4] == 0x0D
                    && payload[5] == 0x0A
                    && payload[6] == 0x1A
                    && payload[7] == 0x0A,
                "image/webp" => payload.Length >= 12
                    && payload[0] == 0x52
                    && payload[1] == 0x49
                    && payload[2] == 0x46
                    && payload[3] == 0x46
                    && payload[8] == 0x57
                    && payload[9] == 0x45
                    && payload[10] == 0x42
                    && payload[11] == 0x50,
                "video/mp4" or "video/quicktime" => payload.Length >= 12
                    && payload[4] == 0x66
                    && payload[5] == 0x74
                    && payload[6] == 0x79
                    && payload[7] == 0x70,
                _ => false,
            };
        }
    }

    private sealed class FailUploadedAttachmentStatusSupportChatService(ISupportChatService inner) : ISupportChatService
    {
        private static readonly Error FinalizeFailedError = new("support.attachment_finalize_failed", "Support attachment state could not be finalized.");

        public Task<Result<SupportConversationDetailResponse>> OpenConversationAsync(OpenSupportConversationCommand command, CancellationToken cancellationToken) =>
            inner.OpenConversationAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(Guid userId, SupportConversationMessagesQuery query, CancellationToken cancellationToken) =>
            inner.GetUserConversationAsync(userId, query, cancellationToken);

        public Task<Result<SupportConversationInboxPageResponse>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken) =>
            inner.ListAdminInboxAsync(query, cancellationToken);

        public Task<Result<AdminSupportInboxMetricsResponse>> GetAdminInboxMetricsAsync(CancellationToken cancellationToken) =>
            inner.GetAdminInboxMetricsAsync(cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(Guid conversationId, SupportConversationMessagesQuery query, CancellationToken cancellationToken) =>
            inner.GetAdminConversationAsync(conversationId, query, cancellationToken);

        public Task<Result<SupportTicketContextResponse>> GetAdminTicketContextAsync(Guid conversationId, CancellationToken cancellationToken) =>
            inner.GetAdminTicketContextAsync(conversationId, cancellationToken);

        public Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken) =>
            inner.SendMessageAsync(command, cancellationToken);

        public Task<Result<SupportMessageResponse>> SendMessageWithAttachmentsAsync(SendSupportAttachmentsCommand command, CancellationToken cancellationToken) =>
            inner.SendMessageWithAttachmentsAsync(command, cancellationToken);

        public Task<Result<SupportMessageResponse>> CreateAttachmentMessageAsync(CreateSupportAttachmentMessageCommand command, CancellationToken cancellationToken) =>
            inner.CreateAttachmentMessageAsync(command, cancellationToken);

        public Task<Result<SupportMessageResponse>> UpdateAttachmentMessageAsync(UpdateSupportAttachmentMessageCommand command, CancellationToken cancellationToken)
        {
            if (command.AttachmentUploadStatus == SupportAttachmentUploadStatus.Uploaded)
            {
                return Task.FromResult(Result.Failure<SupportMessageResponse>(FinalizeFailedError));
            }

            return inner.UpdateAttachmentMessageAsync(command, cancellationToken);
        }

        public Task<Result> MarkConversationReadAsync(MarkSupportConversationReadCommand command, CancellationToken cancellationToken) =>
            inner.MarkConversationReadAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> ResolveConversationAsync(ResolveSupportConversationCommand command, CancellationToken cancellationToken) =>
            inner.ResolveConversationAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> CloseConversationAsync(CloseSupportConversationCommand command, CancellationToken cancellationToken) =>
            inner.CloseConversationAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> ReopenConversationAsync(ReopenSupportConversationCommand command, CancellationToken cancellationToken) =>
            inner.ReopenConversationAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> SubmitConversationFeedbackAsync(SubmitSupportConversationFeedbackCommand command, CancellationToken cancellationToken) =>
            inner.SubmitConversationFeedbackAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> UpdateConversationStatusAsync(UpdateSupportConversationStatusCommand command, CancellationToken cancellationToken) =>
            inner.UpdateConversationStatusAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> AssignConversationAsync(AssignSupportConversationCommand command, CancellationToken cancellationToken) =>
            inner.AssignConversationAsync(command, cancellationToken);

        public Task<Result<SupportConversationDetailResponse>> UpdateConversationMetadataAsync(UpdateSupportConversationMetadataCommand command, CancellationToken cancellationToken) =>
            inner.UpdateConversationMetadataAsync(command, cancellationToken);
    }

    private sealed class NoopSupportChatPushNotificationSender : ISupportChatPushNotificationSender
    {
        public Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private static string EncodeHubAccessToken(Guid userId, params string[] roles)
    {
        var suffix = roles.Length > 0 ? $";roles={string.Join(',', roles)}" : string.Empty;
        return $"{userId:D}{suffix}";
    }
}
