namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class GenerationWorkerGamificationWiringTests
{
    [Fact]
    public void GenerationWorker_ShouldRegisterGamificationAndGateItsSchema()
    {
        var root = FindRepositoryRoot();
        var workerDirectory = Path.Combine(root, "src", "Host", "PetMagic.Host.GenerationWorker");
        var program = File.ReadAllText(Path.Combine(workerDirectory, "Program.cs"));
        var project = File.ReadAllText(Path.Combine(workerDirectory, "PetMagic.Host.GenerationWorker.csproj"));
        var schemaGate = File.ReadAllText(Path.Combine(workerDirectory, "GenerationWorkerSchemaGate.cs"));

        Assert.Contains(
            ".AddGamificationInfrastructure(builder.Configuration, includeAdminServices: false)",
            program,
            StringComparison.Ordinal);
        Assert.Contains("PetMagic.Modules.Gamification.Infrastructure.csproj", project, StringComparison.Ordinal);
        Assert.Contains("GetRequiredService<GamificationDbContext>()", schemaGate, StringComparison.Ordinal);
        Assert.Contains("gamification.Database.GetPendingMigrationsAsync", schemaGate, StringComparison.Ordinal);
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
