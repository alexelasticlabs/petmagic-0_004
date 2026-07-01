namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatConversationOpenHardeningTests
{
    [Fact]
    public void OpenConversationEndpoint_ShouldForwardRelatedContextIdentifiers()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Endpoints",
            "SupportChatEndpoints.UserConversationAccess.cs"));

        Assert.Contains("request?.RelatedGenerationId", source, StringComparison.Ordinal);
        Assert.Contains("request?.RelatedPaymentId", source, StringComparison.Ordinal);
        Assert.Contains("request?.RelatedSubscriptionId", source, StringComparison.Ordinal);
        Assert.DoesNotContain("RelatedGenerationId: null", source, StringComparison.Ordinal);
        Assert.DoesNotContain("RelatedPaymentId: null", source, StringComparison.Ordinal);
        Assert.DoesNotContain("RelatedSubscriptionId: null", source, StringComparison.Ordinal);
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
