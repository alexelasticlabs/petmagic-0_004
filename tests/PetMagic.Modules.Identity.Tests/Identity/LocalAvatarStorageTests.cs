using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class LocalAvatarStorageTests
{
    [Fact]
    public async Task StoreAsync_ShouldNormalizePngAvatarToJpeg()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalAvatarStorage(
            new AvatarStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath,
                MaxFileSizeBytes = 8 * 1024 * 1024
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalAvatarStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new AvatarUploadCommand("avatar.png", "image/png", PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal("image/jpeg", stored.Value.ContentType);
            Assert.EndsWith(".jpg", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            Assert.NotNull(stored.Value.LocalPath);
            var bytes = await File.ReadAllBytesAsync(stored.Value.LocalPath!);
            Assert.True(bytes.Take(3).SequenceEqual([0xFF, 0xD8, 0xFF]));
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-avatar-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private static byte[] PngBytes()
    {
        return
        [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
            0x18, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82
        ];
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
