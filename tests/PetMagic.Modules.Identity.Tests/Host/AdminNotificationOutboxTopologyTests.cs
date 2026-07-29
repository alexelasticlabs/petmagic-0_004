namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class AdminNotificationOutboxTopologyTests
{
    [Theory]
    [InlineData("SupportChat", "SupportChatPushOutboxProcessor.cs")]
    [InlineData("Templates", "TemplateAdminAuditOutboxProcessor.cs")]
    [InlineData("Economy", "EconomyPushOutboxProcessor.cs")]
    public void ModuleOutboxProcessors_ShouldDeliverTheSharedAdminNotificationKind(
        string module,
        string processorFile)
    {
        var source = ReadRepositoryFile(
            "src", "Modules", module, $"PetMagic.Modules.{module}.Infrastructure", processorFile);

        Assert.Contains("AdminNotificationOutbox.Kind", source, StringComparison.Ordinal);
        Assert.Contains("IAdminNotificationSink", source, StringComparison.Ordinal);
        Assert.Contains("AdminNotificationOutbox.Deserialize", source, StringComparison.Ordinal);
        Assert.Contains("PublishAsync", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ActionableProducers_ShouldUseStableDedupeKeysAndNeutralPayloads()
    {
        var support = ReadRepositoryFile(
            "src", "Modules", "SupportChat", "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatPushNotificationOutbox.cs");
        var templates = ReadRepositoryFile(
            "src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure",
            "TemplateAdminNotificationOutbox.cs");
        var economy = ReadRepositoryFile(
            "src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Reconciliation.cs");

        Assert.Contains("support.message.received", support, StringComparison.Ordinal);
        Assert.Contains("generation.failed", templates, StringComparison.Ordinal);
        Assert.Contains("generation.refund_exhausted", templates, StringComparison.Ordinal);
        Assert.Contains("economy.incident.detected", economy, StringComparison.Ordinal);
        Assert.Contains("DeduplicationKey", support, StringComparison.Ordinal);
        Assert.Contains("DeduplicationKey", templates, StringComparison.Ordinal);
        Assert.Contains("DeduplicationKey", economy, StringComparison.Ordinal);
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
            if (File.Exists(Path.Combine(current.FullName, ".gitignore"))) return current.FullName;
            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
