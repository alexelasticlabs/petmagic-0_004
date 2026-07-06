using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

using NSec.Cryptography;
using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Api;

internal interface IFalWebhookSignatureVerifier
{
    Task<bool> VerifyAsync(IHeaderDictionary headers, byte[] body, CancellationToken cancellationToken);
}

internal sealed class FalWebhookSignatureVerifier(
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration,
    IMemoryCache memoryCache,
    ILogger<FalWebhookSignatureVerifier> logger) : IFalWebhookSignatureVerifier
{
    public const string HttpClientName = "FalWebhookJwks";

    private const string RequestIdHeader = "X-Fal-Webhook-Request-Id";
    private const string UserIdHeader = "X-Fal-Webhook-User-Id";
    private const string TimestampHeader = "X-Fal-Webhook-Timestamp";
    private const string SignatureHeader = "X-Fal-Webhook-Signature";
    private const int TimestampLeewaySeconds = 300;
    private const int JwksResponseMaxChars = 64 * 1024;
    private const string JwksCacheKey = "templates:fal:webhook:jwks";

    public async Task<bool> VerifyAsync(IHeaderDictionary headers, byte[] body, CancellationToken cancellationToken)
    {
        var requestId = headers[RequestIdHeader].FirstOrDefault();
        var userId = headers[UserIdHeader].FirstOrDefault();
        var timestamp = headers[TimestampHeader].FirstOrDefault();
        var signatureHex = headers[SignatureHeader].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(requestId)
            || string.IsNullOrWhiteSpace(userId)
            || string.IsNullOrWhiteSpace(timestamp)
            || string.IsNullOrWhiteSpace(signatureHex))
        {
            TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("missing_header");
            return false;
        }

        if (!long.TryParse(timestamp, out var timestampSeconds))
        {
            TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("invalid_timestamp");
            return false;
        }

        var nowSeconds = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (Math.Abs(nowSeconds - timestampSeconds) > TimestampLeewaySeconds)
        {
            TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("timestamp_out_of_range");
            return false;
        }

        byte[] signature;
        try
        {
            signature = Convert.FromHexString(signatureHex);
        }
        catch (FormatException)
        {
            TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("invalid_signature_encoding");
            return false;
        }

        var bodyHashHex = Convert.ToHexString(SHA256.HashData(body)).ToLowerInvariant();
        var message = Encoding.UTF8.GetBytes(string.Join('\n', requestId, userId, timestamp, bodyHashHex));
        var keys = await GetPublicKeysAsync(cancellationToken);
        foreach (var keyBytes in keys)
        {
            if (VerifyWithKey(keyBytes, message, signature))
            {
                return true;
            }
        }

        TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("signature_mismatch");
        return false;
    }

    private async Task<IReadOnlyList<byte[]>> GetPublicKeysAsync(CancellationToken cancellationToken)
    {
        if (memoryCache.TryGetValue<IReadOnlyList<byte[]>>(JwksCacheKey, out var cached) && cached is { Count: > 0 })
        {
            return cached;
        }

        var jwksUrl = configuration["Templates:Fal:WebhookJwksUrl"] ?? "https://rest.fal.ai/.well-known/jwks.json";
        try
        {
            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .GetAsync(jwksUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "fal webhook JWKS fetch failed. StatusCode={StatusCode} JwksUrl={JwksUrl}",
                    response.StatusCode,
                    SafeLogValues.SanitizeText(jwksUrl));
                return [];
            }

            var responseBody = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                JwksResponseMaxChars);
            using var document = JsonDocument.Parse(responseBody);
            if (!document.RootElement.TryGetProperty("keys", out var keysElement)
                || keysElement.ValueKind != JsonValueKind.Array)
            {
                return [];
            }

            var keys = new List<byte[]>();
            foreach (var keyElement in keysElement.EnumerateArray())
            {
                if (keyElement.TryGetProperty("x", out var xElement)
                    && xElement.ValueKind == JsonValueKind.String
                    && TryDecodeBase64Url(xElement.GetString(), out var keyBytes)
                    && keyBytes.Length == 32)
                {
                    keys.Add(keyBytes);
                }
            }

            memoryCache.Set(JwksCacheKey, keys, TimeSpan.FromHours(12));
            return keys;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "fal webhook JWKS fetch failed. ExceptionType={ExceptionType} JwksUrl={JwksUrl}",
                SafeLogValues.ExceptionType(exception),
                SafeLogValues.SanitizeText(jwksUrl));
            return [];
        }
    }

    private static bool VerifyWithKey(byte[] publicKeyBytes, byte[] message, byte[] signature)
    {
        try
        {
            var algorithm = SignatureAlgorithm.Ed25519;
            var publicKey = PublicKey.Import(algorithm, publicKeyBytes, KeyBlobFormat.RawPublicKey);
            return algorithm.Verify(publicKey, message, signature);
        }
        catch (Exception)
        {
            return false;
        }
    }

    private static bool TryDecodeBase64Url(string? value, out byte[] bytes)
    {
        bytes = [];
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var padded = value.Replace('-', '+').Replace('_', '/');
        padded = padded.PadRight(padded.Length + ((4 - (padded.Length % 4)) % 4), '=');
        try
        {
            bytes = Convert.FromBase64String(padded);
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
