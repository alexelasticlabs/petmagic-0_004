using Microsoft.Extensions.Logging;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateMediaTempFiles
{
    private static readonly string Root = Path.Combine(Path.GetTempPath(), "PetMagic", "templates-media", "metadata");

    public static async Task<string> WriteAsync(byte[] content, string extension, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Root);

        var safeExtension = string.IsNullOrWhiteSpace(extension) || extension.Length > 16
            ? ".bin"
            : extension;
        var path = Path.Combine(Root, $"{Guid.NewGuid():N}{safeExtension}");
        await File.WriteAllBytesAsync(path, content, cancellationToken);
        return path;
    }

    public static async Task<string> WriteAsync(Stream contentStream, string extension, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Root);

        var safeExtension = string.IsNullOrWhiteSpace(extension) || extension.Length > 16
            ? ".bin"
            : extension;
        var path = Path.Combine(Root, $"{Guid.NewGuid():N}{safeExtension}");

        await using var output = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
        await contentStream.CopyToAsync(output, cancellationToken);
        return path;
    }

    public static void TryDeleteIfOwned(string? path, ILogger? logger = null)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        try
        {
            var fullPath = Path.GetFullPath(path);
            var root = Path.GetFullPath(Root);
            var rootWithSeparator = root.EndsWith(Path.DirectorySeparatorChar)
                ? root
                : root + Path.DirectorySeparatorChar;

            if (!fullPath.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            if (File.Exists(fullPath))
            {
                File.Delete(fullPath);
            }
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                exception,
                "Template metadata temp file cleanup failed. Operation={Operation} TempFileName={TempFileName}",
                "delete_owned",
                SafeFileName(path));
            // Metadata temp files are best-effort cleanup and must not fail request handling.
        }
    }

    public static bool CleanupNextExpiredAsync(TimeSpan retention, ILogger? logger = null)
    {
        try
        {
            if (retention < TimeSpan.Zero || !Directory.Exists(Root))
            {
                return false;
            }

            var cutoff = DateTime.UtcNow.Subtract(retention);
            var files = new DirectoryInfo(Root)
                .EnumerateFiles("*", SearchOption.TopDirectoryOnly)
                .Where(x => x.LastWriteTimeUtc <= cutoff)
                .Where(x => !x.Name.EndsWith(".part", StringComparison.OrdinalIgnoreCase))
                .OrderBy(x => x.LastWriteTimeUtc)
                .ToArray();

            if (files.Length == 0)
            {
                return false;
            }

            foreach (var file in files)
            {
                try
                {
                    file.Delete();
                    return true;
                }
                catch (Exception exception)
                {
                    logger?.LogWarning(
                        exception,
                        "Template metadata temp file sweep failed. Operation={Operation} RetentionHours={RetentionHours} TempFileName={TempFileName}",
                        "sweep_expired",
                        retention.TotalHours,
                        file.Name);
                }
            }

            return false;
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                exception,
                "Template metadata temp file sweep failed. Operation={Operation} RetentionHours={RetentionHours}",
                "sweep_expired",
                retention.TotalHours);
            return false;
        }
    }

    private static string SafeFileName(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return "unknown";
        }

        var fileName = Path.GetFileName(path.Trim());
        return string.IsNullOrWhiteSpace(fileName) ? "unknown" : fileName;
    }
}
