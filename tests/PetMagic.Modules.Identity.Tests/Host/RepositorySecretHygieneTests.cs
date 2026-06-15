using System.Text.RegularExpressions;
using System.Text.Json;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RepositorySecretHygieneTests
{
    private static readonly Regex FirebaseApiKeyPattern = new(
        @"AIza[0-9A-Za-z_-]{20,}",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly Regex GoogleOauthClientIdPattern = new(
        @"\b\d{6,}-[a-z0-9]+\.apps\.googleusercontent\.com\b",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly Regex ReverseGoogleOauthClientIdPattern = new(
        @"\bcom\.googleusercontent\.apps\.\d{6,}-[a-z0-9]+\b",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly Regex ServerSecretValuePattern = new(
        @"\b(?:sk|rk)_(?:live|test)_[0-9A-Za-z]{8,}\b|\bwhsec_[0-9A-Za-z]{8,}\b|-----BEGIN (?:RSA |EC |)PRIVATE KEY-----",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly string[] ServerOnlyConfigurationKeys =
    [
        "STRIPE_SECRET_KEY",
        "STRIPE_WEBHOOK_SECRET",
        "STRIPE_TEST_SECRET_KEY",
        "STRIPE_LIVE_SECRET_KEY",
        "STRIPE_TEST_WEBHOOK_SECRET",
        "STRIPE_LIVE_WEBHOOK_SECRET",
        "FAL_AI_API_KEY",
        "R2_SECRET_KEY",
        "R2_ACCESS_KEY_ID",
        "GOOGLE_CLIENT_SECRET",
        "APPLE_CLIENT_SECRET",
        "JWT_SIGNING_KEY",
        "BOOTSTRAP_ADMIN_PASSWORD",
        "GOOGLE_PLAY_PRIVATE_KEY_PEM",
        "APP_STORE_SHARED_SECRET",
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        "FIREBASE_SERVICE_ACCOUNT_JSON_PATH"
    ];

    [Fact]
    public void Repository_ShouldNotTrackDatabaseBackups()
    {
        var repositoryRoot = FindRepositoryRoot();
        var gitignore = File.ReadAllText(Path.Combine(repositoryRoot, ".gitignore"));

        Assert.Contains("backups/", gitignore);

        var backupsDirectory = Path.Combine(repositoryRoot, "backups");
        if (!Directory.Exists(backupsDirectory))
        {
            return;
        }

        var databaseBackups = Directory.GetFiles(backupsDirectory, "*.sql", SearchOption.AllDirectories);
        Assert.Empty(databaseBackups);
    }

    [Fact]
    public void EnvExample_ShouldNotDeclareDuplicateKeys()
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExamplePath = Path.Combine(repositoryRoot, ".env.example");

        var duplicateKeys = File.ReadLines(envExamplePath)
            .Select(line => line.Trim())
            .Where(line => !string.IsNullOrWhiteSpace(line) && !line.StartsWith('#'))
            .Select(line => line.StartsWith("export ", StringComparison.Ordinal)
                ? line["export ".Length..].TrimStart()
                : line)
            .Select(line => line.Split('=', 2)[0].Trim())
            .Where(key => !string.IsNullOrWhiteSpace(key))
            .GroupBy(key => key, StringComparer.Ordinal)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToArray();

        Assert.Empty(duplicateKeys);
    }

    [Fact]
    public void ClientFirebaseConfigs_ShouldContainPlaceholdersOnly()
    {
        var repositoryRoot = FindRepositoryRoot();
        var configPaths = new[]
        {
            Path.Combine(repositoryRoot, "GoogleService-Info.plist"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "Info.plist"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "GoogleService-Info.plist"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "google-services.json"),
        };

        foreach (var configPath in configPaths)
        {
            var content = File.ReadAllText(configPath);

            Assert.DoesNotMatch(FirebaseApiKeyPattern, content);
            Assert.DoesNotMatch(GoogleOauthClientIdPattern, content);
            Assert.DoesNotMatch(ReverseGoogleOauthClientIdPattern, content);
            Assert.DoesNotContain("petmagic-f036b", content, StringComparison.OrdinalIgnoreCase);
        }
    }

    [Fact]
    public void ClientEnvExamples_ShouldNotDeclareServerOnlySecrets()
    {
        var repositoryRoot = FindRepositoryRoot();
        var clientEnvExamples = Directory
            .GetFiles(Path.Combine(repositoryRoot, "apps", "admin-web"), ".env*.example", SearchOption.TopDirectoryOnly)
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.NotEmpty(clientEnvExamples);

        var forbiddenServerOnlyKeys = new[]
        {
            "STRIPE_SECRET_KEY",
            "STRIPE_WEBHOOK_SECRET",
            "FAL_AI_API_KEY",
            "R2_SECRET_KEY",
            "R2_ACCESS_KEY_ID",
            "GOOGLE_CLIENT_SECRET",
            "APPLE_CLIENT_SECRET",
            "JWT_SIGNING_KEY",
            "BOOTSTRAP_ADMIN_PASSWORD",
        };

        foreach (var envExample in clientEnvExamples)
        {
            var content = File.ReadAllText(envExample);

            foreach (var forbiddenKey in forbiddenServerOnlyKeys)
            {
                Assert.DoesNotContain($"{forbiddenKey}=", content, StringComparison.Ordinal);
                Assert.DoesNotContain($"NEXT_PUBLIC_{forbiddenKey}=", content, StringComparison.Ordinal);
            }
        }
    }

    [Fact]
    public void ClientSourceAndConfig_ShouldNotContainServerOnlySecrets()
    {
        var repositoryRoot = FindRepositoryRoot();
        var clientFiles = EnumerateClientSourceAndConfigFiles(repositoryRoot).ToArray();

        Assert.NotEmpty(clientFiles);

        foreach (var clientFile in clientFiles)
        {
            var content = File.ReadAllText(clientFile);

            foreach (var forbiddenKey in ServerOnlyConfigurationKeys)
            {
                Assert.DoesNotContain(forbiddenKey, content, StringComparison.Ordinal);
                Assert.DoesNotContain($"NEXT_PUBLIC_{forbiddenKey}", content, StringComparison.Ordinal);
            }

            Assert.DoesNotMatch(ServerSecretValuePattern, content);
            Assert.DoesNotMatch(FirebaseApiKeyPattern, content);
            Assert.DoesNotMatch(GoogleOauthClientIdPattern, content);
            Assert.DoesNotMatch(ReverseGoogleOauthClientIdPattern, content);
            Assert.DoesNotContain("petmagic-f036b", content, StringComparison.OrdinalIgnoreCase);
        }
    }

    [Fact]
    public void HostAppsettings_ShouldNotContainBootstrapAdminPassword()
    {
        var repositoryRoot = FindRepositoryRoot();
        var appsettingsFiles = Directory
            .GetFiles(Path.Combine(repositoryRoot, "src", "Host"), "appsettings*.json", SearchOption.AllDirectories)
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
                && !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.NotEmpty(appsettingsFiles);

        foreach (var appsettingsFile in appsettingsFiles)
        {
            using var document = JsonDocument.Parse(File.ReadAllText(appsettingsFile));
            if (!document.RootElement.TryGetProperty("BootstrapAdmin", out var bootstrapAdmin)
                || !bootstrapAdmin.TryGetProperty("Password", out var password))
            {
                continue;
            }

            Assert.True(
                string.IsNullOrWhiteSpace(password.GetString()),
                $"{Path.GetRelativePath(repositoryRoot, appsettingsFile)} must not contain BootstrapAdmin:Password.");
        }
    }

    [Fact]
    public void MobileLocalSecretFiles_ShouldStayIgnored()
    {
        var repositoryRoot = FindRepositoryRoot();
        var androidGitignore = File.ReadAllText(
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", ".gitignore"));
        var mobileGitignore = File.ReadAllText(
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", ".gitignore"));

        Assert.Contains("key.properties", androidGitignore, StringComparison.Ordinal);
        Assert.Contains("/build/", mobileGitignore, StringComparison.Ordinal);
    }

    [Fact]
    public void Hosts_ShouldLoadDotEnv_WhenDotnetEnvironmentIsDevelopment()
    {
        var repositoryRoot = FindRepositoryRoot();

        AssertHostUsesDotnetEnvironmentForDotEnv(
            Path.Combine(repositoryRoot, "src", "Host", "PetMagic.Host.Api", "Program.cs"));
        AssertHostUsesDotnetEnvironmentForDotEnv(
            Path.Combine(repositoryRoot, "src", "Host", "PetMagic.Host.GenerationWorker", "Program.cs"));
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

    private static IEnumerable<string> EnumerateClientSourceAndConfigFiles(string repositoryRoot)
    {
        var adminRoot = Path.Combine(repositoryRoot, "apps", "admin-web");
        foreach (var file in EnumerateFiles(Path.Combine(adminRoot, "src"), ["*.ts", "*.tsx", "*.js", "*.jsx"]))
        {
            if (IsClientTestFile(file))
            {
                continue;
            }

            yield return file;
        }

        foreach (var file in Directory.GetFiles(adminRoot, ".env*.example", SearchOption.TopDirectoryOnly))
        {
            yield return file;
        }

        foreach (var file in new[]
                 {
                     Path.Combine(adminRoot, "Dockerfile"),
                     Path.Combine(adminRoot, "next.config.ts")
                 })
        {
            if (File.Exists(file))
            {
                yield return file;
            }
        }

        var mobileRoot = Path.Combine(repositoryRoot, "apps", "petmagic-mobile");
        foreach (var file in EnumerateFiles(Path.Combine(mobileRoot, "lib"), ["*.dart"]))
        {
            if (IsClientTestFile(file))
            {
                continue;
            }

            yield return file;
        }

        foreach (var file in new[]
                 {
                     Path.Combine(mobileRoot, "android", "app", "google-services.json"),
                     Path.Combine(mobileRoot, "ios", "Runner", "GoogleService-Info.plist"),
                     Path.Combine(mobileRoot, "ios", "Runner", "Info.plist")
                 })
        {
            if (File.Exists(file))
            {
                yield return file;
            }
        }
    }

    private static bool IsClientTestFile(string file)
    {
        var fileName = Path.GetFileName(file);
        return fileName.Contains(".test.", StringComparison.OrdinalIgnoreCase)
            || fileName.Contains(".spec.", StringComparison.OrdinalIgnoreCase)
            || fileName.EndsWith("_test.dart", StringComparison.OrdinalIgnoreCase);
    }

    private static IEnumerable<string> EnumerateFiles(string directory, IReadOnlyCollection<string> patterns)
    {
        if (!Directory.Exists(directory))
        {
            yield break;
        }

        foreach (var pattern in patterns)
        {
            foreach (var file in Directory.GetFiles(directory, pattern, SearchOption.AllDirectories))
            {
                yield return file;
            }
        }
    }

    private static void AssertHostUsesDotnetEnvironmentForDotEnv(string programPath)
    {
        var source = File.ReadAllText(programPath);

        Assert.Contains("Environment.GetEnvironmentVariable(\"ASPNETCORE_ENVIRONMENT\")", source, StringComparison.Ordinal);
        Assert.Contains("Environment.GetEnvironmentVariable(\"DOTNET_ENVIRONMENT\")", source, StringComparison.Ordinal);
        Assert.Contains("Environments.Development", source, StringComparison.Ordinal);
    }
}
