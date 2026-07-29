using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityAdminNotificationServiceTests
{
    [Fact]
    public async Task PublishAndList_ShouldDedupeAndIsolateAudience()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminNotificationService(dbContext);
        var payload = JsonSerializer.SerializeToElement(new { conversationId = Guid.NewGuid() });

        var message = new AdminNotificationMessage(
            "support.message.received",
            1,
            payload,
            "support",
            AdminNotificationPriorities.Normal,
            ["Admin"],
            "support_chat",
            "message:42",
            "/support/42");
        await service.PublishAsync(message, CancellationToken.None);
        await service.PublishAsync(message, CancellationToken.None);

        var adminPage = await service.ListAsync(
            Guid.NewGuid(),
            ["Admin"],
            new AdminNotificationsQuery(null, null, null, null, null),
            CancellationToken.None);
        var moderatorPage = await service.ListAsync(
            Guid.NewGuid(),
            ["Moderator"],
            new AdminNotificationsQuery(null, null, null, null, null),
            CancellationToken.None);

        Assert.True(adminPage.IsSuccess);
        Assert.Single(adminPage.Value.Items);
        Assert.Equal(1, adminPage.Value.UnreadCount);
        Assert.Empty(moderatorPage.Value.Items);
        Assert.Single(dbContext.AdminNotificationEvents);
    }

    [Fact]
    public async Task ReadAll_ShouldRespectCutoffAndKeepReceiptsPersonal()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminNotificationService(dbContext);
        var firstAt = DateTime.UtcNow.AddMinutes(-2);
        await service.PublishAsync(CreateMessage("first", firstAt), CancellationToken.None);
        var cutoff = DateTime.UtcNow.AddMinutes(-1);
        await service.PublishAsync(CreateMessage("second", DateTime.UtcNow), CancellationToken.None);
        var firstUser = Guid.NewGuid();
        var secondUser = Guid.NewGuid();

        var result = await service.MarkAllReadAsync(
            firstUser,
            ["Admin"],
            cutoff,
            CancellationToken.None);
        var firstUserPage = await service.ListAsync(
            firstUser,
            ["Admin"],
            new AdminNotificationsQuery(null, null, null, null, null),
            CancellationToken.None);
        var secondUserPage = await service.ListAsync(
            secondUser,
            ["Admin"],
            new AdminNotificationsQuery(null, null, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value);
        Assert.Equal(1, firstUserPage.Value.UnreadCount);
        Assert.Equal(2, secondUserPage.Value.UnreadCount);
    }

    [Fact]
    public async Task Acknowledge_ShouldBeIdempotentForSameReplayAndConflictForAnotherOperator()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminNotificationService(dbContext);
        await service.PublishAsync(
            CreateMessage("critical", DateTime.UtcNow, AdminNotificationPriorities.Critical),
            CancellationToken.None);
        var notificationId = dbContext.AdminNotificationEvents.Single().Id;
        var firstOperator = Guid.NewGuid();
        var secondOperator = Guid.NewGuid();

        var accepted = await service.AcknowledgeAsync(
            notificationId,
            firstOperator,
            ["Admin"],
            "Provider capacity restored and verified.",
            1,
            CancellationToken.None);
        var replay = await service.AcknowledgeAsync(
            notificationId,
            firstOperator,
            ["Admin"],
            "Provider capacity restored and verified.",
            1,
            CancellationToken.None);
        var conflict = await service.AcknowledgeAsync(
            notificationId,
            secondOperator,
            ["Admin"],
            "A different acknowledgement.",
            1,
            CancellationToken.None);

        Assert.Equal(AdminNotificationAcknowledgeStatus.Acknowledged, accepted.Status);
        Assert.Equal(AdminNotificationAcknowledgeStatus.IdempotentReplay, replay.Status);
        Assert.Equal(AdminNotificationAcknowledgeStatus.Conflict, conflict.Status);
        Assert.Equal(2, conflict.Notification?.Version);
        Assert.Single(dbContext.AuditEvents);
    }

    [Fact]
    public async Task Publish_ShouldRejectSensitivePayloadKeysAndUnsafeHref()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminNotificationService(dbContext);

        var sensitive = CreateMessage(
            "sensitive",
            DateTime.UtcNow,
            payload: JsonSerializer.SerializeToElement(new { providerToken = "do-not-store" }));
        var unsafeHref = CreateMessage("unsafe-href", DateTime.UtcNow) with
        {
            Href = "//external.example/path",
        };

        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.PublishAsync(sensitive, CancellationToken.None));
        await Assert.ThrowsAsync<ArgumentException>(() =>
            service.PublishAsync(unsafeHref, CancellationToken.None));
    }

    [Fact]
    public async Task Cursor_ShouldRemainStableWhenNewerEventIsInserted()
    {
        await using var dbContext = CreateDbContext();
        var service = new IdentityAdminNotificationService(dbContext);
        var now = DateTime.UtcNow;
        await service.PublishAsync(CreateMessage("old", now.AddMinutes(-2)), CancellationToken.None);
        await service.PublishAsync(CreateMessage("middle", now.AddMinutes(-1)), CancellationToken.None);

        var firstPage = await service.ListAsync(
            Guid.NewGuid(),
            ["Admin"],
            new AdminNotificationsQuery(null, 1, null, null, null),
            CancellationToken.None);
        await service.PublishAsync(CreateMessage("new", now), CancellationToken.None);
        var secondPage = await service.ListAsync(
            Guid.NewGuid(),
            ["Admin"],
            new AdminNotificationsQuery(firstPage.Value.NextCursor, 1, null, null, null),
            CancellationToken.None);

        Assert.Equal("middle", firstPage.Value.Items.Single().Payload.GetProperty("key").GetString());
        Assert.Equal("old", secondPage.Value.Items.Single().Payload.GetProperty("key").GetString());
    }

    private static AdminNotificationMessage CreateMessage(
        string key,
        DateTime occurredAtUtc,
        string priority = AdminNotificationPriorities.Normal,
        JsonElement? payload = null) => new(
            "system.operator_action_required",
            1,
            payload ?? JsonSerializer.SerializeToElement(new { key }),
            "system",
            priority,
            ["Admin", "Moderator"],
            "identity_tests",
            key,
            "/dashboard",
            OccurredAtUtc: occurredAtUtc);

    private static IdentityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase($"identity-admin-notifications-{Guid.NewGuid():N}")
            .Options;
        return new IdentityDbContext(options);
    }
}
