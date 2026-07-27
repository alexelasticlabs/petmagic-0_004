using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task DecideAdminModerationItemAsync_ShouldRejectReasonsOutsideBackendBounds()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Moderation reason bounds",
            "Safety",
            ["moderation"]);
        await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                TemplateAnalyticsEventTypes.Complaint,
                "profile",
                "web",
                "us",
                Guid.NewGuid(),
                null,
                "Unsafe result"),
            CancellationToken.None);
        var eventId = await dbContext.TemplateAnalyticsEvents.Select(x => x.Id).SingleAsync();

        var tooShort = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "reject", "  no  "),
            CancellationToken.None);
        var tooLong = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "reject", new string('x', 501)),
            CancellationToken.None);

        Assert.True(tooShort.IsFailure);
        Assert.Equal("templates.moderation_decision_reason_invalid", tooShort.Error.Code);
        Assert.True(tooLong.IsFailure);
        Assert.Equal("templates.moderation_decision_reason_invalid", tooLong.Error.Code);
        Assert.Empty(auditLog.Entries);
        var persisted = await dbContext.TemplateAnalyticsEvents.SingleAsync(x => x.Id == eventId);
        Assert.Equal("pending", persisted.ModerationStatus);
        Assert.Null(persisted.ModerationComment);
        Assert.Null(persisted.ModeratedAtUtc);
    }

    [Fact]
    public async Task DecideAdminModerationItemAsync_ShouldUseRelationalCompareAndSetReplayAndConflictContract()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var dbContext = await CreateSqliteDbContextAsync(connection);
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Moderation relational CAS",
            "Safety",
            ["moderation"]);
        await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                TemplateAnalyticsEventTypes.Feedback,
                "generation_result",
                "android",
                "pl",
                Guid.NewGuid(),
                Guid.NewGuid(),
                "Wrong result"),
            CancellationToken.None);
        var eventId = await dbContext.TemplateAnalyticsEvents.Select(x => x.Id).SingleAsync();
        dbContext.ChangeTracker.Clear();

        var decided = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "reject", "  Policy violation  "),
            CancellationToken.None);
        var replay = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "rejected", "Policy violation"),
            CancellationToken.None);
        var conflictingAction = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "approve", "Policy violation"),
            CancellationToken.None);
        var conflictingReason = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(eventId, "reject", "Different reason"),
            CancellationToken.None);

        Assert.True(decided.IsSuccess);
        Assert.Equal("rejected", decided.Value.Status);
        Assert.Equal("Policy violation", decided.Value.ModerationComment);
        Assert.NotNull(decided.Value.ModeratedAtUtc);
        Assert.True(replay.IsSuccess);
        Assert.Equal(decided.Value.ModeratedAtUtc, replay.Value.ModeratedAtUtc);
        Assert.Equal("Policy violation", replay.Value.ModerationComment);
        var audit = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.content.rejected", audit.Action);
        Assert.Equal("reason=Policy violation", audit.Details);
        Assert.True(conflictingAction.IsFailure);
        Assert.Equal("templates.moderation_decision_conflict", conflictingAction.Error.Code);
        Assert.True(conflictingReason.IsFailure);
        Assert.Equal("templates.moderation_decision_conflict", conflictingReason.Error.Code);

        var persisted = await dbContext.TemplateAnalyticsEvents.AsNoTracking().SingleAsync(x => x.Id == eventId);
        Assert.Equal("rejected", persisted.ModerationStatus);
        Assert.Equal("Policy violation", persisted.ModerationComment);
        Assert.Equal(decided.Value.ModeratedAtUtc, persisted.ModeratedAtUtc);

        var queue = await service.GetAdminModerationQueueAsync(
            new AdminModerationQueueQuery("all", null, 0, 10),
            CancellationToken.None);
        Assert.True(queue.IsSuccess);
        var summary = Assert.IsType<AdminModerationQueueSummaryResponse>(queue.Value.Summary);
        Assert.Equal(0, summary.PendingCount);
        Assert.Equal(1, summary.RejectedCount);
    }

    [Fact]
    public async Task GetAdminModerationQueueAsync_ShouldReturnUnfilteredModerationSummary()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(
            service,
            "Moderation summary",
            "Safety",
            ["moderation"]);
        var now = new DateTime(2026, 7, 26, 10, 0, 0, DateTimeKind.Utc);
        dbContext.TemplateAnalyticsEvents.AddRange(
            CreateModerationSummaryEvent(templateId, TemplateAnalyticsEventTypes.Complaint, "pending", now.AddHours(-5)),
            CreateModerationSummaryEvent(templateId, TemplateAnalyticsEventTypes.Feedback, "pending", now.AddHours(-2)),
            CreateModerationSummaryEvent(templateId, TemplateAnalyticsEventTypes.Complaint, "approved", now.AddHours(-4)),
            CreateModerationSummaryEvent(templateId, TemplateAnalyticsEventTypes.Feedback, "rejected", now.AddHours(-3)),
            CreateModerationSummaryEvent(templateId, TemplateAnalyticsEventTypes.View, "pending", now.AddHours(-6)));
        await dbContext.SaveChangesAsync();

        var result = await service.GetAdminModerationQueueAsync(
            new AdminModerationQueueQuery("approved", "missing search value", 0, 10),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Empty(result.Value.Items);
        Assert.Equal(0, result.Value.TotalCount);
        var summary = Assert.IsType<AdminModerationQueueSummaryResponse>(result.Value.Summary);
        Assert.Equal(2, summary.PendingCount);
        Assert.Equal(1, summary.ApprovedCount);
        Assert.Equal(1, summary.RejectedCount);
        Assert.Equal(1, summary.PendingComplaintsCount);
        Assert.Equal(1, summary.PendingFeedbackCount);
        Assert.Equal(now.AddHours(-5), summary.OldestPendingAtUtc);
        Assert.Equal(result.Value.GeneratedAtUtc, summary.GeneratedAtUtc);
    }

    private static TemplateAnalyticsEvent CreateModerationSummaryEvent(
        Guid templateId,
        string eventType,
        string moderationStatus,
        DateTime createdAtUtc)
    {
        return new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            EventType = eventType,
            Source = "admin-test",
            DeviceClass = "web",
            CountryCode = "us",
            ModerationStatus = moderationStatus,
            CreatedAtUtc = createdAtUtc,
        };
    }
}
