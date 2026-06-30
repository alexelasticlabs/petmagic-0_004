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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
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
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePremiumCheckoutAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "economy.premium_plan_not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PremiumCheckoutResponse>, ValidationProblem, ProblemHttpResult>> CreateStripeSubscriptionAsync(
        HttpContext context,
        CreateStripeSubscriptionRequest request,
        IValidator<CreatePremiumCheckoutCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new CreatePremiumCheckoutCommand(
            userId!.Value,
            request.PlanId,
            "stripe",
            ResolveCheckoutPlatform(context, request.Platform),
            request.AppVersion,
            request.Country,
            request.Locale);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePremiumCheckoutAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "economy.premium_plan_not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new CreatePremiumBillingPortalCommand(
            userId!.Value,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePremiumBillingPortalAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "economy.premium_billing_unavailable", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new CancelPremiumSubscriptionCommand(
            userId!.Value,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CancelPremiumSubscriptionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "economy.premium_billing_unavailable", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<BillingPortalSessionResponse>, ValidationProblem, ProblemHttpResult>> CreateStripeCustomerPortalAsync(
        HttpContext context,
        CreateStripeCustomerPortalRequest request,
        IValidator<CreatePremiumBillingPortalCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new CreatePremiumBillingPortalCommand(userId!.Value, "stripe");
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePremiumBillingPortalAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }
}
