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
        Assert.Equal(250 * 1024 * 1024, options.GeneratedVideoMaxFileSizeBytes);
        Assert.Equal("LocalFileMediaStorage", mediaStorage.GetType().Name);
        Assert.Equal("FakeImagePreprocessor", imagePreprocessor.GetType().Name);
        Assert.Equal("FakeVideoMotionGenerator", videoMotionGenerator.GetType().Name);
        Assert.Equal("FakeGeneratedMediaImporter", generatedMediaImporter.GetType().Name);
        Assert.Contains(hostedServices, service => service.GetType().Name == "TemplateGenerationWorker");
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
            ["Templates:GeneratedVideoMaxFileSizeBytes"] = "1048576"
        });

        services.AddTemplatesInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();

        var options = provider.GetRequiredService<TemplatesOptions>();
        var mediaStorage = provider.GetRequiredService<IMediaStorage>();
        var imagePreprocessor = provider.GetRequiredService<IImagePreprocessor>();
        var videoMotionGenerator = provider.GetRequiredService<IVideoMotionGenerator>();
        var generatedMediaImporter = provider.GetRequiredService<IGeneratedMediaImporter>();

        Assert.Equal(TemplateStorageProviders.R2, options.StorageProvider);
        Assert.Equal(TemplateAiProviders.Fal, options.AiProvider);
        Assert.Equal("petmagic-test", options.R2.BucketName);
        Assert.Equal("test-fal-key", options.Fal.ApiKey);
        Assert.Equal(250, options.GenerationWorkerPollIntervalMilliseconds);
        Assert.Equal(1024 * 1024, options.GeneratedVideoMaxFileSizeBytes);
        Assert.Equal("R2MediaStorage", mediaStorage.GetType().Name);
        Assert.Equal("FalImagePreprocessor", imagePreprocessor.GetType().Name);
        Assert.Equal("FalVideoMotionGenerator", videoMotionGenerator.GetType().Name);
        Assert.Equal("HttpGeneratedMediaImporter", generatedMediaImporter.GetType().Name);
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
