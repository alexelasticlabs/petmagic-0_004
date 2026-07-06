using System.Net;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed partial class SupportChatEndpointsIntegrationTests
{
    [Fact]
    public async Task AdminInbox_ShouldFilterByAssignmentScope()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var mine = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Assigned case", SupportConversationPriority.Normal));

        var adminReply = await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/tickets/{mine.ConversationId}/messages",
            new SendSupportMessageRequest("Assigned via first admin reply"));
        Assert.True(adminReply.IsFromAdmin);

        var unassignedApplication = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(OtherUserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Unassigned case", SupportConversationPriority.Normal));

        var mineInbox = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            adminClient,
            "/api/admin/support/tickets?assignment=mine");

        var unassignedInbox = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            adminClient,
            "/api/admin/support/tickets?assignment=unassigned");

        Assert.Single(mineInbox.Items);
        Assert.Single(unassignedInbox.Items);
        Assert.Equal(1, mineInbox.TotalCount);
        Assert.Equal(1, unassignedInbox.TotalCount);
        Assert.Equal(mine.ConversationId, mineInbox.Items[0].ConversationId);
        Assert.Equal(unassignedApplication.ConversationId, unassignedInbox.Items[0].ConversationId);
    }

    [Fact]
    public async Task AdminInbox_ShouldReturnPagedMetadata()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("First paged case", SupportConversationPriority.Normal));

        await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(OtherUserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Second paged case", SupportConversationPriority.Normal));

        var firstPage = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            application.CreateClient(AdminId, "Admin"),
            "/api/admin/support/tickets?page=1&pageSize=1");

        Assert.Equal(1, firstPage.Page);
        Assert.Equal(1, firstPage.PageSize);
        Assert.Equal(2, firstPage.TotalCount);
        Assert.True(firstPage.HasMore);
        Assert.Single(firstPage.Items);

        var secondPage = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            application.CreateClient(AdminId, "Admin"),
            "/api/admin/support/tickets?page=2&pageSize=1");

        Assert.Equal(2, secondPage.Page);
        Assert.Equal(1, secondPage.PageSize);
        Assert.Equal(2, secondPage.TotalCount);
        Assert.False(secondPage.HasMore);
        Assert.Single(secondPage.Items);
        Assert.NotEqual(firstPage.Items[0].ConversationId, secondPage.Items[0].ConversationId);
    }

    [Fact]
    public async Task AdminInbox_ShouldAcceptRepeatedStatusFiltersWithPrioritySort()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var otherUserClient = application.CreateClient(OtherUserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var newTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("New high priority case", SupportConversationPriority.High));

        var waitingTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            otherUserClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Waiting case", SupportConversationPriority.Normal));

        await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/tickets/{waitingTicket.ConversationId}/messages",
            new SendSupportMessageRequest("Need more details"));

        var tickets = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            adminClient,
            "/api/admin/support/tickets?status=New&status=WaitingForUser&sort=priority&page=1&pageSize=10");

        Assert.Equal(2, tickets.TotalCount);
        Assert.Equal(newTicket.ConversationId, tickets.Items[0].ConversationId);
        Assert.Equal("High", tickets.Items[0].Priority);
        Assert.Contains(tickets.Items, item => item.Status == "New");
        Assert.Contains(tickets.Items, item => item.Status == "WaitingForUser");
    }

    [Fact]
    public async Task AdminInbox_ShouldFilterWaitingForSupportQueue()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var otherUserClient = application.CreateClient(OtherUserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var newTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Waiting for support", SupportConversationPriority.Normal));

        var waitingForUserTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            otherUserClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Waiting for user", SupportConversationPriority.Normal));

        await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/tickets/{waitingForUserTicket.ConversationId}/messages",
            new SendSupportMessageRequest("Please send details"));

        var tickets = await GetFromJsonAsync<SupportConversationInboxPageResponse>(
            adminClient,
            "/api/admin/support/tickets?queue=waiting_for_support&page=1&pageSize=10");

        Assert.Equal(1, tickets.TotalCount);
        var ticket = Assert.Single(tickets.Items);
        Assert.Equal(newTicket.ConversationId, ticket.ConversationId);
        Assert.Equal("New", ticket.Status);
    }

    [Fact]
    public async Task AdminInbox_ShouldReturnFieldSpecificProblemForInvalidAssignmentFilter()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        using var response = await application.CreateClient(AdminId, "Admin")
            .GetAsync("/api/admin/support/tickets?assignment=everyone");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("support.assignment_invalid", body, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("status=1", "support.status_invalid")]
    [InlineData("status=-1", "support.status_invalid")]
    [InlineData("source=1", "support.source_invalid")]
    [InlineData("source=-1", "support.source_invalid")]
    [InlineData("priority=1", "support.priority_invalid")]
    [InlineData("priority=-1", "support.priority_invalid")]
    [InlineData("queue=unknown", "support.queue_invalid")]
    public async Task AdminInbox_ShouldRejectInvalidFilters(string query, string expectedErrorCode)
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        using var response = await application.CreateClient(AdminId, "Admin")
            .GetAsync($"/api/admin/support/tickets?{query}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains(expectedErrorCode, body, StringComparison.Ordinal);
    }
}
