namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatAdminContextHardeningTests
{
    [Fact]
    public void AdminTicketContext_ShouldUseEconomyAndTemplateServices_InsteadOfHardcodedPlaceholders()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatService.AdminConversationContext.cs"));

        Assert.Contains("economyService?.GetSubscriptionSummaryAsync", source, StringComparison.Ordinal);
        Assert.Contains("adminUserEconomyAnalyticsReader?.GetAdminUserEconomyAnalyticsAsync", source, StringComparison.Ordinal);
        Assert.Contains("adminUserTemplateAnalyticsReader?.GetAdminUserTemplateAnalyticsAsync", source, StringComparison.Ordinal);
        Assert.Contains("templateGenerationService.GetAdminAsync", source, StringComparison.Ordinal);
        Assert.Contains("NormalizeSubscriptionPlanName", source, StringComparison.Ordinal);
        Assert.Contains("NormalizeSubscriptionStatus", source, StringComparison.Ordinal);
        Assert.DoesNotContain("TokenBalance: 0,", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Plan: \"Free\",", source, StringComparison.Ordinal);
        Assert.DoesNotContain("PremiumStatus: \"Inactive\",", source, StringComparison.Ordinal);
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
