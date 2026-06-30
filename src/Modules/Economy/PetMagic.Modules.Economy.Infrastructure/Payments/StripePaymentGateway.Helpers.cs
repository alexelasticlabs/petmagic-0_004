using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
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
                .SendAsync(request, cancellationToken);
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

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
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
            exception,
            "Stripe gateway operation failed. Provider={Provider} Operation={Operation} UserId={UserId} OrderId={OrderId} PlanCode={PlanCode} ExternalCustomerId={ExternalCustomerId} ExternalPaymentId={ExternalPaymentId} ExternalPaymentMethodId={ExternalPaymentMethodId} ExternalSetupId={ExternalSetupId} UsePaymentSheet={UsePaymentSheet} StatusCode={StatusCode} CorrelationId={CorrelationId}",
            Provider,
            operation,
            userId,
            orderId,
            planCode,
            EconomyLogSanitizer.SafeExternalId(externalCustomerId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId),
            EconomyLogSanitizer.SafeExternalId(externalSetupId),
            usePaymentSheet,
            statusCode,
            CorrelationContext.ResolveOrCreate());
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
            "{Summary} Provider={Provider} Operation={Operation} UserId={UserId} OrderId={OrderId} PlanCode={PlanCode} ExternalCustomerId={ExternalCustomerId} ExternalPaymentId={ExternalPaymentId} ExternalPaymentMethodId={ExternalPaymentMethodId} ExternalSetupId={ExternalSetupId} UsePaymentSheet={UsePaymentSheet} StatusCode={StatusCode} CorrelationId={CorrelationId}",
            summary,
            Provider,
            operation,
            userId,
            orderId,
            planCode,
            EconomyLogSanitizer.SafeExternalId(externalCustomerId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentId),
            EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId),
            EconomyLogSanitizer.SafeExternalId(externalSetupId),
            usePaymentSheet,
            statusCode,
            CorrelationContext.ResolveOrCreate());
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
