using System.Net;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed partial class SupportChatEndpointsIntegrationTests
{
    [Fact]
    public async Task AdminAssignmentEndpoint_ShouldSupportDelegatedAssignmentAndRejectStaleVersion()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Delegated assignment", SupportConversationPriority.Normal));

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new
            {
                assignedAdminId = ModeratorId,
                reason = "Routing to the moderator queue owner.",
                expectedVersion = created.Version,
            });

        Assert.Equal(ModeratorId, assigned.AssignedAdminId);
        Assert.True(assigned.Version > created.Version);

        using var staleResponse = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new
            {
                assignedAdminId = AdminId,
                reason = "Taking over the escalated request.",
                expectedVersion = created.Version,
            });

        Assert.Equal(HttpStatusCode.Conflict, staleResponse.StatusCode);
        var problem = await staleResponse.Content.ReadFromJsonAsync<ProblemDetails>();
        Assert.Equal("support.assignment_conflict", problem?.Title);
    }

    [Fact]
    public async Task ModeratorAssignmentEndpoint_ShouldAllowOnlySelfAssignment()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Moderator ownership", SupportConversationPriority.Normal));
        var moderatorClient = application.CreateClient(ModeratorId, "Moderator");

        using var forbiddenResponse = await moderatorClient.PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new
            {
                assignedAdminId = AdminId,
                reason = "This must not allow delegated assignment.",
                expectedVersion = created.Version,
            });

        Assert.Equal(HttpStatusCode.Forbidden, forbiddenResponse.StatusCode);

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            moderatorClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assignment",
            new
            {
                assignedAdminId = ModeratorId,
                reason = "Moderator accepts the ticket.",
                expectedVersion = created.Version,
            });

        Assert.Equal(ModeratorId, assigned.AssignedAdminId);
    }

    [Fact]
    public async Task SupportSla_ShouldExposeUrgentTargetsAndPauseResolutionWhileWaitingForUser()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Urgent SLA", SupportConversationPriority.Normal));
        var assigned = await PostEmptyAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/assign-to-me");
        var urgent = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/metadata",
            new { priority = "Urgent", tags = Array.Empty<string>() });

        Assert.NotNull(urgent.Sla);
        Assert.Equal(15, (urgent.Sla.FirstResponseDueAtUtc - urgent.CreatedAtUtc).TotalMinutes);
        Assert.Equal(240, (urgent.Sla.ResolutionDueAtUtc - urgent.CreatedAtUtc).TotalMinutes);

        _ = await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}/messages",
            new SendSupportMessageRequest("We are investigating this now."));

        var waiting = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{assigned.ConversationId}");
        Assert.Equal("WaitingForUser", waiting.Status);
        Assert.NotNull(waiting.Sla?.FirstResponseAtUtc);
        Assert.True(waiting.Sla?.IsResolutionPaused);
        Assert.Equal("Paused", waiting.Sla?.ResolutionStatus);

        _ = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Here are the requested details."));
        var resumed = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/tickets/{created.ConversationId}");

        Assert.Equal("InProgress", resumed.Status);
        Assert.False(resumed.Sla?.IsResolutionPaused);
    }

    [Fact]
    public async Task ReplyTemplates_ShouldBeAdminOnlyVersionedAndSoftDisabled()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var moderatorClient = application.CreateClient(ModeratorId, "Moderator");
        var adminClient = application.CreateClient(AdminId, "Admin");

        using var moderatorCreateResponse = await moderatorClient.PostAsJsonAsync(
            "/api/admin/support/templates",
            new { title = "Forbidden", body = "Moderator cannot create.", isEnabled = true, sortOrder = 10 });
        Assert.Equal(HttpStatusCode.Forbidden, moderatorCreateResponse.StatusCode);

        var created = await PostAsJsonAsync<SupportReplyTemplateResponse>(
            adminClient,
            "/api/admin/support/templates",
            new { title = "Version one", body = "First response.", isEnabled = true, sortOrder = 10 });
        var updated = await PutAsJsonAsync<SupportReplyTemplateResponse>(
            adminClient,
            $"/api/admin/support/templates/{created.TemplateId}",
            new
            {
                title = "Version two",
                body = "Second response.",
                isEnabled = true,
                sortOrder = 20,
                expectedVersion = created.Version,
                reason = "Improved operator guidance.",
            });

        Assert.Equal(2, updated.Version);
        var versions = await GetFromJsonAsync<IReadOnlyList<SupportReplyTemplateVersionResponse>>(
            moderatorClient,
            $"/api/admin/support/templates/{created.TemplateId}/versions");
        Assert.Equal(2, versions.Count);
        Assert.True(versions[0].IsCurrent);
        Assert.Equal(2, versions[0].Version);
        Assert.Equal(1, versions[1].Version);

        using var disableResponse = await adminClient.DeleteAsync(
            $"/api/admin/support/templates/{created.TemplateId}?expectedVersion={updated.Version}&reason=Retired%20reply");
        Assert.Equal(HttpStatusCode.NoContent, disableResponse.StatusCode);

        var enabled = await GetFromJsonAsync<IReadOnlyList<SupportReplyTemplateResponse>>(
            moderatorClient,
            "/api/admin/support/templates");
        Assert.DoesNotContain(enabled, template => template.TemplateId == created.TemplateId);

        var all = await GetFromJsonAsync<IReadOnlyList<SupportReplyTemplateResponse>>(
            moderatorClient,
            "/api/admin/support/templates?includeDisabled=true");
        var disabled = Assert.Single(all, template => template.TemplateId == created.TemplateId);
        Assert.False(disabled.IsEnabled);
        Assert.Equal(3, disabled.Version);
        Assert.NotNull(disabled.DisabledAtUtc);
    }
}
