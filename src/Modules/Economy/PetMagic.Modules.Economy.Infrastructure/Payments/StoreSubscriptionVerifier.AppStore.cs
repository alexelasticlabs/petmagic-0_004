using System.Text;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StoreSubscriptionVerifier
{
    private async Task<Result<StoreSubscriptionVerificationResponse>> VerifyAppStoreAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken)
    {
        if (IsLikelyJws(request.ServerVerificationData))
        {
            var signatureValidation = appStoreSignedPayloadValidator.ValidateAppStoreSignedPayload(request.ServerVerificationData);
            if (signatureValidation.IsFailure)
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(signatureValidation.Error);
            }

            var transactionInfo = EconomyWebhookParser.TryReadAppStoreTransactionInfo(request.ServerVerificationData);
            if (!IsValidAppStoreTransaction(transactionInfo, request.ProductId))
            {
                return Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            var isActive = transactionInfo!.ExpiresAtUtc.HasValue
                && transactionInfo.ExpiresAtUtc.Value > DateTime.UtcNow;

            return Result.Success(new StoreSubscriptionVerificationResponse(
                isActive,
                transactionInfo.ExpiresAtUtc,
                isActive ? "active" : "expired",
                transactionInfo.OriginalTransactionId ?? transactionInfo.TransactionId));
        }

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
            request,
            cancellationToken);

        if (productionResult.RequiresSandboxRetry)
        {
                var sandboxResult = await SendAppStoreVerificationAsync(
                    "https://sandbox.itunes.apple.com/verifyReceipt",
                    verificationPayload,
                    request,
                    cancellationToken,
                    requiresSandboxRetry: false);

            return sandboxResult.Result;
        }

        return productionResult.Result;
    }

    private async Task<Result<StoreProductVerificationResponse>> VerifyAppStoreProductAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken)
    {
        if (IsLikelyJws(request.ServerVerificationData))
        {
            var signatureValidation = appStoreSignedPayloadValidator.ValidateAppStoreSignedPayload(request.ServerVerificationData);
            if (signatureValidation.IsFailure)
            {
                return Result.Failure<StoreProductVerificationResponse>(signatureValidation.Error);
            }

            var transactionInfo = EconomyWebhookParser.TryReadAppStoreTransactionInfo(request.ServerVerificationData);
            if (!IsValidAppStoreTransaction(transactionInfo, request.ProductId))
            {
                return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(new StoreProductVerificationResponse(
                true,
                "purchased",
                transactionInfo!.TransactionId ?? request.PurchaseId));
        }

        if (string.IsNullOrWhiteSpace(options.Value.AppStoreSharedSecret)
            || string.IsNullOrWhiteSpace(options.Value.AppStoreBundleId))
        {
            return Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }

        var verificationPayload = JsonSerializer.Serialize(
            new Dictionary<string, object?>
            {
                ["receipt-data"] = request.ServerVerificationData,
                ["password"] = options.Value.AppStoreSharedSecret,
                ["exclude-old-transactions"] = true,
            },
            JsonOptions);

        var productionResult = await SendAppStoreProductVerificationAsync(
            "https://buy.itunes.apple.com/verifyReceipt",
            verificationPayload,
            request,
            cancellationToken);

        if (productionResult.RequiresSandboxRetry)
        {
            var sandboxResult = await SendAppStoreProductVerificationAsync(
                "https://sandbox.itunes.apple.com/verifyReceipt",
                verificationPayload,
                request,
                cancellationToken,
                requiresSandboxRetry: false);

            return sandboxResult.Result;
        }

        return productionResult.Result;
    }

    private async Task<(Result<StoreSubscriptionVerificationResponse> Result, bool RequiresSandboxRetry)> SendAppStoreVerificationAsync(
        string url,
        string payload,
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken,
        bool requiresSandboxRetry = true)
    {
        try
        {
            using var response = await CreateClient().PostAsync(
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

            if (!HasExpectedAppStoreBundleId(root, options.Value.AppStoreBundleId))
            {
                return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            DateTime? expiresAtUtc = null;
            string? externalSubscriptionId = null;
            var matchedProduct = false;

            if (root.TryGetProperty("latest_receipt_info", out var receiptsElement)
                && receiptsElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in receiptsElement.EnumerateArray())
                {
                    if (item.TryGetProperty("product_id", out var productIdElement)
                        && productIdElement.ValueKind == JsonValueKind.String
                        && !string.Equals(productIdElement.GetString(), request.ProductId, StringComparison.Ordinal))
                    {
                        continue;
                    }

                    matchedProduct = true;

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

            if (!matchedProduct)
            {
                return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            var isActive = expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow;
            var result = new StoreSubscriptionVerificationResponse(
                isActive,
                expiresAtUtc,
                isActive ? "active" : "expired",
                externalSubscriptionId);

            return (Result.Success(result), false);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Store subscription verification failed. Provider={Provider} Operation={Operation} Endpoint={Endpoint} UserId={UserId} PlanCode={PlanCode} ProductId={ProductId} PurchaseId={PurchaseId} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} CorrelationId={CorrelationId}",
                "app_store",
                "subscription_verify",
                ResolveAppStoreEndpointName(url),
                request.UserId,
                request.PlanCode,
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeAppStoreVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                CorrelationContext.ResolveOrCreate());

            return (Result.Failure<StoreSubscriptionVerificationResponse>(EconomyErrors.StoreVerificationUnavailable), false);
        }
    }

    private async Task<(Result<StoreProductVerificationResponse> Result, bool RequiresSandboxRetry)> SendAppStoreProductVerificationAsync(
        string url,
        string payload,
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken,
        bool requiresSandboxRetry = true)
    {
        try
        {
            using var response = await CreateClient().PostAsync(
                url,
                new StringContent(payload, Encoding.UTF8, "application/json"),
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                return (Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var root = document.RootElement;
            var status = root.TryGetProperty("status", out var statusElement) && statusElement.ValueKind == JsonValueKind.Number
                ? statusElement.GetInt32()
                : -1;

            if (status == 21007 && requiresSandboxRetry)
            {
                return (Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid), true);
            }

            if (status != 0)
            {
                return (Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            if (!HasExpectedAppStoreBundleId(root, options.Value.AppStoreBundleId))
            {
                return (Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StorePurchaseInvalid), false);
            }

            var matched = false;
            string? transactionId = null;
            string? expectedPurchaseId = string.IsNullOrWhiteSpace(request.PurchaseId)
                ? null
                : request.PurchaseId.Trim();

            if (root.TryGetProperty("receipt", out var receiptElement)
                && receiptElement.ValueKind == JsonValueKind.Object
                && receiptElement.TryGetProperty("in_app", out var inAppElement)
                && inAppElement.ValueKind == JsonValueKind.Array)
            {
                matched = TryMatchAppStoreProductTransaction(
                    inAppElement,
                    request.ProductId,
                    expectedPurchaseId,
                    out transactionId);
            }

            if (!matched
                && root.TryGetProperty("latest_receipt_info", out var latestReceiptsElement)
                && latestReceiptsElement.ValueKind == JsonValueKind.Array)
            {
                matched = TryMatchAppStoreProductTransaction(
                    latestReceiptsElement,
                    request.ProductId,
                    expectedPurchaseId,
                    out transactionId);
            }

            return (Result.Success(new StoreProductVerificationResponse(
                matched,
                matched ? "purchased" : "not_purchased",
                transactionId)), false);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Store product verification failed. Provider={Provider} Operation={Operation} Endpoint={Endpoint} UserId={UserId} ProductId={ProductId} PurchaseId={PurchaseId} VerificationDataKind={VerificationDataKind} HasLocalVerificationData={HasLocalVerificationData} HasTransactionDate={HasTransactionDate} CorrelationId={CorrelationId}",
                "app_store",
                "product_verify",
                ResolveAppStoreEndpointName(url),
                request.UserId,
                request.ProductId,
                EconomyLogSanitizer.SafeExternalId(request.PurchaseId),
                DescribeAppStoreVerificationData(request.ServerVerificationData),
                !string.IsNullOrWhiteSpace(request.LocalVerificationData),
                !string.IsNullOrWhiteSpace(request.TransactionDate),
                CorrelationContext.ResolveOrCreate());

            return (Result.Failure<StoreProductVerificationResponse>(EconomyErrors.StoreVerificationUnavailable), false);
        }
    }

    private static string ResolveAppStoreEndpointName(string url)
    {
        return url.Contains("sandbox", StringComparison.OrdinalIgnoreCase)
            ? "sandbox"
            : "production";
    }

    private bool IsValidAppStoreTransaction(
        EconomyWebhookParser.AppStoreTransactionInfo? transactionInfo,
        string expectedProductId)
    {
        if (transactionInfo is null
            || string.IsNullOrWhiteSpace(transactionInfo.TransactionId)
            || string.IsNullOrWhiteSpace(transactionInfo.BundleId)
            || string.IsNullOrWhiteSpace(transactionInfo.ProductId)
            || !string.Equals(transactionInfo.BundleId, options.Value.AppStoreBundleId, StringComparison.Ordinal)
            || !string.Equals(transactionInfo.ProductId, expectedProductId, StringComparison.Ordinal)
            || transactionInfo.RevokedAtUtc.HasValue)
        {
            return false;
        }

        var expectedEnvironment = options.Value.AppStoreEnvironment?.Trim();
        return string.IsNullOrWhiteSpace(expectedEnvironment)
            || string.IsNullOrWhiteSpace(transactionInfo.Environment)
            || string.Equals(transactionInfo.Environment, expectedEnvironment, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsLikelyJws(string value)
    {
        return value.Split('.').Length >= 3;
    }

    private static bool TryMatchAppStoreProductTransaction(
        JsonElement receiptsArray,
        string expectedProductId,
        string? expectedPurchaseId,
        out string? transactionId)
    {
        transactionId = null;
        foreach (var item in receiptsArray.EnumerateArray())
        {
            if (!item.TryGetProperty("product_id", out var productIdElement)
                || productIdElement.ValueKind != JsonValueKind.String
                || !string.Equals(productIdElement.GetString(), expectedProductId, StringComparison.Ordinal))
            {
                continue;
            }

            var candidateTransactionId = item.TryGetProperty("transaction_id", out var transactionIdElement)
                && transactionIdElement.ValueKind == JsonValueKind.String
                ? transactionIdElement.GetString()
                : null;

            if (!string.IsNullOrWhiteSpace(expectedPurchaseId)
                && !string.IsNullOrWhiteSpace(candidateTransactionId)
                && !string.Equals(candidateTransactionId, expectedPurchaseId, StringComparison.Ordinal))
            {
                continue;
            }

            transactionId = candidateTransactionId;
            return true;
        }

        return false;
    }

    private static bool HasExpectedAppStoreBundleId(JsonElement root, string expectedBundleId)
    {
        if (string.IsNullOrWhiteSpace(expectedBundleId))
        {
            return false;
        }

        return root.TryGetProperty("receipt", out var receiptElement)
            && receiptElement.ValueKind == JsonValueKind.Object
            && receiptElement.TryGetProperty("bundle_id", out var bundleIdElement)
            && bundleIdElement.ValueKind == JsonValueKind.String
            && string.Equals(bundleIdElement.GetString(), expectedBundleId, StringComparison.Ordinal);
    }
}
