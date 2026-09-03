using System.Net;
using System.Net.Http.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task AdminModerationLeaseEndpoints_ShouldEnforceRoleOwnerVersionAndDecisionContract()
    {
        var auditLog = new RecordingAdminAuditLog();
        var moderatorA = Guid.NewGuid();
        var moderatorB = Guid.NewGuid();
        var admin = Guid.NewGuid();
        await using var application = await TestApplication.CreateAsync(
            startGenerationWorker: false,
            adminAuditLog: auditLog,
            identityUserLookupService: new FixedIdentityUserLookupService(
                new Dictionary<Guid, string>
                {
                    [moderatorA] = "Moderator",
                    [moderatorB] = "Moderator",
                    [admin] = "Admin"
                }));
        var eventId = await CreatePendingModerationLeaseEventAsync(application.Services);
        var path = $"/api/admin/templates/moderation/{eventId:D}";

        application.Client.DefaultRequestHeaders.Add("X-Test-Role", "Moderator");
        application.Client.DefaultRequestHeaders.Add("X-Test-UserId", moderatorA.ToString("D"));
        using var claimResponse = await application.Client.PostAsJsonAsync(
            $"{path}/claim",
            new AdminTemplateEndpoints.AdminModerationClaimRequest(0, 10));
        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
        var claimed = await ReadJsonAsync<AdminModerationQueueItemResponse>(claimResponse);
        Assert.Equal(moderatorA, claimed.LeaseOwnerUserId);
        Assert.Equal(1, claimed.Version);

        using var forbiddenHandoff = await application.Client.PostAsJsonAsync(
            $"{path}/handoff",
            new AdminTemplateEndpoints.AdminModerationHandoffRequest(
                moderatorB,
                1,
                "Balance workload"));
        Assert.Equal(HttpStatusCode.Forbidden, forbiddenHandoff.StatusCode);

        application.Client.DefaultRequestHeaders.Remove("X-Test-UserId");
        application.Client.DefaultRequestHeaders.Add("X-Test-UserId", moderatorB.ToString("D"));
        using var otherRelease = await application.Client.PostAsJsonAsync(
            $"{path}/release",
            new AdminTemplateEndpoints.AdminModerationReleaseRequest(1, "Return to queue"));
        Assert.Equal(HttpStatusCode.Conflict, otherRelease.StatusCode);

        application.Client.DefaultRequestHeaders.Remove("X-Test-Role");
        application.Client.DefaultRequestHeaders.Remove("X-Test-UserId");
        application.Client.DefaultRequestHeaders.Add("X-Test-Role", "Admin");
        application.Client.DefaultRequestHeaders.Add("X-Test-UserId", admin.ToString("D"));
        using var handoffResponse = await application.Client.PostAsJsonAsync(
            $"{path}/handoff",
            new AdminTemplateEndpoints.AdminModerationHandoffRequest(
                moderatorB,
                1,
                "Balance the moderation workload",
                20));
        Assert.Equal(HttpStatusCode.OK, handoffResponse.StatusCode);
        var handedOff = await ReadJsonAsync<AdminModerationQueueItemResponse>(handoffResponse);
        Assert.Equal(moderatorB, handedOff.LeaseOwnerUserId);
        Assert.Equal(2, handedOff.Version);

        application.Client.DefaultRequestHeaders.Remove("X-Test-Role");
        application.Client.DefaultRequestHeaders.Remove("X-Test-UserId");
        application.Client.DefaultRequestHeaders.Add("X-Test-Role", "Moderator");
        application.Client.DefaultRequestHeaders.Add("X-Test-UserId", moderatorB.ToString("D"));
        using var decisionResponse = await application.Client.PostAsJsonAsync(
            $"{path}/decision",
            new AdminTemplateEndpoints.AdminModerationDecisionRequest(
                "approve",
                "No policy violation",
                2));
        Assert.Equal(HttpStatusCode.OK, decisionResponse.StatusCode);
        var decided = await ReadJsonAsync<AdminModerationQueueItemResponse>(decisionResponse);
        Assert.Equal("approved", decided.Status);
        Assert.Null(decided.LeaseOwnerUserId);
        Assert.Null(decided.LeaseExpiresAtUtc);
        Assert.Equal(3, decided.Version);

        Assert.Equal(
            [
                "admin.content.moderation_claimed",
                "admin.content.moderation_handed_off",
                "admin.content.approved"
            ],
            auditLog.Entries.Select(entry => entry.Action).ToArray());
    }

    private static async Task<Guid> CreatePendingModerationLeaseEventAsync(IServiceProvider services)
    {
        await using var scope = services.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<ITemplatesService>();
        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Moderation lease HTTP contract",
                "Template for moderation lease endpoint integration coverage.",
                "Safety",
                ["moderation", "lease"],
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                new TemplateAssetCommand(
                    "https://cdn.example.com/moderation-lease-http.jpg",
                    "moderation-lease-http.jpg",
                    "image/jpeg",
                    2_048,
                    null),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                PetPhotoRequirements: ["One pet with a clearly visible face"]),
            CancellationToken.None);
        Assert.True(created.IsSuccess, created.Error.Code);

        var recorded = await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                created.Value.TemplateId,
                TemplateAnalyticsEventTypes.Complaint,
                "profile",
                "web",
                "us",
                Guid.NewGuid(),
                null,
                "Review requested"),
            CancellationToken.None);
        Assert.True(recorded.IsSuccess, recorded.Error.Code);

        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        return await dbContext.TemplateAnalyticsEvents
            .Where(item => item.TemplateId == created.Value.TemplateId)
            .Select(item => item.Id)
            .SingleAsync();
    }
}
