using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityAdminAuditLogTests
{
    [Fact]
    public async Task WriteAsync_ShouldSanitizeDurableAuditValues()
    {
        await using var dbContext = CreateDbContext();
        var httpContext = new DefaultHttpContext();
        httpContext.Request.Headers.UserAgent = "PetMagicAdmin token=user-agent-secret api_secret=ua-secret";
        var accessor = new HttpContextAccessor
        {
            HttpContext = httpContext
        };
        var auditLog = new IdentityAdminAuditLog(dbContext, accessor);

        await auditLog.WriteAsync(
            new AdminAuditEntry(
                "admin.test.action",
                "purchase_order",
                "target token=target-secret api_secret=target-api-secret",
                "old token=old-secret",
                "new api_secret=new-secret",
                "details purchaseToken=gp-token-secret signedPayload=app-store-secret",
                Guid.NewGuid()),
            CancellationToken.None);

        var auditEvent = await dbContext.AuditEvents.SingleAsync();
        Assert.DoesNotContain("target-secret", auditEvent.TargetId);
        Assert.DoesNotContain("target-api-secret", auditEvent.TargetId);
        Assert.DoesNotContain("old-secret", auditEvent.OldValue);
        Assert.DoesNotContain("new-secret", auditEvent.NewValue);
        Assert.DoesNotContain("gp-token-secret", auditEvent.Details);
        Assert.DoesNotContain("app-store-secret", auditEvent.Details);
        Assert.DoesNotContain("user-agent-secret", auditEvent.UserAgent);
        Assert.DoesNotContain("ua-secret", auditEvent.UserAgent);
    }

    [Fact]
    public async Task WriteAsync_WithEventId_ShouldBeIdempotentAcrossImmediateAndRetriedDelivery()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new IdentityAdminAuditLog(
            dbContext,
            new HttpContextAccessor { HttpContext = new DefaultHttpContext() });
        var eventId = Guid.NewGuid();
        var actorUserId = Guid.NewGuid();
        var entry = new AdminAuditEntry(
            "admin.support.ticket.assigned",
            "SupportConversation",
            Guid.NewGuid().ToString("D"),
            NewValue: actorUserId.ToString("D"),
            SubjectUserId: Guid.NewGuid(),
            EventId: eventId,
            ActorUserId: actorUserId,
            CorrelationId: "support-assignment-test");

        await auditLog.WriteAsync(entry, CancellationToken.None);
        await auditLog.WriteAsync(entry, CancellationToken.None);

        var persisted = await dbContext.AuditEvents.SingleAsync();
        Assert.Equal(eventId, persisted.Id);
        Assert.Equal(actorUserId, persisted.ActorUserId);
        Assert.Equal("support-assignment-test", persisted.CorrelationId);
    }

    private static IdentityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase($"identity-admin-audit-tests-{Guid.NewGuid():N}")
            .Options;

        return new IdentityDbContext(options);
    }
}
