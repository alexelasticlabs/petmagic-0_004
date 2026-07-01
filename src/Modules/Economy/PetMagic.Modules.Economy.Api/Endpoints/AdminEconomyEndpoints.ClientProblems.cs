using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static ProblemHttpResult ToAdminEconomyProblem(Error error, int fallbackStatusCode)
    {
        var statusCode = ResolveAdminEconomyProblemStatusCode(error.Code, fallbackStatusCode);
        return TypedResults.Problem(
            title: error.Code,
            detail: GetAdminEconomyProblemDetail(error.Code, statusCode),
            statusCode: statusCode);
    }

    private static int ResolveAdminEconomyProblemStatusCode(string errorCode, int fallbackStatusCode)
    {
        return errorCode switch
        {
            "users.not_found" => StatusCodes.Status404NotFound,
            "economy.pack_not_found" => StatusCodes.Status404NotFound,
            "economy.purchase_not_found" => StatusCodes.Status404NotFound,
            "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
            "economy.payment_provider_config_not_found" => StatusCodes.Status404NotFound,
            "economy.redeem_code_not_found" => StatusCodes.Status404NotFound,
            "economy.purchase_not_refundable" => StatusCodes.Status409Conflict,
            "economy.payment_provider_config_exists" => StatusCodes.Status409Conflict,
            "economy.redeem_code_exists" => StatusCodes.Status409Conflict,
            "economy.payment_gateway_failed" => StatusCodes.Status502BadGateway,
            "economy.payment_provider_unavailable"
                or "economy.payment_provider_config_invalid"
                or "economy.payment_provider_config_not_found"
                or "economy.premium_billing_unavailable" => StatusCodes.Status503ServiceUnavailable,
            _ => fallbackStatusCode,
        };
    }

    private static string GetAdminEconomyProblemDetail(string errorCode, int statusCode)
    {
        return errorCode switch
        {
            "users.not_found" => "Account was not found.",
            "economy.pack_not_found" => "Currency pack was not found.",
            "economy.purchase_not_found" => "Purchase was not found.",
            "economy.premium_plan_not_found" => "Premium plan was not found.",
            "economy.payment_provider_config_not_found" => "Payment provider configuration was not found.",
            "economy.redeem_code_not_found" => "Redeem code was not found.",
            "economy.purchase_not_refundable" => "Purchase cannot be refunded.",
            "economy.payment_provider_config_exists" => "Payment provider configuration already exists.",
            "economy.redeem_code_exists" => "Redeem code already exists.",
            "economy.purchase_status_invalid" => "Query parameter status must be pending, succeeded, failed, or refunded.",
            "economy.subscription_status_invalid" => "Query parameter status is not supported for admin subscription filtering.",
            "economy.subscription_event_status_invalid" => "Query parameter status is not supported for admin subscription event filtering.",
            "economy.payment_provider_invalid" => "Query parameter provider must be stripe, app_store, or google_play.",
            "economy.redeem_code_status_invalid" => "Query parameter status must be all, draft, scheduled, active, paused, exhausted, expired, or archived.",
            "economy.redeem_code_reward_kind_invalid" => "Query parameter rewardKind must be all or spark.",
            "economy.redeem_code_sort_invalid" => "Query parameter sort must be updated, usage, reward, code, or expiry.",
            "economy.payment_gateway_failed" => "Billing gateway is temporarily unavailable.",
            "economy.payment_provider_unavailable"
                or "economy.payment_provider_config_invalid"
                or "economy.premium_billing_unavailable" => "Billing administration is temporarily unavailable.",
            _ when statusCode == StatusCodes.Status404NotFound => "Requested billing resource was not found.",
            _ when statusCode == StatusCodes.Status409Conflict => "Billing request conflicts with current resource state.",
            _ when statusCode == StatusCodes.Status502BadGateway
                || statusCode == StatusCodes.Status503ServiceUnavailable => "Billing administration is temporarily unavailable.",
            _ => "Billing administration request is invalid.",
        };
    }
}
