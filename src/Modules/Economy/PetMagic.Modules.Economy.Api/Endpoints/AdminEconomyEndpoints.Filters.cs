using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static ProblemHttpResult? ValidatePurchaseFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, PurchaseStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.purchase_status_invalid",
                "Query parameter status must be pending, succeeded, failed, or refunded.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.subscription_status_invalid",
                "Query parameter status is not supported for admin subscription filtering.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionEventFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionEventStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.subscription_event_status_invalid",
                "Query parameter status is not supported for admin subscription event filtering.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidatePaymentProviderFilter(string? provider)
    {
        if (IsAllowedOptionalFilter(provider, PaymentProviderFilters))
        {
            return null;
        }

        return ToAdminEconomyFilterProblem(
            "economy.payment_provider_invalid",
            "Query parameter provider must be stripe, app_store, or google_play.");
    }

    private static ProblemHttpResult ToAdminEconomyFilterProblem(string errorCode, string detail)
    {
        return ToAdminEconomyProblem(new Error(errorCode, detail), StatusCodes.Status400BadRequest);
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
