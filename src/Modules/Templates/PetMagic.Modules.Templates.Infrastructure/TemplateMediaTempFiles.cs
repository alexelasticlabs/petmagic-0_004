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

    public static void TryDeleteIfOwned(string? path)
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
        catch
        {
            // Metadata temp files are best-effort cleanup and must not fail request handling.
        }
    }

    public static bool CleanupNextExpiredAsync(TimeSpan retention)
    {
        try
        {
            if (retention < TimeSpan.Zero || !Directory.Exists(Root))
            {
                return false;
            }

            var cutoff = DateTime.UtcNow.Subtract(retention);
            var file = new DirectoryInfo(Root)
                .EnumerateFiles("*", SearchOption.TopDirectoryOnly)
                .Where(x => x.LastWriteTimeUtc <= cutoff)
                .OrderBy(x => x.LastWriteTimeUtc)
                .FirstOrDefault();

            if (file is null)
            {
                return false;
            }

            file.Delete();
            return true;
        }
        catch
        {
            return false;
        }
    }
}
