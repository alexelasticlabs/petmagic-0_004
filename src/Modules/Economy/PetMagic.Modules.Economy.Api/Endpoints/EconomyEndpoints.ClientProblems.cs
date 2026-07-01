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
            detail: GetClientEconomyProblemDetail(errorCode),
            statusCode: ResolveClientEconomyProblemStatusCode(errorCode));
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
            "economy.referral_self_referral" => StatusCodes.Status409Conflict,
            "economy.referral_already_linked" => StatusCodes.Status409Conflict,
            "economy.referral_paid_user_ineligible" => StatusCodes.Status409Conflict,
            "economy.redeem_code_not_found" => StatusCodes.Status404NotFound,
            "economy.referral_code_not_found" => StatusCodes.Status404NotFound,
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

    private static string GetClientEconomyProblemDetail(string errorCode)
    {
        return errorCode switch
        {
            "economy.invalid_subject" => "Authentication failed.",
            "economy.weekly_cooldown" => "Weekly reward is not available yet.",
            "economy.ad_reward_limit_reached" => "Daily ad reward limit has been reached.",
            "economy.pack_not_found" => "Billing product was not found.",
            "economy.purchase_not_found" => "Purchase was not found.",
            "economy.premium_plan_not_found" => "Premium plan was not found.",
            "economy.payment_method_not_found" => "Payment method was not found.",
            "economy.insufficient_balance" => "Not enough balance to complete this action.",
            "economy.purchase_already_processed" => "Purchase is already processed.",
            "economy.store_purchase_inactive" => "Store purchase is not active.",
            "economy.redeem_code_not_found" => "Redeem code was not found.",
            "economy.redeem_code_inactive" => "Redeem code is not active.",
            "economy.redeem_code_expired" => "Redeem code is expired.",
            "economy.redeem_code_already_used" => "Redeem code was already used.",
            "economy.redeem_code_user_limit_reached" => "Redeem code is no longer available for this user.",
            "economy.redeem_code_purchase_requirement_not_met" => "Redeem code requires a paid purchase history.",
            "economy.redeem_code_exhausted" => "Redeem code redemption limit has been reached.",
            "economy.referral_code_not_found" => "Referral code was not found.",
            "economy.referral_self_referral" => "Your own referral code cannot be activated.",
            "economy.referral_already_linked" => "Referral code is already activated for this account.",
            "economy.referral_paid_user_ineligible" => "Referral code must be activated before the first paid purchase.",
            "economy.payment_provider_unsupported" => "Payment provider is not supported for this request.",
            "economy.payment_method_provider_invalid" => "Selected payment method is not supported for this request.",
            "economy.store_purchase_invalid" => "Store purchase data is invalid.",
            "economy.push_token_invalid" => "Push token is invalid.",
            "economy.invalid_stripe_signature"
                or "economy.invalid_store_webhook_signature"
                or "economy.invalid_webhook_payload" => "Payment verification payload is invalid.",
            "economy.payment_provider_unavailable"
                or "economy.payment_provider_config_not_found"
                or "economy.payment_gateway_failed"
                or "economy.premium_billing_unavailable" => "Billing is temporarily unavailable.",
            "economy.store_verification_unavailable" => "Payment verification is temporarily unavailable.",
            _ => "Billing request could not be completed.",
        };
    }
}
