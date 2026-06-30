using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    private static async Task<Results<Ok<PremiumStoreVerificationResponse>, ValidationProblem, ProblemHttpResult>> VerifyPremiumStorePurchaseAsync(
        HttpContext context,
        VerifyPremiumStorePurchaseRequest request,
        IValidator<VerifyPremiumStorePurchaseCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new VerifyPremiumStorePurchaseCommand(
            userId!.Value,
            request.PlanCode,
            request.PaymentProvider,
            request.ProductId,
            request.ServerVerificationData,
            request.LocalVerificationData,
            request.PurchaseId,
            request.TransactionDate);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.VerifyPremiumStorePurchaseAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
                "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
                "economy.store_purchase_invalid" => StatusCodes.Status400BadRequest,
                "economy.store_purchase_inactive" => StatusCodes.Status409Conflict,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ValidationProblem, ProblemHttpResult>> VerifyPremiumStripeSubscriptionAsync(
        HttpContext context,
        VerifyPremiumStripeSubscriptionRequest request,
        IValidator<VerifyPremiumStripeSubscriptionCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new VerifyPremiumStripeSubscriptionCommand(
            userId!.Value,
            request.PlanCode,
            request.ExternalSubscriptionId);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.VerifyPremiumStripeSubscriptionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
                "economy.premium_billing_unavailable" => StatusCodes.Status503ServiceUnavailable,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }
}
