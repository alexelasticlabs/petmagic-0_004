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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }
}
