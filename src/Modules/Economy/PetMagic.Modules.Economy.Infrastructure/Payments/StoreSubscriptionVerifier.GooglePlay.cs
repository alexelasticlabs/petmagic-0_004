using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StoreSubscriptionVerifier
{
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

            using var response = await CreateClient().SendAsync(requestMessage, cancellationToken);
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
            var matchedLineItem = false;
            if (root.TryGetProperty("latestOrderId", out var orderIdElement) && orderIdElement.ValueKind == JsonValueKind.String)
            {
                externalSubscriptionId = orderIdElement.GetString();
            }

            if (root.TryGetProperty("lineItems", out var lineItemsElement)
                && lineItemsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in lineItemsElement.EnumerateArray())
                {
                    if (!item.TryGetProperty("productId", out var productIdElement)
                        || productIdElement.ValueKind != JsonValueKind.String
                        || !string.Equals(productIdElement.GetString(), request.ProductId, StringComparison.Ordinal))
                    {
                        continue;
                    }

                    matchedLineItem = true;

                    if (item.TryGetProperty("expiryTime", out var expiryTimeElement)
                        && expiryTimeElement.ValueKind == JsonValueKind.String
                        && DateTimeOffset.TryParse(expiryTimeElement.GetString(), out var parsedExpiry))
                    {
                        expiresAtUtc = parsedExpiry.UtcDateTime;
                    }

                    break;
                }
            }

            if (!matchedLineItem)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            if (!isActive)
            {
                return Result.Success(new StoreSubscriptionVerificationResponse(false, expiresAtUtc, subscriptionState, externalSubscriptionId));
            }

            if (!expiresAtUtc.HasValue)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(new StoreSubscriptionVerificationResponse(true, expiresAtUtc, subscriptionState, externalSubscriptionId));
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Store subscription verification failed. Provider={Provider} Operation={Operation} UserId={UserId} PlanCode={PlanCode} ProductId={ProductId} PurchaseId={PurchaseId} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} CorrelationId={CorrelationId}",
                "google_play",
                "subscription_verify",
                request.UserId,
                request.PlanCode,
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeGooglePlayVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                CorrelationContext.ResolveOrCreate());

            return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }
    }

    private async Task<Result<StoreProductVerificationResponse>> VerifyGooglePlayProductAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(options.Value.GooglePlayServiceAccountEmail)
            || string.IsNullOrWhiteSpace(options.Value.GooglePlayPrivateKeyPem)
            || string.IsNullOrWhiteSpace(options.Value.GooglePlayPackageName))
        {
            return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }

        try
        {
            var accessToken = await RequestGoogleAccessTokenAsync(cancellationToken);
            if (string.IsNullOrWhiteSpace(accessToken))
            {
                return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
            }

            using var requestMessage = new HttpRequestMessage(
                HttpMethod.Get,
                $"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{Uri.EscapeDataString(options.Value.GooglePlayPackageName)}/purchases/products/{Uri.EscapeDataString(request.ProductId)}/tokens/{Uri.EscapeDataString(request.ServerVerificationData)}");
            requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            using var response = await CreateClient().SendAsync(requestMessage, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var root = document.RootElement;

            var purchaseState = root.TryGetProperty("purchaseState", out var purchaseStateElement)
                && purchaseStateElement.ValueKind == JsonValueKind.Number
                ? purchaseStateElement.GetInt32()
                : -1;
            var acknowledgementState = root.TryGetProperty("acknowledgementState", out var acknowledgementStateElement)
                && acknowledgementStateElement.ValueKind == JsonValueKind.Number
                ? acknowledgementStateElement.GetInt32()
                : 1;
            var purchaseType = root.TryGetProperty("purchaseType", out var purchaseTypeElement)
                && purchaseTypeElement.ValueKind == JsonValueKind.Number
                ? purchaseTypeElement.GetInt32()
                : 0;
            var hasRefundOrCancelSignal = root.TryGetProperty("voidedPurchaseType", out _)
                || root.TryGetProperty("cancelReason", out _);

            var isPurchased = purchaseState == 0
                && acknowledgementState == 1
                && !hasRefundOrCancelSignal
                && purchaseType >= 0;
            var orderId = root.TryGetProperty("orderId", out var orderIdElement)
                && orderIdElement.ValueKind == JsonValueKind.String
                ? orderIdElement.GetString()
                : request.PurchaseId;

            return Result.Success(new StoreProductVerificationResponse(
                isPurchased,
                isPurchased ? "purchased" : "not_purchased",
                orderId));
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Store product verification failed. Provider={Provider} Operation={Operation} UserId={UserId} ProductId={ProductId} PurchaseId={PurchaseId} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} CorrelationId={CorrelationId}",
                "google_play",
                "product_verify",
                request.UserId,
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeGooglePlayVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                CorrelationContext.ResolveOrCreate());

            return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
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

        using var response = await CreateClient().PostAsync(
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
