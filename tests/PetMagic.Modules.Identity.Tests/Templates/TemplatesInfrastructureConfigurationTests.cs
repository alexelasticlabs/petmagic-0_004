using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesInfrastructureConfigurationTests
{
    [Fact]
    public void AddTemplatesInfrastructure_ShouldUseLocalAndFakeProviders_ByDefault()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();

        var options = provider.GetRequiredService<TemplatesOptions>();
        var mediaStorage = provider.GetRequiredService<IMediaStorage>();
        var imagePreprocessor = provider.GetRequiredService<IImagePreprocessor>();
        var videoMotionGenerator = provider.GetRequiredService<IVideoMotionGenerator>();
        var generatedMediaImporter = provider.GetRequiredService<IGeneratedMediaImporter>();
        var hostedServices = provider.GetServices<IHostedService>();

        Assert.Equal(TemplateStorageProviders.Local, options.StorageProvider);
        Assert.Equal(TemplateAiProviders.Fake, options.AiProvider);
        Assert.False(options.SeedSampleTemplates);
        Assert.True(options.GenerationWorkerEnabled);
        Assert.Equal(1_000, options.GenerationWorkerPollIntervalMilliseconds);
        Assert.Equal(1_000, options.RealtimePollingIntervalMilliseconds);
        Assert.Equal(60, options.RealtimeEventRetentionMinutes);
        Assert.Equal(10, options.RealtimeEventCleanupIntervalMinutes);
        Assert.Equal(1_000, options.RealtimeEventCleanupBatchSize);
        Assert.Equal(1, options.MaxConcurrentJobsPerWorker);
        Assert.Equal(3, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(0, options.ImageReservedConcurrentGenerations);
        Assert.Equal(2, options.ImageMaxConcurrentGenerations);
        Assert.Equal(0, options.ImageProtectedConcurrentGenerations);
        Assert.Equal(0, options.VideoReservedConcurrentGenerations);
        Assert.Equal(1, options.VideoMaxConcurrentGenerations);
        Assert.Equal(0, options.VideoBorrowMaxConcurrentGenerations);
        Assert.False(options.EnableElasticLaneBorrowing);
        Assert.False(options.QaFixturesEnabled);
        Assert.True(options.AllowVideoBorrowWhenImageQueueEmpty);
        Assert.Equal(120, options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds);
        Assert.Equal("natural_completion", options.VideoBorrowReleaseMode);
        Assert.Equal(1, options.VideoPreprocessingMaxConcurrentGenerations);
        Assert.Equal(0, options.FalProviderConcurrencyLimit);
        Assert.Equal(1, options.FalProviderReservedConcurrency);
        Assert.Equal(100m, options.FalProviderBalanceLowThresholdUsd);
        Assert.Equal(25m, options.FalProviderBalanceCriticalThresholdUsd);
        Assert.Equal(0m, options.FalProviderSpendDailyLimitUsd);
        Assert.Equal(60, options.MaxAiProviderRequestsPerMinute);
        Assert.Equal(900_000, options.JobLockTimeoutMilliseconds);
        Assert.Equal(1_000, options.QueueMaxSize);
        Assert.Equal(420, options.EstimatedVideoGenerationSeconds);
        Assert.Equal(90, options.EstimatedImageGenerationSeconds);
        Assert.Equal(90, options.EstimatedVideoPreprocessingSeconds);
        Assert.Equal(1_000, options.FreeQueuePriorityScore);
        Assert.Equal(4_000, options.PremiumQueuePriorityScore);
        Assert.Equal(8_000, options.PrivilegedQueuePriorityScore);
        Assert.Equal(10_000, options.AdminQueuePriorityScore);
        Assert.Equal(60, options.QueuePriorityAgingIntervalSeconds);
        Assert.Equal(500, options.QueuePriorityAgingBoost);
        Assert.True(options.CancelQueuedGenerationEnabled);
        Assert.Equal(1_800, options.FreeImageMaxEstimatedWaitSeconds);
        Assert.Equal(600, options.PremiumImageMaxEstimatedWaitSeconds);
        Assert.Equal(3_600, options.FreeVideoMaxEstimatedWaitSeconds);
        Assert.Equal(1_800, options.PremiumVideoMaxEstimatedWaitSeconds);
        Assert.Equal(1, options.FreeUserMaxActiveGenerations);
        Assert.Equal(3, options.PremiumUserMaxActiveGenerations);
        Assert.Equal(10, options.PrivilegedUserMaxActiveGenerations);
        Assert.Equal(900_000, options.StaleProcessingRecoveryDelayMilliseconds);
        Assert.Equal(120_000, options.OrphanQueuedJobTimeoutMilliseconds);
        Assert.Equal(3, options.MaxGenerationAttempts);
        Assert.Equal(5, options.MaxRefundAttempts);
        Assert.Equal(30_000, options.RefundRetryDelayMilliseconds);
        Assert.Equal(7, options.GenerationRetentionDaysAfterCompletion);
        Assert.Equal(60, options.TemporaryUploadRetentionMinutes);
        Assert.True(options.MediaCleanupWorkerEnabled);
        Assert.Equal(1_000, options.MediaCleanupPollIntervalMilliseconds);
        Assert.Equal(30_000, options.MediaCleanupRetryDelayMilliseconds);
        Assert.Equal(24, options.MetadataTempRetentionHours);
        Assert.True(options.CleanupExpiredGenerationMediaWhileRefundPending);
        Assert.Equal(250 * 1024 * 1024, options.GeneratedVideoMaxFileSizeBytes);
        Assert.Equal("LocalFileMediaStorage", mediaStorage.GetType().Name);
        Assert.Equal("FakeImagePreprocessor", imagePreprocessor.GetType().Name);
        Assert.Equal("FakeVideoMotionGenerator", videoMotionGenerator.GetType().Name);
        Assert.Equal("FakeGeneratedMediaImporter", generatedMediaImporter.GetType().Name);
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateGenerationWorker");
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateMediaCleanupWorker");
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldUseExplicitSchedulerComponent_WhenProvided()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GenerationWorkerEnabled"] = "true"
        });

        services.AddTemplatesInfrastructure(
            configuration,
            schedulerComponent: TemplateSchedulerConfigFingerprint.ApiComponent);

        using var provider = services.BuildServiceProvider();

        var component = provider.GetRequiredService<TemplateSchedulerConfigComponent>();
        Assert.Equal(TemplateSchedulerConfigFingerprint.ApiComponent, component.Value);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRegisterR2AndFalProviders_WhenConfigured()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.example.test",
            ["Templates:R2:ObjectKeyPrefix"] = "templates-media-test",
            ["Templates:Fal:ApiKey"] = "test-fal-key",
            ["Templates:Fal:QueueBaseUrl"] = "https://queue.fal.run",
            ["Templates:Fal:ImageMaxPollingAttempts"] = "90",
            ["Templates:Fal:ImagePreprocessingMaxPollingAttempts"] = "100",
            ["Templates:Fal:VideoMaxPollingAttempts"] = "360",
            ["Templates:GenerationWorkerPollIntervalMilliseconds"] = "250",
            ["Templates:RealtimePollingIntervalMilliseconds"] = "500",
            ["Templates:RealtimeEventRetentionMinutes"] = "30",
            ["Templates:RealtimeEventCleanupIntervalMinutes"] = "5",
            ["Templates:RealtimeEventCleanupBatchSize"] = "250",
            ["Templates:MaxConcurrentJobsPerWorker"] = "2",
            ["Templates:GlobalMaxConcurrentGenerations"] = "5",
            ["Templates:ImageReservedConcurrentGenerations"] = "3",
            ["Templates:ImageMaxConcurrentGenerations"] = "4",
            ["Templates:ImageProtectedConcurrentGenerations"] = "2",
            ["Templates:VideoReservedConcurrentGenerations"] = "1",
            ["Templates:VideoMaxConcurrentGenerations"] = "2",
            ["Templates:VideoBorrowMaxConcurrentGenerations"] = "1",
            ["Templates:EnableElasticLaneBorrowing"] = "true",
            ["Templates:AllowVideoBorrowWhenImageQueueEmpty"] = "false",
            ["Templates:AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds"] = "90",
            ["Templates:VideoBorrowReleaseMode"] = "natural_completion",
            ["Templates:BorrowedVideoMaxAgeSeconds"] = "900",
            ["Templates:BorrowingPriorityTiers"] = "premium,free",
            ["Templates:VideoPreprocessingMaxConcurrentGenerations"] = "1",
            ["Templates:FalProviderConcurrencyLimit"] = "30",
            ["Templates:FalProviderReservedConcurrency"] = "2",
            ["Templates:FalProviderBalanceLowThresholdUsd"] = "150.50",
            ["Templates:FalProviderBalanceCriticalThresholdUsd"] = "50.25",
            ["Templates:FalProviderSpendDailyLimitUsd"] = "300.75",
            ["Templates:MaxAiProviderRequestsPerMinute"] = "12",
            ["Templates:JobLockTimeoutMilliseconds"] = "450000",
            ["Templates:QueueMaxSize"] = "25",
            ["Templates:EstimatedVideoGenerationSeconds"] = "180",
            ["Templates:EstimatedImageGenerationSeconds"] = "45",
            ["Templates:EstimatedVideoPreprocessingSeconds"] = "30",
            ["Templates:FreeQueuePriorityScore"] = "10",
            ["Templates:PremiumQueuePriorityScore"] = "40",
            ["Templates:PrivilegedQueuePriorityScore"] = "80",
            ["Templates:AdminQueuePriorityScore"] = "100",
            ["Templates:QueuePriorityAgingIntervalSeconds"] = "15",
            ["Templates:QueuePriorityAgingBoost"] = "5",
            ["Templates:CancelQueuedGenerationEnabled"] = "false",
            ["Templates:FreeImageMaxEstimatedWaitSeconds"] = "120",
            ["Templates:PremiumImageMaxEstimatedWaitSeconds"] = "60",
            ["Templates:PrivilegedImageMaxEstimatedWaitSeconds"] = "45",
            ["Templates:FreeVideoMaxEstimatedWaitSeconds"] = "3600",
            ["Templates:PremiumVideoMaxEstimatedWaitSeconds"] = "900",
            ["Templates:PrivilegedVideoMaxEstimatedWaitSeconds"] = "600",
            ["Templates:StaleProcessingRecoveryDelayMilliseconds"] = "600000",
            ["Templates:OrphanQueuedJobTimeoutMilliseconds"] = "45000",
            ["Templates:MaxGenerationAttempts"] = "4",
            ["Templates:MaxRefundAttempts"] = "6",
            ["Templates:RefundRetryDelayMilliseconds"] = "125",
            ["Templates:GenerationRetentionDaysAfterCompletion"] = "14",
            ["Templates:TemporaryUploadRetentionMinutes"] = "90",
            ["Templates:MediaCleanupWorkerEnabled"] = "false",
            ["Templates:MediaCleanupPollIntervalMilliseconds"] = "2500",
            ["Templates:MediaCleanupRetryDelayMilliseconds"] = "7500",
            ["Templates:MetadataTempRetentionHours"] = "48",
            ["Templates:CleanupExpiredGenerationMediaWhileRefundPending"] = "false",
            ["Templates:GeneratedVideoMaxFileSizeBytes"] = "1048576"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();

        var options = provider.GetRequiredService<TemplatesOptions>();
        var mediaStorage = provider.GetRequiredService<IMediaStorage>();
        var imagePreprocessor = provider.GetRequiredService<IImagePreprocessor>();
        var videoMotionGenerator = provider.GetRequiredService<IVideoMotionGenerator>();
        var generatedMediaImporter = provider.GetRequiredService<IGeneratedMediaImporter>();
        var hostedServices = provider.GetServices<IHostedService>();

        Assert.Equal(TemplateStorageProviders.R2, options.StorageProvider);
        Assert.Equal(TemplateAiProviders.Fal, options.AiProvider);
        Assert.Equal("petmagic-test", options.R2.BucketName);
        Assert.Equal("test-fal-key", options.Fal.ApiKey);
        Assert.Equal(90, options.Fal.ImageMaxPollingAttempts);
        Assert.Equal(100, options.Fal.ImagePreprocessingMaxPollingAttempts);
        Assert.Equal(360, options.Fal.VideoMaxPollingAttempts);
        Assert.Equal(250, options.GenerationWorkerPollIntervalMilliseconds);
        Assert.Equal(500, options.RealtimePollingIntervalMilliseconds);
        Assert.Equal(30, options.RealtimeEventRetentionMinutes);
        Assert.Equal(5, options.RealtimeEventCleanupIntervalMinutes);
        Assert.Equal(250, options.RealtimeEventCleanupBatchSize);
        Assert.Equal(2, options.MaxConcurrentJobsPerWorker);
        Assert.Equal(5, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(3, options.ImageReservedConcurrentGenerations);
        Assert.Equal(4, options.ImageMaxConcurrentGenerations);
        Assert.Equal(2, options.ImageProtectedConcurrentGenerations);
        Assert.Equal(1, options.VideoReservedConcurrentGenerations);
        Assert.Equal(2, options.VideoMaxConcurrentGenerations);
        Assert.Equal(1, options.VideoBorrowMaxConcurrentGenerations);
        Assert.True(options.EnableElasticLaneBorrowing);
        Assert.False(options.AllowVideoBorrowWhenImageQueueEmpty);
        Assert.Equal(90, options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds);
        Assert.Equal("natural_completion", options.VideoBorrowReleaseMode);
        Assert.Equal(900, options.BorrowedVideoMaxAgeSeconds);
        Assert.Equal("premium,free", options.BorrowingPriorityTiers);
        Assert.Equal(1, options.VideoPreprocessingMaxConcurrentGenerations);
        Assert.Equal(30, options.FalProviderConcurrencyLimit);
        Assert.Equal(2, options.FalProviderReservedConcurrency);
        Assert.Equal(150.50m, options.FalProviderBalanceLowThresholdUsd);
        Assert.Equal(50.25m, options.FalProviderBalanceCriticalThresholdUsd);
        Assert.Equal(300.75m, options.FalProviderSpendDailyLimitUsd);
        Assert.Equal(12, options.MaxAiProviderRequestsPerMinute);
        Assert.Equal(450_000, options.JobLockTimeoutMilliseconds);
        Assert.Equal(25, options.QueueMaxSize);
        Assert.Equal(180, options.EstimatedVideoGenerationSeconds);
        Assert.Equal(45, options.EstimatedImageGenerationSeconds);
        Assert.Equal(30, options.EstimatedVideoPreprocessingSeconds);
        Assert.Equal(10, options.FreeQueuePriorityScore);
        Assert.Equal(40, options.PremiumQueuePriorityScore);
        Assert.Equal(80, options.PrivilegedQueuePriorityScore);
        Assert.Equal(100, options.AdminQueuePriorityScore);
        Assert.Equal(15, options.QueuePriorityAgingIntervalSeconds);
        Assert.Equal(5, options.QueuePriorityAgingBoost);
        Assert.False(options.CancelQueuedGenerationEnabled);
        Assert.Equal(120, options.FreeImageMaxEstimatedWaitSeconds);
        Assert.Equal(60, options.PremiumImageMaxEstimatedWaitSeconds);
        Assert.Equal(45, options.PrivilegedImageMaxEstimatedWaitSeconds);
        Assert.Equal(3600, options.FreeVideoMaxEstimatedWaitSeconds);
        Assert.Equal(900, options.PremiumVideoMaxEstimatedWaitSeconds);
        Assert.Equal(600, options.PrivilegedVideoMaxEstimatedWaitSeconds);
        Assert.Equal(600_000, options.StaleProcessingRecoveryDelayMilliseconds);
        Assert.Equal(45_000, options.OrphanQueuedJobTimeoutMilliseconds);
        Assert.Equal(4, options.MaxGenerationAttempts);
        Assert.Equal(6, options.MaxRefundAttempts);
        Assert.Equal(125, options.RefundRetryDelayMilliseconds);
        Assert.Equal(14, options.GenerationRetentionDaysAfterCompletion);
        Assert.Equal(90, options.TemporaryUploadRetentionMinutes);
        Assert.False(options.MediaCleanupWorkerEnabled);
        Assert.Equal(2500, options.MediaCleanupPollIntervalMilliseconds);
        Assert.Equal(7500, options.MediaCleanupRetryDelayMilliseconds);
        Assert.Equal(48, options.MetadataTempRetentionHours);
        Assert.False(options.CleanupExpiredGenerationMediaWhileRefundPending);
        Assert.Equal(1024 * 1024, options.GeneratedVideoMaxFileSizeBytes);
        Assert.Equal("R2MediaStorage", mediaStorage.GetType().Name);
        Assert.Equal("FalImagePreprocessor", imagePreprocessor.GetType().Name);
        Assert.Equal("FalVideoMotionGenerator", videoMotionGenerator.GetType().Name);
        Assert.Equal("HttpGeneratedMediaImporter", generatedMediaImporter.GetType().Name);
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateGenerationWorker");
        Assert.DoesNotContain(hostedServices, service => service.GetType().Name == "TemplateMediaCleanupWorker");
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldConfigureExternalHttpClientTimeouts()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.example.test",
            ["Templates:Fal:ApiKey"] = "test-fal-key",
            ["Templates:Fal:StartTimeoutSeconds"] = "120"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var httpClientFactory = provider.GetRequiredService<IHttpClientFactory>();

        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(150), httpClientFactory.CreateClient(FalQueueClient.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient(FalProviderHealthService.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(5), httpClientFactory.CreateClient(TemplateContentHealthCheck.HttpClientName).Timeout);
    }

    [Fact]
    public void TemplateHttpClientsThatProbeMedia_ShouldNotFollowRedirects()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesInfrastructureServiceCollectionExtensions.cs"));

        Assert.Contains("TemplateContentHealthCheck.HttpClientName", source, StringComparison.Ordinal);
        Assert.Contains("HttpGeneratedMediaImporter.HttpClientName", source, StringComparison.Ordinal);
        Assert.Contains(".ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler", source, StringComparison.Ordinal);
        Assert.True(
            source.Split("AllowAutoRedirect = false", StringSplitOptions.None).Length >= 3,
            "Template content health and generated media import HTTP clients must both disable automatic redirects.");
    }

    [Fact]
    public void TemplateMediaNetworkSafetyPolicy_ShouldStayShared()
    {
        var root = FindRepositoryRoot();
        var policySource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "SafeNetworkTargetPolicy.cs"));

        Assert.Contains("IsPrivateNetworkTarget", policySource, StringComparison.Ordinal);
        Assert.Contains("IsPrivateNetworkAddress", policySource, StringComparison.Ordinal);

        foreach (var relativePath in new[]
        {
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateContentHealthCheck.cs"),
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "HttpGeneratedMediaImporter.cs")
        })
        {
            var source = File.ReadAllText(Path.Combine(root, relativePath));
            Assert.Contains("SafeNetworkTargetPolicy.IsPrivateNetworkTarget", source, StringComparison.Ordinal);
            Assert.DoesNotContain("static bool IsPrivateNetworkAddress", source, StringComparison.Ordinal);
            Assert.DoesNotContain("IPAddress.TryParse", source, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldNotRegisterHostedGenerationWorker_WhenDisabled()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GenerationWorkerEnabled"] = "false"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();

        var options = provider.GetRequiredService<TemplatesOptions>();
        var hostedServices = provider.GetServices<IHostedService>();

        Assert.False(options.GenerationWorkerEnabled);
        Assert.NotEmpty(provider.GetServices<IImagePreprocessor>());
        Assert.NotEmpty(provider.GetServices<IImageGenerator>());
        Assert.NotEmpty(provider.GetServices<IVideoMotionGenerator>());
        Assert.NotEmpty(provider.GetServices<IGeneratedMediaImporter>());
        Assert.NotEmpty(provider.GetServices<TemplateGenerationJobProcessor>());
        Assert.NotEmpty(provider.GetServices<ITemplateGenerationProviderCallbackService>());
        Assert.DoesNotContain(hostedServices, service => service.GetType().Name == "TemplateGenerationWorker");
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateMediaCleanupWorker");
    }

    [Theory]
    [InlineData("2", "3", "1")]
    [InlineData("2", "1", "3")]
    public void AddTemplatesInfrastructure_ShouldRejectMediaConcurrencyCapAboveGlobal(
        string globalCap,
        string imageCap,
        string videoCap)
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GlobalMaxConcurrentGenerations"] = globalCap,
            ["Templates:ImageMaxConcurrentGenerations"] = imageCap,
            ["Templates:VideoMaxConcurrentGenerations"] = videoCap
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration));

        Assert.Contains("media concurrency limits cannot exceed", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldAllowMediaCapSumAboveGlobalBecauseGlobalCapIsUpperBound()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GlobalMaxConcurrentGenerations"] = "3",
            ["Templates:ImageMaxConcurrentGenerations"] = "2",
            ["Templates:VideoMaxConcurrentGenerations"] = "2"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<TemplatesOptions>();

        Assert.Equal(3, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(2, options.ImageMaxConcurrentGenerations);
        Assert.Equal(2, options.VideoMaxConcurrentGenerations);
    }

    [Theory]
    [InlineData(10, 8, 3, 3, 7, 2, 4, 2, 2)]
    [InlineData(30, 24, 8, 6, 21, 5, 14, 9, 4)]
    [InlineData(40, 32, 12, 8, 28, 8, 20, 12, 4)]
    public void AddTemplatesInfrastructure_ShouldAcceptElasticFalConcurrencyProfiles(
        int falConcurrency,
        int global,
        int imageReserved,
        int imageProtected,
        int imageMax,
        int videoReserved,
        int videoMax,
        int videoBorrowMax,
        int maxConcurrentJobsPerWorker)
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GlobalMaxConcurrentGenerations"] = global.ToString(),
            ["Templates:ImageReservedConcurrentGenerations"] = imageReserved.ToString(),
            ["Templates:ImageProtectedConcurrentGenerations"] = imageProtected.ToString(),
            ["Templates:ImageMaxConcurrentGenerations"] = imageMax.ToString(),
            ["Templates:VideoReservedConcurrentGenerations"] = videoReserved.ToString(),
            ["Templates:VideoMaxConcurrentGenerations"] = videoMax.ToString(),
            ["Templates:VideoBorrowMaxConcurrentGenerations"] = videoBorrowMax.ToString(),
            ["Templates:EnableElasticLaneBorrowing"] = "true",
            ["Templates:MaxConcurrentJobsPerWorker"] = maxConcurrentJobsPerWorker.ToString(),
            ["Templates:FalProviderConcurrencyLimit"] = falConcurrency.ToString(),
            ["Templates:FalProviderReservedConcurrency"] = "2"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<TemplatesOptions>();

        Assert.Equal(global, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(imageReserved, options.ImageReservedConcurrentGenerations);
        Assert.Equal(imageProtected, options.ImageProtectedConcurrentGenerations);
        Assert.Equal(imageMax, options.ImageMaxConcurrentGenerations);
        Assert.Equal(videoReserved, options.VideoReservedConcurrentGenerations);
        Assert.Equal(videoMax, options.VideoMaxConcurrentGenerations);
        Assert.Equal(videoBorrowMax, options.VideoBorrowMaxConcurrentGenerations);
        Assert.True(options.EnableElasticLaneBorrowing);
        Assert.Equal(maxConcurrentJobsPerWorker, options.MaxConcurrentJobsPerWorker);
        Assert.Equal(falConcurrency, options.FalProviderConcurrencyLimit);
        Assert.Equal(2, options.FalProviderReservedConcurrency);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectMisorderedMaxEstimatedWaitThresholds()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:FreeVideoMaxEstimatedWaitSeconds"] = "900",
            ["Templates:PremiumVideoMaxEstimatedWaitSeconds"] = "1800"
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration));

        Assert.Contains("Privileged <= Premium <= Free", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectR2Provider_WhenRequiredSettingsAreMissing()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration));

        Assert.Contains("R2 media storage is selected", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectImplicitProviders_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Templates:StorageProvider", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectLocalStorage_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:StorageProvider"] = TemplateStorageProviders.Local,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Local templates media storage", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectNoopBilling_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.example.test",
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Economy-backed template generation billing", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectSampleTemplateSeed_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:SeedSampleTemplates"] = "true",
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.example.test",
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Sample template seed data", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldRejectQaFixtures_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:QaFixturesEnabled"] = "true",
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.example.test",
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Template QA fixtures", exception.Message);
    }

    [Theory]
    [InlineData("http://localhost:5000")]
    [InlineData("https://127.0.0.1:5000")]
    [InlineData("https://[::1]:5000")]
    [InlineData("https://cdn.petmagic.app/templates?token=secret")]
    public void AddTemplatesInfrastructure_ShouldRejectUnsafePublicBaseUrl_InProduction(string publicBaseUrl)
    {
        var services = CreateServices();
        services.AddScoped<IEconomyService>(_ => throw new NotSupportedException("Test stub"));
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = publicBaseUrl,
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.petmagic.app/r2",
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Templates:PublicBaseUrl", exception.Message);
    }

    [Theory]
    [InlineData("http://localhost:5000")]
    [InlineData("https://127.0.0.1:5000")]
    [InlineData("https://cdn.petmagic.app/r2#assets")]
    public void AddTemplatesInfrastructure_ShouldRejectUnsafeR2PublicBaseUrl_InProduction(string r2PublicBaseUrl)
    {
        var services = CreateServices();
        services.AddScoped<IEconomyService>(_ => throw new NotSupportedException("Test stub"));
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = r2PublicBaseUrl,
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddTemplatesInfrastructure(configuration, environment));

        Assert.Contains("Templates:R2:PublicBaseUrl", exception.Message);
    }

    [Fact]
    public void AddTemplatesInfrastructure_ShouldAllowHttpsPublicBaseUrls_InProduction()
    {
        var services = CreateServices();
        services.AddScoped<IEconomyService>(_ => throw new NotSupportedException("Test stub"));
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
            ["Templates:StorageProvider"] = TemplateStorageProviders.R2,
            ["Templates:AiProvider"] = TemplateAiProviders.Fal,
            ["Templates:R2:AccountId"] = "test-account",
            ["Templates:R2:AccessKey"] = "test-access-key",
            ["Templates:R2:SecretKey"] = "test-secret-key",
            ["Templates:R2:BucketName"] = "petmagic-test",
            ["Templates:R2:PublicBaseUrl"] = "https://cdn.petmagic.app/r2",
            ["Templates:Fal:ApiKey"] = "test-fal-key"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        services.AddTemplatesInfrastructure(configuration, environment);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("true")]
    public void RequireGenerationWorkerMode_ShouldRejectEnabledGenerationWorker_ForProductionApiHost(string? configuredValue)
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GenerationWorkerEnabled"] = configuredValue
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() =>
            TemplateGenerationHostModeValidator.RequireGenerationWorkerMode(
                configuration,
                environment,
                "PetMagic.Host.Api",
                expectedEnabled: false));

        Assert.Contains("Templates:GenerationWorkerEnabled=false", exception.Message);
    }

    [Fact]
    public void RequireGenerationWorkerMode_ShouldRejectDisabledGenerationWorker_ForProductionWorkerHost()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GenerationWorkerEnabled"] = "false"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };

        var exception = Assert.Throws<InvalidOperationException>(() =>
            TemplateGenerationHostModeValidator.RequireGenerationWorkerMode(
                configuration,
                environment,
                "PetMagic.Host.GenerationWorker",
                expectedEnabled: true));

        Assert.Contains("Templates:GenerationWorkerEnabled=true", exception.Message);
    }

    [Fact]
    public void RequireGenerationWorkerMode_ShouldAllowDevelopmentHostOverrides()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Templates:GenerationWorkerEnabled"] = "true"
        });
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Development
        };

        TemplateGenerationHostModeValidator.RequireGenerationWorkerMode(
            configuration,
            environment,
            "PetMagic.Host.Api",
            expectedEnabled: false);
    }

    private static IConfiguration CreateConfiguration(IEnumerable<KeyValuePair<string, string?>> values)
    {
        var defaults = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = "Host=localhost;Database=petmagic_tests;Username=test;Password=test",
            ["Templates:PublicBaseUrl"] = "http://localhost:5000",
            ["Templates:LocalMediaRootPath"] = "wwwroot/templates-media"
        };

        foreach (var value in values)
        {
            defaults[value.Key] = value.Value;
        }

        return new ConfigurationBuilder()
            .AddInMemoryCollection(defaults)
            .Build();
    }

    private static ServiceCollection CreateServices()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IHostEnvironment>(new TestHostEnvironment(Directory.GetCurrentDirectory()));
        return services;
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

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
