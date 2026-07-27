using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static ProblemHttpResult? ValidateDashboardPeriodDays(int? periodDays)
    {
        if (periodDays is null or 7 or 30 or 90)
        {
            return null;
        }

        return ToAdminEconomyFilterProblem(
            "economy.dashboard_period_invalid",
            "Dashboard period filter is invalid.");
    }

    private static ProblemHttpResult? ValidatePurchaseFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, PurchaseStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.purchase_status_invalid",
                "Purchase status filter is invalid.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.subscription_status_invalid",
                "Subscription status filter is invalid.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionEventFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionEventStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.subscription_event_status_invalid",
                "Subscription event status filter is invalid.");
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateIncidentFilters(string? status, string? category)
    {
        if (!IsAllowedOptionalFilter(status, IncidentStatusFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.incident_status_invalid",
                "Incident status filter is invalid.");
        }

        if (!IsAllowedOptionalFilter(category, IncidentCategoryFilters))
        {
            return ToAdminEconomyFilterProblem(
                "economy.incident_category_invalid",
                "Incident category filter is invalid.");
        }

        return null;
    }

    private static ProblemHttpResult? ValidatePaymentProviderFilter(string? provider)
    {
        if (IsAllowedOptionalFilter(provider, PaymentProviderFilters))
        {
            return null;
        }

        return ToAdminEconomyFilterProblem(
            "economy.payment_provider_invalid",
            "Payment provider filter is invalid.");
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
