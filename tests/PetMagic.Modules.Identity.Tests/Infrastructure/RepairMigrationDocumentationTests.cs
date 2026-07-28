namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class RepairMigrationDocumentationTests
{
    [Fact]
    public void IrreversibleRepairAndNormalizationMigrations_ShouldExplainWhyDownIsEmpty()
    {
        var repositoryRoot = FindRepositoryRoot();
        var migrationFiles = new[]
        {
            Path.Combine(repositoryRoot, "src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Data", "Migrations", "20260629141713_NormalizeLegacyCurrencyPackStoreSkus.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Data", "Migrations", "20260629135142_NormalizeLegacyStripeProviderDisclosures.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Data", "Migrations", "20260629134311_NormalizeLegacyRedeemCodeWindows.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "SupportChat", "PetMagic.Modules.SupportChat.Infrastructure", "Data", "Migrations", "20260629132451_NormalizeLegacyConversationEnums.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "SupportChat", "PetMagic.Modules.SupportChat.Infrastructure", "Data", "Migrations", "20260629133404_RepairSupportChatSchemaDrift.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "Data", "Migrations", "20260629133929_RepairTemplatesSchemaDrift.cs"),
            Path.Combine(repositoryRoot, "src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "Data", "Migrations", "20260728170000_RepairGenerationAlertAcknowledgementActivation.cs"),
        };

        foreach (var path in migrationFiles)
        {
            var source = File.ReadAllText(path);
            Assert.Contains("Intentionally irreversible:", source, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void GenerationAlertAcknowledgementRepair_ShouldBeIdempotentAndBackfillBeforeNotNull()
    {
        var repositoryRoot = FindRepositoryRoot();
        var path = Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations",
            "20260728170000_RepairGenerationAlertAcknowledgementActivation.cs");

        var source = File.ReadAllText(path);

        Assert.Contains("ADD COLUMN IF NOT EXISTS", source, StringComparison.Ordinal);
        Assert.Contains("SET \"AlertActivatedAtUtc\" = alert.\"ActivatedAtUtc\"", source, StringComparison.Ordinal);
        Assert.Contains("SET \"AlertActivatedAtUtc\" = \"AcknowledgedAtUtc\"", source, StringComparison.Ordinal);
        Assert.Contains("ALTER COLUMN \"AlertActivatedAtUtc\" SET NOT NULL", source, StringComparison.Ordinal);
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
