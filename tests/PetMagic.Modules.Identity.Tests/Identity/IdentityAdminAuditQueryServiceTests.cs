using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityAdminAuditQueryServiceTests
{
    [Fact]
    public async Task ListAsync_ShouldReturnDeterministicRedactedPageWithFilteredSummary()
    {
        await using var dbContext = CreateDbContext();
        var actorId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        var subjectId = Guid.Parse("20000000-0000-0000-0000-000000000001");
        dbContext.Users.AddRange(
            CreateUser(actorId, "Auditor", "auditor@petmagic.test"),
            CreateUser(subjectId, "Pet owner", "owner@petmagic.test"));

        var occurredAtUtc = new DateTime(2026, 7, 26, 10, 0, 0, DateTimeKind.Utc);
        var identityEventId = Guid.Parse("30000000-0000-0000-0000-000000000002");
        var economyEventId = Guid.Parse("30000000-0000-0000-0000-000000000003");
        dbContext.AuditEvents.AddRange(
            CreateAuditEvent(
                identityEventId,
                "auth.login.succeeded",
                "User",
                subjectId.ToString("D"),
                actorId,
                subjectId,
                occurredAtUtc),
            CreateAuditEvent(
                economyEventId,
                "admin.user.wallet.credited",
                "User",
                "token=target-secret",
                actorId,
                subjectId,
                occurredAtUtc),
            CreateAuditEvent(
                Guid.Parse("30000000-0000-0000-0000-000000000001"),
                "system.configuration.reloaded",
                "Configuration",
                "identity",
                null,
                null,
                occurredAtUtc.AddMinutes(-1)));
        await dbContext.SaveChangesAsync();

        var service = new IdentityAdminAuditQueryService(dbContext);
        var result = await service.ListAsync(
            new AdminAuditEventsQuery(0, 2, null, null, null, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(3, result.Value.TotalCount);
        Assert.Equal(2, result.Value.Items.Count);
        Assert.True(result.Value.HasMore);
        Assert.Equal(economyEventId, result.Value.Items[0].AuditEventId);
        Assert.Equal(identityEventId, result.Value.Items[1].AuditEventId);
        Assert.Equal(AdminAuditCategories.Economy, result.Value.Items[0].Category);
        Assert.Equal("Auditor", result.Value.Items[0].ActorDisplayName);
        Assert.Equal("owner@petmagic.test", result.Value.Items[0].SubjectEmail);
        Assert.DoesNotContain("target-secret", result.Value.Items[0].TargetId, StringComparison.Ordinal);
        Assert.Equal(3, result.Value.Summary.TotalEvents);
        Assert.Equal(1, result.Value.Summary.UniqueActors);
        Assert.Equal(1, result.Value.Summary.AccessEvents);
        Assert.Equal(1, result.Value.Summary.SystemEvents);
    }

    [Theory]
    [InlineData("auth.login.succeeded", "User", AdminAuditCategories.Identity)]
    [InlineData("admin.user.wallet.credited", "User", AdminAuditCategories.Economy)]
    [InlineData("legacy.subscription_plan.changed", "subscription_plan", AdminAuditCategories.Economy)]
    [InlineData("admin.templates.generation.retry", "TemplateGenerationJob", AdminAuditCategories.Content)]
    [InlineData("admin.support.ticket.assigned", "SupportConversation", AdminAuditCategories.Support)]
    [InlineData("admin.gamification.streak.reset", "DailyStreak", AdminAuditCategories.Gamification)]
    [InlineData("system.configuration.reloaded", "Configuration", AdminAuditCategories.System)]
    public async Task ListAsync_ShouldUseStableCategoryMapping(
        string action,
        string targetType,
        string expectedCategory)
    {
        await using var dbContext = CreateDbContext();
        var auditEvent = CreateAuditEvent(
            Guid.NewGuid(),
            action,
            targetType,
            Guid.NewGuid().ToString("D"),
            null,
            null,
            new DateTime(2026, 7, 26, 11, 0, 0, DateTimeKind.Utc));
        dbContext.AuditEvents.Add(auditEvent);
        await dbContext.SaveChangesAsync();

        var result = await new IdentityAdminAuditQueryService(dbContext).ListAsync(
            new AdminAuditEventsQuery(0, 25, null, expectedCategory, null, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(expectedCategory, item.Category);
    }

    [Fact]
    public async Task ListAsync_ShouldFilterByIdentitySearchAndOneSidedNinetyDayWindow()
    {
        await using var dbContext = CreateDbContext();
        var actorId = Guid.NewGuid();
        var subjectId = Guid.NewGuid();
        dbContext.Users.AddRange(
            CreateUser(actorId, "Audit Operator", "operator@petmagic.test"),
            CreateUser(subjectId, "Target", "target@petmagic.test"));
        var toUtc = new DateTime(2026, 7, 26, 12, 0, 0, DateTimeKind.Utc);
        dbContext.AuditEvents.AddRange(
            CreateAuditEvent(
                Guid.NewGuid(),
                "admin.user.wallet.debited",
                "User",
                subjectId.ToString("D"),
                actorId,
                subjectId,
                toUtc.AddDays(-30)),
            CreateAuditEvent(
                Guid.NewGuid(),
                "admin.user.wallet.credited",
                "User",
                subjectId.ToString("D"),
                actorId,
                subjectId,
                toUtc.AddDays(-91)));
        await dbContext.SaveChangesAsync();

        var service = new IdentityAdminAuditQueryService(dbContext);
        var result = await service.ListAsync(
            new AdminAuditEventsQuery(
                0,
                25,
                "OPERATOR@PETMAGIC.TEST",
                AdminAuditCategories.Economy,
                actorId,
                subjectId,
                null,
                toUtc),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal("admin.user.wallet.debited", item.Action);
        Assert.Equal(1, result.Value.TotalCount);
    }

    [Fact]
    public async Task ListAsync_ShouldValidateFiltersAndBoundPagination()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminAuditQueryService(dbContext);

        var longSearch = await service.ListAsync(
            new AdminAuditEventsQuery(0, 25, new string('x', 121), null, null, null, null, null),
            CancellationToken.None);
        var invalidCategory = await service.ListAsync(
            new AdminAuditEventsQuery(0, 25, null, "payments", null, null, null, null),
            CancellationToken.None);
        var reversedRange = await service.ListAsync(
            new AdminAuditEventsQuery(
                0,
                25,
                null,
                null,
                null,
                null,
                new DateTime(2026, 7, 2, 0, 0, 0, DateTimeKind.Utc),
                new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc)),
            CancellationToken.None);
        var excessiveRange = await service.ListAsync(
            new AdminAuditEventsQuery(
                0,
                25,
                null,
                null,
                null,
                null,
                new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                new DateTime(2026, 4, 2, 0, 0, 0, DateTimeKind.Utc)),
            CancellationToken.None);
        var bounded = await service.ListAsync(
            new AdminAuditEventsQuery(-10, 500, null, null, null, null, null, null),
            CancellationToken.None);

        Assert.Equal(AdminAuditErrors.SearchTooLong.Code, longSearch.Error.Code);
        Assert.Equal(AdminAuditErrors.CategoryInvalid.Code, invalidCategory.Error.Code);
        Assert.Equal(AdminAuditErrors.DateRangeInvalid.Code, reversedRange.Error.Code);
        Assert.Equal(AdminAuditErrors.DateRangeInvalid.Code, excessiveRange.Error.Code);
        Assert.True(bounded.IsSuccess);
        Assert.Equal(0, bounded.Value.Skip);
        Assert.Equal(100, bounded.Value.Take);
    }

    [Fact]
    public async Task GetAsync_ShouldReturnSanitizedDetailAndMissingError()
    {
        await using var dbContext = CreateDbContext();
        var actorId = Guid.NewGuid();
        dbContext.Users.Add(CreateUser(actorId, "Admin", "admin@petmagic.test"));
        var auditEventId = Guid.NewGuid();
        var auditEvent = CreateAuditEvent(
            auditEventId,
            "admin.payment.refunded",
            "purchase_order",
            Guid.NewGuid().ToString("D"),
            actorId,
            null,
            new DateTime(2026, 7, 26, 13, 0, 0, DateTimeKind.Utc));
        auditEvent.OldValue = "token=old-secret";
        auditEvent.NewValue = "api_secret=new-secret";
        auditEvent.Details = "purchaseToken=store-secret";
        auditEvent.IpAddress = "203.0.113.10";
        auditEvent.UserAgent = "PetMagicAdmin token=user-agent-secret";
        dbContext.AuditEvents.Add(auditEvent);
        await dbContext.SaveChangesAsync();

        var service = new IdentityAdminAuditQueryService(dbContext);
        var result = await service.GetAsync(auditEventId, CancellationToken.None);
        var missing = await service.GetAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(AdminAuditCategories.Economy, result.Value.Category);
        Assert.Equal("Admin", result.Value.ActorDisplayName);
        Assert.DoesNotContain("old-secret", result.Value.OldValue, StringComparison.Ordinal);
        Assert.DoesNotContain("new-secret", result.Value.NewValue, StringComparison.Ordinal);
        Assert.DoesNotContain("store-secret", result.Value.Details, StringComparison.Ordinal);
        Assert.DoesNotContain("user-agent-secret", result.Value.UserAgent, StringComparison.Ordinal);
        Assert.Equal("203.0.113.10", result.Value.IpAddress);
        Assert.Equal(AdminAuditErrors.EventNotFound.Code, missing.Error.Code);
    }

    private static IdentityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase($"identity-admin-audit-query-tests-{Guid.NewGuid():N}")
            .Options;

        return new IdentityDbContext(options);
    }

    private static AppUser CreateUser(Guid userId, string displayName, string email)
    {
        return new AppUser
        {
            Id = userId,
            UserName = email,
            NormalizedUserName = email.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            DisplayName = displayName,
        };
    }

    private static AuditEvent CreateAuditEvent(
        Guid auditEventId,
        string action,
        string targetType,
        string targetId,
        Guid? actorUserId,
        Guid? subjectUserId,
        DateTime occurredAtUtc)
    {
        return new AuditEvent
        {
            Id = auditEventId,
            Action = action,
            ActorUserId = actorUserId,
            ActorRole = actorUserId.HasValue ? "Admin" : null,
            SubjectUserId = subjectUserId,
            TargetType = targetType,
            TargetId = targetId,
            CorrelationId = $"audit-{auditEventId:N}",
            Details = "persisted details",
            CreatedAtUtc = occurredAtUtc.AddSeconds(1),
            OccurredAtUtc = occurredAtUtc,
        };
    }
}
