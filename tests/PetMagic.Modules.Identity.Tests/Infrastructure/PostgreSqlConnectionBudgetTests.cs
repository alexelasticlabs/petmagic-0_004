using System.Text.Json;
using System.Text.RegularExpressions;

using Npgsql;

using PetMagic.BuildingBlocks.Data;

namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class PostgreSqlConnectionBudgetTests
{
    [Fact]
    public async Task DefaultApiAndWorkerBudgets_ShouldRemainBelowAcceptanceLimit()
    {
        var apiBudget = new PostgreSqlConnectionBudget(
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections);
        var workerBudget = new PostgreSqlConnectionBudget(
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections);

        Assert.Equal(68, apiBudget.PlannedAggregateConnections);
        Assert.Equal(apiBudget.PlannedAggregateConnections, workerBudget.PlannedAggregateConnections);
        Assert.True(
            apiBudget.PlannedAggregateConnections
                < PostgreSqlConnectionBudget.AcceptanceConnectionLimitExclusive);

        await using var dataSource = apiBudget.CreateDataSource(
            "Host=localhost;Database=petmagic;Username=postgres;Password=unused;Maximum Pool Size=60",
            "PetMagic.Host.Api.Tests");
        var appliedConnectionString = new NpgsqlConnectionStringBuilder(dataSource.ConnectionString);
        Assert.True(appliedConnectionString.Pooling);
        Assert.Equal(0, appliedConnectionString.MinPoolSize);
        Assert.Equal(PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize, appliedConnectionString.MaxPoolSize);
        Assert.Equal("PetMagic.Host.Api.Tests", appliedConnectionString.ApplicationName);
    }

    [Fact]
    public async Task RenderPostgreSqlUri_ShouldBeConvertedAndBudgeted()
    {
        var budget = new PostgreSqlConnectionBudget(
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections);

        await using var dataSource = budget.CreateDataSource(
            "postgresql://render%40user:p%40ss%3Aword%2Fwith%3Fchars@internal-host:5439/petmagic%2Ddb"
                + "?sslmode=require&connect_timeout=17&application_name=ignored",
            "PetMagic.Host.Api.RenderTests");
        var appliedConnectionString = new NpgsqlConnectionStringBuilder(dataSource.ConnectionString);

        Assert.Equal("internal-host", appliedConnectionString.Host);
        Assert.Equal(5439, appliedConnectionString.Port);
        Assert.Equal("petmagic-db", appliedConnectionString.Database);
        Assert.Equal("render@user", appliedConnectionString.Username);
        Assert.Null(appliedConnectionString.Password);
        Assert.Equal(SslMode.Require, appliedConnectionString.SslMode);
        Assert.Equal(17, appliedConnectionString.Timeout);
        Assert.Equal(PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize, appliedConnectionString.MaxPoolSize);
        Assert.Equal("PetMagic.Host.Api.RenderTests", appliedConnectionString.ApplicationName);
    }

    [Fact]
    public async Task PostgreSqlUriWithoutExplicitPort_ShouldUsePostgreSqlDefault()
    {
        var budget = new PostgreSqlConnectionBudget(
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections);

        await using var dataSource = budget.CreateDataSource(
            "postgres://worker:password@internal-host/petmagic",
            "PetMagic.Host.GenerationWorker.RenderTests");
        var appliedConnectionString = new NpgsqlConnectionStringBuilder(dataSource.ConnectionString);

        Assert.Equal(5432, appliedConnectionString.Port);
        Assert.Equal("internal-host", appliedConnectionString.Host);
        Assert.Equal("petmagic", appliedConnectionString.Database);
    }

    [Fact]
    public void UnsupportedUriQueryParameter_ShouldBeRejectedWithoutLeakingItsValue()
    {
        var budget = new PostgreSqlConnectionBudget(
            PostgreSqlConnectionBudget.ApiDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.GenerationWorkerDefaultMaxPoolSize,
            PostgreSqlConnectionBudget.DefaultOperationalReserveConnections);

        var exception = Assert.Throws<ArgumentException>(() => budget.CreateDataSource(
            "postgresql://user:password@internal-host/petmagic?unsupported=do-not-log-this",
            "PetMagic.Host.Api.RenderTests"));

        Assert.Contains("query parameter 'unsupported' is not supported", exception.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("do-not-log-this", exception.ToString(), StringComparison.Ordinal);
    }

    [Fact]
    public void AggregateAtAcceptanceLimit_ShouldBeRejectedBeforeCreatingPools()
    {
        var budget = new PostgreSqlConnectionBudget(
            HostMaxPoolSize: 30,
            PeerMaxPoolSize: 24,
            OperationalReserveConnections: 16);

        var exception = Assert.Throws<InvalidOperationException>(() => budget.Validate("test-host"));
        Assert.Contains("must remain below 70", exception.Message, StringComparison.Ordinal);
        Assert.Contains("Configured aggregate is 70", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void HostConfigurationAndEveryPooledDbContext_ShouldUseOneSharedDataSource()
    {
        var repositoryRoot = FindRepositoryRoot();
        foreach (var relativePath in new[]
        {
            Path.Combine("src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "EconomyInfrastructureServiceCollectionExtensions.cs"),
            Path.Combine("src", "Modules", "Gamification", "PetMagic.Modules.Gamification.Infrastructure", "GamificationInfrastructureServiceCollectionExtensions.cs"),
            Path.Combine("src", "Modules", "Identity", "PetMagic.Modules.Identity.Infrastructure", "IdentityInfrastructureServiceCollectionExtensions.cs"),
            Path.Combine("src", "Modules", "SupportChat", "PetMagic.Modules.SupportChat.Infrastructure", "SupportChatInfrastructureServiceCollectionExtensions.cs"),
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplatesInfrastructureServiceCollectionExtensions.cs")
        })
        {
            var source = File.ReadAllText(Path.Combine(repositoryRoot, relativePath));
            var pooledContextRegistrations = Regex.Matches(
                source,
                "AddDbContextPool<",
                RegexOptions.CultureInvariant).Count;
            Assert.True(pooledContextRegistrations > 0, relativePath);
            Assert.Equal(
                pooledContextRegistrations,
                Regex.Matches(
                    source,
                    "GetService<NpgsqlDataSource>\\(\\)",
                    RegexOptions.CultureInvariant).Count);
            Assert.Equal(
                pooledContextRegistrations,
                Regex.Matches(
                    source,
                    "UseNpgsql\\(sharedDataSource\\)",
                    RegexOptions.CultureInvariant).Count);
        }

        foreach (var relativePath in new[]
        {
            Path.Combine("src", "Host", "PetMagic.Host.Api", "Program.cs"),
            Path.Combine("src", "Host", "PetMagic.Host.GenerationWorker", "Program.cs")
        })
        {
            var source = File.ReadAllText(Path.Combine(repositoryRoot, relativePath));
            Assert.Contains("CreateDataSource(", source, StringComparison.Ordinal);
            Assert.Contains("AddSingleton(_ => sharedPostgreSqlDataSource)", source, StringComparison.Ordinal);
        }

        var apiProgram = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Program.cs"));
        Assert.Contains(
            "StartupMigrationLock.RunWithMigrationLockAsync(\n        sharedPostgreSqlDataSource",
            apiProgram.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);

        var economyReconciliation = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Reconciliation.cs"));
        Assert.Contains("_postgreSqlDataSource.OpenConnectionAsync", economyReconciliation, StringComparison.Ordinal);
    }

    [Fact]
    public void HostAppSettings_ShouldDeclareReciprocalConnectionBudgets()
    {
        var repositoryRoot = FindRepositoryRoot();
        var api = ReadDatabaseSettings(Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "appsettings.json"));
        var worker = ReadDatabaseSettings(Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
            "appsettings.json"));

        Assert.Equal(28, api.MaxPoolSize);
        Assert.Equal(24, worker.MaxPoolSize);
        Assert.Equal(worker.MaxPoolSize, api.PeerMaxPoolSize);
        Assert.Equal(api.MaxPoolSize, worker.PeerMaxPoolSize);
        Assert.Equal(16, api.OperationalReserveConnections);
        Assert.Equal(api.OperationalReserveConnections, worker.OperationalReserveConnections);
        Assert.True(api.MaxPoolSize + worker.MaxPoolSize + api.OperationalReserveConnections < 70);
    }

    private static (int MaxPoolSize, int PeerMaxPoolSize, int OperationalReserveConnections)
        ReadDatabaseSettings(string path)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var database = document.RootElement.GetProperty("Database");
        return (
            database.GetProperty("MaxPoolSize").GetInt32(),
            database.GetProperty("PeerMaxPoolSize").GetInt32(),
            database.GetProperty("OperationalReserveConnections").GetInt32());
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Repository root with PetMagic.slnx was not found.");
    }
}
