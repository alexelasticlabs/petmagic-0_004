using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static ProblemHttpResult? ValidatePurchaseFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, PurchaseStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.purchase_status_invalid",
                detail: "Query parameter status must be pending, succeeded, failed, or refunded.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.subscription_status_invalid",
                detail: "Query parameter status is not supported for admin subscription filtering.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionEventFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionEventStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.subscription_event_status_invalid",
                detail: "Query parameter status is not supported for admin subscription event filtering.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidatePaymentProviderFilter(string? provider)
    {
        if (IsAllowedOptionalFilter(provider, PaymentProviderFilters))
        {
            return null;
        }

        return TypedResults.Problem(
            title: "economy.payment_provider_invalid",
            detail: "Query parameter provider must be stripe, app_store, or google_play.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    private static bool IsAllowedOptionalFilter(string? rawValue, string[] allowedValues)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return true;
        }

        var normalized = rawValue.Trim().ToLowerInvariant();
        return allowedValues.Contains(normalized, StringComparer.Ordinal);
    }
}
