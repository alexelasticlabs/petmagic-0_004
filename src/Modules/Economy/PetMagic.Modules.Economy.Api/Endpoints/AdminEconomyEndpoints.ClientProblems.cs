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
            statusCode: statusCode,
            extensions: BuildAdminEconomyProblemExtensions(error.Code));
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
            "economy.incident_not_found" => StatusCodes.Status404NotFound,
            "economy.purchase_not_refundable" => StatusCodes.Status409Conflict,
            "economy.incident_action_invalid" => StatusCodes.Status409Conflict,
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

    private static Dictionary<string, object?> BuildAdminEconomyProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
    }
}
