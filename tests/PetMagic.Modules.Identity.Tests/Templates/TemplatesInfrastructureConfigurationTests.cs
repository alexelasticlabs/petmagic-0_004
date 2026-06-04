using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

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
        Assert.True(options.GenerationWorkerEnabled);
        Assert.Equal(1_000, options.GenerationWorkerPollIntervalMilliseconds);
        Assert.Equal(1, options.MaxConcurrentJobsPerWorker);
        Assert.Equal(3, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(60, options.MaxAiProviderRequestsPerMinute);
        Assert.Equal(900_000, options.JobLockTimeoutMilliseconds);
        Assert.Equal(1_000, options.QueueMaxSize);
        Assert.Equal(120, options.EstimatedVideoGenerationSeconds);
        Assert.Equal(60, options.EstimatedImageGenerationSeconds);
        Assert.Equal(1, options.FreeUserMaxActiveGenerations);
        Assert.Equal(3, options.PremiumUserMaxActiveGenerations);
        Assert.Equal(10, options.PrivilegedUserMaxActiveGenerations);
        Assert.Equal(900_000, options.StaleProcessingRecoveryDelayMilliseconds);
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
            ["Templates:GenerationWorkerPollIntervalMilliseconds"] = "250",
            ["Templates:MaxConcurrentJobsPerWorker"] = "2",
            ["Templates:GlobalMaxConcurrentGenerations"] = "5",
            ["Templates:MaxAiProviderRequestsPerMinute"] = "12",
            ["Templates:JobLockTimeoutMilliseconds"] = "450000",
            ["Templates:QueueMaxSize"] = "25",
            ["Templates:EstimatedVideoGenerationSeconds"] = "180",
            ["Templates:EstimatedImageGenerationSeconds"] = "45",
            ["Templates:StaleProcessingRecoveryDelayMilliseconds"] = "600000",
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
        Assert.Equal(250, options.GenerationWorkerPollIntervalMilliseconds);
        Assert.Equal(2, options.MaxConcurrentJobsPerWorker);
        Assert.Equal(5, options.GlobalMaxConcurrentGenerations);
        Assert.Equal(12, options.MaxAiProviderRequestsPerMinute);
        Assert.Equal(450_000, options.JobLockTimeoutMilliseconds);
        Assert.Equal(25, options.QueueMaxSize);
        Assert.Equal(180, options.EstimatedVideoGenerationSeconds);
        Assert.Equal(45, options.EstimatedImageGenerationSeconds);
        Assert.Equal(600_000, options.StaleProcessingRecoveryDelayMilliseconds);
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
    public void AddTemplatesInfrastructure_ShouldNotRegisterGenerationWorker_WhenDisabled()
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
        Assert.Empty(provider.GetServices<IImagePreprocessor>());
        Assert.Empty(provider.GetServices<IImageGenerator>());
        Assert.Empty(provider.GetServices<IVideoMotionGenerator>());
        Assert.Empty(provider.GetServices<IGeneratedMediaImporter>());
        Assert.Empty(provider.GetServices<TemplateGenerationJobProcessor>());
        Assert.DoesNotContain(hostedServices, service => service.GetType().Name == "TemplateGenerationWorker");
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateMediaCleanupWorker");
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

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
