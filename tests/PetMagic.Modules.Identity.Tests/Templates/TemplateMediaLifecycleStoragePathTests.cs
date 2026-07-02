using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateMediaLifecycleStoragePathTests
{
    [Theory]
    [InlineData(
        "http://localhost:5000/templates-media/2026/../private.png?pmexp=123",
        "http://localhost:5000/templates-media/2026/../private.png?pmexp=123")]
    [InlineData(
        "http://localhost:5000templates-media/2026/06/result.png",
        "http://localhost:5000templates-media/2026/06/result.png")]
    [InlineData(
        "https://cdn.petmagic.test/templates-media/2026/./private.png",
        "https://cdn.petmagic.test/templates-media/2026/./private.png")]
    public async Task RegisterTemporaryUploadAsync_ShouldNotPersistUnsafeManagedStoragePath(
        string assetUrl,
        string expectedStoragePath)
    {
        await using var dbContext = CreateDbContext();
        var service = new TemplateMediaLifecycleService(dbContext, CreateOptions());

        await service.RegisterTemporaryUploadAsync(
            new TemplateAssetCommand(assetUrl, "result.png", "image/png", 1024, null),
            TemplateMediaRole.PreviewAsset,
            CancellationToken.None);
        await service.SaveChangesAsync(CancellationToken.None);

        var record = await dbContext.TemplateMediaRecords.SingleAsync();
        Assert.Equal(expectedStoragePath, record.StoragePath);
    }

    [Theory]
    [InlineData(
        "http://localhost:5000/templates-media/2026/06/result.png?pmexp=123",
        "templates-media/2026/06/result.png")]
    [InlineData(
        "https://cdn.petmagic.test/templates-media/2026/06/result.png#fragment",
        "templates-media/2026/06/result.png")]
    public async Task RegisterTemporaryUploadAsync_ShouldPersistSafeManagedStoragePath(
        string assetUrl,
        string expectedStoragePath)
    {
        await using var dbContext = CreateDbContext();
        var service = new TemplateMediaLifecycleService(dbContext, CreateOptions());

        await service.RegisterTemporaryUploadAsync(
            new TemplateAssetCommand(assetUrl, "result.png", "image/png", 1024, null),
            TemplateMediaRole.PreviewAsset,
            CancellationToken.None);
        await service.SaveChangesAsync(CancellationToken.None);

        var record = await dbContext.TemplateMediaRecords.SingleAsync();
        Assert.Equal(expectedStoragePath, record.StoragePath);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"template-media-lifecycle-storage-path-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static TemplatesOptions CreateOptions()
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            SeedSampleTemplates = false,
            R2 = new R2StorageOptions
            {
                AccountId = "account",
                AccessKey = "access",
                SecretKey = "secret",
                BucketName = "bucket",
                PublicBaseUrl = "https://cdn.petmagic.test",
                ObjectKeyPrefix = "templates-media"
            }
        };
    }
}
