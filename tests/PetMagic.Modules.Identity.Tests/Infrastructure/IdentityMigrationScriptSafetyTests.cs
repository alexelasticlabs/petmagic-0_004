namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class IdentityMigrationScriptSafetyTests
{
    [Fact]
    public void AdminAuditMigration_ShouldTerminateBackfillBeforeAlterColumn()
    {
        var source = ReadIdentityMigration("20260606120000_AddAdminAuditContext.cs");

        Assert.Contains("WHERE \"CreatedAtUtc\" IS NULL;", source, StringComparison.Ordinal);
    }

    [Fact]
    public void CompatibilityMigration_ShouldRemainSafeInsideIdempotentEfWrapper()
    {
        var source = ReadIdentityMigration("20260609071042_AddIdentityModelCompatibility.cs");

        Assert.Contains("ADD COLUMN IF NOT EXISTS \"LastLoginAtUtc\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("DO $$", source, StringComparison.Ordinal);
    }

    private static string ReadIdentityMigration(string fileName)
    {
        var repositoryRoot = FindRepositoryRoot();
        var path = Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "Data",
            "Migrations",
            fileName);

        return File.ReadAllText(path);
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
