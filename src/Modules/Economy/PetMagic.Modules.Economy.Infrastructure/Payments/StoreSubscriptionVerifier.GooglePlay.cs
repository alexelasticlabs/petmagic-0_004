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

            using var response = await CreateClient().SendAsync(
                requestMessage,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            using var document = await ReadProviderJsonAsync(response.Content, cancellationToken);
            var root = document.RootElement;

            if (IsGooglePlayProduction
                && root.TryGetProperty("testPurchase", out var testPurchaseElement)
                && testPurchaseElement.ValueKind == JsonValueKind.Object)
            {
                LogGooglePlayTestPurchaseRejected("subscription_verify", request.UserId, request.ProductId);
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            if (!root.TryGetProperty("subscriptionState", out var stateElement)
                || stateElement.ValueKind != JsonValueKind.String)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            var subscriptionState = stateElement.GetString() ?? string.Empty;
            var isActive = string.Equals(subscriptionState, "SUBSCRIPTION_STATE_ACTIVE", StringComparison.Ordinal)
                || string.Equals(subscriptionState, "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", StringComparison.Ordinal);
            var providerAccountId = root.TryGetProperty("externalAccountIdentifiers", out var accountIdentifiersElement)
                && accountIdentifiersElement.ValueKind == JsonValueKind.Object
                && accountIdentifiersElement.TryGetProperty("obfuscatedExternalAccountId", out var accountIdElement)
                && accountIdElement.ValueKind == JsonValueKind.String
                    ? accountIdElement.GetString()
                    : null;
            var accountBindingState = ResolveAccountBindingState(providerAccountId, request.UserId);

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
                return Result.Success(new StoreSubscriptionVerificationResponse(
                    false,
                    expiresAtUtc,
                    subscriptionState,
                    externalSubscriptionId,
                    accountBindingState,
                    ResolveBoundUserId(providerAccountId)));
            }

            if (!expiresAtUtc.HasValue)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(new StoreSubscriptionVerificationResponse(
                true,
                expiresAtUtc,
                subscriptionState,
                externalSubscriptionId,
                accountBindingState,
                ResolveBoundUserId(providerAccountId)));
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Store subscription verification failed. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} PlanCode={PlanCode} ProductId={ProductId} PurchaseIdSafe={PurchaseIdSafe} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                "google_play",
                "subscription_verify",
                EconomyLogSanitizer.SafeUserId(request.UserId),
                request.PlanCode,
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeGooglePlayVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                SafeLogValues.ExceptionType(ex),
                SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

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

            using var response = await CreateClient().SendAsync(
                requestMessage,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            using var document = await ReadProviderJsonAsync(response.Content, cancellationToken);
            var root = document.RootElement;

            var purchaseState = root.TryGetProperty("purchaseState", out var purchaseStateElement)
                && purchaseStateElement.ValueKind == JsonValueKind.Number
                ? purchaseStateElement.GetInt32()
                : -1;
            int? purchaseType = root.TryGetProperty("purchaseType", out var purchaseTypeElement)
                && purchaseTypeElement.ValueKind == JsonValueKind.Number
                ? purchaseTypeElement.GetInt32()
                : null;
            var quantity = root.TryGetProperty("quantity", out var quantityElement)
                && quantityElement.ValueKind == JsonValueKind.Number
                && quantityElement.TryGetInt32(out var parsedQuantity)
                    ? parsedQuantity
                    : 1;
            int? refundableQuantity = root.TryGetProperty("refundableQuantity", out var refundableQuantityElement)
                && refundableQuantityElement.ValueKind == JsonValueKind.Number
                && refundableQuantityElement.TryGetInt32(out var parsedRefundableQuantity)
                    ? parsedRefundableQuantity
                    : null;
            var hasRefundOrCancelSignal = root.TryGetProperty("voidedPurchaseType", out _)
                || root.TryGetProperty("cancelReason", out _);

            var isDisallowedProductionPurchaseType = IsGooglePlayProduction
                && purchaseType is 0 or 2;
            if (isDisallowedProductionPurchaseType)
            {
                LogGooglePlayTestPurchaseRejected("product_verify", request.UserId, request.ProductId);
            }

            var isPurchased = purchaseState == 0
                && !hasRefundOrCancelSignal
                && !isDisallowedProductionPurchaseType
                && quantity == 1
                && (!refundableQuantity.HasValue || refundableQuantity.Value == quantity);
            var orderId = root.TryGetProperty("orderId", out var orderIdElement)
                && orderIdElement.ValueKind == JsonValueKind.String
                ? orderIdElement.GetString()
                : request.PurchaseId;
            var providerAccountId = root.TryGetProperty("obfuscatedExternalAccountId", out var accountIdElement)
                && accountIdElement.ValueKind == JsonValueKind.String
                    ? accountIdElement.GetString()
                    : null;

            return Result.Success(new StoreProductVerificationResponse(
                isPurchased,
                isPurchased ? "purchased" : "not_purchased",
                orderId,
                ResolveAccountBindingState(providerAccountId, request.UserId),
                ResolveBoundUserId(providerAccountId)));
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Store product verification failed. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} ProductId={ProductId} PurchaseIdSafe={PurchaseIdSafe} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                "google_play",
                "product_verify",
                EconomyLogSanitizer.SafeUserId(request.UserId),
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeGooglePlayVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                SafeLogValues.ExceptionType(ex),
                SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

            return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }
    }

    private bool IsGooglePlayProduction =>
        string.Equals(options.Value.GooglePlayEnvironment?.Trim(), "production", StringComparison.OrdinalIgnoreCase);

    private void LogGooglePlayTestPurchaseRejected(string operation, Guid userId, string productId)
    {
        EconomyMetrics.RecordSandboxReceiptInProduction("google_play", operation);
        logger?.LogError(
            "SECURITY: Google Play test or rewarded purchase rejected in production. Operation={Operation} UserIdHash={UserIdHash} ProductId={ProductId} CorrelationIdHash={CorrelationIdHash}",
            operation,
            EconomyLogSanitizer.SafeUserId(userId),
            productId,
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));
    }

    private async Task<string?> RequestGoogleAccessTokenAsync(CancellationToken cancellationToken)
    {
        if (TryGetCachedGoogleAccessToken(out var cachedAccessToken))
        {
            return cachedAccessToken;
        }

        await googleAccessTokenRefreshLock.WaitAsync(cancellationToken);
        try
        {
            if (TryGetCachedGoogleAccessToken(out cachedAccessToken))
            {
                return cachedAccessToken;
            }

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

            using var tokenRequest = new HttpRequestMessage(HttpMethod.Post, "https://oauth2.googleapis.com/token")
            {
                Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = assertion
                })
            };
            using var response = await CreateClient().SendAsync(
                tokenRequest,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                return null;
            }

            using var document = await ReadProviderJsonAsync(response.Content, cancellationToken);
            if (!document.RootElement.TryGetProperty("access_token", out var tokenElement)
                || tokenElement.ValueKind != JsonValueKind.String)
            {
                return null;
            }

            var accessToken = tokenElement.GetString();
            if (string.IsNullOrWhiteSpace(accessToken))
            {
                return null;
            }

            var expiresInSeconds = document.RootElement.TryGetProperty("expires_in", out var expiresInElement)
                && expiresInElement.ValueKind == JsonValueKind.Number
                && expiresInElement.TryGetInt32(out var parsedExpiresIn)
                ? parsedExpiresIn
                : 3600;
            CacheGoogleAccessToken(accessToken, expiresInSeconds);
            return accessToken;
        }
        finally
        {
            googleAccessTokenRefreshLock.Release();
        }
    }

    private static string SignGoogleJwt(string value, string pem)
    {
        using var rsa = RSA.Create();
        rsa.ImportFromPem(pem);
        var signature = rsa.SignData(Encoding.UTF8.GetBytes(value), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return Base64UrlEncode(signature);
    }

    private static async Task<JsonDocument> ReadProviderJsonAsync(
        HttpContent content,
        CancellationToken cancellationToken)
    {
        var responseBody = await SafeHttpContentReader.ReadRawStringPrefixAsync(
            content,
            cancellationToken,
            ProviderJsonResponseMaxChars);
        return JsonDocument.Parse(responseBody);
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
}
