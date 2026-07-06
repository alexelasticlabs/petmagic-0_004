namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatRealtimePrivacyTests
{
    [Fact]
    public void RealtimeNotifier_ShouldSendAudienceSpecificPayloads()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Realtime",
            "SignalRSupportChatRealtimeNotifier.cs"));

        var adminPayload = SliceBetween(source, "var adminPayload = new", "};", "adminPayload");
        var userPayload = SliceBetween(source, "var userPayload = new", "};", "userPayload");

        Assert.Contains("initiatorUserId = notification.InitiatorUserId", adminPayload, StringComparison.Ordinal);
        Assert.Contains("adminUnreadCount = notification.AdminUnreadCount", adminPayload, StringComparison.Ordinal);
        Assert.DoesNotContain("lastMessagePreview", adminPayload, StringComparison.Ordinal);
        Assert.DoesNotContain("userUnreadCount", adminPayload, StringComparison.Ordinal);

        Assert.Contains("userUnreadCount = notification.UserUnreadCount", userPayload, StringComparison.Ordinal);
        Assert.DoesNotContain("lastMessagePreview", userPayload, StringComparison.Ordinal);
        Assert.DoesNotContain("initiatorUserId", userPayload, StringComparison.Ordinal);
        Assert.DoesNotContain("adminUnreadCount", userPayload, StringComparison.Ordinal);
        Assert.Contains(".SendAsync(SupportChatHub.ConversationUpdatedEvent, adminPayload, cancellationToken)", source, StringComparison.Ordinal);
        Assert.Contains(".SendAsync(SupportChatHub.ConversationUpdatedEvent, userPayload, cancellationToken)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void RealtimeContract_ShouldNotCarryRawSupportMessagePreview()
    {
        var root = FindRepositoryRoot();
        var contractsSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Application",
            "Abstractions",
            "ISupportChatService.cs"));
        var fanOutSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatService.RealtimeNotifications.cs"));
        var notifierSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Realtime",
            "SignalRSupportChatRealtimeNotifier.cs"));

        var realtimeContract = SliceBetween(
            contractsSource,
            "public sealed record SupportConversationRealtimeEvent(",
            ");",
            "SupportConversationRealtimeEvent");
        Assert.DoesNotContain("LastMessagePreview", realtimeContract, StringComparison.Ordinal);
        Assert.DoesNotContain("x.LastMessagePreview", fanOutSource, StringComparison.Ordinal);
        Assert.DoesNotContain("lastMessagePreview", notifierSource, StringComparison.Ordinal);
    }

    [Fact]
    public void PushNotifications_ShouldNotSendRawSupportMessageText()
    {
        var root = FindRepositoryRoot();
        var contractsSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Application",
            "Abstractions",
            "ISupportChatService.cs"));
        var fanOutSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatService.RealtimeNotifications.cs"));
        var senderSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "FcmSupportChatPushNotificationSender.cs"));

        var notificationContract = SliceBetween(
            contractsSource,
            "public sealed record SupportChatPushNotification(",
            ");",
            "SupportChatPushNotification");
        Assert.DoesNotContain("Body", notificationContract, StringComparison.Ordinal);
        Assert.DoesNotContain("SenderDisplayName", notificationContract, StringComparison.Ordinal);

        var notifyUserBody = SliceBetween(
            fanOutSource,
            "private async Task NotifyUserMessageAsync(",
            "    }",
            "NotifyUserMessageAsync");
        Assert.DoesNotContain("message.Body", notifyUserBody, StringComparison.Ordinal);
        Assert.DoesNotContain("message.SenderDisplayName", notifyUserBody, StringComparison.Ordinal);

        var buildBody = SliceBetween(
            senderSource,
            "private static string BuildBody(",
            "    }",
            "BuildBody");
        Assert.Contains("SupportChatPushNotificationLocalizer.BuildFallbackBody", buildBody, StringComparison.Ordinal);
        Assert.DoesNotContain(".Body", buildBody, StringComparison.Ordinal);
    }

    [Fact]
    public void NotificationFanOutLogs_ShouldHashStableIdentifiers()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatService.RealtimeNotifications.cs"));

        Assert.Contains("ConversationIdHash={ConversationIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("InitiatorUserIdHash={InitiatorUserIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("MessageIdHash={MessageIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(conversation.Id.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(conversation.InitiatorUserId.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(message.MessageId.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ConversationId={ConversationId}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("InitiatorUserId={InitiatorUserId}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("MessageId={MessageId}", source, StringComparison.Ordinal);
    }

    private static string SliceBetween(string source, string start, string end, string label)
    {
        var startIndex = source.IndexOf(start, StringComparison.Ordinal);
        Assert.True(startIndex >= 0, $"{label} start marker was not found.");

        var endIndex = source.IndexOf(end, startIndex, StringComparison.Ordinal);
        Assert.True(endIndex > startIndex, $"{label} end marker was not found.");

        return source[startIndex..endIndex];
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
