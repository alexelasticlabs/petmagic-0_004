using System.Security.Cryptography;
using System.Text;

using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public interface IAvatarReadUrlSigner
{
    string CreateReadUrl(string fileUrl);

    bool IsAuthorizedRequest(string requestPath, IReadOnlyDictionary<string, string?> query);
}

public sealed class AvatarReadUrlSigningOptions
{
    public string SigningKey { get; init; } = string.Empty;

    public int ReadUrlTtlMinutes { get; init; } = 60;
}

public sealed class AvatarReadUrlSigner(
    AvatarStorageOptions storageOptions,
    AvatarReadUrlSigningOptions signingOptions) : IAvatarReadUrlSigner
{
    private const string ManagedPathSegment = "/user-avatars/";
    private const string ExpiresQueryKey = "pmexp";
    private const string SignatureQueryKey = "pmsig";

    public string CreateReadUrl(string fileUrl)
    {
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return string.Empty;
        }

        if (!TryBuildManagedPath(fileUrl, out var managedPath))
        {
            return ContainsManagedPathSegment(fileUrl) ? string.Empty : fileUrl;
        }

        if (string.IsNullOrWhiteSpace(signingOptions.SigningKey))
        {
            return string.Empty;
        }

        var expiresAtUnixSeconds = DateTimeOffset.UtcNow
            .AddMinutes(Math.Max(1, signingOptions.ReadUrlTtlMinutes))
            .ToUnixTimeSeconds();
        var signature = ComputeSignature(managedPath, expiresAtUnixSeconds);

        var builder = new UriBuilder(fileUrl)
        {
            Query =
                $"{ExpiresQueryKey}={Uri.EscapeDataString(expiresAtUnixSeconds.ToString())}&{SignatureQueryKey}={Uri.EscapeDataString(signature)}"
        };
        return builder.Uri.ToString();
    }

    public bool IsAuthorizedRequest(string requestPath, IReadOnlyDictionary<string, string?> query)
    {
        if (!TryResolveManagedRequestPath(requestPath, out var managedPath)
            || string.IsNullOrWhiteSpace(signingOptions.SigningKey))
        {
            return false;
        }

        query.TryGetValue(ExpiresQueryKey, out var expiresRaw);
        query.TryGetValue(SignatureQueryKey, out var signatureRaw);
        if (!long.TryParse(expiresRaw, out var expiresAtUnixSeconds)
            || expiresAtUnixSeconds <= DateTimeOffset.UtcNow.ToUnixTimeSeconds()
            || string.IsNullOrWhiteSpace(signatureRaw))
        {
            return false;
        }

        var expectedSignature = ComputeSignature(managedPath, expiresAtUnixSeconds);
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expectedSignature),
            Encoding.UTF8.GetBytes(signatureRaw));
    }

    private bool TryBuildManagedPath(string fileUrl, out string managedPath)
    {
        managedPath = string.Empty;
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return false;
        }

        if (ContainsUnsafePathSegments(fileUrl.Replace('\\', '/')))
        {
            return false;
        }

        if (!Uri.TryCreate(fileUrl, UriKind.Absolute, out var uri)
            || !Uri.TryCreate(storageOptions.PublicBaseUrl, UriKind.Absolute, out var baseUri))
        {
            return false;
        }

        if (!UriHasSameOrigin(uri, baseUri))
        {
            return false;
        }

        return TryExtractCanonicalManagedPath(
            uri.AbsolutePath.Replace('\\', '/'),
            baseUri.AbsolutePath,
            out managedPath);
    }

    private bool TryResolveManagedRequestPath(string? requestPath, out string managedPath)
    {
        managedPath = string.Empty;
        if (string.IsNullOrWhiteSpace(requestPath) || requestPath.Contains('\\'))
        {
            return false;
        }

        var basePath = Uri.TryCreate(storageOptions.PublicBaseUrl, UriKind.Absolute, out var baseUri)
            ? baseUri.AbsolutePath
            : string.Empty;
        return TryExtractCanonicalManagedPath(requestPath.Replace('\\', '/'), basePath, out managedPath);
    }

    private string ComputeSignature(string managedPath, long expiresAtUnixSeconds)
    {
        var payload = $"{managedPath}\n{expiresAtUnixSeconds}";
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(signingOptions.SigningKey));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
        return Convert.ToHexString(hash);
    }

    private static bool UriHasSameOrigin(Uri uri, Uri baseUri)
    {
        return string.Equals(uri.Scheme, baseUri.Scheme, StringComparison.OrdinalIgnoreCase)
            && string.Equals(uri.Host, baseUri.Host, StringComparison.OrdinalIgnoreCase)
            && uri.Port == baseUri.Port;
    }

    private static bool TryExtractCanonicalManagedPath(
        string normalizedPath,
        string? publicBasePath,
        out string managedPath)
    {
        managedPath = string.Empty;
        if (normalizedPath.StartsWith(ManagedPathSegment, StringComparison.OrdinalIgnoreCase))
        {
            return TryNormalizeManagedPath(normalizedPath, out managedPath);
        }

        var normalizedBasePath = NormalizePublicBasePath(publicBasePath);
        if (string.IsNullOrWhiteSpace(normalizedBasePath))
        {
            return false;
        }

        var prefixedManagedPath = $"{normalizedBasePath}{ManagedPathSegment}";
        if (!normalizedPath.StartsWith(prefixedManagedPath, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return TryNormalizeManagedPath(normalizedPath[normalizedBasePath.Length..], out managedPath);
    }

    private static bool TryNormalizeManagedPath(string candidate, out string managedPath)
    {
        managedPath = string.Empty;
        if (!candidate.StartsWith(ManagedPathSegment, StringComparison.OrdinalIgnoreCase)
            || candidate.Length <= ManagedPathSegment.Length
            || candidate.EndsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var segments = candidate
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Length <= 1
            || !string.Equals(segments[0], ManagedPathSegment.Trim('/'), StringComparison.OrdinalIgnoreCase)
            || segments.Any(IsUnsafePathSegment))
        {
            return false;
        }

        managedPath = $"/{string.Join('/', segments)}";
        return true;
    }

    private static bool IsUnsafePathSegment(string segment)
    {
        if (string.Equals(segment, ".", StringComparison.Ordinal)
            || string.Equals(segment, "..", StringComparison.Ordinal))
        {
            return true;
        }

        var decodedSegment = Uri.UnescapeDataString(segment);
        return string.Equals(decodedSegment, ".", StringComparison.Ordinal)
            || string.Equals(decodedSegment, "..", StringComparison.Ordinal);
    }

    private static bool ContainsUnsafePathSegments(string value)
    {
        return value
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Any(IsUnsafePathSegment);
    }

    private static string NormalizePublicBasePath(string? publicBasePath)
    {
        if (string.IsNullOrWhiteSpace(publicBasePath) || publicBasePath == "/")
        {
            return string.Empty;
        }

        return publicBasePath.TrimEnd('/');
    }

    private static bool ContainsManagedPathSegment(string fileUrl)
    {
        return fileUrl.Contains(ManagedPathSegment, StringComparison.OrdinalIgnoreCase)
            || fileUrl.Contains(ManagedPathSegment.TrimStart('/'), StringComparison.OrdinalIgnoreCase);
    }
}
