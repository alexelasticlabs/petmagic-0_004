using System.Diagnostics;
using System.Globalization;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatePreviewOptimizer(
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService,
    IHttpClientFactory httpClientFactory,
    IVideoDimensionsProbe videoDimensionsProbe,
    TemplatesOptions options,
    TemplatePreviewOptimizationGate optimizationGate,
    ILogger<TemplatePreviewOptimizer> logger) : ITemplatePreviewOptimizer
{
    private static readonly TimeSpan InputReadUrlTtl = TimeSpan.FromMinutes(5);
    private const string MaxPreviewVideoDurationSeconds = "18";

    public async Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
        StoredMediaResponse original,
        double? durationSeconds,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(original);

        if (!options.PreviewOptimization.Enabled)
        {
            TemplateMediaTempFiles.TryDeleteIfOwned(original.LocalPath, logger);
            return Result.Success(new TemplatePreviewOptimizationResult(
                original,
                null,
                null,
                null,
                null,
                null,
                false));
        }

        using var timeoutSource = new CancellationTokenSource(TimeSpan.FromSeconds(options.PreviewOptimization.TimeoutSeconds));
        using var linkedSource = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken,
            timeoutSource.Token);

        var storedOutputs = new List<StoredMediaResponse>();
        string? downloadedInputPath = null;
        IDisposable? optimizationLease = null;
        try
        {
            optimizationLease = await optimizationGate.EnterAsync(linkedSource.Token);
            var input = await ResolveInputPathAsync(original, linkedSource.Token);
            downloadedInputPath = input.TempPath;

            TemplatePreviewOptimizationResult optimized;
            if (IsImage(original.ContentType))
            {
                optimized = await OptimizeImageAsync(
                    input.Path,
                    original,
                    storedOutputs,
                    linkedSource.Token);
            }
            else if (IsVideo(original.ContentType))
            {
                optimized = await OptimizeVideoAsync(
                    input.Path,
                    original,
                    durationSeconds,
                    storedOutputs,
                    linkedSource.Token);
            }
            else
            {
                throw new InvalidPreviewException("Unsupported preview media type.");
            }

            foreach (var stored in storedOutputs)
            {
                TemplateMediaTempFiles.TryDeleteIfOwned(stored.LocalPath, logger);
            }

            return Result.Success(optimized);
        }
        catch (InvalidPreviewException exception)
        {
            await RollbackAsync(storedOutputs);
            logger.LogWarning(
                "Template preview optimization rejected invalid media. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "optimize_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<TemplatePreviewOptimizationResult>(TemplatesErrors.PreviewOptimizationInvalid);
        }
        catch (Exception exception) when (exception is UnknownImageFormatException or InvalidImageContentException)
        {
            await RollbackAsync(storedOutputs);
            logger.LogWarning(
                "Template preview optimization rejected invalid image. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "optimize_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<TemplatePreviewOptimizationResult>(TemplatesErrors.PreviewOptimizationInvalid);
        }
        catch (PreviewOptimizationTimeoutException exception)
        {
            await RollbackAsync(storedOutputs);
            logger.LogWarning(
                "Template preview optimization timed out. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} TimeoutSeconds={TimeoutSeconds} ExceptionType={ExceptionType}",
                "optimize_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                options.MediaMetadataProbeTimeoutSeconds,
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<TemplatePreviewOptimizationResult>(TemplatesErrors.PreviewOptimizationTimedOut);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            await RollbackAsync(storedOutputs);
            logger.LogWarning(
                "Template preview optimization timed out. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} TimeoutSeconds={TimeoutSeconds}",
                "optimize_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                options.PreviewOptimization.TimeoutSeconds);
            return Result.Failure<TemplatePreviewOptimizationResult>(TemplatesErrors.PreviewOptimizationTimedOut);
        }
        catch (OperationCanceledException)
        {
            await RollbackAsync(storedOutputs);
            throw;
        }
        catch (Exception exception)
        {
            await RollbackAsync(storedOutputs);
            logger.LogWarning(
                "Template preview optimization failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "optimize_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<TemplatePreviewOptimizationResult>(TemplatesErrors.PreviewOptimizationFailed);
        }
        finally
        {
            optimizationLease?.Dispose();
            TryDeleteTemporaryFile(downloadedInputPath);
            TemplateMediaTempFiles.TryDeleteIfOwned(original.LocalPath, logger);
        }
    }

    private async Task<TemplatePreviewOptimizationResult> OptimizeImageAsync(
        string inputPath,
        StoredMediaResponse original,
        List<StoredMediaResponse> storedOutputs,
        CancellationToken cancellationToken)
    {
        await using var input = File.OpenRead(inputPath);
        var decoderOptions = new DecoderOptions { MaxFrames = 1 };
        var imageInfo = await Image.IdentifyAsync(decoderOptions, input, cancellationToken)
            ?? throw new InvalidPreviewException("Image metadata could not be read.");
        var pixelCount = (long)imageInfo.Width * imageInfo.Height;
        if (imageInfo.Width > options.PreviewOptimization.MaxImageDimension
            || imageInfo.Height > options.PreviewOptimization.MaxImageDimension
            || pixelCount > options.PreviewOptimization.MaxImagePixelCount)
        {
            throw new InvalidPreviewException("Image dimensions exceed the configured safety limit.");
        }

        input.Position = 0;
        using var image = await Image.LoadAsync(
            decoderOptions,
            input,
            cancellationToken);
        image.Mutate(context => context.AutoOrient());

        var batchKey = BuildBatchKey();
        var thumbnail = await ResizeAndStoreWebpAsync(
            image,
            options.PreviewOptimization.ThumbnailMaxDimension,
            options.PreviewOptimization.ThumbnailWebpQuality,
            "preview-thumbnail.webp",
            $"{batchKey}/thumbnail.webp",
            storedOutputs,
            cancellationToken);
        var detail = await ResizeAndStoreWebpAsync(
            image,
            options.PreviewOptimization.DetailImageMaxDimension,
            options.PreviewOptimization.DetailImageWebpQuality,
            "preview-detail.webp",
            $"{batchKey}/detail.webp",
            storedOutputs,
            cancellationToken);

        return new TemplatePreviewOptimizationResult(
            detail,
            thumbnail,
            null,
            thumbnail,
            null,
            detail,
            true);
    }

    private async Task<StoredMediaResponse> ResizeAndStoreWebpAsync(
        Image source,
        int maxDimension,
        int quality,
        string outputFileName,
        string storageKey,
        List<StoredMediaResponse> storedOutputs,
        CancellationToken cancellationToken)
    {
        using var resized = source.Width <= maxDimension && source.Height <= maxDimension
            ? source.Clone(_ => { })
            : source.Clone(context => context.Resize(new ResizeOptions
            {
                Size = new Size(maxDimension, maxDimension),
                Mode = ResizeMode.Max
            }));
        resized.Metadata.ExifProfile = null;
        resized.Metadata.IptcProfile = null;
        resized.Metadata.XmpProfile = null;
        await using var output = new MemoryStream();
        await resized.SaveAsWebpAsync(output, new WebpEncoder { Quality = quality }, cancellationToken);
        output.Position = 0;

        return await StoreAsync(
            outputFileName,
            "image/webp",
            output,
            storageKey,
            storedOutputs,
            cancellationToken,
            null);
    }

    private async Task<TemplatePreviewOptimizationResult> OptimizeVideoAsync(
        string inputPath,
        StoredMediaResponse original,
        double? durationSeconds,
        List<StoredMediaResponse> storedOutputs,
        CancellationToken cancellationToken)
    {
        await ValidateVideoDimensionsAsync(inputPath, original, cancellationToken);

        var batchKey = BuildBatchKey();
        var tempId = Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture);
        var thumbnailPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-thumbnail-{tempId}.jpg");
        var feedPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-feed-{tempId}.mp4");
        var detailPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-detail-{tempId}.mp4");
        var ffmpegThreads = options.PreviewOptimization.FfmpegThreads.ToString(CultureInfo.InvariantCulture);

        try
        {
            var seekSeconds = Math.Min(0.25, Math.Max(0, (durationSeconds ?? 0.5) / 2));
            await RunFfmpegAsync(
                [
                    "-y",
                    "-nostdin",
                    "-threads", ffmpegThreads,
                    "-filter_threads", ffmpegThreads,
                    "-ss", seekSeconds.ToString("0.###", CultureInfo.InvariantCulture),
                    "-i", inputPath,
                    "-map", "0:v:0",
                    "-frames:v", "1",
                    "-vf", BuildScaleFilter(options.PreviewOptimization.ThumbnailMaxDimension),
                    "-q:v", "4",
                    "-map_metadata", "-1",
                    "-threads:v", ffmpegThreads,
                    thumbnailPath
                ],
                thumbnailPath,
                original,
                "create_thumbnail",
                cancellationToken);
            var thumbnail = await StoreFileAsync(
                thumbnailPath,
                "preview-thumbnail.jpg",
                "image/jpeg",
                $"{batchKey}/thumbnail.jpg",
                storedOutputs,
                cancellationToken,
                null);

            await RunFfmpegAsync(
                [
                    "-y",
                    "-nostdin",
                    "-threads", ffmpegThreads,
                    "-filter_threads", ffmpegThreads,
                    "-i", inputPath,
                    "-t", MaxPreviewVideoDurationSeconds,
                    "-map", "0:v:0",
                    "-vf", BuildScaleFilter(options.PreviewOptimization.FeedVideoMaxDimension),
                    "-an", "-sn", "-dn",
                    "-map_metadata", "-1",
                    "-map_chapters", "-1",
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-crf", options.PreviewOptimization.FeedVideoCrf.ToString(CultureInfo.InvariantCulture),
                    "-maxrate", $"{options.PreviewOptimization.FeedVideoMaxBitrateKbps}k",
                    "-bufsize", $"{options.PreviewOptimization.FeedVideoMaxBitrateKbps * 2}k",
                    "-pix_fmt", "yuv420p",
                    "-fpsmax", "30",
                    "-threads:v", ffmpegThreads,
                    "-movflags", "+faststart",
                    feedPath
                ],
                feedPath,
                original,
                "create_feed_loop",
                cancellationToken);
            var feed = await StoreFileAsync(
                feedPath,
                "preview-feed-low.mp4",
                "video/mp4",
                $"{batchKey}/feed-low.mp4",
                storedOutputs,
                cancellationToken,
                durationSeconds);

            await RunFfmpegAsync(
                [
                    "-y",
                    "-nostdin",
                    "-threads", ffmpegThreads,
                    "-filter_threads", ffmpegThreads,
                    "-i", inputPath,
                    "-t", MaxPreviewVideoDurationSeconds,
                    "-map", "0:v:0",
                    "-map", "0:a:0?",
                    "-vf", BuildScaleFilter(options.PreviewOptimization.DetailVideoMaxDimension),
                    "-sn", "-dn",
                    "-map_metadata", "-1",
                    "-map_chapters", "-1",
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-crf", options.PreviewOptimization.DetailVideoCrf.ToString(CultureInfo.InvariantCulture),
                    "-maxrate", $"{options.PreviewOptimization.DetailVideoMaxBitrateKbps}k",
                    "-bufsize", $"{options.PreviewOptimization.DetailVideoMaxBitrateKbps * 2}k",
                    "-pix_fmt", "yuv420p",
                    "-fpsmax", "30",
                    "-c:a", "aac",
                    "-b:a", $"{options.PreviewOptimization.DetailVideoAudioBitrateKbps}k",
                    "-threads:v", ffmpegThreads,
                    "-movflags", "+faststart",
                    detailPath
                ],
                detailPath,
                original,
                "create_detail_preview",
                cancellationToken);
            var detail = await StoreFileAsync(
                detailPath,
                "preview-detail.mp4",
                "video/mp4",
                $"{batchKey}/detail.mp4",
                storedOutputs,
                cancellationToken,
                durationSeconds);

            return new TemplatePreviewOptimizationResult(
                detail,
                thumbnail,
                null,
                feed,
                null,
                detail,
                true);
        }
        finally
        {
            TryDeleteTemporaryFile(thumbnailPath);
            TryDeleteTemporaryFile(feedPath);
            TryDeleteTemporaryFile(detailPath);
        }
    }

    private async Task ValidateVideoDimensionsAsync(
        string inputPath,
        StoredMediaResponse original,
        CancellationToken cancellationToken)
    {
        var probeResult = await videoDimensionsProbe.ProbeDimensionsAsync(
            original with { LocalPath = inputPath },
            cancellationToken);
        if (probeResult.IsFailure)
        {
            if (string.Equals(
                probeResult.Error.Code,
                TemplatesErrors.MediaMetadataInvalid.Code,
                StringComparison.Ordinal))
            {
                throw new InvalidPreviewException("Video dimensions metadata is invalid.");
            }

            if (string.Equals(
                probeResult.Error.Code,
                TemplatesErrors.MediaMetadataTimedOut.Code,
                StringComparison.Ordinal))
            {
                throw new PreviewOptimizationTimeoutException("Video dimensions probe timed out.");
            }

            throw new PreviewOptimizationException("Video dimensions could not be probed.");
        }

        var dimensions = probeResult.Value;
        var codedPixelCount = (long)dimensions.Width * dimensions.Height;
        var displayPixelCount = dimensions.DisplayWidth * dimensions.DisplayHeight;
        if (dimensions.Width > options.PreviewOptimization.MaxVideoDimension
            || dimensions.Height > options.PreviewOptimization.MaxVideoDimension
            || dimensions.DisplayWidth > options.PreviewOptimization.MaxVideoDimension
            || dimensions.DisplayHeight > options.PreviewOptimization.MaxVideoDimension
            || codedPixelCount > options.PreviewOptimization.MaxVideoPixelCount
            || !double.IsFinite(displayPixelCount)
            || displayPixelCount > options.PreviewOptimization.MaxVideoPixelCount)
        {
            throw new InvalidPreviewException("Video dimensions exceed the configured safety limit.");
        }
    }

    private async Task<StoredMediaResponse> StoreFileAsync(
        string path,
        string fileName,
        string contentType,
        string storageKey,
        List<StoredMediaResponse> storedOutputs,
        CancellationToken cancellationToken,
        double? durationSeconds)
    {
        await using var stream = File.OpenRead(path);
        return await StoreAsync(
            fileName,
            contentType,
            stream,
            storageKey,
            storedOutputs,
            cancellationToken,
            durationSeconds);
    }

    private async Task<StoredMediaResponse> StoreAsync(
        string fileName,
        string contentType,
        Stream content,
        string storageKey,
        List<StoredMediaResponse> storedOutputs,
        CancellationToken cancellationToken,
        double? durationSeconds)
    {
        var stored = await mediaStorage.StoreAsync(
            new MediaUploadCommand(
                fileName,
                contentType,
                null,
                content,
                content.Length,
                storageKey),
            cancellationToken);
        if (stored.IsFailure)
        {
            await CleanupAmbiguousStoreAsync(
                storageKey,
                fileName,
                contentType,
                content.Length,
                durationSeconds);
            cancellationToken.ThrowIfCancellationRequested();
            throw new PreviewOptimizationException("An optimized preview could not be stored.");
        }

        storedOutputs.Add(stored.Value);
        await PersistTemporaryOutputAsync(stored.Value, durationSeconds);
        cancellationToken.ThrowIfCancellationRequested();
        return stored.Value;
    }

    private async Task RunFfmpegAsync(
        IReadOnlyList<string> arguments,
        string expectedOutputPath,
        StoredMediaResponse original,
        string operation,
        CancellationToken cancellationToken)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = options.Watermark.FfmpegPath,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };
        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        process.Start();
        var stderrLengthTask = ProcessOutputDrainer.CountAsync(process.StandardError, CancellationToken.None);
        var stdoutDrainTask = ProcessOutputDrainer.DrainAsync(process.StandardOutput, CancellationToken.None);
        try
        {
            await process.WaitForExitAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            TryKill(process);
            await ObserveProcessDrainAsync(stderrLengthTask, stdoutDrainTask);
            throw;
        }

        await stdoutDrainTask;
        var errorLength = await stderrLengthTask;
        if (process.ExitCode != 0
            || !File.Exists(expectedOutputPath)
            || new FileInfo(expectedOutputPath).Length == 0)
        {
            logger.LogWarning(
                "Template preview ffmpeg operation failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExitCode={ExitCode} ErrorLength={ErrorLength}",
                operation,
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                process.ExitCode,
                errorLength);
            throw new InvalidPreviewException("ffmpeg could not create an optimized preview.");
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

        if (original.FileSizeBytes is > 0 && original.FileSizeBytes > options.PreviewMaxFileSizeBytes)
        {
            throw new InvalidPreviewException("Preview input exceeds the configured size limit.");
        }

        var signed = await mediaStorage.CreateReadUrlAsync(original.Url, InputReadUrlTtl, cancellationToken);
        if (signed.IsFailure)
        {
            throw new PreviewOptimizationException("A preview read URL could not be created.");
        }

        var extension = Path.GetExtension(original.FileName);
        if (string.IsNullOrWhiteSpace(extension) || extension.Length > 16)
        {
            extension = ".bin";
        }

        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-input-{Guid.NewGuid():N}{extension}");
        try
        {
            var client = httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName);
            using var response = await client.GetAsync(
                signed.Value,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode
                || response.Content.Headers.ContentLength > options.PreviewMaxFileSizeBytes)
            {
                throw new PreviewOptimizationException("Preview input could not be downloaded.");
            }

            await using var source = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var destination = File.Create(tempPath);
            await CopyWithLimitAsync(
                source,
                destination,
                options.PreviewMaxFileSizeBytes,
                cancellationToken);
            return (tempPath, tempPath);
        }
        catch
        {
            TryDeleteTemporaryFile(tempPath);
            throw;
        }
    }

    private static async Task CopyWithLimitAsync(
        Stream source,
        Stream destination,
        long maxBytes,
        CancellationToken cancellationToken)
    {
        var buffer = new byte[81920];
        long copied = 0;
        while (true)
        {
            var read = await source.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                return;
            }

            copied += read;
            if (copied > maxBytes)
            {
                throw new InvalidPreviewException("Preview input exceeds the configured size limit.");
            }

            await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
        }
    }

    private async Task RollbackAsync(IEnumerable<StoredMediaResponse> storedOutputs)
    {
        var outputs = storedOutputs.Reverse().ToArray();
        if (outputs.Length == 0)
        {
            return;
        }

        await PersistCleanupIntentAsync(outputs, "rollback_preview_lifecycle");
        var cleanupResults = new List<(StoredMediaResponse Asset, Result DeleteResult)>(outputs.Length);
        using var deleteSource = CreateCleanupTimeoutSource();

        foreach (var stored in outputs)
        {
            Result deleteResult;
            try
            {
                deleteResult = await mediaStorage.DeleteAsync(stored.Url, deleteSource.Token);
            }
            catch (Exception exception)
            {
                deleteResult = Result.Failure(new Error(
                    TemplatesErrors.MediaStorageFailed.Code,
                    "Optimized template preview cleanup failed."));
                logger.LogWarning(
                    "Template preview rollback failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ExceptionType={ExceptionType}",
                    "rollback_preview",
                    SafeLogValues.StableHash(stored.StorageKey),
                    SafeLogValues.ExceptionType(exception));
            }

            if (deleteResult.IsFailure)
            {
                logger.LogWarning(
                    "Template preview rollback storage delete failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ErrorCode={ErrorCode}",
                    "rollback_preview",
                    SafeLogValues.StableHash(stored.StorageKey),
                    SafeStorageErrorCode(deleteResult.Error.Code));
            }

            cleanupResults.Add((stored, deleteResult));
            TemplateMediaTempFiles.TryDeleteIfOwned(stored.LocalPath, logger);
        }

        await PersistCleanupResultsAsync(cleanupResults, "rollback_preview_lifecycle");
    }

    private async Task CleanupAmbiguousStoreAsync(
        string preferredStorageKey,
        string fileName,
        string contentType,
        long? fileSizeBytes,
        double? durationSeconds)
    {
        var configuredPrefix = string.Equals(
            options.StorageProvider,
            TemplateStorageProviders.R2,
            StringComparison.OrdinalIgnoreCase)
            ? options.R2.ObjectKeyPrefix.Trim().Trim('/').Replace('\\', '/')
            : "templates-media";
        var prefix = string.IsNullOrWhiteSpace(configuredPrefix) ? "templates-media" : configuredPrefix;
        var managedStorageKey = $"{prefix}/{preferredStorageKey}";
        var candidate = new StoredMediaResponse(
            managedStorageKey,
            managedStorageKey,
            fileName,
            contentType,
            fileSizeBytes,
            null);

        await PersistCleanupIntentAsync([candidate], "cleanup_ambiguous_store_lifecycle");
        using var deleteSource = CreateCleanupTimeoutSource();
        Result deleteResult;
        try
        {
            deleteResult = await mediaStorage.DeleteAsync(managedStorageKey, deleteSource.Token);
        }
        catch (Exception exception)
        {
            deleteResult = Result.Failure(new Error(
                TemplatesErrors.MediaStorageFailed.Code,
                "Ambiguous template preview cleanup failed."));
            logger.LogWarning(
                "Template preview ambiguous store cleanup failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ExceptionType={ExceptionType}",
                "cleanup_ambiguous_store",
                SafeLogValues.StableHash(managedStorageKey),
                SafeLogValues.ExceptionType(exception));
        }

        if (deleteResult.IsSuccess)
        {
            await PersistCleanupResultsAsync(
                [(candidate, deleteResult)],
                "cleanup_ambiguous_store_lifecycle");
            return;
        }

        logger.LogWarning(
            "Template preview ambiguous store cleanup failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ErrorCode={ErrorCode}",
            "cleanup_ambiguous_store",
            SafeLogValues.StableHash(managedStorageKey),
            SafeStorageErrorCode(deleteResult.Error.Code));
        await PersistCleanupResultsAsync(
            [(candidate, deleteResult)],
            "cleanup_ambiguous_store_lifecycle");
    }

    private async Task PersistTemporaryOutputAsync(StoredMediaResponse stored, double? durationSeconds)
    {
        using var auditSource = CreateCleanupTimeoutSource();
        await mediaLifecycleService.RegisterTemporaryUploadAsync(
            ToAssetCommand(stored, durationSeconds),
            TemplateMediaRole.PreviewAsset,
            auditSource.Token);
        await mediaLifecycleService.SaveChangesAsync(auditSource.Token);
    }

    private async Task PersistCleanupIntentAsync(
        IReadOnlyCollection<StoredMediaResponse> assets,
        string operation)
    {
        try
        {
            using var auditSource = CreateCleanupTimeoutSource();
            foreach (var asset in assets)
            {
                await mediaLifecycleService.RegisterTemporaryUploadAsync(
                    ToAssetCommand(asset, null),
                    TemplateMediaRole.PreviewAsset,
                    auditSource.Token);
                await mediaLifecycleService.MarkCleanupFailureAsync(
                    asset.Url,
                    TemplatesErrors.MediaStorageFailed.Code,
                    "Optimized template preview cleanup pending.",
                    auditSource.Token);
            }

            await mediaLifecycleService.SaveChangesAsync(auditSource.Token);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template preview cleanup intent lifecycle update failed. Operation={Operation} AssetCount={AssetCount} ExceptionType={ExceptionType}",
                operation,
                assets.Count,
                SafeLogValues.ExceptionType(exception));
        }
    }

    private async Task PersistCleanupResultsAsync(
        IReadOnlyCollection<(StoredMediaResponse Asset, Result DeleteResult)> results,
        string operation)
    {
        try
        {
            using var auditSource = CreateCleanupTimeoutSource();
            foreach (var (asset, deleteResult) in results)
            {
                await mediaLifecycleService.RegisterTemporaryUploadAsync(
                    ToAssetCommand(asset, null),
                    TemplateMediaRole.PreviewAsset,
                    auditSource.Token);
                if (deleteResult.IsSuccess)
                {
                    await mediaLifecycleService.MarkDeletedAsync(asset.Url, auditSource.Token);
                }
                else
                {
                    await mediaLifecycleService.MarkCleanupFailureAsync(
                        asset.Url,
                        SafeStorageErrorCode(deleteResult.Error.Code),
                        "Optimized template preview cleanup failed.",
                        auditSource.Token);
                }
            }

            await mediaLifecycleService.SaveChangesAsync(auditSource.Token);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template preview cleanup result lifecycle update failed. Operation={Operation} AssetCount={AssetCount} ExceptionType={ExceptionType}",
                operation,
                results.Count,
                SafeLogValues.ExceptionType(exception));
        }
    }

    private CancellationTokenSource CreateCleanupTimeoutSource()
    {
        return new CancellationTokenSource(
            TimeSpan.FromSeconds(options.PreviewOptimization.CleanupTimeoutSeconds));
    }

    private static TemplateAssetCommand ToAssetCommand(StoredMediaResponse stored, double? durationSeconds)
    {
        return new TemplateAssetCommand(
            stored.Url,
            stored.FileName,
            stored.ContentType,
            stored.FileSizeBytes,
            IsVideo(stored.ContentType) ? durationSeconds : null);
    }

    private static string BuildBatchKey()
    {
        return $"template-previews/{Guid.NewGuid():N}";
    }

    private static string SafeStorageErrorCode(string? code)
    {
        var trimmed = code?.Trim();
        var sanitized = AdminFailureMessageSanitizer.SanitizeCode(trimmed);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized ?? TemplatesErrors.MediaStorageFailed.Code
            : TemplatesErrors.MediaStorageFailed.Code;
    }

    private static string BuildScaleFilter(int maxDimension)
    {
        return $"scale=w='min(iw,{maxDimension})':h='min(ih,{maxDimension})':force_original_aspect_ratio=decrease:force_divisible_by=2";
    }

    private static bool IsImage(string contentType)
    {
        return contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsVideo(string contentType)
    {
        return contentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "application/mp4", StringComparison.OrdinalIgnoreCase);
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(5_000);
            }
        }
        catch
        {
            // The process is already terminating; the original cancellation remains authoritative.
        }
    }

    private static async Task ObserveProcessDrainAsync(params Task[] drainTasks)
    {
        try
        {
            await Task.WhenAll(drainTasks);
        }
        catch
        {
            // Stream closure after process termination is expected during cancellation.
        }
    }

    private void TryDeleteTemporaryFile(string? path)
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
                "Template preview temp cleanup failed. Operation={Operation} TempFileName={TempFileName} ExceptionType={ExceptionType}",
                "delete_preview_temp",
                Path.GetFileName(path),
                SafeLogValues.ExceptionType(exception));
        }
    }

    private sealed class PreviewOptimizationException(string message) : Exception(message);

    private sealed class PreviewOptimizationTimeoutException(string message) : Exception(message);

    private sealed class InvalidPreviewException(string message) : Exception(message);
}
