namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminNotificationEndpointContractTests
{
    [Fact]
    public void Endpoints_ShouldExposeProtectedInboxContractAndPrivateHeaders()
    {
        var source = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Api", "Endpoints",
            "AdminNotificationEndpoints.cs");

        Assert.Contains("endpoints.MapGroup(\"/api/admin/notifications\")", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"\", ListAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"/{notificationId:guid}/read\", MarkReadAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"/read-all\", MarkAllReadAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"/{notificationId:guid}/archive\", ArchiveAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"/{notificationId:guid}/acknowledge\", AcknowledgeAsync);", source, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"ModeratorOrAdmin\")", source, StringComparison.Ordinal);
        Assert.Contains(".RequireRateLimiting(\"admin\")", source, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status428PreconditionRequired", source, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
    }

    [Fact]
    public void RealtimeHub_ShouldBeAuthorizedAndOnlySendInvalidation()
    {
        var module = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Api", "IdentityApiModule.cs");
        var hub = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Api", "Realtime",
            "AdminNotificationsHub.cs");
        var notifier = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Api", "Realtime",
            "SignalRAdminNotificationRealtimeNotifier.cs");

        Assert.Contains("app.MapHub<AdminNotificationsHub>(AdminNotificationsHub.RoutePattern)", module, StringComparison.Ordinal);
        Assert.Contains("public const string RoutePattern = \"/hubs/admin-notifications\";", hub, StringComparison.Ordinal);
        Assert.Contains("[Authorize(Policy = \"ModeratorOrAdmin\")]", hub, StringComparison.Ordinal);
        Assert.Contains("AdminNotificationsHub.NotificationsChangedEvent", notifier, StringComparison.Ordinal);
        Assert.DoesNotContain("PayloadJson", notifier, StringComparison.Ordinal);
    }

    [Fact]
    public void Inbox_ShouldUseNeutralPayloadsAndPersonalReceipts()
    {
        var context = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Infrastructure", "Data",
            "IdentityDbContext.cs");
        var service = ReadRepositoryFile(
            "src", "Modules", "Identity", "PetMagic.Modules.Identity.Infrastructure",
            "IdentityAdminNotificationService.cs");

        Assert.Contains("\"admin_notification_events\",", context, StringComparison.Ordinal);
        Assert.Contains("entity.ToTable(\"admin_notification_receipts\")", context, StringComparison.Ordinal);
        Assert.Contains("entity.HasKey(x => new { x.EventId, x.UserId })", context, StringComparison.Ordinal);
        Assert.Contains("ForbiddenPayloadKeyFragments", service, StringComparison.Ordinal);
        Assert.Contains("AllowedHrefPrefixes", service, StringComparison.Ordinal);
        Assert.Contains("catch (DbUpdateConcurrencyException)", service, StringComparison.Ordinal);
        Assert.Contains("Action = \"admin.notification.acknowledged\"", service, StringComparison.Ordinal);
    }

    private static string ReadRepositoryFile(params string[] pathSegments)
    {
        return File.ReadAllText(Path.Combine([FindRepositoryRoot(), .. pathSegments]));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
