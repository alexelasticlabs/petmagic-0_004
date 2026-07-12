using System.Text.RegularExpressions;
using System.Text.Json;
using System.Xml.Linq;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class BackendEnvironmentContractTests
{
    private static readonly string[] BillingAndStoreEnvironmentKeys =
    [
        "STRIPE_TEST_SECRET_KEY",
        "STRIPE_TEST_PUBLISHABLE_KEY",
        "STRIPE_TEST_WEBHOOK_SECRET",
        "STRIPE_LIVE_SECRET_KEY",
        "STRIPE_LIVE_PUBLISHABLE_KEY",
        "STRIPE_LIVE_WEBHOOK_SECRET",
        "STRIPE_CHECKOUT_SUCCESS_URL",
        "STRIPE_CHECKOUT_CANCEL_URL",
        "STRIPE_BILLING_PORTAL_RETURN_URL",
        "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL",
        "GOOGLE_PLAY_PRIVATE_KEY_PEM",
        "GOOGLE_PLAY_ENVIRONMENT",
        "GOOGLE_PLAY_PUBSUB_AUDIENCE",
        "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL",
        "APP_STORE_SHARED_SECRET",
        "APP_STORE_ENVIRONMENT"
    ];

    [Fact]
    public void EnvExample_ShouldDocumentEveryDockerComposeSubstitutionKey()
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExampleKeys = ReadEnvExampleKeys(Path.Combine(repositoryRoot, ".env.example"));
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var composeKeys = Regex
            .Matches(dockerCompose, @"\$\{(?<key>[A-Z0-9_]+)(?::[-?][^}]*)?\}")
            .Select(match => match.Groups["key"].Value)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();

        var missingKeys = composeKeys
            .Where(key => !envExampleKeys.Contains(key))
            .ToArray();

        Assert.Empty(missingKeys);
    }

    [Theory]
    [InlineData(".env.example")]
    [InlineData(".env.local-smoke.example")]
    [InlineData(".env.staging.local.example")]
    public void ComposeEnvExamples_ShouldProvideValuesForRequiredDockerComposeSubstitutions(string envExampleFileName)
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExampleValues = ReadEnvExampleValues(Path.Combine(repositoryRoot, envExampleFileName));
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var requiredComposeKeys = Regex
            .Matches(dockerCompose, @"\$\{(?<key>[A-Z0-9_]+):\?[^}]*\}")
            .Select(match => match.Groups["key"].Value)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();

        var missingOrBlankKeys = requiredComposeKeys
            .Where(key => !envExampleValues.TryGetValue(key, out var value) || string.IsNullOrWhiteSpace(value))
            .ToArray();

        Assert.Empty(missingOrBlankKeys);
    }

    [Fact]
    public void EnvExample_ShouldExposeBackendBillingAndStoreKeysThatBackendReads()
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExample = File.ReadAllText(Path.Combine(repositoryRoot, ".env.example"));

        Assert.DoesNotContain(Environment.NewLine + "STRIPE_SECRET_KEY=", envExample, StringComparison.Ordinal);
        Assert.DoesNotContain(Environment.NewLine + "STRIPE_WEBHOOK_SECRET=", envExample, StringComparison.Ordinal);

        foreach (var key in BillingAndStoreEnvironmentKeys)
        {
            Assert.Contains($"{key}=", envExample, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void DockerComposeBackend_ShouldForwardBackendBillingAndStoreKeys()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var backendEnvironment = ExtractBackendEnvironmentBlock(dockerCompose);

        foreach (var key in BillingAndStoreEnvironmentKeys)
        {
            Assert.Contains($"{key}:", backendEnvironment, StringComparison.Ordinal);
        }

        Assert.DoesNotContain("STRIPE_SECRET_KEY:", backendEnvironment, StringComparison.Ordinal);
        Assert.DoesNotContain("STRIPE_WEBHOOK_SECRET:", backendEnvironment, StringComparison.Ordinal);
    }

    [Fact]
    public void DockerComposeBackend_ShouldRequireExplicitNonWildcardAllowedHosts()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var backendEnvironment = ExtractBackendEnvironmentBlock(dockerCompose);
        var envExampleValues = ReadEnvExampleValues(Path.Combine(repositoryRoot, ".env.example"));

        Assert.Contains(
            "AllowedHosts: \"${BACKEND_ALLOWED_HOSTS:?Set BACKEND_ALLOWED_HOSTS to the public backend host names}\"",
            backendEnvironment,
            StringComparison.Ordinal);
        Assert.Contains(
            "curl --fail --silent --header 'Host: ${BACKEND_HEALTHCHECK_HOST:?Set BACKEND_HEALTHCHECK_HOST to a host allowed by BACKEND_ALLOWED_HOSTS}' http://localhost:5000/health",
            dockerCompose,
            StringComparison.Ordinal);
        Assert.DoesNotContain("AllowedHosts: \"*\"", backendEnvironment, StringComparison.Ordinal);
        Assert.True(envExampleValues.TryGetValue("BACKEND_ALLOWED_HOSTS", out var allowedHosts));
        Assert.True(envExampleValues.TryGetValue("BACKEND_HEALTHCHECK_HOST", out var healthcheckHost));
        Assert.False(string.IsNullOrWhiteSpace(allowedHosts));
        Assert.DoesNotContain("*", allowedHosts, StringComparison.Ordinal);
        Assert.DoesNotContain("localhost", allowedHosts, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(healthcheckHost, allowedHosts.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries), StringComparer.Ordinal);

        var readme = File.ReadAllText(Path.Combine(repositoryRoot, "README.md"));
        Assert.Contains("BACKEND_ALLOWED_HOSTS=api.petmagic.app", readme, StringComparison.Ordinal);
        Assert.Contains("BACKEND_HEALTHCHECK_HOST=api.petmagic.app", readme, StringComparison.Ordinal);
        Assert.Contains("explicit non-wildcard `AllowedHosts`", readme, StringComparison.Ordinal);

        var apiContracts = File.ReadAllText(Path.Combine(repositoryRoot, "docs", "API_CONTRACTS.md"));
        Assert.Contains("wildcard, localhost, loopback, private-network, malformed, or port-qualified `AllowedHosts`", apiContracts, StringComparison.Ordinal);
    }

    [Fact]
    public void DockerComposeGenerationWorker_ShouldForwardProductionCriticalEconomyAndTemplateKeys()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var workerEnvironment = ExtractServiceEnvironmentBlock(dockerCompose, "generation-worker");

        foreach (var key in BillingAndStoreEnvironmentKeys)
        {
            Assert.Contains($"{key}:", workerEnvironment, StringComparison.Ordinal);
        }

        foreach (var key in new[]
        {
            "FAL_AI_API_KEY",
            "FAL_WEBHOOK_URL",
            "R2_ACCOUNT_ID",
            "R2_ACCESS_KEY",
            "R2_SECRET_KEY",
            "R2_BUCKET_NAME",
            "R2_PUBLIC_URL",
            "Jwt__SigningKey",
            "Templates__PublicBaseUrl",
            "Templates__StorageProvider",
            "Templates__AiProvider"
        })
        {
            Assert.Contains($"{key}:", workerEnvironment, StringComparison.Ordinal);
        }

        Assert.Contains("Templates__GenerationWorkerEnabled: \"true\"", workerEnvironment, StringComparison.Ordinal);
        Assert.DoesNotContain("STRIPE_SECRET_KEY:", workerEnvironment, StringComparison.Ordinal);
        Assert.DoesNotContain("STRIPE_WEBHOOK_SECRET:", workerEnvironment, StringComparison.Ordinal);
    }

    [Fact]
    public void DockerComposeApiAndGenerationWorkerSchedulerFingerprintKeys_ShouldStayInParity()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var backendEnvironment = ExtractBackendEnvironmentBlock(dockerCompose);
        var workerEnvironment = ExtractServiceEnvironmentBlock(dockerCompose, "generation-worker");
        var fingerprintEnvironmentKeys = new[]
        {
            "Templates__GlobalMaxConcurrentGenerations",
            "Templates__ImageReservedConcurrentGenerations",
            "Templates__ImageMaxConcurrentGenerations",
            "Templates__ImageProtectedConcurrentGenerations",
            "Templates__VideoReservedConcurrentGenerations",
            "Templates__VideoMaxConcurrentGenerations",
            "Templates__VideoBorrowMaxConcurrentGenerations",
            "Templates__EnableElasticLaneBorrowing",
            "Templates__AllowVideoBorrowWhenImageQueueEmpty",
            "Templates__AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds",
            "Templates__VideoBorrowReleaseMode",
            "Templates__BorrowedVideoMaxAgeSeconds",
            "Templates__BorrowingPriorityTiers",
            "Templates__VideoPreprocessingMaxConcurrentGenerations",
            "Templates__FalProviderConcurrencyLimit",
            "Templates__FalProviderReservedConcurrency",
            "Templates__QueueMaxSize",
            "Templates__EstimatedVideoGenerationSeconds",
            "Templates__EstimatedImageGenerationSeconds",
            "Templates__EstimatedVideoPreprocessingSeconds",
            "Templates__FreeImageMaxEstimatedWaitSeconds",
            "Templates__PremiumImageMaxEstimatedWaitSeconds",
            "Templates__PrivilegedImageMaxEstimatedWaitSeconds",
            "Templates__FreeVideoMaxEstimatedWaitSeconds",
            "Templates__PremiumVideoMaxEstimatedWaitSeconds",
            "Templates__PrivilegedVideoMaxEstimatedWaitSeconds",
            "Templates__QueuePriorityAgingIntervalSeconds",
            "Templates__QueuePriorityAgingBoost",
            "Templates__CancelQueuedGenerationEnabled",
            "Templates__MaxConcurrentJobsPerWorker",
            "Templates__GenerationWorkerPollIntervalMilliseconds",
            "Templates__MaxAiProviderRequestsPerMinute",
            "Templates__MaxGenerationAttempts",
            "Templates__RefundRetryDelayMilliseconds",
            "Templates__JobLockTimeoutMilliseconds",
            "Templates__OrphanQueuedJobTimeoutMilliseconds"
        };

        foreach (var key in fingerprintEnvironmentKeys)
        {
            Assert.Contains($"{key}:", backendEnvironment, StringComparison.Ordinal);
            Assert.Contains($"{key}:", workerEnvironment, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void DockerComposeGenerationSchedulerFallbacks_ShouldStayInternallyConsistentAndStagingSafe()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));

        Assert.Equal(3, ReadComposeFallbackInt(dockerCompose, "GENERATION_GLOBAL_MAX_CONCURRENT"));
        Assert.Equal(2, ReadComposeFallbackInt(dockerCompose, "GENERATION_IMAGE_MAX_CONCURRENT"));
        Assert.Equal(1, ReadComposeFallbackInt(dockerCompose, "GENERATION_VIDEO_MAX_CONCURRENT"));
        Assert.Equal(900, ReadComposeFallbackInt(dockerCompose, "GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS"));
        Assert.Equal(900, ReadComposeFallbackInt(dockerCompose, "GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS"));
        Assert.Equal(900_000, ReadComposeFallbackInt(dockerCompose, "GENERATION_JOB_LOCK_TIMEOUT_MS"));
        Assert.Equal(30_000, ReadComposeFallbackInt(dockerCompose, "GENERATION_REFUND_RETRY_DELAY_MS"));
    }

    [Fact]
    public void DockerComposeBackend_ShouldNotRunTemplateOfTheDayAutoPickWorkerByDefault()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var backendEnvironment = ExtractBackendEnvironmentBlock(dockerCompose);

        Assert.Contains(
            "Templates__TemplateOfTheDayAutoPickWorkerEnabled: \"${TEMPLATES_TEMPLATE_OF_THE_DAY_AUTO_PICK_WORKER_ENABLED:-false}\"",
            backendEnvironment,
            StringComparison.Ordinal);
    }

    [Fact]
    public void EnvExampleGenerationSchedulerValues_ShouldMatchComposeReleaseFallbacks()
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExampleValues = ReadEnvExampleValues(Path.Combine(repositoryRoot, ".env.example"));
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var schedulerKeys = new[]
        {
            "GENERATION_GLOBAL_MAX_CONCURRENT",
            "GENERATION_IMAGE_MAX_CONCURRENT",
            "GENERATION_VIDEO_MAX_CONCURRENT",
            "GENERATION_FREE_IMAGE_MAX_WAIT_SECONDS",
            "GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS",
            "GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS",
            "GENERATION_FREE_VIDEO_MAX_WAIT_SECONDS",
            "GENERATION_PREMIUM_VIDEO_MAX_WAIT_SECONDS",
            "GENERATION_PRIVILEGED_VIDEO_MAX_WAIT_SECONDS",
            "GENERATION_JOB_LOCK_TIMEOUT_MS",
            "GENERATION_REFUND_RETRY_DELAY_MS"
        };

        foreach (var key in schedulerKeys)
        {
            Assert.True(envExampleValues.TryGetValue(key, out var envValue), $".env.example is missing {key}.");
            Assert.Equal(ReadComposeFallbackInt(dockerCompose, key).ToString(), envValue);
        }
    }

    [Fact]
    public void HostAppsettingsGenerationSchedulerImageWaits_ShouldMatchComposeReleaseFallbacks()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var apiSettingsPath = Path.Combine(repositoryRoot, "src", "Host", "PetMagic.Host.Api", "appsettings.json");
        var workerSettingsPath = Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
            "appsettings.json");

        Assert.Equal(1800, ReadJsonInt(apiSettingsPath, "Templates", "FreeImageMaxEstimatedWaitSeconds"));
        Assert.Equal(1800, ReadJsonInt(workerSettingsPath, "Templates", "FreeImageMaxEstimatedWaitSeconds"));
        Assert.Equal(
            ReadComposeFallbackInt(dockerCompose, "GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS"),
            ReadJsonInt(apiSettingsPath, "Templates", "PremiumImageMaxEstimatedWaitSeconds"));
        Assert.Equal(
            ReadComposeFallbackInt(dockerCompose, "GENERATION_PREMIUM_IMAGE_MAX_WAIT_SECONDS"),
            ReadJsonInt(workerSettingsPath, "Templates", "PremiumImageMaxEstimatedWaitSeconds"));
        Assert.Equal(
            ReadComposeFallbackInt(dockerCompose, "GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS"),
            ReadJsonInt(apiSettingsPath, "Templates", "PrivilegedImageMaxEstimatedWaitSeconds"));
        Assert.Equal(
            ReadComposeFallbackInt(dockerCompose, "GENERATION_PRIVILEGED_IMAGE_MAX_WAIT_SECONDS"),
            ReadJsonInt(workerSettingsPath, "Templates", "PrivilegedImageMaxEstimatedWaitSeconds"));
    }

    [Fact]
    public void ApiDevelopmentAllowedHosts_ShouldSupportLocalSmokeWithoutWeakeningProductionHosts()
    {
        var repositoryRoot = FindRepositoryRoot();
        var apiSettingsPath = Path.Combine(repositoryRoot, "src", "Host", "PetMagic.Host.Api", "appsettings.json");
        var apiDevelopmentSettingsPath = Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "appsettings.Development.json");

        Assert.Equal("api.petmagic.app", ReadJsonString(apiSettingsPath, "AllowedHosts"));

        var developmentAllowedHosts = ReadJsonString(apiDevelopmentSettingsPath, "AllowedHosts");
        Assert.NotEqual("*", developmentAllowedHosts);
        Assert.Contains("localhost", developmentAllowedHosts, StringComparison.Ordinal);
        Assert.Contains("127.0.0.1", developmentAllowedHosts, StringComparison.Ordinal);
        Assert.Contains("[::1]", developmentAllowedHosts, StringComparison.Ordinal);
    }

    [Fact]
    public void ApiAndGenerationWorkerDevelopmentSchedulerDefaults_ShouldStayFingerprintCompatible()
    {
        var repositoryRoot = FindRepositoryRoot();
        var apiDevelopmentSettingsPath = Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "appsettings.Development.json");
        var workerSettingsPath = Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
            "appsettings.json");

        Assert.Equal(
            ReadJsonInt(workerSettingsPath, "Templates", "EstimatedImageGenerationSeconds"),
            ReadJsonInt(apiDevelopmentSettingsPath, "Templates", "EstimatedImageGenerationSeconds"));
        Assert.Equal(
            ReadJsonInt(workerSettingsPath, "Templates", "EstimatedVideoGenerationSeconds"),
            ReadJsonInt(apiDevelopmentSettingsPath, "Templates", "EstimatedVideoGenerationSeconds"));
        Assert.Equal(
            ReadJsonIntOrDefault(workerSettingsPath, 30_000, "Templates", "RefundRetryDelayMilliseconds"),
            ReadJsonInt(apiDevelopmentSettingsPath, "Templates", "RefundRetryDelayMilliseconds"));
        Assert.Equal(
            ReadJsonInt(workerSettingsPath, "Templates", "GenerationWorkerPollIntervalMilliseconds"),
            ReadJsonInt(apiDevelopmentSettingsPath, "Templates", "GenerationWorkerPollIntervalMilliseconds"));
    }

    [Fact]
    public void GenerationWorkerProject_ShouldCopyAppsettingsToOutputAndPublishDirectories()
    {
        var repositoryRoot = FindRepositoryRoot();
        var projectPath = Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
            "PetMagic.Host.GenerationWorker.csproj");
        var project = XDocument.Load(projectPath);

        var appsettingsItem = project
            .Descendants("None")
            .SingleOrDefault(element => string.Equals(
                element.Attribute("Update")?.Value,
                "appsettings*.json",
                StringComparison.Ordinal));

        Assert.NotNull(appsettingsItem);
        Assert.Equal("PreserveNewest", appsettingsItem.Element("CopyToOutputDirectory")?.Value);
        Assert.Equal("PreserveNewest", appsettingsItem.Element("CopyToPublishDirectory")?.Value);
    }

    [Fact]
    public void DotnetToolManifest_ShouldPinEfToolForMigrationChecks()
    {
        var repositoryRoot = FindRepositoryRoot();
        var toolManifestPath = Path.Combine(repositoryRoot, ".config", "dotnet-tools.json");
        var packagesPath = Path.Combine(repositoryRoot, "Directory.Packages.props");

        Assert.True(File.Exists(toolManifestPath), ".config/dotnet-tools.json must be tracked for reproducible EF checks.");

        using var toolManifest = JsonDocument.Parse(File.ReadAllText(toolManifestPath));
        var dotnetEf = toolManifest.RootElement
            .GetProperty("tools")
            .GetProperty("dotnet-ef");
        var efDesignVersion = ReadPackageVersion(packagesPath, "Microsoft.EntityFrameworkCore.Design");

        Assert.Equal(efDesignVersion, dotnetEf.GetProperty("version").GetString());
        Assert.False(dotnetEf.GetProperty("rollForward").GetBoolean());
        Assert.Contains(
            dotnetEf.GetProperty("commands").EnumerateArray(),
            command => string.Equals(command.GetString(), "dotnet-ef", StringComparison.Ordinal));
    }

    [Fact]
    public void DockerComposeMonitoringProfile_ShouldUseConfigBackedLocalImages()
    {
        var repositoryRoot = FindRepositoryRoot();
        var dockerCompose = File.ReadAllText(Path.Combine(repositoryRoot, "docker-compose.yml"));
        var monitoringServices = new Dictionary<string, string>
        {
            ["otel-collector"] = "deploy/monitoring/otel-collector",
            ["tempo"] = "deploy/monitoring/tempo",
            ["prometheus"] = "deploy/monitoring/prometheus",
            ["alertmanager"] = "deploy/monitoring/alertmanager",
            ["grafana"] = "deploy/monitoring/grafana"
        };

        foreach (var (serviceName, contextPath) in monitoringServices)
        {
            var serviceBlock = ExtractServiceBlock(dockerCompose, serviceName);
            var dockerfilePath = Path.Combine(
                repositoryRoot,
                Path.Combine(contextPath.Split('/')),
                "Dockerfile");

            Assert.True(File.Exists(dockerfilePath), $"{contextPath}/Dockerfile must exist.");
            Assert.Contains("profiles: [\"monitoring\"]", serviceBlock, StringComparison.Ordinal);
            Assert.Contains($"context: ./{contextPath}", serviceBlock, StringComparison.Ordinal);
        }

        Assert.DoesNotContain("./deploy/monitoring/otel-collector/config.yaml:/etc/otelcol/config.yaml", dockerCompose, StringComparison.Ordinal);
        Assert.DoesNotContain("./deploy/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml", dockerCompose, StringComparison.Ordinal);
        Assert.DoesNotContain("./deploy/monitoring/prometheus/petmagic-alerts.yml:/etc/prometheus/rules/petmagic-alerts.yml", dockerCompose, StringComparison.Ordinal);
        Assert.DoesNotContain("./deploy/monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml", dockerCompose, StringComparison.Ordinal);
        Assert.DoesNotContain("./deploy/monitoring/grafana/provisioning:/etc/grafana/provisioning", dockerCompose, StringComparison.Ordinal);
    }

    [Fact]
    public void EnvExampleMonitoringWebhook_ShouldNotDefaultToLocalOrInsecureUrl()
    {
        var repositoryRoot = FindRepositoryRoot();
        var envExampleValues = ReadEnvExampleValues(Path.Combine(repositoryRoot, ".env.example"));

        Assert.True(envExampleValues.TryGetValue("ALERTMANAGER_WEBHOOK_URL", out var alertmanagerWebhookUrl));
        Assert.StartsWith("https://", alertmanagerWebhookUrl, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("localhost", alertmanagerWebhookUrl, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("127.0.0.1", alertmanagerWebhookUrl, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("host.docker.internal", alertmanagerWebhookUrl, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void LoadTestingManualHostDefaults_ShouldMatchComposeBackendHostPort()
    {
        var repositoryRoot = FindRepositoryRoot();
        var loadTestingDoc = File.ReadAllText(Path.Combine(repositoryRoot, "docs", "LOAD_TESTING.md"));
        var k6Script = File.ReadAllText(Path.Combine(repositoryRoot, "scripts", "k6", "template-generation-load-test.js"));

        Assert.Contains("http://localhost:5001", loadTestingDoc, StringComparison.Ordinal);
        Assert.Contains("'http://localhost:5001'", k6Script, StringComparison.Ordinal);
        Assert.DoesNotContain("BASE_URL=http://localhost:5000", loadTestingDoc, StringComparison.Ordinal);
        Assert.DoesNotContain("'http://localhost:5000'", k6Script, StringComparison.Ordinal);
        Assert.Contains("BASE_URL=http://backend:5000", loadTestingDoc, StringComparison.Ordinal);
    }

    private static string ExtractBackendEnvironmentBlock(string dockerCompose)
    {
        return ExtractServiceEnvironmentBlock(dockerCompose, "backend");
    }

    private static string ExtractServiceEnvironmentBlock(string dockerCompose, string serviceName)
    {
        var match = Regex.Match(
            dockerCompose,
            $@"(?ms)^  {Regex.Escape(serviceName)}:\r?\n.*?^    environment:\r?\n(?<environment>.*?)(?=^    [A-Za-z_][A-Za-z0-9_-]*:|^  [A-Za-z_][A-Za-z0-9_-]*:|\z)");

        Assert.True(match.Success, $"Could not locate {serviceName} environment block in docker-compose.yml.");

        return match.Groups["environment"].Value;
    }

    private static string ExtractServiceBlock(string dockerCompose, string serviceName)
    {
        var match = Regex.Match(
            dockerCompose,
            $@"(?ms)^  {Regex.Escape(serviceName)}:\r?\n(?<service>.*?)(?=^  [A-Za-z_][A-Za-z0-9_-]*:|\z)");

        Assert.True(match.Success, $"Could not locate {serviceName} service in docker-compose.yml.");

        return match.Groups["service"].Value;
    }

    private static int ReadComposeFallbackInt(string dockerCompose, string key)
    {
        var matches = Regex.Matches(
            dockerCompose,
            $@"\$\{{{Regex.Escape(key)}:-(?<value>\d+)\}}");

        Assert.NotEmpty(matches);

        var values = matches
            .Select(match => int.Parse(match.Groups["value"].Value))
            .Distinct()
            .ToArray();

        Assert.True(values.Length == 1, $"Inconsistent docker-compose.yml numeric fallbacks for {key}.");
        return values[0];
    }

    private static string ReadPackageVersion(string packagesPath, string packageName)
    {
        var packages = XDocument.Load(packagesPath);
        var package = packages
            .Descendants("PackageVersion")
            .SingleOrDefault(element => string.Equals(
                element.Attribute("Include")?.Value,
                packageName,
                StringComparison.Ordinal));

        Assert.NotNull(package);
        return package.Attribute("Version")?.Value
            ?? throw new InvalidOperationException($"{packageName} does not declare a Version attribute.");
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

    private static HashSet<string> ReadEnvExampleKeys(string envExamplePath)
    {
        return File.ReadLines(envExamplePath)
            .Select(line => line.Trim())
            .Where(line => !string.IsNullOrWhiteSpace(line) && !line.StartsWith('#'))
            .Select(line => line.Split('=', 2)[0].Trim())
            .Where(key => !string.IsNullOrWhiteSpace(key))
            .ToHashSet(StringComparer.Ordinal);
    }

    private static Dictionary<string, string> ReadEnvExampleValues(string envExamplePath)
    {
        return File.ReadLines(envExamplePath)
            .Select(line => line.Trim())
            .Where(line => !string.IsNullOrWhiteSpace(line) && !line.StartsWith('#'))
            .Select(line => line.Split('=', 2))
            .Where(parts => parts.Length == 2 && !string.IsNullOrWhiteSpace(parts[0]))
            .ToDictionary(parts => parts[0].Trim(), parts => parts[1].Trim(), StringComparer.Ordinal);
    }

    private static int ReadJsonInt(string jsonPath, params string[] path)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(jsonPath));
        return ReadJsonElement(document.RootElement, path).GetInt32();
    }

    private static int ReadJsonIntOrDefault(string jsonPath, int defaultValue, params string[] path)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(jsonPath));
        return TryReadJsonElement(document.RootElement, path, out var element)
            ? element.GetInt32()
            : defaultValue;
    }

    private static string ReadJsonString(string jsonPath, params string[] path)
    {
        using var document = JsonDocument.Parse(File.ReadAllText(jsonPath));
        return ReadJsonElement(document.RootElement, path).GetString()
            ?? throw new InvalidOperationException($"JSON value is null: {string.Join(':', path)}");
    }

    private static JsonElement ReadJsonElement(JsonElement root, params string[] path)
    {
        Assert.True(
            TryReadJsonElement(root, path, out var element),
            $"Missing JSON property in path '{string.Join(':', path)}'.");

        return element;
    }

    private static bool TryReadJsonElement(JsonElement root, string[] path, out JsonElement element)
    {
        element = root;
        foreach (var segment in path)
        {
            if (!element.TryGetProperty(segment, out element))
            {
                return false;
            }
        }

        return true;
    }
}
