using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateSchedulerConfigFingerprintTests
{
    [Fact]
    public void Create_ShouldReturnSameChecksum_ForSameSchedulerConfig()
    {
        var options = CreateOptions();

        var api = TemplateSchedulerConfigFingerprint.Create(
            options,
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);
        var worker = TemplateSchedulerConfigFingerprint.Create(
            options,
            "Staging",
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent);

        Assert.Equal(api.Checksum, worker.Checksum);
        Assert.Equal(api.CanonicalJson, worker.CanonicalJson);
    }

    [Fact]
    public void Create_ShouldIgnoreRuntimePolicyConcurrency_WhenGlobalCapChanges()
    {
        var first = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(globalMaxConcurrentGenerations: 3),
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);
        var second = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(globalMaxConcurrentGenerations: 4),
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);

        Assert.Equal(first.Checksum, second.Checksum);
    }

    [Fact]
    public void Create_ShouldReturnDifferentChecksum_WhenSchedulerModeChanges()
    {
        var compatibility = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(generationSchedulerV2Enabled: false),
            "Production",
            TemplateSchedulerConfigFingerprint.ApiComponent);
        var schedulerV2 = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(generationSchedulerV2Enabled: true),
            "Production",
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent);

        Assert.NotEqual(compatibility.Checksum, schedulerV2.Checksum);
        Assert.Contains("generationSchedulerV2Enabled", compatibility.CanonicalJson, StringComparison.Ordinal);
    }

    [Fact]
    public void Create_ShouldIgnoreWorkerOnlyLoopAndUnusedSpendSettings()
    {
        var firstOptions = CreateOptions();
        var secondOptions = CreateOptions(
            generationWorkerPollIntervalMilliseconds: 250,
            generationDispatchConcurrency: 12,
            providerReconciliationConcurrency: 9,
            mediaImportConcurrency: 3,
            generationMaintenanceConcurrency: 2,
            falProviderSpendDailyLimitUsd: 999m);
        var first = TemplateSchedulerConfigFingerprint.Create(
            firstOptions,
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);
        var second = TemplateSchedulerConfigFingerprint.Create(
            secondOptions,
            "Staging",
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent);

        Assert.Equal(first.Checksum, second.Checksum);
        Assert.DoesNotContain("falProviderSpendDailyLimitUsd", first.CanonicalJson, StringComparison.Ordinal);
        Assert.DoesNotContain("generationWorkerPollIntervalMilliseconds", first.CanonicalJson, StringComparison.Ordinal);
        Assert.DoesNotContain("generationDispatchConcurrency", first.CanonicalJson, StringComparison.Ordinal);
    }

    [Fact]
    public void Create_ShouldReturnDifferentChecksum_WhenMaxWaitChanges()
    {
        var first = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(freeImageMaxEstimatedWaitSeconds: 1_800),
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);
        var second = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(freeImageMaxEstimatedWaitSeconds: 1_801),
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);

        Assert.NotEqual(first.Checksum, second.Checksum);
    }

    [Fact]
    public void Create_ShouldNotIncludeSecretsInSanitizedDumpOrCanonicalJson()
    {
        const string r2AccessKey = "test-r2-access-secret";
        const string r2SecretKey = "test-r2-secret-key";
        const string falApiKey = "test-fal-api-secret";
        const string firebaseSecret = "test-firebase-service-account-secret";
        const string webhookSecret = "https://webhook.example.test/test-secret";
        var fingerprint = TemplateSchedulerConfigFingerprint.Create(
            CreateOptions(
                r2AccessKey: r2AccessKey,
                r2SecretKey: r2SecretKey,
                falApiKey: falApiKey,
                firebaseServiceAccountJson: firebaseSecret,
                falWebhookUrl: webhookSecret),
            "Staging",
            TemplateSchedulerConfigFingerprint.ApiComponent);

        Assert.DoesNotContain(r2AccessKey, fingerprint.SanitizedDumpJson);
        Assert.DoesNotContain(r2SecretKey, fingerprint.SanitizedDumpJson);
        Assert.DoesNotContain(falApiKey, fingerprint.SanitizedDumpJson);
        Assert.DoesNotContain(firebaseSecret, fingerprint.SanitizedDumpJson);
        Assert.DoesNotContain(webhookSecret, fingerprint.SanitizedDumpJson);
        Assert.DoesNotContain(r2AccessKey, fingerprint.CanonicalJson);
        Assert.DoesNotContain(r2SecretKey, fingerprint.CanonicalJson);
        Assert.DoesNotContain(falApiKey, fingerprint.CanonicalJson);
        Assert.DoesNotContain(firebaseSecret, fingerprint.CanonicalJson);
        Assert.DoesNotContain(webhookSecret, fingerprint.CanonicalJson);
    }

    [Fact]
    public async Task StartupService_ShouldIgnoreStaleMismatchRows_WhenRecoveringAfterConfigFix()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-startup-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var options = CreateOptions();
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = Environments.Development,
                Checksum = "stale-worker-checksum",
                ConfigJson = "{}",
                StartedAtUtc = DateTime.UtcNow.AddMinutes(-5),
                LastSeenAtUtc = DateTime.UtcNow.AddMinutes(-5),
                MismatchDetected = true,
                MismatchDetails = "stale failed worker start"
            });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.ApiComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);

        Assert.True(runtimeState.Snapshot.Initialized);
        Assert.False(runtimeState.Snapshot.IsMismatchDetected);
        await startupService.StopAsync(CancellationToken.None);
        await using var verificationScope = provider.CreateAsyncScope();
        var verificationDbContext = verificationScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var latestApi = await verificationDbContext.TemplateRuntimeConfigFingerprints
            .Where(x => x.Component == TemplateSchedulerConfigFingerprint.ApiComponent)
            .OrderByDescending(x => x.StartedAtUtc)
            .FirstAsync();
        Assert.False(latestApi.MismatchDetected);
    }

    [Fact]
    public async Task StartupService_ShouldIgnoreStaleSuccessfulRows_WhenCounterpartIsNotCurrentlyAlive()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-stale-success-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var now = DateTime.UtcNow;
        var options = CreateOptions();
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = Environments.Development,
                Checksum = "stale-successful-worker-checksum",
                ConfigJson = "{}",
                StartedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10),
                MismatchDetected = false
            });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.ApiComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);

        Assert.True(runtimeState.Snapshot.Initialized);
        Assert.False(runtimeState.Snapshot.IsMismatchDetected);
        await startupService.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task StartupService_ShouldPersistGenerationWorkerRuntimeConfiguration()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-worker-runtime-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var options = CreateOptions(
            generationSchedulerV2Enabled: true,
            generationDispatchConcurrency: 8,
            providerReconciliationConcurrency: 7,
            mediaImportConcurrency: 2,
            generationMaintenanceConcurrency: 3);
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.GenerationWorkerComponent),
            new TestHostEnvironment(Environments.Development),
            new TemplateSchedulerConfigRuntimeState(),
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);
        await startupService.StopAsync(CancellationToken.None);

        await using var verificationScope = provider.CreateAsyncScope();
        var dbContext = verificationScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var fingerprint = await dbContext.TemplateRuntimeConfigFingerprints.SingleAsync();
        Assert.True(fingerprint.GenerationSchedulerV2Enabled);
        Assert.Equal(8, fingerprint.GenerationDispatchConcurrency);
        Assert.Equal(7, fingerprint.ProviderReconciliationConcurrency);
        Assert.Equal(2, fingerprint.MediaImportConcurrency);
        Assert.Equal(3, fingerprint.GenerationMaintenanceConcurrency);
    }

    [Fact]
    public async Task StartupService_ShouldDetectActiveCounterpartMismatch()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-active-mismatch-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var now = DateTime.UtcNow;
        var options = CreateOptions();
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = Environments.Development,
                Checksum = "active-worker-checksum",
                ConfigJson = "{}",
                StartedAtUtc = now,
                LastSeenAtUtc = now,
                MismatchDetected = false
            });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.ApiComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);

        Assert.True(runtimeState.Snapshot.Initialized);
        Assert.True(runtimeState.Snapshot.IsMismatchDetected);
        Assert.Contains("active-worker-checksum", runtimeState.Snapshot.MismatchDetails, StringComparison.Ordinal);
        await startupService.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task StartupService_ApiHeartbeat_ShouldConvergeAfterMatchingWorkerRevisionStarts()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-rolling-api-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var now = DateTime.UtcNow;
        var options = CreateOptions(generationSchedulerV2Enabled: true);
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = Environments.Development,
                Checksum = "previous-worker-revision",
                ConfigJson = "{}",
                StartedAtUtc = now,
                LastSeenAtUtc = now,
                MismatchDetected = false
            });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.ApiComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);
        Assert.True(runtimeState.Snapshot.IsMismatchDetected);

        Guid apiFingerprintId;
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var apiFingerprint = await dbContext.TemplateRuntimeConfigFingerprints
                .SingleAsync(x => x.Component == TemplateSchedulerConfigFingerprint.ApiComponent);
            apiFingerprintId = apiFingerprint.Id;
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                ProfileName = Environments.Development,
                Checksum = apiFingerprint.Checksum,
                ConfigJson = "{}",
                StartedAtUtc = now.AddSeconds(1),
                LastSeenAtUtc = DateTime.UtcNow,
                MismatchDetected = false
            });
            await dbContext.SaveChangesAsync();
        }

        Assert.True(await startupService.RefreshHeartbeatAsync(apiFingerprintId, CancellationToken.None));
        Assert.False(runtimeState.Snapshot.IsMismatchDetected);
        await startupService.StopAsync(CancellationToken.None);

        await using var verificationScope = provider.CreateAsyncScope();
        var verificationDbContext = verificationScope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var persistedApi = await verificationDbContext.TemplateRuntimeConfigFingerprints
            .SingleAsync(x => x.Id == apiFingerprintId);
        Assert.False(persistedApi.MismatchDetected);
        Assert.Null(persistedApi.MismatchDetails);
    }

    [Fact]
    public async Task StartupService_WorkerShouldUseLatestRollingApiFingerprint_EvenWhenApiRowWasInitiallyMismatch()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-rolling-worker-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var now = DateTime.UtcNow;
        var options = CreateOptions(generationSchedulerV2Enabled: true);
        var expectedChecksum = TemplateSchedulerConfigFingerprint.Create(
            options,
            Environments.Development,
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent).Checksum;
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.AddRange(
                new TemplateRuntimeConfigFingerprint
                {
                    Id = Guid.NewGuid(),
                    Component = TemplateSchedulerConfigFingerprint.ApiComponent,
                    ProfileName = Environments.Development,
                    Checksum = "previous-api-revision",
                    ConfigJson = "{}",
                    StartedAtUtc = now.AddSeconds(-1),
                    LastSeenAtUtc = now,
                    MismatchDetected = false
                },
                new TemplateRuntimeConfigFingerprint
                {
                    Id = Guid.NewGuid(),
                    Component = TemplateSchedulerConfigFingerprint.ApiComponent,
                    ProfileName = Environments.Development,
                    Checksum = expectedChecksum,
                    ConfigJson = "{}",
                    StartedAtUtc = now,
                    LastSeenAtUtc = now,
                    MismatchDetected = true,
                    MismatchDetails = "waiting for matching worker rollout"
                });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.GenerationWorkerComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await startupService.StartAsync(CancellationToken.None);

        Assert.True(runtimeState.Snapshot.Initialized);
        Assert.False(runtimeState.Snapshot.IsMismatchDetected);
        Assert.Equal(expectedChecksum, runtimeState.Snapshot.Checksum);
        await startupService.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task StartupService_ShouldThrow_WhenGenerationWorkerDetectsActiveCounterpartMismatch()
    {
        var services = new ServiceCollection();
        var databaseName = $"scheduler-config-worker-active-mismatch-{Guid.NewGuid():N}";
        services.AddDbContext<TemplatesDbContext>(options => options.UseInMemoryDatabase(databaseName));
        await using var provider = services.BuildServiceProvider();
        var now = DateTime.UtcNow;
        var options = CreateOptions();
        await using (var scope = provider.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
                Component = TemplateSchedulerConfigFingerprint.ApiComponent,
                ProfileName = Environments.Development,
                Checksum = "active-api-checksum",
                ConfigJson = "{}",
                StartedAtUtc = now,
                LastSeenAtUtc = now,
                MismatchDetected = false
            });
            await dbContext.SaveChangesAsync();
        }

        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        var startupService = new TemplateSchedulerConfigStartupService(
            provider.GetRequiredService<IServiceScopeFactory>(),
            options,
            new TemplateSchedulerConfigComponent(TemplateSchedulerConfigFingerprint.GenerationWorkerComponent),
            new TestHostEnvironment(Environments.Development),
            runtimeState,
            new TemplateGenerationWorkerRuntimeState(),
            NullLogger<TemplateSchedulerConfigStartupService>.Instance);

        await Assert.ThrowsAnyAsync<InvalidOperationException>(() => startupService.StartAsync(CancellationToken.None));

        Assert.True(runtimeState.Snapshot.Initialized);
        Assert.True(runtimeState.Snapshot.IsMismatchDetected);
        Assert.Contains("active-api-checksum", runtimeState.Snapshot.MismatchDetails, StringComparison.Ordinal);
    }

    [Fact]
    public async Task HealthCheck_ShouldReportApiMismatchAsDegraded()
    {
        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        runtimeState.MarkMismatch(
            TemplateSchedulerConfigFingerprint.ApiComponent,
            Environments.Development,
            "api-checksum",
            "current=api:api-checksum; other=generation-worker:worker-checksum; profile=Development");
        var healthCheck = new TemplateSchedulerConfigHealthCheck(runtimeState);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Degraded, result.Status);
        Assert.Equal(true, result.Data["initialized"]);
        Assert.Equal(TemplateSchedulerConfigFingerprint.ApiComponent, result.Data["component"]);
        Assert.Equal("api-checksum", result.Data["checksum"]);
        Assert.Contains("worker-checksum", Assert.IsType<string>(result.Data["mismatchDetails"]), StringComparison.Ordinal);
    }

    [Fact]
    public async Task HealthCheck_ShouldReportGenerationWorkerMismatchAsUnhealthy()
    {
        var runtimeState = new TemplateSchedulerConfigRuntimeState();
        runtimeState.MarkMismatch(
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
            Environments.Development,
            "worker-checksum",
            "current=generation-worker:worker-checksum; other=api:api-checksum; profile=Development");
        var healthCheck = new TemplateSchedulerConfigHealthCheck(runtimeState);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Unhealthy, result.Status);
        Assert.Equal(true, result.Data["initialized"]);
        Assert.Equal(TemplateSchedulerConfigFingerprint.GenerationWorkerComponent, result.Data["component"]);
        Assert.Equal("worker-checksum", result.Data["checksum"]);
        Assert.Contains("api-checksum", Assert.IsType<string>(result.Data["mismatchDetails"]), StringComparison.Ordinal);
    }

    private static TemplatesOptions CreateOptions(
        int globalMaxConcurrentGenerations = 3,
        int freeImageMaxEstimatedWaitSeconds = 1_800,
        string r2AccessKey = "",
        string r2SecretKey = "",
        string falApiKey = "",
        string firebaseServiceAccountJson = "",
        string falWebhookUrl = "",
        int generationWorkerPollIntervalMilliseconds = 1_000,
        bool generationSchedulerV2Enabled = false,
        int generationDispatchConcurrency = 4,
        int providerReconciliationConcurrency = 4,
        int mediaImportConcurrency = 1,
        int generationMaintenanceConcurrency = 1,
        decimal falProviderSpendDailyLimitUsd = 0m)
    {
        return new TemplatesOptions
        {
            StorageProvider = TemplateStorageProviders.R2,
            AiProvider = TemplateAiProviders.Fal,
            PublicBaseUrl = "https://api.example.test",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "motion",
            DefaultImagePrompt = "image",
            AllowedImageModels = ["image-model"],
            AllowedPreprocessingModels = ["preprocessing-model"],
            AllowedKlingModels = ["video-model"],
            SupportedLocalizationLocales = ["ru", "de"],
            GenerationWorkerEnabled = false,
            GenerationWorkerPollIntervalMilliseconds = generationWorkerPollIntervalMilliseconds,
            GenerationSchedulerV2Enabled = generationSchedulerV2Enabled,
            GenerationDispatchConcurrency = generationDispatchConcurrency,
            ProviderReconciliationConcurrency = providerReconciliationConcurrency,
            MediaImportConcurrency = mediaImportConcurrency,
            GenerationMaintenanceConcurrency = generationMaintenanceConcurrency,
            FalProviderSpendDailyLimitUsd = falProviderSpendDailyLimitUsd,
            GlobalMaxConcurrentGenerations = globalMaxConcurrentGenerations,
            ImageReservedConcurrentGenerations = 1,
            ImageMaxConcurrentGenerations = 2,
            ImageProtectedConcurrentGenerations = 1,
            VideoReservedConcurrentGenerations = 1,
            VideoMaxConcurrentGenerations = 1,
            VideoBorrowMaxConcurrentGenerations = 1,
            EnableElasticLaneBorrowing = true,
            AllowVideoBorrowWhenImageQueueEmpty = true,
            AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds = 120,
            VideoBorrowReleaseMode = "natural_completion",
            BorrowedVideoMaxAgeSeconds = 900,
            BorrowingPriorityTiers = "premium,privileged,admin,free",
            VideoPreprocessingMaxConcurrentGenerations = 1,
            FalProviderConcurrencyLimit = 30,
            FalProviderReservedConcurrency = 2,
            MaxAiProviderRequestsPerMinute = 60,
            QueueMaxSize = 1_000,
            EstimatedVideoGenerationSeconds = 420,
            EstimatedImageGenerationSeconds = 90,
            EstimatedVideoPreprocessingSeconds = 90,
            FreeQueuePriorityScore = 1_000,
            PremiumQueuePriorityScore = 4_000,
            PrivilegedQueuePriorityScore = 8_000,
            AdminQueuePriorityScore = 10_000,
            QueuePriorityAgingIntervalSeconds = 60,
            QueuePriorityAgingBoost = 500,
            CancelQueuedGenerationEnabled = true,
            FreeImageMaxEstimatedWaitSeconds = freeImageMaxEstimatedWaitSeconds,
            PremiumImageMaxEstimatedWaitSeconds = 600,
            PrivilegedImageMaxEstimatedWaitSeconds = 600,
            FreeVideoMaxEstimatedWaitSeconds = 3_600,
            PremiumVideoMaxEstimatedWaitSeconds = 1_800,
            PrivilegedVideoMaxEstimatedWaitSeconds = 1_800,
            FreeUserMaxActiveGenerations = 1,
            PremiumUserMaxActiveGenerations = 3,
            PrivilegedUserMaxActiveGenerations = 10,
            JobLockTimeoutMilliseconds = 900_000,
            StaleProcessingRecoveryDelayMilliseconds = 900_000,
            OrphanQueuedJobTimeoutMilliseconds = 120_000,
            MaxGenerationAttempts = 3,
            MaxRefundAttempts = 5,
            RefundRetryDelayMilliseconds = 30_000,
            R2 = new R2StorageOptions
            {
                AccountId = "account",
                AccessKey = r2AccessKey,
                SecretKey = r2SecretKey,
                BucketName = "bucket",
                PublicBaseUrl = "https://cdn.example.test",
                ObjectKeyPrefix = "templates-media"
            },
            Fal = new FalAiOptions
            {
                ApiKey = falApiKey,
                QueueBaseUrl = "https://queue.fal.run",
                WebhookUrl = falWebhookUrl,
                WebhookJwksUrl = "https://rest.fal.ai/.well-known/jwks.json",
                StartTimeoutSeconds = 120,
                PollIntervalMilliseconds = 2_000,
                MaxPollingAttempts = 180,
                ImageMaxPollingAttempts = 180,
                ImagePreprocessingMaxPollingAttempts = 180,
                VideoMaxPollingAttempts = 300
            },
            FirebasePush = new FirebasePushOptions
            {
                Enabled = true,
                ProjectId = "firebase-project",
                ServiceAccountJson = firebaseServiceAccountJson
            }
        };
    }

    private sealed class TestHostEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = Directory.GetCurrentDirectory();

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
