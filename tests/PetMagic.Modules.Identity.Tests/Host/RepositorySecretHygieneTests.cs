using System.Text.RegularExpressions;
using System.Text.Json;
using System.Diagnostics;

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

    private static readonly Regex DisabledTestPattern = new(
        string.Join("|",
        [
            @"\[(?:Fact|Theory)\s*\([^\)]*\b" + "Skip" + @"\s*=",
            @"\b(?:describe|it|test)\." + "skip" + @"\s*\(",
            @"\b(?:xdescribe|xit)\s*\(",
            "@" + "Skip" + @"\b",
            @"\b" + "skip" + @"\s*:\s*(?:true|[""'])"
        ]),
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly Regex FocusedTestPattern = new(
        string.Join("|",
        [
            @"\b(?:describe|it|test)\." + "only" + @"\s*\(",
            @"\b(?:fdescribe|fit)\s*\(",
            @"\bsolo_" + "test" + @"\s*\(",
            @"\bsolo_" + "group" + @"\s*\("
        ]),
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly (Regex Pattern, string Description)[] RuntimeDebugOutputPatterns =
    [
        (new Regex(@"\bdebugger\s*;", RegexOptions.Compiled | RegexOptions.CultureInvariant), "debugger statement"),
        (new Regex(@"\bconsole\.(?:log|debug|trace)\s*\(", RegexOptions.Compiled | RegexOptions.CultureInvariant), "console debug output"),
        (new Regex(@"\bdebugPrint\s*\(", RegexOptions.Compiled | RegexOptions.CultureInvariant), "Flutter debugPrint output"),
        (new Regex(@"(?<![\w.])print\s*\(", RegexOptions.Compiled | RegexOptions.CultureInvariant), "Flutter print output"),
        (new Regex(@"\bConsole\.WriteLine\s*\(", RegexOptions.Compiled | RegexOptions.CultureInvariant), "Console.WriteLine output"),
    ];

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

        using var process = Process.Start(new ProcessStartInfo("git", "ls-files -- backups")
        {
            WorkingDirectory = repositoryRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        });
        Assert.NotNull(process);
        var trackedFiles = process.StandardOutput.ReadToEnd();
        process.WaitForExit();

        Assert.True(process.ExitCode == 0, process.StandardError.ReadToEnd());
        Assert.DoesNotContain(".sql", trackedFiles, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Repository_ShouldNotContainTemporaryOrBackupArtifacts()
    {
        var repositoryRoot = FindRepositoryRoot();
        var forbiddenExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".bak",
            ".backup",
            ".tmp",
            ".temp",
            ".old",
            ".orig",
            ".rej",
            ".swp",
            ".swo",
            ".log",
        };
        var forbiddenExactNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".DS_Store",
            "Thumbs.db",
            "desktop.ini",
        };
        var forbiddenPrefixes = new[] { "tmp_", "debug_", "backup_" };

        var violations = Directory
            .EnumerateFiles(repositoryRoot, "*", SearchOption.AllDirectories)
            .Where(file => !IsIgnoredArtifactScanPath(repositoryRoot, file))
            .Select(file => new
            {
                RelativePath = Path.GetRelativePath(repositoryRoot, file),
                FileName = Path.GetFileName(file),
                Extension = Path.GetExtension(file),
            })
            .Where(file =>
                forbiddenExactNames.Contains(file.FileName)
                || forbiddenExtensions.Contains(file.Extension)
                || forbiddenPrefixes.Any(prefix => file.FileName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
            .Select(file => file.RelativePath)
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(violations);
    }

    [Fact]
    public void Gitignore_ShouldExcludeTemporaryAndBackupArtifacts()
    {
        var repositoryRoot = FindRepositoryRoot();
        var gitignore = File.ReadAllText(Path.Combine(repositoryRoot, ".gitignore"));

        var requiredPatterns = new[]
        {
            "temp/",
            "tmp/",
            ".tmp/",
            "artifacts/",
            "*.bak",
            "*.backup",
            "*.tmp",
            "*.temp",
            "*.old",
            "*.orig",
            "*.rej",
            "tmp_*",
            "debug_*",
            "backup_*",
        };

        foreach (var requiredPattern in requiredPatterns)
        {
            Assert.Contains(requiredPattern, gitignore, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void Dockerignore_ShouldKeepLocalSecretsOutOfBuildContext()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerignore = File.ReadAllText(Path.Combine(repositoryRoot, ".dockerignore"));

        var requiredPatterns = new[]
        {
            ".env",
            ".env.*",
            "**/.env",
            "**/.env.*",
            "!.env.example",
            "!**/.env.example",
            "*.pfx",
            "*.pem",
            "*.key",
            "artifacts/",
            "apps/admin-web/.next/",
            "apps/petmagic-mobile/.dart_tool/",
            "apps/petmagic-mobile/build/",
            "apps/petmagic-mobile/android/.gradle/",
            "apps/petmagic-mobile/android/app/build/",
            "*.bak",
            "*.backup",
            "*.tmp",
            "*.temp",
            "*.old",
            "*.orig",
            "*.rej",
            "tmp_*",
            "debug_*",
            "backup_*",
            "temp/",
            "tmp/",
            ".tmp/",
        };

        foreach (var requiredPattern in requiredPatterns)
        {
            Assert.Contains(requiredPattern, dockerignore, StringComparison.Ordinal);
        }

        Assert.DoesNotContain("/Users/", dockerignore, StringComparison.Ordinal);
        Assert.DoesNotContain("D:\\", dockerignore, StringComparison.Ordinal);
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
    public void ClientFirebaseConfigExamples_ShouldContainPlaceholdersOnly()
    {
        var repositoryRoot = FindRepositoryRoot();
        var configPaths = new[]
        {
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "Info.plist"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "GoogleService-Info.plist.example"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "google-services.json.example"),
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
    public void ClientFirebaseConfigs_ShouldUseIgnoredActiveFilesAndTrackedExamples()
    {
        var repositoryRoot = FindRepositoryRoot();
        var forbiddenRootConfigs = new[]
        {
            "GoogleService-Info.plist",
            "google-services.json",
        };

        foreach (var forbiddenRootConfig in forbiddenRootConfigs)
        {
            Assert.False(
                File.Exists(Path.Combine(repositoryRoot, forbiddenRootConfig)),
                $"{forbiddenRootConfig} must not live at the repository root.");
        }

        var activeMobileConfigs = new[]
        {
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "GoogleService-Info.plist"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "google-services.json"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "src", "staging", "google-services.json"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "src", "production", "google-services.json"),
        };

        foreach (var activeMobileConfig in activeMobileConfigs)
        {
            Assert.False(
                File.Exists(activeMobileConfig),
                $"{Path.GetRelativePath(repositoryRoot, activeMobileConfig)} must be injected from a protected environment.");
        }

        var requiredMobileExamples = new[]
        {
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "ios", "Runner", "GoogleService-Info.plist.example"),
            Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "android", "app", "google-services.json.example"),
        };

        foreach (var requiredMobileExample in requiredMobileExamples)
        {
            Assert.True(
                File.Exists(requiredMobileExample),
                $"{Path.GetRelativePath(repositoryRoot, requiredMobileExample)} must remain in the mobile platform project.");
        }

        var gitignore = File.ReadAllText(Path.Combine(repositoryRoot, ".gitignore"));
        Assert.Contains("apps/petmagic-mobile/android/app/google-services.json", gitignore, StringComparison.Ordinal);
        Assert.Contains("apps/petmagic-mobile/android/app/src/staging/google-services.json", gitignore, StringComparison.Ordinal);
        Assert.Contains("apps/petmagic-mobile/android/app/src/production/google-services.json", gitignore, StringComparison.Ordinal);
        Assert.Contains("apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist", gitignore, StringComparison.Ordinal);
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
    public void DeployableSourceAndConfig_ShouldNotContainHighConfidenceSecretValues()
    {
        var repositoryRoot = FindRepositoryRoot();
        var scannedFiles = EnumerateDeployableSourceAndConfigFiles(repositoryRoot).ToArray();

        Assert.NotEmpty(scannedFiles);

        var violations = scannedFiles
            .SelectMany(file =>
            {
                var content = File.ReadAllText(file);
                var relativePath = Path.GetRelativePath(repositoryRoot, file);
                var findings = new List<string>();

                if (ServerSecretValuePattern.IsMatch(content))
                {
                    findings.Add($"{relativePath} contains a server secret value pattern.");
                }

                if (FirebaseApiKeyPattern.IsMatch(content))
                {
                    findings.Add($"{relativePath} contains a Firebase API-key-shaped value.");
                }

                if (GoogleOauthClientIdPattern.IsMatch(content)
                    || ReverseGoogleOauthClientIdPattern.IsMatch(content))
                {
                    findings.Add($"{relativePath} contains a Google OAuth client-id-shaped value.");
                }

                if (content.Contains("petmagic-f036b", StringComparison.OrdinalIgnoreCase))
                {
                    findings.Add($"{relativePath} contains the real Firebase project id.");
                }

                return findings;
            })
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(violations);
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

    [Fact]
    public void RuntimeSource_ShouldNotCarryIncompleteImplementationMarkers()
    {
        var repositoryRoot = FindRepositoryRoot();
        var forbiddenMarkers = new[]
        {
            "TODO",
            "FIXME",
            "HACK",
            "XXX",
            "NotImplementedException",
            "UnimplementedError",
        };
        var markerViolations = EnumerateRuntimeSourceFiles(repositoryRoot)
            .SelectMany(ReadRuntimeSourceLines)
            .SelectMany(line => forbiddenMarkers
                .Where(marker => line.Line.Contains(marker, StringComparison.Ordinal))
                .Select(marker => $"{line.RelativePath}:{line.LineNumber} contains {marker}"));

        var debugOutputViolations = EnumerateRuntimeSourceFiles(repositoryRoot)
            .SelectMany(ReadRuntimeSourceLines)
            .SelectMany(line => RuntimeDebugOutputPatterns
                .Where(rule => rule.Pattern.IsMatch(line.Line))
                .Select(rule => $"{line.RelativePath}:{line.LineNumber} contains {rule.Description}"));

        var violations = markerViolations
            .Concat(debugOutputViolations)
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(violations);
    }

    private static IEnumerable<(string RelativePath, int LineNumber, string Line)> ReadRuntimeSourceLines(string file)
    {
        var repositoryRoot = FindRepositoryRoot();
        var relativePath = Path.GetRelativePath(repositoryRoot, file);
        return File.ReadLines(file)
            .Select((line, index) => (relativePath, index + 1, line));
    }

    [Fact]
    public void Repository_ShouldNotCarryManualApiScratchFiles()
    {
        var repositoryRoot = FindRepositoryRoot();
        var scratchFiles = Directory
            .EnumerateFiles(repositoryRoot, "*", SearchOption.AllDirectories)
            .Where(file => !IsIgnoredArtifactScanPath(repositoryRoot, file))
            .Where(IsManualApiScratchFile)
            .Select(file => Path.GetRelativePath(repositoryRoot, file))
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(scratchFiles);
    }

    [Fact]
    public void TestSuites_ShouldNotContainSkippedFocusedOrDisabledTests()
    {
        var repositoryRoot = FindRepositoryRoot();
        var violations = EnumerateTestSourceFiles(repositoryRoot)
            .SelectMany(file =>
            {
                var relativePath = Path.GetRelativePath(repositoryRoot, file);
                return File.ReadLines(file)
                    .Select((line, index) => new
                    {
                        RelativePath = relativePath,
                        LineNumber = index + 1,
                        Line = line,
                    });
            })
            .Where(line => DisabledTestPattern.IsMatch(line.Line) || FocusedTestPattern.IsMatch(line.Line))
            .Select(line => $"{line.RelativePath}:{line.LineNumber} contains a skipped, focused, or disabled test marker")
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Empty(violations);
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

    private static IEnumerable<string> EnumerateRuntimeSourceFiles(string repositoryRoot)
    {
        foreach (var file in EnumerateFiles(Path.Combine(repositoryRoot, "src"), ["*.cs"]))
        {
            if (IsGeneratedOrBuildOutput(file))
            {
                continue;
            }

            yield return file;
        }

        foreach (var file in EnumerateFiles(Path.Combine(repositoryRoot, "apps", "petmagic-mobile", "lib"), ["*.dart"]))
        {
            if (IsGeneratedOrBuildOutput(file) || IsClientTestFile(file))
            {
                continue;
            }

            yield return file;
        }

        foreach (var file in EnumerateFiles(Path.Combine(repositoryRoot, "apps", "admin-web", "src"), ["*.ts", "*.tsx"]))
        {
            if (IsGeneratedOrBuildOutput(file) || IsClientTestFile(file))
            {
                continue;
            }

            yield return file;
        }
    }

    private static IEnumerable<string> EnumerateDeployableSourceAndConfigFiles(string repositoryRoot)
    {
        var allowedExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".cs",
            ".css",
            ".dart",
            ".json",
            ".js",
            ".jsx",
            ".kt",
            ".mjs",
            ".plist",
            ".props",
            ".ps1",
            ".sh",
            ".ts",
            ".tsx",
            ".xml",
            ".yaml",
            ".yml",
        };
        var allowedExactNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".dockerignore",
            ".env.example",
            ".env.local-smoke.example",
            ".env.staging.local.example",
            ".gitignore",
            "Dockerfile",
            "docker-compose.yml",
        };

        return Directory
            .EnumerateFiles(repositoryRoot, "*", SearchOption.AllDirectories)
            .Where(file => !IsIgnoredArtifactScanPath(repositoryRoot, file))
            .Where(file => IsDeployableSecretScanPath(repositoryRoot, file))
            .Where(file =>
            {
                var fileName = Path.GetFileName(file);
                return allowedExactNames.Contains(fileName)
                    || allowedExtensions.Contains(Path.GetExtension(file));
            });
    }

    private static IEnumerable<string> EnumerateTestSourceFiles(string repositoryRoot)
    {
        foreach (var file in EnumerateFiles(Path.Combine(repositoryRoot, "tests"), ["*.cs"]))
        {
            if (!IsGeneratedOrBuildOutput(file))
            {
                yield return file;
            }
        }

        foreach (var file in EnumerateFiles(Path.Combine(repositoryRoot, "apps", "admin-web", "src"), ["*.test.ts", "*.test.tsx", "*.spec.ts", "*.spec.tsx"]))
        {
            if (!IsGeneratedOrBuildOutput(file))
            {
                yield return file;
            }
        }

        var mobileRoot = Path.Combine(repositoryRoot, "apps", "petmagic-mobile");
        foreach (var directoryName in new[] { "test", "integration_test" })
        {
            foreach (var file in EnumerateFiles(Path.Combine(mobileRoot, directoryName), ["*_test.dart"]))
            {
                if (!IsGeneratedOrBuildOutput(file))
                {
                    yield return file;
                }
            }
        }
    }

    private static bool IsGeneratedOrBuildOutput(string file)
    {
        return file.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
            || file.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
            || file.Contains($"{Path.DirectorySeparatorChar}generated{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
            || file.EndsWith(".g.cs", StringComparison.OrdinalIgnoreCase)
            || file.EndsWith(".Designer.cs", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsIgnoredArtifactScanPath(string repositoryRoot, string file)
    {
        var relativePath = Path.GetRelativePath(repositoryRoot, file);
        var segments = relativePath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var ignoredDirectories = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".dart_tool",
            ".git",
            ".gradle",
            ".next",
            ".turbo",
            "artifacts",
            "bin",
            "build",
            "coverage",
            "node_modules",
            "obj",
        };

        return segments.Any(segment => ignoredDirectories.Contains(segment));
    }

    private static bool IsDeployableSecretScanPath(string repositoryRoot, string file)
    {
        var relativePath = Path.GetRelativePath(repositoryRoot, file);
        var segments = relativePath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var ignoredDirectories = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "docs",
            "integration_test",
            "test",
            "tests",
            "ux-audit-2026-06-13",
        };

        if (segments.Any(segment => ignoredDirectories.Contains(segment)))
        {
            return false;
        }

        var fileName = Path.GetFileName(file);
        return !fileName.Contains(".test.", StringComparison.OrdinalIgnoreCase)
            && !fileName.Contains(".spec.", StringComparison.OrdinalIgnoreCase)
            && !fileName.EndsWith("_test.dart", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsManualApiScratchFile(string file)
    {
        var extension = Path.GetExtension(file);
        if (extension.Equals(".http", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".rest", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var fileName = Path.GetFileName(file);
        return fileName.Contains("postman", StringComparison.OrdinalIgnoreCase)
            || fileName.Contains("insomnia", StringComparison.OrdinalIgnoreCase);
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
