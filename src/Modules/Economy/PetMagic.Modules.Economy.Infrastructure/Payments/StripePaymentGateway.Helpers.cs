using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
    private const int StripeProviderJsonResponseMaxChars = 64 * 1024;

    private static bool IsStripe(string provider)
    {
        return string.Equals(provider, Provider, StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeRecurringInterval(string value)
    {
        return value.Trim().ToLowerInvariant() switch
        {
            "monthly" => "month",
            "yearly" => "year",
            "year" => "year",
            _ => "month"
        };
    }

    private static bool EnsureConfigured(string? apiKey)
    {
        return !string.IsNullOrWhiteSpace(apiKey);
    }

    private static bool IsSucceededPaymentIntentStatus(string? status)
    {
        return string.Equals(status, "succeeded", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsSucceededSetupIntentStatus(string? status)
    {
        return string.Equals(status, "succeeded", StringComparison.OrdinalIgnoreCase);
    }

    private StripeClient CreateStripeClient(string apiKey)
    {
        return new StripeClient(
            apiKey,
            httpClient: new SystemNetHttpClient(httpClientFactory.CreateClient(HttpClientName)));
    }

    private async Task<Result<string>> CreateCustomerEphemeralKeySecretAsync(
        string apiKey,
        string customerId,
        Guid userId,
        Guid? orderId,
        string operation,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.stripe.com/v1/ephemeral_keys");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Headers.Add("Stripe-Version", MobileEphemeralKeyStripeVersion);
        request.Content = new FormUrlEncodedContent([
            new KeyValuePair<string, string>("customer", customerId)
        ]);

        try
        {
            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                LogGatewayWarning(
                    "Stripe gateway operation returned non-success status.",
                    operation,
                    userId,
                    orderId,
                    externalCustomerId: customerId,
                    statusCode: (int)response.StatusCode);
                return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
            }

            var responseBody = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                StripeProviderJsonResponseMaxChars);
            using var document = JsonDocument.Parse(responseBody);
            if (document.RootElement.TryGetProperty("secret", out var secretElement)
                && secretElement.ValueKind == JsonValueKind.String)
            {
                var secret = secretElement.GetString();
                if (!string.IsNullOrWhiteSpace(secret))
                {
                    return Result.Success(secret);
                }
            }

            LogGatewayWarning(
                "Stripe gateway operation returned an unexpected response shape.",
                operation,
                userId,
                orderId,
                externalCustomerId: customerId);
            return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                operation,
                userId,
                orderId,
                externalCustomerId: customerId);
            return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
        }
        catch
        {
            LogGatewayFailure(
                null,
                operation,
                userId,
                orderId,
                externalCustomerId: customerId);
            return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    private void LogGatewayFailure(
        Exception? exception,
        string operation,
        Guid? userId = null,
        Guid? orderId = null,
        string? planCode = null,
        string? externalCustomerId = null,
        string? externalPaymentId = null,
        string? externalPaymentMethodId = null,
        string? externalSetupId = null,
        bool? usePaymentSheet = null,
        int? statusCode = null)
    {
        logger?.LogWarning(
            "Stripe gateway operation failed. Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} OrderIdHash={OrderIdHash} PlanCode={PlanCode} ExternalCustomerIdSafe={ExternalCustomerIdSafe} ExternalPaymentIdSafe={ExternalPaymentIdSafe} ExternalPaymentMethodIdSafe={ExternalPaymentMethodIdSafe} ExternalSetupIdSafe={ExternalSetupIdSafe} UsePaymentSheet={UsePaymentSheet} StatusCode={StatusCode} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
            Provider,
            operation,
            EconomyLogSanitizer.SafeUserId(userId),
            orderId.HasValue ? SafeLogValues.StableHash(orderId.Value.ToString("D")) : null,
            planCode,
            EconomyLogSanitizer.SafeExternalId(externalCustomerId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId),
            EconomyLogSanitizer.SafeExternalId(externalSetupId),
            usePaymentSheet,
            statusCode,
            SafeLogValues.ExceptionType(exception),
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));
    }

    private void LogGatewayWarning(
        string summary,
        string operation,
        Guid? userId = null,
        Guid? orderId = null,
        string? planCode = null,
        string? externalCustomerId = null,
        string? externalPaymentId = null,
        string? externalPaymentMethodId = null,
        string? externalSetupId = null,
        bool? usePaymentSheet = null,
        int? statusCode = null)
    {
        logger?.LogWarning(
            "{Summary} Provider={Provider} Operation={Operation} UserIdHash={UserIdHash} OrderIdHash={OrderIdHash} PlanCode={PlanCode} ExternalCustomerIdSafe={ExternalCustomerIdSafe} ExternalPaymentIdSafe={ExternalPaymentIdSafe} ExternalPaymentMethodIdSafe={ExternalPaymentMethodIdSafe} ExternalSetupIdSafe={ExternalSetupIdSafe} UsePaymentSheet={UsePaymentSheet} StatusCode={StatusCode} CorrelationIdHash={CorrelationIdHash}",
            summary,
            Provider,
            operation,
            EconomyLogSanitizer.SafeUserId(userId),
            orderId.HasValue ? SafeLogValues.StableHash(orderId.Value.ToString("D")) : null,
            planCode,
            EconomyLogSanitizer.SafeExternalId(externalCustomerId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId),
            EconomyLogSanitizer.SafeExternalId(externalSetupId),
            usePaymentSheet,
            statusCode,
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));
    }

    private string ResolveApiKey(string? apiKey = null)
    {
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            return apiKey;
        }

        if (!string.IsNullOrWhiteSpace(options.StripeLiveSecretKey))
        {
            return options.StripeLiveSecretKey;
        }

        return options.StripeTestSecretKey;
    }
}
