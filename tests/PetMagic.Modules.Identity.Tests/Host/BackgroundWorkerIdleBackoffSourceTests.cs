namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class BackgroundWorkerIdleBackoffSourceTests
{
    private static readonly string[] WorkerPaths =
    [
        "src/Modules/Identity/PetMagic.Modules.Identity.Infrastructure/EmailDispatchWorker.cs",
        "src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/EconomyPushOutboxWorker.cs",
        "src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/SupportChatPushOutboxWorker.cs",
        "src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplatePushOutboxWorker.cs",
        "src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateAdminAuditOutboxWorker.cs",
        "src/Modules/Gamification/PetMagic.Modules.Gamification.Infrastructure/GamificationAdminAuditOutboxWorker.cs"
    ];

    [Fact]
    public void DatabasePollingWorkers_ShouldBackOffOutsideScopeAndResetAfterWork()
    {
        var repositoryRoot = FindRepositoryRoot();

        foreach (var workerPath in WorkerPaths)
        {
            var source = File.ReadAllText(Path.Combine(repositoryRoot, workerPath))
                .Replace("\r\n", "\n", StringComparison.Ordinal);

            Assert.Contains("var idleBackoff = new AdaptiveIdlePollBackoff", source, StringComparison.Ordinal);
            Assert.Equal(2, CountOccurrences(source, "idleBackoff.Reset();"));
            Assert.Contains("await idleBackoff.DelayAsync(stoppingToken);", source, StringComparison.Ordinal);

            var scopeStart = source.IndexOf("using (var scope = scopeFactory.Create", StringComparison.Ordinal);
            Assert.True(scopeStart >= 0, $"{workerPath} must create an explicit processing scope.");

            var scopeOpeningBrace = source.IndexOf('{', scopeStart);
            Assert.True(scopeOpeningBrace > scopeStart, $"{workerPath} processing scope must use a block.");

            var scopeClosingBrace = FindMatchingClosingBrace(source, scopeOpeningBrace);
            Assert.True(scopeClosingBrace > scopeOpeningBrace, $"{workerPath} processing scope block is incomplete.");

            var processedBranch = source.IndexOf("if (processed)", scopeClosingBrace, StringComparison.Ordinal);
            Assert.True(processedBranch > scopeClosingBrace, $"{workerPath} must dispose its scope before idle handling.");

            var idleDelay = source.IndexOf(
                "await idleBackoff.DelayAsync(stoppingToken);",
                processedBranch,
                StringComparison.Ordinal);

            Assert.True(idleDelay > processedBranch, $"{workerPath} idle delay must run after scope disposal.");
        }

        var emailWorker = File.ReadAllText(Path.Combine(repositoryRoot, WorkerPaths[0]));
        Assert.Contains("options.DispatchPollIntervalMilliseconds", emailWorker, StringComparison.Ordinal);
        Assert.Contains("initialIdleDelay > TimeSpan.FromSeconds(5)", emailWorker, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string source, string value) =>
        source.Split(value, StringSplitOptions.None).Length - 1;

    private static int FindMatchingClosingBrace(string source, int openingBrace)
    {
        if (openingBrace < 0)
        {
            return -1;
        }

        var depth = 0;
        for (var index = openingBrace; index < source.Length; index++)
        {
            if (source[index] == '{')
            {
                depth++;
            }
            else if (source[index] == '}' && --depth == 0)
            {
                return index;
            }
        }

        return -1;
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "src"))
                && Directory.Exists(Path.Combine(directory.FullName, "tests")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Repository root was not found.");
    }
}
