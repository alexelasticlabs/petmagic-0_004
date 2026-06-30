using System.Diagnostics;

using PetMagic.BuildingBlocks.Images;
using PetMagic.Modules.Templates.Application.Contracts;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService
{
    private async Task<StoredMediaResponse?> CreateThumbnailAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(original.LocalPath) || !File.Exists(original.LocalPath))
        {
            return null;
        }

        try
        {
            await using var input = File.OpenRead(original.LocalPath);
            using var image = await Image.LoadAsync(input, cancellationToken);
            image.Mutate(context => context.Resize(new ResizeOptions
            {
                Size = new Size(360, 360),
                Mode = ResizeMode.Max
            }));

            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 78 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (NotSupportedException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
        catch (InvalidImageContentException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
        catch (UnknownImageFormatException)
        {
            return await CreateHeicThumbnailWithExternalToolsAsync(original, userId, petId, photoId, cancellationToken);
        }
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithExternalToolsAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(original.ContentType, "image/heic", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(original.ContentType, "image/heif", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return await CreateHeicThumbnailWithFfmpegAsync(original, userId, petId, photoId, cancellationToken)
            ?? await CreateHeicThumbnailWithSipsAsync(original, userId, petId, photoId, cancellationToken);
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithFfmpegAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        var tempOutput = Path.Combine(Path.GetTempPath(), $"petmagic-pet-thumbnail-{photoId:N}.webp");
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = options.Watermark.FfmpegPath,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                }
            };
            process.StartInfo.ArgumentList.Add("-y");
            process.StartInfo.ArgumentList.Add("-i");
            process.StartInfo.ArgumentList.Add(original.LocalPath!);
            process.StartInfo.ArgumentList.Add("-vf");
            process.StartInfo.ArgumentList.Add("scale=w='min(360,iw)':h=-2");
            process.StartInfo.ArgumentList.Add("-frames:v");
            process.StartInfo.ArgumentList.Add("1");
            process.StartInfo.ArgumentList.Add("-quality");
            process.StartInfo.ArgumentList.Add("78");
            process.StartInfo.ArgumentList.Add(tempOutput);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempOutput) || new FileInfo(tempOutput).Length == 0)
            {
                return null;
            }

            await using var output = File.OpenRead(tempOutput);
            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return null;
        }
        finally
        {
            TryDelete(tempOutput);
        }
    }

    private async Task<StoredMediaResponse?> CreateHeicThumbnailWithSipsAsync(
        StoredMediaResponse original,
        Guid userId,
        Guid petId,
        Guid photoId,
        CancellationToken cancellationToken)
    {
        var sipsPath = OperatingSystem.IsMacOS() ? "/usr/bin/sips" : "sips";
        var tempPng = Path.Combine(Path.GetTempPath(), $"petmagic-pet-thumbnail-{photoId:N}.png");
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = sipsPath,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                }
            };
            process.StartInfo.ArgumentList.Add("-s");
            process.StartInfo.ArgumentList.Add("format");
            process.StartInfo.ArgumentList.Add("png");
            process.StartInfo.ArgumentList.Add("-Z");
            process.StartInfo.ArgumentList.Add("360");
            process.StartInfo.ArgumentList.Add(original.LocalPath!);
            process.StartInfo.ArgumentList.Add("--out");
            process.StartInfo.ArgumentList.Add(tempPng);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempPng) || new FileInfo(tempPng).Length == 0)
            {
                return null;
            }

            await using var input = File.OpenRead(tempPng);
            using var image = await Image.LoadAsync(input, cancellationToken);
            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 78 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    $"pet-thumbnail-{photoId:N}.webp",
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    BuildPetPhotoThumbnailStorageKey(userId, petId, photoId)),
                cancellationToken);

            return stored.IsSuccess ? stored.Value : null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            return null;
        }
        finally
        {
            TryDelete(tempPng);
        }
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
            // Best-effort temp cleanup.
        }
    }
}
