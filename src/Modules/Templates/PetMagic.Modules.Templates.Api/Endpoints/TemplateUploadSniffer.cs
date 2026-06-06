using Microsoft.AspNetCore.Http;

namespace PetMagic.Modules.Templates.Api.Endpoints;

internal static class TemplateUploadSniffer
{
    private const int HeaderBytesToRead = 16;

    public static async Task<string?> DetectContentTypeAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var buffer = new byte[Math.Min(HeaderBytesToRead, (int)Math.Min(file.Length, HeaderBytesToRead))];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
        return DetectContentType(buffer.AsSpan(0, read));
    }

    public static bool MatchesDeclaredContentType(string detectedContentType, string declaredContentType)
    {
        var normalizedDeclared = NormalizeContentType(declaredContentType);
        if (string.IsNullOrWhiteSpace(normalizedDeclared)
            || string.Equals(normalizedDeclared, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(detectedContentType, normalizedDeclared, StringComparison.OrdinalIgnoreCase)
            || (string.Equals(detectedContentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "image/jpg", StringComparison.OrdinalIgnoreCase))
            || (string.Equals(detectedContentType, "video/mp4", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "application/mp4", StringComparison.OrdinalIgnoreCase));
    }

    public static string NormalizeContentType(string contentType)
    {
        var semicolonIndex = contentType.IndexOf(';');
        var normalized = semicolonIndex >= 0 ? contentType[..semicolonIndex] : contentType;
        return normalized.Trim().ToLowerInvariant();
    }

    private static string? DetectContentType(ReadOnlySpan<byte> header)
    {
        if (header.Length >= 3
            && header[0] == 0xFF
            && header[1] == 0xD8
            && header[2] == 0xFF)
        {
            return "image/jpeg";
        }

        if (header.Length >= 8
            && header[0] == 0x89
            && header[1] == 0x50
            && header[2] == 0x4E
            && header[3] == 0x47
            && header[4] == 0x0D
            && header[5] == 0x0A
            && header[6] == 0x1A
            && header[7] == 0x0A)
        {
            return "image/png";
        }

        if (header.Length >= 12
            && header[0] == 0x52
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x46
            && header[8] == 0x57
            && header[9] == 0x45
            && header[10] == 0x42
            && header[11] == 0x50)
        {
            return "image/webp";
        }

        if (header.Length >= 6
            && header[0] == 0x47
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x38
            && (header[4] == 0x37 || header[4] == 0x39)
            && header[5] == 0x61)
        {
            return "image/gif";
        }

        if (header.Length >= 12
            && header[4] == 0x66
            && header[5] == 0x74
            && header[6] == 0x79
            && header[7] == 0x70)
        {
            return "video/mp4";
        }

        if (header.Length >= 4
            && header[0] == 0x1A
            && header[1] == 0x45
            && header[2] == 0xDF
            && header[3] == 0xA3)
        {
            return "video/webm";
        }

        return null;
    }
}
