using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class ImagePreviewGenerator(
    IMediaStorage mediaStorage,
    IHttpClientFactory httpClientFactory,
    ILogger<ImagePreviewGenerator> logger) : IImagePreviewGenerator
{
    private const int MaxPreviewSize = 1024;

    public async Task<StoredMediaResponse?> CreatePreviewAsync(
        StoredMediaResponse original,
        string outputFileName,
        string? preferredStorageKey,
        CancellationToken cancellationToken)
    {
        string? tempInput = null;
        try
        {
            var inputPath = await ResolveInputPathAsync(original, cancellationToken);
            tempInput = inputPath.TempPath;

            await using var input = File.OpenRead(inputPath.Path);
            using var image = await Image.LoadAsync(input, cancellationToken);
            image.Mutate(context => context.Resize(new ResizeOptions
            {
                Size = new Size(MaxPreviewSize, MaxPreviewSize),
                Mode = ResizeMode.Max
            }));

            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 82 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    outputFileName,
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    preferredStorageKey),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogDebug(exception, "Could not create image preview for {AssetUrl}", original.Url);
            return null;
        }
        finally
        {
            TryDelete(tempInput);
        }
    }

    private async Task<(string Path, string? TempPath)> ResolveInputPathAsync(
        StoredMediaResponse original,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(original.LocalPath) && File.Exists(original.LocalPath))
        {
            return (original.LocalPath, null);
        }

        var signed = await mediaStorage.CreateReadUrlAsync(
            original.Url,
            TimeSpan.FromMinutes(5),
            cancellationToken);
        if (signed.IsFailure)
        {
            throw new InvalidOperationException("Could not create read URL for preview input.");
        }

        var extension = Path.GetExtension(original.FileName);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".img";
        }

        var tempPath = Path.Combine(
            Path.GetTempPath(),
            $"petmagic-preview-input-{Guid.NewGuid():N}{extension}");
        var client = httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName);
        await using var stream = await client.GetStreamAsync(signed.Value, cancellationToken);
        await using var file = File.Create(tempPath);
        await stream.CopyToAsync(file, cancellationToken);
        return (tempPath, tempPath);
    }

    private static void TryDelete(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
        }
    }
}
