using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public void TemplatesModelSnapshot_ShouldIncludeModerationLeaseConcurrencyContract()
    {
        var options = new DbContextOptionsBuilder<PetMagic.Modules.Templates.Infrastructure.Data.TemplatesDbContext>()
            .UseNpgsql("Host=127.0.0.1;Database=petmagic_model_check;Username=model_check;Password=model_check")
            .Options;
        using var dbContext = new PetMagic.Modules.Templates.Infrastructure.Data.TemplatesDbContext(options);

        Assert.False(dbContext.Database.HasPendingModelChanges());
        var entityType = dbContext.Model.FindEntityType(
            typeof(PetMagic.Modules.Templates.Infrastructure.Entities.TemplateAnalyticsEvent));
        var version = entityType?.FindProperty("ModerationVersion");
        Assert.NotNull(version);
        Assert.True(version!.IsConcurrencyToken);
        Assert.Contains(
            entityType!.GetIndexes(),
            index => index.GetDatabaseName() == "IX_templates_analytics_events_moderation_lease");
    }

    [Fact]
    public async Task AdminModerationLeaseWorkflow_ShouldVersionProtectOwnershipAndAuditEveryMutation()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var moderatorA = Guid.NewGuid();
        var moderatorB = Guid.NewGuid();
        var admin = Guid.NewGuid();
        var service = CreateService(
            dbContext,
            adminAuditLog: auditLog,
            identityUserLookupService: new ModerationIdentityUserLookupService(
                new ModerationLookupUser(moderatorA, true, [SystemRoles.Moderator]),
                new ModerationLookupUser(moderatorB, true, [SystemRoles.Moderator]),
                new ModerationLookupUser(admin, true, [SystemRoles.Admin])));
        var eventId = await CreatePendingModerationLeaseEventAsync(service, dbContext, "Moderation lease workflow");

        var claimed = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, moderatorA, "Moderator", 0, 10),
            CancellationToken.None);

        Assert.True(claimed.IsSuccess, claimed.Error.Code);
        Assert.Equal(moderatorA, claimed.Value.LeaseOwnerUserId);
        Assert.Equal(1, claimed.Value.Version);
        Assert.NotNull(claimed.Value.LeaseClaimedAtUtc);
        Assert.True(claimed.Value.LeaseExpiresAtUtc > claimed.Value.LeaseClaimedAtUtc);

        var otherModeratorClaim = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, moderatorB, "Moderator", 1),
            CancellationToken.None);
        Assert.True(otherModeratorClaim.IsFailure);
        Assert.Equal("templates.moderation_lease_not_owned", otherModeratorClaim.Error.Code);

        var staleRelease = await service.ReleaseAdminModerationItemAsync(
            new AdminModerationReleaseCommand(eventId, moderatorA, "Moderator", 0, "Operator changed queue"),
            CancellationToken.None);
        Assert.True(staleRelease.IsFailure);
        Assert.Equal("templates.moderation_lease_conflict", staleRelease.Error.Code);

        var handedOff = await service.HandoffAdminModerationItemAsync(
            new AdminModerationHandoffCommand(
                eventId,
                admin,
                "Admin",
                moderatorB,
                1,
                "Balance the moderation workload",
                20),
            CancellationToken.None);

        Assert.True(handedOff.IsSuccess, handedOff.Error.Code);
        Assert.Equal(moderatorB, handedOff.Value.LeaseOwnerUserId);
        Assert.Equal(2, handedOff.Value.Version);

        var released = await service.ReleaseAdminModerationItemAsync(
            new AdminModerationReleaseCommand(
                eventId,
                moderatorB,
                "Moderator",
                2,
                "Returning item to the queue"),
            CancellationToken.None);

        Assert.True(released.IsSuccess, released.Error.Code);
        Assert.Null(released.Value.LeaseOwnerUserId);
        Assert.Null(released.Value.LeaseClaimedAtUtc);
        Assert.Null(released.Value.LeaseExpiresAtUtc);
        Assert.Equal(3, released.Value.Version);

        Assert.Equal(
            [
                "admin.content.moderation_claimed",
                "admin.content.moderation_handed_off",
                "admin.content.moderation_released"
            ],
            auditLog.Entries.Select(entry => entry.Action).ToArray());
        Assert.All(auditLog.Entries, entry => Assert.NotNull(entry.EventId));
        Assert.Equal(3, await dbContext.PushOutboxMessages.CountAsync());
        Assert.All(
            await dbContext.PushOutboxMessages.ToListAsync(),
            message => Assert.Equal(PushOutboxStatus.Sent, message.Status));
    }

    [Fact]
    public async Task AdminModerationHandoff_ShouldAllowActiveAdminAssignee()
    {
        await using var dbContext = CreateDbContext();
        var actorId = Guid.NewGuid();
        var assigneeId = Guid.NewGuid();
        var service = CreateService(
            dbContext,
            identityUserLookupService: new ModerationIdentityUserLookupService(
                new ModerationLookupUser(actorId, true, [SystemRoles.Admin]),
                new ModerationLookupUser(assigneeId, true, [SystemRoles.Admin])));
        var eventId = await CreatePendingModerationLeaseEventAsync(service, dbContext, "Admin moderation handoff");
        var claimed = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, actorId, SystemRoles.Admin, 0),
            CancellationToken.None);
        Assert.True(claimed.IsSuccess, claimed.Error.Code);

        var handedOff = await service.HandoffAdminModerationItemAsync(
            new AdminModerationHandoffCommand(
                eventId,
                actorId,
                SystemRoles.Admin,
                assigneeId,
                1,
                "Transfer to another administrator"),
            CancellationToken.None);

        Assert.True(handedOff.IsSuccess, handedOff.Error.Code);
        Assert.Equal(assigneeId, handedOff.Value.LeaseOwnerUserId);
        Assert.Equal(2, handedOff.Value.Version);
    }

    [Theory]
    [InlineData(true, true, "User")]
    [InlineData(true, false, "Moderator")]
    [InlineData(false, false, null)]
    public async Task AdminModerationHandoff_ShouldRejectUnavailableAssigneeWithoutChangingLease(
        bool assigneeExists,
        bool assigneeIsActive,
        string? assigneeRole)
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var actorId = Guid.NewGuid();
        var assigneeId = Guid.NewGuid();
        var users = new List<ModerationLookupUser>
        {
            new(actorId, true, [SystemRoles.Admin])
        };
        if (assigneeExists)
        {
            IReadOnlyList<string> roles = assigneeRole is null ? [] : [assigneeRole];
            users.Add(new ModerationLookupUser(assigneeId, assigneeIsActive, roles));
        }

        var service = CreateService(
            dbContext,
            adminAuditLog: auditLog,
            identityUserLookupService: new ModerationIdentityUserLookupService(users.ToArray()));
        var eventId = await CreatePendingModerationLeaseEventAsync(service, dbContext, "Rejected moderation handoff");
        var claimed = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, actorId, SystemRoles.Admin, 0),
            CancellationToken.None);
        Assert.True(claimed.IsSuccess, claimed.Error.Code);

        var handedOff = await service.HandoffAdminModerationItemAsync(
            new AdminModerationHandoffCommand(
                eventId,
                actorId,
                SystemRoles.Admin,
                assigneeId,
                1,
                "Invalid assignee must not receive the lease"),
            CancellationToken.None);

        Assert.True(handedOff.IsFailure);
        Assert.Equal("templates.moderation_assignee_invalid", handedOff.Error.Code);
        dbContext.ChangeTracker.Clear();
        var persisted = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .SingleAsync(item => item.Id == eventId);
        Assert.Equal(actorId, persisted.ModerationLeaseOwnerUserId);
        Assert.Equal(1, persisted.ModerationVersion);
        Assert.Single(auditLog.Entries);
        Assert.Equal("admin.content.moderation_claimed", auditLog.Entries[0].Action);
    }

    [Fact]
    public async Task AdminModerationClaim_ShouldRejectStaleConcurrentOwner()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var firstDbContext = await CreateSqliteDbContextAsync(connection);
        await using var secondDbContext = await CreateSqliteDbContextAsync(connection);
        var firstAuditLog = new RecordingAdminAuditLog();
        var secondAuditLog = new RecordingAdminAuditLog();
        var firstService = CreateService(firstDbContext, adminAuditLog: firstAuditLog);
        var secondService = CreateService(secondDbContext, adminAuditLog: secondAuditLog);
        var eventId = await CreatePendingModerationLeaseEventAsync(
            firstService,
            firstDbContext,
            "Moderation concurrency");
        var firstModerator = Guid.NewGuid();
        var secondModerator = Guid.NewGuid();

        firstDbContext.ChangeTracker.Clear();
        secondDbContext.ChangeTracker.Clear();
        await firstDbContext.TemplateAnalyticsEvents.Include(item => item.Template).SingleAsync(item => item.Id == eventId);
        await secondDbContext.TemplateAnalyticsEvents.Include(item => item.Template).SingleAsync(item => item.Id == eventId);

        var firstClaim = await firstService.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, firstModerator, "Moderator", 0),
            CancellationToken.None);
        var staleClaim = await secondService.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, secondModerator, "Moderator", 0),
            CancellationToken.None);

        Assert.True(firstClaim.IsSuccess, firstClaim.Error.Code);
        Assert.True(staleClaim.IsFailure);
        Assert.Equal("templates.moderation_lease_conflict", staleClaim.Error.Code);
        Assert.Single(firstAuditLog.Entries);
        Assert.Empty(secondAuditLog.Entries);

        firstDbContext.ChangeTracker.Clear();
        var persisted = await firstDbContext.TemplateAnalyticsEvents.AsNoTracking().SingleAsync(item => item.Id == eventId);
        Assert.Equal(firstModerator, persisted.ModerationLeaseOwnerUserId);
        Assert.Equal(1, persisted.ModerationVersion);
    }

    [Fact]
    public async Task AdminModerationClaim_ShouldPersistQueuedAuditWhenImmediateDeliveryFails()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext, adminAuditLog: new ThrowingAdminAuditLog());
        var eventId = await CreatePendingModerationLeaseEventAsync(service, dbContext, "Moderation durable audit");
        var moderatorId = Guid.NewGuid();

        var result = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, moderatorId, "Moderator", 0),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Code);
        var outbox = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(TemplateAdminAuditOutbox.Kind, outbox.Kind);
        Assert.Equal(PushOutboxStatus.Queued, outbox.Status);
        var persisted = await dbContext.TemplateAnalyticsEvents.AsNoTracking().SingleAsync(item => item.Id == eventId);
        Assert.Equal(moderatorId, persisted.ModerationLeaseOwnerUserId);
        Assert.Equal(1, persisted.ModerationVersion);

        var replayAuditLog = new RecordingAdminAuditLog();
        var processor = new TemplateAdminAuditOutboxProcessor(
            dbContext,
            replayAuditLog,
            NullLogger<TemplateAdminAuditOutboxProcessor>.Instance);
        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.Single(replayAuditLog.Entries);
        Assert.Equal(PushOutboxStatus.Sent, outbox.Status);
    }

    [Fact]
    public async Task AdminModerationDecision_ShouldRequireLeaseOwnerAndClearLeaseOnSuccess()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);
        var eventId = await CreatePendingModerationLeaseEventAsync(service, dbContext, "Moderation leased decision");
        var owner = Guid.NewGuid();
        var otherModerator = Guid.NewGuid();
        var claimed = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(eventId, owner, "Moderator", 0),
            CancellationToken.None);
        Assert.True(claimed.IsSuccess, claimed.Error.Code);

        var denied = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(
                eventId,
                "approve",
                "No policy violation",
                otherModerator,
                "Moderator",
                1),
            CancellationToken.None);
        Assert.True(denied.IsFailure);
        Assert.Equal("templates.moderation_lease_not_owned", denied.Error.Code);

        var decided = await service.DecideAdminModerationItemAsync(
            new AdminModerationDecisionCommand(
                eventId,
                "approve",
                "No policy violation",
                owner,
                "Moderator",
                1),
            CancellationToken.None);

        Assert.True(decided.IsSuccess, decided.Error.Code);
        Assert.Equal("approved", decided.Value.Status);
        Assert.Null(decided.Value.LeaseOwnerUserId);
        Assert.Null(decided.Value.LeaseExpiresAtUtc);
        Assert.Equal(2, decided.Value.Version);
        Assert.Equal(
            ["admin.content.moderation_claimed", "admin.content.approved"],
            auditLog.Entries.Select(entry => entry.Action).ToArray());
    }

    private static async Task<Guid> CreatePendingModerationLeaseEventAsync(
        PetMagic.Modules.Templates.Application.Abstractions.ITemplatesService service,
        PetMagic.Modules.Templates.Infrastructure.Data.TemplatesDbContext dbContext,
        string title)
    {
        var templateId = await CreateActiveImageTemplateAsync(service, title, "Safety", ["moderation"]);
        var recorded = await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                TemplateAnalyticsEventTypes.Complaint,
                "admin_test",
                "web",
                "us",
                Guid.NewGuid(),
                null,
                "Review requested"),
            CancellationToken.None);
        Assert.True(recorded.IsSuccess, recorded.Error.Code);

        return await dbContext.TemplateAnalyticsEvents
            .Where(item => item.TemplateId == templateId)
            .Select(item => item.Id)
            .SingleAsync();
    }
}
