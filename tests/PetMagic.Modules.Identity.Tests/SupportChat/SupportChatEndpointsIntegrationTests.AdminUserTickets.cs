using System.Net;
using System.Net.Http.Json;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed partial class SupportChatEndpointsIntegrationTests
{
    [Fact]
    public async Task AdminUserTickets_ShouldFilterOnInitiatorAndRequireAdminAccess()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("User-specific case", SupportConversationPriority.Normal));

        var otherUserTicket = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(OtherUserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Other user case", SupportConversationPriority.Normal));

        using var moderatorResponse = await application.CreateClient(ModeratorId, "Moderator")
            .GetAsync($"/api/admin/users/{UserId}/support/tickets");
        Assert.Equal(HttpStatusCode.Forbidden, moderatorResponse.StatusCode);

        using var adminResponse = await application.CreateClient(AdminId, "Admin")
            .GetAsync($"/api/admin/users/{UserId}/support/tickets?page=0&pageSize=500");
        await AssertSuccessAsync(adminResponse);
        AssertPrivateSupportResponseHeaders(adminResponse);

        var tickets = (await adminResponse.Content.ReadFromJsonAsync<SupportConversationInboxPageResponse>(JsonOptions))!;
        Assert.Equal(1, tickets.Page);
        Assert.Equal(100, tickets.PageSize);
        Assert.Equal(1, tickets.TotalCount);
        Assert.False(tickets.HasMore);

        var ticket = Assert.Single(tickets.Items);
        Assert.Equal(userTicket.ConversationId, ticket.ConversationId);
        Assert.Equal(UserId, ticket.InitiatorUserId);
        Assert.DoesNotContain(tickets.Items, item => item.ConversationId == otherUserTicket.ConversationId);
    }
}
