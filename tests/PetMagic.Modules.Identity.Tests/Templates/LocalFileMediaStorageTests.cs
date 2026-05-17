using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class LocalFileMediaStorageTests
{
    [Fact]
    public async Task DeleteAsync_ShouldRemoveManagedLocalFile()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var stored = await storage.StoreAsync(
                new MediaUploadCommand("preview.jpg", "image/jpeg", [1, 2, 3]),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.True(File.Exists(stored.Value.LocalPath));

            var deleted = await storage.DeleteAsync(stored.Value.Url, CancellationToken.None);

            Assert.True(deleted.IsSuccess);
            Assert.False(File.Exists(stored.Value.LocalPath));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    [Fact]
    public async Task DeleteAsync_ShouldIgnoreExternalUrl()
    {
        var rootPath = CreateTempDirectory();
        var storage = CreateStorage(rootPath);

        try
        {
            var deleted = await storage.DeleteAsync("https://cdn.example.com/preview.jpg", CancellationToken.None);

            Assert.True(deleted.IsSuccess);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static LocalFileMediaStorage CreateStorage(string rootPath)
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = rootPath,
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SeedSampleTemplates = false
        };

        return new LocalFileMediaStorage(options, new TestHostEnvironment(rootPath));
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-media-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
