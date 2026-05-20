using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed class StoreSubscriptionVerifier(HttpClient httpClient, IOptions<EconomyOptions> options) : IStoreSubscriptionVerifier
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken)
    {
        return request.PaymentProvider switch
        {
            "google_play" => await VerifyGooglePlayAsync(request, cancellationToken),
            "app_store" => await VerifyAppStoreAsync(request, cancellationToken),
            _ => Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.UnsupportedPaymentProvider)
        };
    }

    private async Task<Result<StoreSubscriptionVerificationResponse>> VerifyGooglePlayAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.GooglePlayServiceAccountEmail)
            || string.IsNullOrWhiteSpace(options.Value.GooglePlayPrivateKeyPem)
            || string.IsNullOrWhiteSpace(options.Value.GooglePlayPackageName))
        {
            return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }

        try
        {
            var accessToken = await RequestGoogleAccessTokenAsync(cancellationToken);
            if (string.IsNullOrWhiteSpace(accessToken))
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
            }

            using var requestMessage = new HttpRequestMessage(
                HttpMethod.Get,
                $"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{Uri.EscapeDataString(options.Value.GooglePlayPackageName)}/purchases/subscriptionsv2/tokens/{Uri.EscapeDataString(request.ServerVerificationData)}");
            requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            using var response = await httpClient.SendAsync(requestMessage, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var root = document.RootElement;

            if (!root.TryGetProperty("subscriptionState", out var stateElement)
                || stateElement.ValueKind != JsonValueKind.String)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            var subscriptionState = stateElement.GetString() ?? string.Empty;
            var isActive = string.Equals(subscriptionState, "SUBSCRIPTION_STATE_ACTIVE", StringComparison.Ordinal)
                || string.Equals(subscriptionState, "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", StringComparison.Ordinal);

            DateTime? expiresAtUtc = null;
            string? externalSubscriptionId = null;
            if (root.TryGetProperty("latestOrderId", out var orderIdElement) && orderIdElement.ValueKind == JsonValueKind.String)
            {
                externalSubscriptionId = orderIdElement.GetString();
            }

            if (root.TryGetProperty("lineItems", out var lineItemsElement)
                && lineItemsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in lineItemsElement.EnumerateArray())
                {
                    if (item.TryGetProperty("productId", out var productIdElement)
                        && productIdElement.ValueKind == JsonValueKind.String
                        && !string.Equals(productIdElement.GetString(), request.ProductId, StringComparison.Ordinal))
                    {
                        continue;
                    }

                    if (item.TryGetProperty("expiryTime", out var expiryTimeElement)
                        && expiryTimeElement.ValueKind == JsonValueKind.String
                        && DateTimeOffset.TryParse(expiryTimeElement.GetString(), out var parsedExpiry))
                    {
                        expiresAtUtc = parsedExpiry.UtcDateTime;
                    }

                    break;
                }
            }

            if (!isActive)
            {
                return Result.Success(new StoreSubscriptionVerificationResponse(false, expiresAtUtc, subscriptionState, externalSubscriptionId));
            }

            return Result.Success(new StoreSubscriptionVerificationResponse(true, expiresAtUtc, subscriptionState, externalSubscriptionId));
        }
        catch
        {
            return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }
    }

    private async Task<Result<StoreSubscriptionVerificationResponse>> VerifyAppStoreAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.AppStoreSharedSecret)
            || string.IsNullOrWhiteSpace(options.Value.AppStoreBundleId))
        {
            return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }

        var verificationPayload = JsonSerializer.Serialize(
            new Dictionary<string, object?>
            {
                ["receipt-data"] = request.ServerVerificationData,
                ["password"] = options.Value.AppStoreSharedSecret,
                ["exclude-old-transactions"] = true,
            },
            JsonOptions);

        var productionResult = await SendAppStoreVerificationAsync(
            "https://buy.itunes.apple.com/verifyReceipt",
            verificationPayload,
            request.ProductId,
            cancellationToken);

        if (productionResult.RequiresSandboxRetry)
        {
            var sandboxResult = await SendAppStoreVerificationAsync(
                "https://sandbox.itunes.apple.com/verifyReceipt",
                verificationPayload,
                request.ProductId,
                cancellationToken,
                requiresSandboxRetry: false);

            return sandboxResult.Result;
        }

        return productionResult.Result;
    }

    private async Task<(Result<StoreSubscriptionVerificationResponse> Result, bool RequiresSandboxRetry)> SendAppStoreVerificationAsync(
        string url,
        string payload,
        string productId,
        CancellationToken cancellationToken,
        bool requiresSandboxRetry = true)
    {
        try
        {
            using var response = await httpClient.PostAsync(
                url,
                new StringContent(payload, Encoding.UTF8, "application/json"),
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var root = document.RootElement;
            var status = root.TryGetProperty("status", out var statusElement) && statusElement.ValueKind == JsonValueKind.Number
                ? statusElement.GetInt32()
                : -1;

            if (status == 21007 && requiresSandboxRetry)
            {
                return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid), true);
            }

            if (status != 0)
            {
                return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            DateTime? expiresAtUtc = null;
            string? externalSubscriptionId = null;
            var isActive = false;

            if (root.TryGetProperty("latest_receipt_info", out var receiptsElement)
                && receiptsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in receiptsElement.EnumerateArray())
                {
                    if (item.TryGetProperty("product_id", out var productIdElement)
                        && productIdElement.ValueKind == JsonValueKind.String
                        && !string.Equals(productIdElement.GetString(), productId, StringComparison.Ordinal))
                    {
                        continue;
                    }

                    if (item.TryGetProperty("original_transaction_id", out var transactionElement)
                        && transactionElement.ValueKind == JsonValueKind.String)
                    {
                        externalSubscriptionId = transactionElement.GetString();
                    }

                    if (item.TryGetProperty("expires_date_ms", out var expiresElement)
                        && expiresElement.ValueKind == JsonValueKind.String
                        && long.TryParse(expiresElement.GetString(), out var expiresAtMs))
                    {
                        var candidate = DateTimeOffset.FromUnixTimeMilliseconds(expiresAtMs).UtcDateTime;
                        if (expiresAtUtc is null || candidate > expiresAtUtc)
                        {
                            expiresAtUtc = candidate;
                        }
                    }
                }
            }

            isActive = expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow;
            var result = new StoreSubscriptionVerificationResponse(
                isActive,
                expiresAtUtc,
                isActive ? "active" : "expired",
                externalSubscriptionId);

            return (Result.Success(result), false);
        }
        catch
        {
            return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable), false);
        }
    }

    private async Task<string?> RequestGoogleAccessTokenAsync(CancellationToken cancellationToken)
    {
        var issuedAt = DateTimeOffset.UtcNow;
        var expiresAt = issuedAt.AddMinutes(55);

        var header = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(new Dictionary<string, object?>
        {
            ["alg"] = "RS256",
            ["typ"] = "JWT"
        }));

        var claimSet = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(new Dictionary<string, object?>
        {
            ["iss"] = options.Value.GooglePlayServiceAccountEmail,
            ["scope"] = "https://www.googleapis.com/auth/androidpublisher",
            ["aud"] = "https://oauth2.googleapis.com/token",
            ["iat"] = issuedAt.ToUnixTimeSeconds(),
            ["exp"] = expiresAt.ToUnixTimeSeconds()
        }));

        var unsignedToken = $"{header}.{claimSet}";
        var signature = SignGoogleJwt(unsignedToken, options.Value.GooglePlayPrivateKeyPem);
        var assertion = $"{unsignedToken}.{signature}";

        using var response = await httpClient.PostAsync(
            "https://oauth2.googleapis.com/token",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                ["assertion"] = assertion
            }),
            cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return document.RootElement.TryGetProperty("access_token", out var tokenElement)
            && tokenElement.ValueKind == JsonValueKind.String
            ? tokenElement.GetString()
            : null;
    }

    private static string SignGoogleJwt(string value, string pem)
    {
        using var rsa = RSA.Create();
        rsa.ImportFromPem(pem);
        var signature = rsa.SignData(Encoding.UTF8.GetBytes(value), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return Base64UrlEncode(signature);
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
}