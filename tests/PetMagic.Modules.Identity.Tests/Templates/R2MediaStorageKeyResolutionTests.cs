using System.Reflection;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class R2MediaStorageKeyResolutionTests
{
    [Theory]
    [InlineData(
        "templates-media/2026/06/result.png",
        "templates-media/2026/06/result.png")]
    [InlineData(
        "https://cdn.petmagic.test/templates-media/2026/06/result.png",
        "templates-media/2026/06/result.png")]
    [InlineData(
        "https://cdn.petmagic.test/templates-media/2026/06/result.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc",
        "templates-media/2026/06/result.png")]
    [InlineData(
        "https://cdn.petmagic.test/templates-media/2026/06/result.png#fragment",
        "templates-media/2026/06/result.png")]
    public void TryResolveManagedKey_ShouldNormalizeManagedStorageKeys(
        string assetUrl,
        string expected)
    {
        var storage = CreateStorage();

        var resolved = InvokeTryResolveManagedKey(storage, assetUrl);

        Assert.Equal(expected, resolved);
    }

    [Fact]
    public void TryResolveManagedKey_ShouldIgnoreExternalUrl()
    {
        var storage = CreateStorage();

        var resolved = InvokeTryResolveManagedKey(
            storage,
            "https://example.com/templates-media/2026/06/result.png");

        Assert.Null(resolved);
    }

    [Fact]
    public async Task CreateReadUrlAsync_ShouldRejectExternalUrl()
    {
        var storage = CreateStorage();

        var result = await storage.CreateReadUrlAsync(
            "https://example.com/templates-media/2026/06/result.png",
            TimeSpan.FromMinutes(5),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.media_storage_failed", result.Error.Code);
    }

    [Fact]
    public async Task StoreAsync_ShouldRejectUnsupportedIsoBmffBrandDeclaredAsVideoMp4()
    {
        var storage = CreateStorage();

        var result = await storage.StoreAsync(
            new MediaUploadCommand(
                "preview.mp4",
                "video/mp4",
                [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0x00, 0x00, 0x00, 0x00],
                null,
                16,
                "tests/preview.mp4"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.invalid_media_upload", result.Error.Code);
    }

    [Fact]
    public void MediaMagicBytes_ShouldDetectQuickTimeBrand()
    {
        var detectedContentType = MediaMagicBytes.DetectContentType(
            [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00]);

        Assert.Equal("video/quicktime", detectedContentType);
    }

    [Theory]
    [InlineData("video/mp4", true)]
    [InlineData("video/mp4; charset=binary", true)]
    [InlineData("application/mp4; charset=binary", true)]
    [InlineData("image/jpg; charset=binary", false)]
    public void ContentTypesMatch_ShouldNormalizeDeclaredContentType(
        string declaredContentType,
        bool expected)
    {
        var storage = CreateStorage();

        var matches = InvokeContentTypesMatch(storage, "video/mp4", declaredContentType);

        Assert.Equal(expected, matches);
    }

    private static R2MediaStorage CreateStorage()
    {
        var options = new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "unused",
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

        return new R2MediaStorage(options, null!);
    }

    private static string? InvokeTryResolveManagedKey(
        R2MediaStorage storage,
        string assetUrl)
    {
        var method = typeof(R2MediaStorage).GetMethod(
            "TryResolveManagedKey",
            BindingFlags.Instance | BindingFlags.NonPublic);

        Assert.NotNull(method);
        return (string?)method!.Invoke(storage, [assetUrl]);
    }

    private static bool InvokeContentTypesMatch(
        R2MediaStorage storage,
        string detectedContentType,
        string declaredContentType)
    {
        var method = typeof(R2MediaStorage).GetMethod(
            "ContentTypesMatch",
            BindingFlags.Static | BindingFlags.NonPublic);

        Assert.NotNull(method);
        return (bool)method!.Invoke(storage, [detectedContentType, declaredContentType])!;
    }
}
