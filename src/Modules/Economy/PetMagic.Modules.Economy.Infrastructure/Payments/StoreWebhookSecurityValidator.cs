using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;
using Google.Apis.Auth;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed record GoogleStoreWebhookTokenPayload(string Issuer, string? Email, bool EmailVerified, string Subject);

public interface IGoogleStoreWebhookTokenVerifier
{
    Task<Result<GoogleStoreWebhookTokenPayload>> ValidateAsync(string idToken, string audience, CancellationToken cancellationToken);
}

public sealed class GoogleStoreWebhookTokenVerifier : IGoogleStoreWebhookTokenVerifier
{
    public async Task<Result<GoogleStoreWebhookTokenPayload>> ValidateAsync(string idToken, string audience, CancellationToken cancellationToken)
    {
        try
        {
            var payload = await GoogleJsonWebSignature.ValidateAsync(
                idToken,
                new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = [audience]
                });

            return Result.Success(new GoogleStoreWebhookTokenPayload(
                payload.Issuer,
                payload.Email,
                payload.EmailVerified,
                payload.Subject));
        }
        catch (InvalidJwtException)
        {
            return Result.Failure<GoogleStoreWebhookTokenPayload>(EconomyErrors.InvalidStoreWebhookSignature);
        }
    }
}

public sealed class StoreWebhookSecurityValidator(
    IOptions<EconomyOptions> options,
    IGoogleStoreWebhookTokenVerifier googleTokenVerifier) : IStoreWebhookSecurityValidator
{
    private static readonly string[] ValidGoogleIssuers = ["accounts.google.com", "https://accounts.google.com"];

    public Result ValidateAppStoreSignedPayload(string signedPayload)
    {
        if (string.IsNullOrWhiteSpace(signedPayload))
        {
            return Result.Failure(EconomyErrors.InvalidWebhookPayload);
        }

        try
        {
            var parts = signedPayload.Split('.');
            if (parts.Length != 3)
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            using var headerDocument = JsonDocument.Parse(DecodeBase64UrlJson(parts[0]));
            var header = headerDocument.RootElement;
            var algorithm = header.TryGetProperty("alg", out var algElement) && algElement.ValueKind == JsonValueKind.String
                ? algElement.GetString()
                : null;

            if (!string.Equals(algorithm, "ES256", StringComparison.Ordinal))
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            if (!header.TryGetProperty("x5c", out var chainElement) || chainElement.ValueKind != JsonValueKind.Array || chainElement.GetArrayLength() == 0)
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

#pragma warning disable SYSLIB0057
            var certificates = chainElement.EnumerateArray()
                .Where(x => x.ValueKind == JsonValueKind.String)
                .Select(x =>
                {
                    var certificateBytes = Convert.FromBase64String(x.GetString()!);
                    return X509CertificateLoader.LoadCertificate(certificateBytes.AsSpan());
                })
                .ToArray();
#pragma warning restore SYSLIB0057

            if (certificates.Length == 0)
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            using var chain = new X509Chain();
            chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
            chain.ChainPolicy.VerificationTime = DateTime.UtcNow;
            chain.ChainPolicy.VerificationFlags = X509VerificationFlags.NoFlag;

            foreach (var certificate in certificates.Skip(1))
            {
                chain.ChainPolicy.ExtraStore.Add(certificate);
            }

            if (!chain.Build(certificates[0]))
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            var signedBytes = Encoding.ASCII.GetBytes($"{parts[0]}.{parts[1]}");
            var signatureBytes = DecodeBase64Url(parts[2]);
            using var ecdsa = certificates[0].GetECDsaPublicKey();

            if (ecdsa is null || !ecdsa.VerifyData(signedBytes, signatureBytes, HashAlgorithmName.SHA256))
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            if (!ValidateAppStoreBundleId(parts[1], options.Value.AppStoreBundleId))
            {
                return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
            }

            return Result.Success();
        }
        catch
        {
            return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
        }
    }

    public async Task<Result> ValidateGooglePlayPushAsync(string? authorizationHeader, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.GooglePlayPubSubAudience))
        {
            return Result.Failure(EconomyErrors.StoreVerificationUnavailable);
        }

        var token = ExtractBearerToken(authorizationHeader);
        if (string.IsNullOrWhiteSpace(token))
        {
            return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
        }

        var validation = await googleTokenVerifier.ValidateAsync(token, options.Value.GooglePlayPubSubAudience, cancellationToken);
        if (validation.IsFailure)
        {
            return Result.Failure(validation.Error);
        }

        if (!ValidGoogleIssuers.Contains(validation.Value.Issuer, StringComparer.Ordinal))
        {
            return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
        }

        if (!validation.Value.EmailVerified)
        {
            return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
        }

        if (!string.IsNullOrWhiteSpace(options.Value.GooglePlayPubSubExpectedEmail)
            && !string.Equals(validation.Value.Email, options.Value.GooglePlayPubSubExpectedEmail, StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure(EconomyErrors.InvalidStoreWebhookSignature);
        }

        return Result.Success();
    }

    private static string? ExtractBearerToken(string? authorizationHeader)
    {
        if (string.IsNullOrWhiteSpace(authorizationHeader))
        {
            return null;
        }

        const string prefix = "Bearer ";
        return authorizationHeader.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            ? authorizationHeader[prefix.Length..].Trim()
            : null;
    }

    private static bool ValidateAppStoreBundleId(string payloadSegment, string expectedBundleId)
    {
        if (string.IsNullOrWhiteSpace(expectedBundleId))
        {
            return true;
        }

        using var payloadDocument = JsonDocument.Parse(DecodeBase64UrlJson(payloadSegment));
        var payload = payloadDocument.RootElement;

        var bundleId = TryReadBundleId(payload);
        if (!string.IsNullOrWhiteSpace(bundleId))
        {
            return string.Equals(bundleId, expectedBundleId, StringComparison.Ordinal);
        }

        if (payload.TryGetProperty("data", out var dataElement) && dataElement.ValueKind == JsonValueKind.Object)
        {
            foreach (var propertyName in new[] { "signedTransactionInfo", "signedRenewalInfo" })
            {
                if (!dataElement.TryGetProperty(propertyName, out var nestedElement) || nestedElement.ValueKind != JsonValueKind.String)
                {
                    continue;
                }

                using var nestedDocument = JsonDocument.Parse(DecodeSignedPayloadJson(nestedElement.GetString()!));
                var nestedBundleId = TryReadBundleId(nestedDocument.RootElement);
                if (!string.IsNullOrWhiteSpace(nestedBundleId))
                {
                    return string.Equals(nestedBundleId, expectedBundleId, StringComparison.Ordinal);
                }
            }
        }

        return false;
    }

    private static string? TryReadBundleId(JsonElement element)
    {
        return element.TryGetProperty("bundleId", out var bundleElement) && bundleElement.ValueKind == JsonValueKind.String
            ? bundleElement.GetString()
            : null;
    }

    private static string DecodeSignedPayloadJson(string signedPayload)
    {
        var parts = signedPayload.Split('.');
        if (parts.Length < 2)
        {
            throw new InvalidOperationException("Invalid signed payload.");
        }

        return DecodeBase64UrlJson(parts[1]);
    }

    private static string DecodeBase64UrlJson(string value)
    {
        return Encoding.UTF8.GetString(DecodeBase64Url(value));
    }

    private static byte[] DecodeBase64Url(string value)
    {
        var normalized = value.Replace('-', '+').Replace('_', '/');
        var padding = normalized.Length % 4;
        if (padding != 0)
        {
            normalized = normalized.PadRight(normalized.Length + (4 - padding), '=');
        }

        return Convert.FromBase64String(normalized);
    }
}