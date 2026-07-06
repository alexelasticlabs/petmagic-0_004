using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    private static ProblemHttpResult ToClientEconomyProblem(string errorCode)
    {
        return TypedResults.Problem(
            title: errorCode,
            statusCode: ResolveClientEconomyProblemStatusCode(errorCode),
            extensions: BuildClientEconomyProblemExtensions(errorCode));
    }

    private static ProblemHttpResult ToClientEconomyProblem(Error error)
    {
        return ToClientEconomyProblem(error.Code);
    }

    private static int ResolveClientEconomyProblemStatusCode(string errorCode)
    {
        return errorCode switch
        {
            "economy.invalid_subject" => StatusCodes.Status401Unauthorized,
            "economy.invalid_amount" => StatusCodes.Status400BadRequest,
            "economy.invalid_wallet_reason" => StatusCodes.Status400BadRequest,
            "economy.weekly_cooldown" => StatusCodes.Status409Conflict,
            "economy.ad_reward_limit_reached" => StatusCodes.Status409Conflict,
            "economy.pack_not_found" => StatusCodes.Status404NotFound,
            "economy.purchase_not_found" => StatusCodes.Status404NotFound,
            "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
            "economy.payment_method_not_found" => StatusCodes.Status404NotFound,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            "economy.purchase_already_processed" => StatusCodes.Status409Conflict,
            "economy.store_purchase_inactive" => StatusCodes.Status409Conflict,
            "economy.redeem_code_inactive" => StatusCodes.Status409Conflict,
            "economy.redeem_code_expired" => StatusCodes.Status409Conflict,
            "economy.redeem_code_already_used" => StatusCodes.Status409Conflict,
            "economy.redeem_code_user_limit_reached" => StatusCodes.Status409Conflict,
            "economy.redeem_code_purchase_requirement_not_met" => StatusCodes.Status409Conflict,
            "economy.redeem_code_exhausted" => StatusCodes.Status409Conflict,
            "economy.redeem_code_reward_unsupported" => StatusCodes.Status409Conflict,
            "economy.referral_self_referral" => StatusCodes.Status409Conflict,
            "economy.referral_already_linked" => StatusCodes.Status409Conflict,
            "economy.referral_paid_user_ineligible" => StatusCodes.Status409Conflict,
            "economy.redeem_code_not_found" => StatusCodes.Status404NotFound,
            "economy.referral_code_not_found" => StatusCodes.Status404NotFound,
            "economy.payment_method_ownership_conflict" => StatusCodes.Status409Conflict,
            "economy.subscription_ownership_conflict" => StatusCodes.Status409Conflict,
            "economy.payment_provider_unsupported" => StatusCodes.Status400BadRequest,
            "economy.payment_method_provider_invalid" => StatusCodes.Status400BadRequest,
            "economy.store_purchase_invalid" => StatusCodes.Status400BadRequest,
            "economy.push_token_invalid" => StatusCodes.Status400BadRequest,
            "economy.invalid_stripe_signature" => StatusCodes.Status400BadRequest,
            "economy.invalid_store_webhook_signature" => StatusCodes.Status400BadRequest,
            "economy.invalid_webhook_payload" => StatusCodes.Status400BadRequest,
            "economy.payment_provider_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.payment_provider_config_not_found" => StatusCodes.Status503ServiceUnavailable,
            "economy.payment_gateway_failed" => StatusCodes.Status503ServiceUnavailable,
            "economy.premium_billing_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status400BadRequest,
        };
    }

    private static Dictionary<string, object?> BuildClientEconomyProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
