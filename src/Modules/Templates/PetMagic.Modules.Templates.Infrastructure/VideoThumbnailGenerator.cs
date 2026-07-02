using System.Diagnostics;

using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class VideoThumbnailGenerator(
    IMediaStorage mediaStorage,
    IHttpClientFactory httpClientFactory,
    TemplatesOptions options,
    ILogger<VideoThumbnailGenerator> logger) : IVideoThumbnailGenerator
{
    public async Task<StoredMediaResponse?> CreateThumbnailAsync(
        StoredMediaResponse original,
        Guid generationId,
        string outputFileName,
        string? preferredStorageKey,
        CancellationToken cancellationToken)
    {
        string? tempInput = null;
        string? tempOutput = null;
        try
        {
            var inputPath = await ResolveInputPathAsync(original, cancellationToken);
            tempInput = inputPath.TempPath;
            tempOutput = Path.Combine(Path.GetTempPath(), $"petmagic-video-thumbnail-{generationId:N}.jpg");

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
            process.StartInfo.ArgumentList.Add("-ss");
            process.StartInfo.ArgumentList.Add("00:00:01");
            process.StartInfo.ArgumentList.Add("-i");
            process.StartInfo.ArgumentList.Add(inputPath.Path);
            process.StartInfo.ArgumentList.Add("-frames:v");
            process.StartInfo.ArgumentList.Add("1");
            process.StartInfo.ArgumentList.Add("-vf");
            process.StartInfo.ArgumentList.Add("scale=w='min(1024,iw)':h=-2");
            process.StartInfo.ArgumentList.Add("-q:v");
            process.StartInfo.ArgumentList.Add("3");
            process.StartInfo.ArgumentList.Add(tempOutput);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempOutput) || new FileInfo(tempOutput).Length == 0)
            {
                var error = await process.StandardError.ReadToEndAsync(cancellationToken);
                logger.LogWarning(
                    "Video thumbnail generation failed. Operation={Operation} GenerationId={GenerationId} FileName={FileName} ContentType={ContentType} ExitCode={ExitCode} ErrorPreview={ErrorPreview} HasLocalPath={HasLocalPath}",
                    "create_video_thumbnail",
                    generationId,
                    original.FileName,
                    original.ContentType,
                    process.ExitCode,
                    error.Length > 500 ? error[..500] : error,
                    !string.IsNullOrWhiteSpace(original.LocalPath));
                return null;
            }

            await using var output = File.OpenRead(tempOutput);
            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    outputFileName,
                    "image/jpeg",
                    null,
                    output,
                    output.Length,
                    preferredStorageKey),
                cancellationToken);

            if (stored.IsSuccess)
            {
                return stored.Value;
            }

            logger.LogWarning(
                "Video thumbnail storage failed. Operation={Operation} GenerationId={GenerationId} FileName={FileName} ContentType={ContentType} ErrorCode={ErrorCode} HasLocalPath={HasLocalPath}",
                "store_video_thumbnail",
                generationId,
                original.FileName,
                original.ContentType,
                stored.Error.Code,
                !string.IsNullOrWhiteSpace(original.LocalPath));
            return null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "Video thumbnail generation failed. Operation={Operation} GenerationId={GenerationId} FileName={FileName} ContentType={ContentType} HasLocalPath={HasLocalPath}",
                "create_video_thumbnail",
                generationId,
                original.FileName,
                original.ContentType,
                !string.IsNullOrWhiteSpace(original.LocalPath));
            return null;
        }
        finally
        {
            TryDelete(tempInput);
            TryDelete(tempOutput);
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

        if (original.FileSizeBytes is > 0 && original.FileSizeBytes > options.GeneratedVideoMaxFileSizeBytes)
        {
            throw new InvalidOperationException("Video thumbnail input exceeds configured size limit.");
        }

        var signed = await mediaStorage.CreateReadUrlAsync(
            original.Url,
            TimeSpan.FromMinutes(5),
            cancellationToken);
        if (signed.IsFailure)
        {
            throw new InvalidOperationException("Could not create read URL for video thumbnail input.");
        }

        var extension = Path.GetExtension(original.FileName);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".mp4";
        }

        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-video-thumbnail-input-{Guid.NewGuid():N}{extension}");
        var client = httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName);
        using var response = await client.GetAsync(signed.Value, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException("Could not download video thumbnail input.");
        }

        var contentLength = response.Content.Headers.ContentLength;
        if (contentLength is > 0 && contentLength > options.GeneratedVideoMaxFileSizeBytes)
        {
            throw new InvalidOperationException("Video thumbnail input exceeds configured size limit.");
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var file = File.Create(tempPath);
        await CopyWithLimitAsync(stream, file, options.GeneratedVideoMaxFileSizeBytes, cancellationToken);
        return (tempPath, tempPath);
    }

    private static async Task CopyWithLimitAsync(Stream source, Stream destination, long maxBytes, CancellationToken cancellationToken)
    {
        var buffer = new byte[81920];
        long totalBytes = 0;
        while (true)
        {
            var bytesRead = await source.ReadAsync(buffer, cancellationToken);
            if (bytesRead == 0)
            {
                return;
            }

            totalBytes += bytesRead;
            if (totalBytes > maxBytes)
            {
                throw new InvalidOperationException("Video thumbnail input exceeds configured size limit.");
            }

            await destination.WriteAsync(buffer.AsMemory(0, bytesRead), cancellationToken);
        }
    }

    private void TryDelete(string? path)
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
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "Video thumbnail temp cleanup failed. Operation={Operation} TempFileName={TempFileName}",
                "delete_temp_video_thumbnail",
                Path.GetFileName(path));
        }
    }
}
