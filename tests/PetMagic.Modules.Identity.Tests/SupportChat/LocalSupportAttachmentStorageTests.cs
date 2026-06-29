using System.Linq;

using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class LocalSupportAttachmentStorageTests
{
    [Fact]
    public async Task StoreAsync_ShouldNormalizeImageAttachmentToJpeg()
    {
        var rootPath = CreateTempDirectory();
        var storage = new LocalSupportAttachmentStorage(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "http://localhost:5000",
                LocalMediaRootPath = rootPath
            },
            new TestHostEnvironment(rootPath),
            NullLogger<LocalSupportAttachmentStorage>.Instance);

        try
        {
            var stored = await storage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    "support.png",
                    "image/png",
                    PngBytes()),
                CancellationToken.None);

            Assert.True(stored.IsSuccess);
            Assert.Equal("image/jpeg", stored.Value.ContentType);
            Assert.EndsWith(".jpg", stored.Value.StorageKey, StringComparison.OrdinalIgnoreCase);
            var bytes = await File.ReadAllBytesAsync(stored.Value.LocalPath!);
            Assert.Equal((byte)0xFF, bytes[0]);
            Assert.Equal((byte)0xD8, bytes[1]);
            Assert.Equal((byte)0xFF, bytes[2]);
            using var normalized = Image.Load(bytes);
            Assert.Equal(1800, normalized.Width);
            Assert.Equal(1350, normalized.Height);
        }
        finally
        {
            Directory.Delete(rootPath, recursive: true);
        }
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), $"petmagic-support-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }

    private static byte[] PngBytes()
    {
        using var image = new Image<Rgba32>(2400, 1800);
        for (var y = 0; y < image.Height; y++)
        {
            for (var x = 0; x < image.Width; x++)
            {
                image[x, y] = new Rgba32(
                    (byte)((x * 31 + y * 17) & 0xFF),
                    (byte)((x * 13 + y * 29) & 0xFF),
                    (byte)((x * 7 + y * 19) & 0xFF));
            }
        }

        using var buffer = new MemoryStream();
        image.Save(buffer, new PngEncoder());
        return buffer.ToArray();
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
