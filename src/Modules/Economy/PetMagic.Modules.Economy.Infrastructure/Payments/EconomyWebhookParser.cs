using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

internal static partial class EconomyWebhookParser
{
    public sealed record AppStoreTransactionInfo(
        string? BundleId,
        string? ProductId,
        string? TransactionId,
        string? OriginalTransactionId,
        DateTime? ExpiresAtUtc,
        DateTime? RevokedAtUtc,
        string? Environment);

    public static bool IsStoreSubscriptionPremium(string status, DateTime? currentPeriodEndUtc)
    {
        if (!string.Equals(status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "GracePeriod", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return currentPeriodEndUtc is null || currentPeriodEndUtc >= DateTime.UtcNow;
    }

    public static string MapStoreSubscriptionStatus(string providerStatus, bool isActive)
    {
        if (!isActive)
        {
            return "Expired";
        }

        return providerStatus.Contains("GRACE", StringComparison.OrdinalIgnoreCase)
            ? "GracePeriod"
            : "Active";
    }

    public static string MapStripeSubscriptionStatus(string? providerStatus)
    {
        if (string.Equals(providerStatus, "trialing", StringComparison.OrdinalIgnoreCase))
        {
            return "Trialing";
        }

        if (string.Equals(providerStatus, "past_due", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "unpaid", StringComparison.OrdinalIgnoreCase))
        {
            return "PastDue";
        }

        if (string.Equals(providerStatus, "canceled", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "cancelled", StringComparison.OrdinalIgnoreCase))
        {
            return "Canceled";
        }

        return "Active";
    }

    public static string MapAppStoreNotificationStatus(string? notificationType, string? subtype, DateTime? expiresAtUtc)
    {
        if (string.Equals(notificationType, "EXPIRED", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "REFUND", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "REVOKE", StringComparison.OrdinalIgnoreCase)
            || string.Equals(notificationType, "GRACE_PERIOD_EXPIRED", StringComparison.OrdinalIgnoreCase))
        {
            return "Expired";
        }

        if (string.Equals(notificationType, "DID_FAIL_TO_RENEW", StringComparison.OrdinalIgnoreCase))
        {
            return expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow ? "GracePeriod" : "Expired";
        }

        if (string.Equals(notificationType, "DID_CHANGE_RENEWAL_STATUS", StringComparison.OrdinalIgnoreCase)
            && string.Equals(subtype, "AUTO_RENEW_DISABLED", StringComparison.OrdinalIgnoreCase))
        {
            return expiresAtUtc.HasValue && expiresAtUtc.Value > DateTime.UtcNow ? "Canceled" : "Expired";
        }

        return expiresAtUtc.HasValue && expiresAtUtc.Value <= DateTime.UtcNow ? "Expired" : "Active";
    }

    public static string MapGooglePlayNotificationStatus(int notificationType, string providerStatus, bool isActive)
    {
        return notificationType switch
        {
            3 => isActive ? "Canceled" : "Expired",
            5 or 6 => "GracePeriod",
            12 or 13 => "Expired",
            _ => MapStoreSubscriptionStatus(providerStatus, isActive)
        };
    }

    public static (bool Success, string? EventId, string? NotificationType, string? Subtype, string? ProductId, string? ExternalSubscriptionId, string? ExternalPurchaseId, DateTime? ExpiresAtUtc, bool CancelAtPeriodEnd) ParseAppStoreServerNotification(string signedPayload)
    {
        try
        {
            using var rootDocument = JsonDocument.Parse(DecodeJwsPayloadJson(signedPayload));
            var root = rootDocument.RootElement;
            var eventId = root.TryGetProperty("notificationUUID", out var eventIdElement) && eventIdElement.ValueKind == JsonValueKind.String
                ? eventIdElement.GetString()
                : null;
            var notificationType = root.TryGetProperty("notificationType", out var typeElement) && typeElement.ValueKind == JsonValueKind.String
                ? typeElement.GetString()
                : null;
            var subtype = root.TryGetProperty("subtype", out var subtypeElement) && subtypeElement.ValueKind == JsonValueKind.String
                ? subtypeElement.GetString()
                : null;

            string? productId = null;
            string? externalSubscriptionId = null;
            string? externalPurchaseId = null;
            DateTime? expiresAtUtc = null;
            var cancelAtPeriodEnd = string.Equals(subtype, "AUTO_RENEW_DISABLED", StringComparison.OrdinalIgnoreCase);

            if (root.TryGetProperty("data", out var dataElement) && dataElement.ValueKind == JsonValueKind.Object)
            {
                if (dataElement.TryGetProperty("signedTransactionInfo", out var transactionInfoElement)
                    && transactionInfoElement.ValueKind == JsonValueKind.String)
                {
                    using var transactionDocument = JsonDocument.Parse(DecodeJwsPayloadJson(transactionInfoElement.GetString()!));
                    var transaction = transactionDocument.RootElement;
                    productId = transaction.TryGetProperty("productId", out var productElement) && productElement.ValueKind == JsonValueKind.String
                        ? productElement.GetString()
                        : null;
                    externalSubscriptionId = transaction.TryGetProperty("originalTransactionId", out var originalElement) && originalElement.ValueKind == JsonValueKind.String
                        ? originalElement.GetString()
                        : null;
                    externalPurchaseId = transaction.TryGetProperty("transactionId", out var transactionIdElement) && transactionIdElement.ValueKind == JsonValueKind.String
                        ? transactionIdElement.GetString()
                        : null;
                    expiresAtUtc = transaction.TryGetProperty("expiresDate", out var expiresElement)
                        ? ParseUnixMilliseconds(expiresElement)
                        : null;
                }

                if (dataElement.TryGetProperty("signedRenewalInfo", out var renewalInfoElement)
                    && renewalInfoElement.ValueKind == JsonValueKind.String)
                {
                    using var renewalDocument = JsonDocument.Parse(DecodeJwsPayloadJson(renewalInfoElement.GetString()!));
                    var renewal = renewalDocument.RootElement;
                    if (renewal.TryGetProperty("autoRenewStatus", out var autoRenewElement))
                    {
                        var autoRenewDisabled = autoRenewElement.ValueKind switch
                        {
                            JsonValueKind.Number => autoRenewElement.GetInt32() == 0,
                            JsonValueKind.String => autoRenewElement.GetString() == "0",
                            _ => false
                        };

                        cancelAtPeriodEnd = cancelAtPeriodEnd || autoRenewDisabled;
                    }
                }
            }

            return (!string.IsNullOrWhiteSpace(eventId), eventId, notificationType, subtype, productId, externalSubscriptionId, externalPurchaseId, expiresAtUtc, cancelAtPeriodEnd);
        }
        catch
        {
            return (false, null, null, null, null, null, null, null, false);
        }
    }

    public static string? TryReadAppStoreProductId(string signedTransactionInfo)
    {
        return TryReadAppStoreTransactionInfo(signedTransactionInfo)?.ProductId;
    }

    public static AppStoreTransactionInfo? TryReadAppStoreTransactionInfo(string signedTransactionInfo)
    {
        try
        {
            using var document = JsonDocument.Parse(DecodeJwsPayloadJson(signedTransactionInfo));
            var root = document.RootElement;

            var bundleId = root.TryGetProperty("bundleId", out var bundleElement)
                && bundleElement.ValueKind == JsonValueKind.String
                    ? bundleElement.GetString()
                    : null;
            var productId = root.TryGetProperty("productId", out var productElement)
                && productElement.ValueKind == JsonValueKind.String
                    ? productElement.GetString()
                    : null;
            var transactionId = root.TryGetProperty("transactionId", out var transactionElement)
                && transactionElement.ValueKind == JsonValueKind.String
                    ? transactionElement.GetString()
                    : null;
            var originalTransactionId = root.TryGetProperty("originalTransactionId", out var originalElement)
                && originalElement.ValueKind == JsonValueKind.String
                    ? originalElement.GetString()
                    : null;
            var expiresAtUtc = root.TryGetProperty("expiresDate", out var expiresElement)
                ? ParseUnixMilliseconds(expiresElement)
                : null;
            var revokedAtUtc = root.TryGetProperty("revocationDate", out var revocationElement)
                ? ParseUnixMilliseconds(revocationElement)
                : null;
            var environment = root.TryGetProperty("environment", out var environmentElement)
                && environmentElement.ValueKind == JsonValueKind.String
                    ? environmentElement.GetString()
                    : null;

            return new AppStoreTransactionInfo(
                bundleId,
                productId,
                transactionId,
                originalTransactionId,
                expiresAtUtc,
                revokedAtUtc,
                environment);
        }
        catch
        {
            return null;
        }
    }

    public static (bool Success, string? EventId, int NotificationType, string? ProductId, string? PurchaseToken, bool IsSubscriptionNotification, bool IsOneTimeProductNotification) ParseGooglePlayDeveloperNotification(string messageData, string? messageId)
    {
        try
        {
            var payloadBytes = Convert.FromBase64String(PadBase64(messageData));
            using var document = JsonDocument.Parse(payloadBytes);
            var root = document.RootElement;

            if (root.TryGetProperty("subscriptionNotification", out var subscriptionElement)
                && subscriptionElement.ValueKind == JsonValueKind.Object)
            {
                var productId = subscriptionElement.TryGetProperty("subscriptionId", out var productElement) && productElement.ValueKind == JsonValueKind.String
                    ? productElement.GetString()
                    : null;
                var purchaseToken = subscriptionElement.TryGetProperty("purchaseToken", out var tokenElement) && tokenElement.ValueKind == JsonValueKind.String
                    ? tokenElement.GetString()
                    : null;
                var notificationType = subscriptionElement.TryGetProperty("notificationType", out var typeElement) && typeElement.ValueKind == JsonValueKind.Number
                    ? typeElement.GetInt32()
                    : 0;

                var eventId = !string.IsNullOrWhiteSpace(messageId)
                    ? messageId
                    : $"{purchaseToken}:{notificationType}:sub";

                return (!string.IsNullOrWhiteSpace(productId) && !string.IsNullOrWhiteSpace(purchaseToken), eventId, notificationType, productId, purchaseToken, true, false);
            }

            if (root.TryGetProperty("oneTimeProductNotification", out var oneTimeElement)
                && oneTimeElement.ValueKind == JsonValueKind.Object)
            {
                var productId = oneTimeElement.TryGetProperty("sku", out var skuElement) && skuElement.ValueKind == JsonValueKind.String
                    ? skuElement.GetString()
                    : oneTimeElement.TryGetProperty("productId", out var productIdElement) && productIdElement.ValueKind == JsonValueKind.String
                        ? productIdElement.GetString()
                        : null;
                var purchaseToken = oneTimeElement.TryGetProperty("purchaseToken", out var tokenElement) && tokenElement.ValueKind == JsonValueKind.String
                    ? tokenElement.GetString()
                    : null;
                var notificationType = oneTimeElement.TryGetProperty("notificationType", out var typeElement) && typeElement.ValueKind == JsonValueKind.Number
                    ? typeElement.GetInt32()
                    : 0;

                var eventId = !string.IsNullOrWhiteSpace(messageId)
                    ? messageId
                    : $"{purchaseToken}:{notificationType}:one_time";

                return (!string.IsNullOrWhiteSpace(productId) && !string.IsNullOrWhiteSpace(purchaseToken), eventId, notificationType, productId, purchaseToken, false, true);
            }

            return (false, null, 0, null, null, false, false);
        }
        catch
        {
            return (false, null, 0, null, null, false, false);
        }
    }

    public static (bool Success, Guid? OrderId, Guid? UserId, string? ObjectId, string? Purpose, string? SetupIntentId, string? Status, string? PlanCode, string? SubscriptionId, string? CustomerId, DateTime? CurrentPeriodStartUtc, DateTime? CurrentPeriodEndUtc, bool CancelAtPeriodEnd) ParseStripeEvent(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("data", out var dataElement)
                || dataElement.ValueKind != JsonValueKind.Object
                || !dataElement.TryGetProperty("object", out var objectElement)
                || objectElement.ValueKind != JsonValueKind.Object)
            {
                return (false, null, null, null, null, null, null, null, null, null, null, null, false);
            }

            string? objectId = null;
            if (objectElement.TryGetProperty("id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
            {
                objectId = idElement.GetString();
            }

            string? setupIntentId = null;
            if (objectElement.TryGetProperty("setup_intent", out var setupIntentElement) && setupIntentElement.ValueKind == JsonValueKind.String)
            {
                setupIntentId = setupIntentElement.GetString();
            }

            string? status = null;
            if (objectElement.TryGetProperty("status", out var statusElement) && statusElement.ValueKind == JsonValueKind.String)
            {
                status = statusElement.GetString();
            }

            string? customerId = null;
            if (objectElement.TryGetProperty("customer", out var customerElement) && customerElement.ValueKind == JsonValueKind.String)
            {
                customerId = customerElement.GetString();
            }

            string? subscriptionId = null;
            if (objectElement.TryGetProperty("subscription", out var subscriptionElement) && subscriptionElement.ValueKind == JsonValueKind.String)
            {
                subscriptionId = subscriptionElement.GetString();
            }
            else if (subscriptionElement.ValueKind == JsonValueKind.Object
                && subscriptionElement.TryGetProperty("id", out var nestedSubscriptionIdElement)
                && nestedSubscriptionIdElement.ValueKind == JsonValueKind.String)
            {
                subscriptionId = nestedSubscriptionIdElement.GetString();
            }
            else if (objectElement.TryGetProperty("object", out var objectTypeElement)
                && string.Equals(objectTypeElement.GetString(), "subscription", StringComparison.OrdinalIgnoreCase)
                && !string.IsNullOrWhiteSpace(objectId))
            {
                subscriptionId = objectId;
            }

            DateTime? currentPeriodStartUtc = null;
            if (objectElement.TryGetProperty("current_period_start", out var currentPeriodStartElement)
                && currentPeriodStartElement.TryGetInt64(out var currentPeriodStartUnix))
            {
                currentPeriodStartUtc = DateTimeOffset.FromUnixTimeSeconds(currentPeriodStartUnix).UtcDateTime;
            }

            DateTime? currentPeriodEndUtc = null;
            if (objectElement.TryGetProperty("current_period_end", out var currentPeriodEndElement)
                && currentPeriodEndElement.TryGetInt64(out var currentPeriodEndUnix))
            {
                currentPeriodEndUtc = DateTimeOffset.FromUnixTimeSeconds(currentPeriodEndUnix).UtcDateTime;
            }

            var cancelAtPeriodEnd = false;
            if (objectElement.TryGetProperty("cancel_at_period_end", out var cancelAtPeriodEndElement)
                && (cancelAtPeriodEndElement.ValueKind == JsonValueKind.True || cancelAtPeriodEndElement.ValueKind == JsonValueKind.False))
            {
                cancelAtPeriodEnd = cancelAtPeriodEndElement.GetBoolean();
            }

            Guid? orderId = null;
            Guid? userId = null;
            string? purpose = null;
            string? planCode = null;
            if (objectElement.TryGetProperty("metadata", out var metadataElement)
                && metadataElement.ValueKind == JsonValueKind.Object)
            {
                ApplyStripeMetadata(metadataElement, ref orderId, ref userId, ref purpose, ref planCode);
            }

            if (objectElement.TryGetProperty("subscription_details", out var subscriptionDetailsElement)
                && subscriptionDetailsElement.ValueKind == JsonValueKind.Object
                && subscriptionDetailsElement.TryGetProperty("metadata", out var subscriptionMetadataElement)
                && subscriptionMetadataElement.ValueKind == JsonValueKind.Object)
            {
                ApplyStripeMetadata(subscriptionMetadataElement, ref orderId, ref userId, ref purpose, ref planCode);
            }

            return (true, orderId, userId, objectId, purpose, setupIntentId, status, planCode, subscriptionId, customerId, currentPeriodStartUtc, currentPeriodEndUtc, cancelAtPeriodEnd);
        }
        catch
        {
            var orderIdMatch = OrderIdRegex().Match(rawBody);
            Guid? orderId = null;
            if (orderIdMatch.Success)
            {
                var rawOrderId = orderIdMatch.Groups["value"].Value;
                if (Guid.TryParse(rawOrderId, out var parsedOrderId))
                {
                    orderId = parsedOrderId;
                }
            }

            string? objectId = null;
            var objectIdMatch = ObjectIdRegex().Match(rawBody);

            if (objectIdMatch.Success)
            {
                objectId = objectIdMatch.Groups["value"].Value;
            }

            if (!orderId.HasValue && string.IsNullOrWhiteSpace(objectId))
            {
                return (false, null, null, null, null, null, null, null, null, null, null, null, false);
            }

            return (true, orderId, null, objectId, null, null, null, null, null, null, null, null, false);
        }
    }

    private static void ApplyStripeMetadata(
        JsonElement metadataElement,
        ref Guid? orderId,
        ref Guid? userId,
        ref string? purpose,
        ref string? planCode)
    {
        if (!orderId.HasValue
            && metadataElement.TryGetProperty("order_id", out var orderIdElement)
            && orderIdElement.ValueKind == JsonValueKind.String)
        {
            var rawOrderId = orderIdElement.GetString();
            if (Guid.TryParse(rawOrderId, out var parsedOrderId))
            {
                orderId = parsedOrderId;
            }
        }

        if (!userId.HasValue
            && metadataElement.TryGetProperty("user_id", out var userIdElement)
            && userIdElement.ValueKind == JsonValueKind.String)
        {
            var rawUserId = userIdElement.GetString();
            if (Guid.TryParse(rawUserId, out var parsedUserId))
            {
                userId = parsedUserId;
            }
        }

        if (string.IsNullOrWhiteSpace(purpose)
            && metadataElement.TryGetProperty("purpose", out var purposeElement)
            && purposeElement.ValueKind == JsonValueKind.String)
        {
            purpose = purposeElement.GetString();
        }

        if (string.IsNullOrWhiteSpace(planCode)
            && metadataElement.TryGetProperty("plan_code", out var planCodeElement)
            && planCodeElement.ValueKind == JsonValueKind.String)
        {
            planCode = planCodeElement.GetString();
        }
    }

    public static (bool Success, string? EventId, string? EventType) ParseStripeEnvelope(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("id", out var idElement)
                || idElement.ValueKind != JsonValueKind.String
                || !root.TryGetProperty("type", out var typeElement)
                || typeElement.ValueKind != JsonValueKind.String)
            {
                return (false, null, null);
            }

            var eventId = idElement.GetString();
            var eventType = typeElement.GetString();
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
        catch
        {
            var idMatch = StripeEventIdRegex().Match(rawBody);
            var typeMatch = StripeEventTypeRegex().Match(rawBody);

            if (!idMatch.Success || !typeMatch.Success)
            {
                return (false, null, null);
            }

            var eventId = idMatch.Groups["value"].Value;
            var eventType = typeMatch.Groups["value"].Value;
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
    }

    public static bool VerifyStripeSignatureFallback(string rawBody, string signatureHeader, string secret)
    {
        if (string.IsNullOrWhiteSpace(signatureHeader) || string.IsNullOrWhiteSpace(secret))
        {
            return false;
        }

        string? timestamp = null;
        string? expectedSignature = null;

        var parts = signatureHeader.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var part in parts)
        {
            if (part.StartsWith("t=", StringComparison.Ordinal))
            {
                timestamp = part[2..];
            }
            else if (part.StartsWith("v1=", StringComparison.Ordinal))
            {
                expectedSignature = part[3..];
            }
        }

        if (string.IsNullOrWhiteSpace(timestamp) || string.IsNullOrWhiteSpace(expectedSignature))
        {
            return false;
        }

        var signedPayload = $"{timestamp}.{rawBody}";
        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var payloadBytes = Encoding.UTF8.GetBytes(signedPayload);

        using var hmac = new HMACSHA256(keyBytes);
        var computed = Convert.ToHexString(hmac.ComputeHash(payloadBytes)).ToLowerInvariant();
        return string.Equals(computed, expectedSignature, StringComparison.OrdinalIgnoreCase);
    }

    private static string DecodeJwsPayloadJson(string signedPayload)
    {
        var parts = signedPayload.Split('.');
        if (parts.Length < 2)
        {
            throw new InvalidOperationException("Invalid JWS payload.");
        }

        return Encoding.UTF8.GetString(DecodeBase64Url(parts[1]));
    }

    private static byte[] DecodeBase64Url(string value)
    {
        return Convert.FromBase64String(PadBase64(value.Replace('-', '+').Replace('_', '/')));
    }

    private static string PadBase64(string value)
    {
        var remainder = value.Length % 4;
        return remainder == 0 ? value : value.PadRight(value.Length + (4 - remainder), '=');
    }

    private static DateTime? ParseUnixMilliseconds(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.String && long.TryParse(element.GetString(), out var stringValue))
        {
            return DateTimeOffset.FromUnixTimeMilliseconds(stringValue).UtcDateTime;
        }

        if (element.ValueKind == JsonValueKind.Number && element.TryGetInt64(out var numericValue))
        {
            return DateTimeOffset.FromUnixTimeMilliseconds(numericValue).UtcDateTime;
        }

        return null;
    }

    [GeneratedRegex("\"order_id\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant)]
    private static partial Regex OrderIdRegex();

    [GeneratedRegex("\"data\"\\s*:\\s*\\{\\s*\"object\"\\s*:\\s*\\{.*?\"id\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant | RegexOptions.Singleline)]
    private static partial Regex ObjectIdRegex();

    [GeneratedRegex("\"id\"\\s*:\\s*\"(?<value>evt_[^\"]+)\"", RegexOptions.CultureInvariant)]
    private static partial Regex StripeEventIdRegex();

    [GeneratedRegex("\"type\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant)]
    private static partial Regex StripeEventTypeRegex();
}
