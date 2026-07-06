using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    private static async Task<Results<Ok<PremiumCheckoutResponse>, ValidationProblem, ProblemHttpResult>> CreatePremiumCheckoutAsync(
        HttpContext context,
        CreatePremiumCheckoutRequest request,
        IValidator<CreatePremiumCheckoutCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new CreatePremiumCheckoutCommand(
            userId!.Value,
            request.PlanCode,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider,
            ResolveCheckoutPlatform(context, request.Platform),
            request.AppVersion,
            request.Country,
            request.Locale);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.CreatePremiumCheckoutAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<BillingPortalSessionResponse>, ValidationProblem, ProblemHttpResult>> CreatePremiumBillingPortalAsync(
        HttpContext context,
        CreatePremiumBillingPortalRequest request,
        IValidator<CreatePremiumBillingPortalCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new CreatePremiumBillingPortalCommand(
            userId!.Value,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.CreatePremiumBillingPortalAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ValidationProblem, ProblemHttpResult>> CancelPremiumSubscriptionAsync(
        HttpContext context,
        CancelPremiumSubscriptionRequest request,
        IValidator<CancelPremiumSubscriptionCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new CancelPremiumSubscriptionCommand(
            userId!.Value,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.CancelPremiumSubscriptionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

}
