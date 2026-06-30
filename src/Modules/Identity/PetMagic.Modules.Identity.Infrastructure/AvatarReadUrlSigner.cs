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

    public int ReadUrlTtlMinutes { get; init; } = 720;
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
        if (!TryBuildManagedPath(fileUrl, out var managedPath) || string.IsNullOrWhiteSpace(signingOptions.SigningKey))
        {
            return fileUrl;
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

        if (!Uri.TryCreate(fileUrl, UriKind.Absolute, out var uri)
            || !Uri.TryCreate(storageOptions.PublicBaseUrl, UriKind.Absolute, out var baseUri))
        {
            return false;
        }

        if (!UriHasSameOrigin(uri, baseUri))
        {
            return false;
        }

        return TryExtractCanonicalManagedPath(uri.AbsolutePath.Replace('\\', '/'), out managedPath);
    }

    private static bool TryResolveManagedRequestPath(string? requestPath, out string managedPath)
    {
        managedPath = string.Empty;
        if (string.IsNullOrWhiteSpace(requestPath) || requestPath.Contains('\\'))
        {
            return false;
        }

        return TryExtractCanonicalManagedPath(requestPath.Replace('\\', '/'), out managedPath);
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

    private static bool TryExtractCanonicalManagedPath(string normalizedPath, out string managedPath)
    {
        managedPath = string.Empty;
        var segmentIndex = normalizedPath.IndexOf(ManagedPathSegment, StringComparison.OrdinalIgnoreCase);
        if (segmentIndex < 0)
        {
            return false;
        }

        managedPath = normalizedPath[segmentIndex..];
        return managedPath.Length > ManagedPathSegment.Length;
    }
}
