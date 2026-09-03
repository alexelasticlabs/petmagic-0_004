using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
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
    public async Task AdminModerationEndpoints_ShouldKeepReplayConflictAuditAndSummaryContract()
    {
        var auditLog = new RecordingAdminAuditLog();
        await using var application = await TestApplication.CreateAsync(
            startGenerationWorker: false,
            adminAuditLog: auditLog);

        Guid complaintEventId;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<ITemplatesService>();
            var created = await service.CreateImageAsync(
                new CreateImageTemplateCommand(
                    "Moderation HTTP Contract",
                    "Template for moderation endpoint integration coverage.",
                    "Safety",
                    ["moderation", "http"],
                    false,
                    20,
                    TemplatePromoBadgeMode.New.ToString(),
                    new TemplateAssetCommand(
                        "https://cdn.example.com/moderation-http-contract.jpg",
                        "moderation-http-contract.jpg",
                        "image/jpeg",
                        2_048,
                        null),
                    "openai/gpt-image-2/edit",
                    "Keep the same pet.",
                    TemplateStatus.Active.ToString(),
                    PetPhotoRequirements: ["One pet with a clearly visible face"]),
                CancellationToken.None);
            Assert.True(created.IsSuccess, created.Error.Code);

            var complaint = await service.RecordAnalyticsEventAsync(
                new RecordTemplateAnalyticsEventCommand(
                    created.Value.TemplateId,
                    TemplateAnalyticsEventTypes.Complaint,
                    "profile",
                    "web",
                    "us",
                    Guid.NewGuid(),
                    null,
                    "Unsafe generated result"),
                CancellationToken.None);
            var feedback = await service.RecordAnalyticsEventAsync(
                new RecordTemplateAnalyticsEventCommand(
                    created.Value.TemplateId,
                    TemplateAnalyticsEventTypes.Feedback,
                    "generation_result",
                    "android",
                    "pl",
                    Guid.NewGuid(),
                    null,
                    "Unexpected generated result"),
                CancellationToken.None);
            Assert.True(complaint.IsSuccess, complaint.Error.Code);
            Assert.True(feedback.IsSuccess, feedback.Error.Code);

            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            complaintEventId = await dbContext.TemplateAnalyticsEvents
                .AsNoTracking()
                .Where(analyticsEvent =>
                    analyticsEvent.TemplateId == created.Value.TemplateId
                    && analyticsEvent.EventType == TemplateAnalyticsEventTypes.Complaint)
                .Select(analyticsEvent => analyticsEvent.Id)
                .SingleAsync();
        }

        auditLog.Entries.Clear();
        var decisionPath = $"/api/admin/templates/moderation/{complaintEventId:D}/decision";

        using var firstResponse = await application.Client.PostAsJsonAsync(
            decisionPath,
            new AdminTemplateEndpoints.AdminModerationDecisionRequest("reject", "  Policy violation  "));
        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);
        var first = await ReadJsonAsync<AdminModerationQueueItemResponse>(firstResponse);
        Assert.Equal("rejected", first.Status);
        Assert.Equal("Policy violation", first.ModerationComment);
        Assert.NotNull(first.ModeratedAtUtc);

        using var replayResponse = await application.Client.PostAsJsonAsync(
            decisionPath,
            new AdminTemplateEndpoints.AdminModerationDecisionRequest("rejected", "Policy violation"));
        Assert.Equal(HttpStatusCode.OK, replayResponse.StatusCode);
        var replay = await ReadJsonAsync<AdminModerationQueueItemResponse>(replayResponse);
        Assert.Equal(first.ModeratedAtUtc, replay.ModeratedAtUtc);
        Assert.Equal(first.ModerationComment, replay.ModerationComment);

        await AssertModerationConflictAsync(application.Client, decisionPath, "approve", "Policy violation");
        await AssertModerationConflictAsync(application.Client, decisionPath, "reject", "Different reason");

        var audit = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.content.rejected", audit.Action);
        Assert.Equal("template_analytics_event", audit.TargetType);
        Assert.Equal(complaintEventId.ToString("D"), audit.TargetId);
        Assert.Equal("pending", audit.OldValue);
        Assert.Equal("rejected", audit.NewValue);
        Assert.Equal("reason=Policy violation", audit.Details);

        using var queueResponse = await application.Client.GetAsync(
            "/api/admin/templates/moderation?status=approved&search=missing");
        Assert.Equal(HttpStatusCode.OK, queueResponse.StatusCode);
        var queue = await ReadJsonAsync<AdminModerationQueuePageResponse>(queueResponse);
        Assert.Empty(queue.Items);
        Assert.Equal(0, queue.TotalCount);
        var summary = Assert.IsType<AdminModerationQueueSummaryResponse>(queue.Summary);
        Assert.Equal(1, summary.PendingCount);
        Assert.Equal(0, summary.ApprovedCount);
        Assert.Equal(1, summary.RejectedCount);
        Assert.Equal(0, summary.PendingComplaintsCount);
        Assert.Equal(1, summary.PendingFeedbackCount);
        Assert.NotNull(summary.OldestPendingAtUtc);
        Assert.Equal(queue.GeneratedAtUtc, summary.GeneratedAtUtc);
    }

    private static async Task AssertModerationConflictAsync(
        HttpClient client,
        string decisionPath,
        string action,
        string reason)
    {
        using var response = await client.PostAsJsonAsync(
            decisionPath,
            new AdminTemplateEndpoints.AdminModerationDecisionRequest(action, reason));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        using var problem = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        const string expectedCode = "templates.moderation_decision_conflict";
        Assert.Equal(expectedCode, problem.RootElement.GetProperty("title").GetString());
        Assert.Equal(expectedCode, problem.RootElement.GetProperty("code").GetString());
        Assert.Equal(StatusCodes.Status409Conflict, problem.RootElement.GetProperty("status").GetInt32());
    }
}
