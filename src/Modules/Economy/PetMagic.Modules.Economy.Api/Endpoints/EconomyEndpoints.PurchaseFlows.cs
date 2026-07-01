using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    private static async Task<Results<Ok<OffsetPagedResponse<PurchaseHistoryItemResponse>>, ProblemHttpResult>> ListPurchasesAsync(
        HttpContext context,
        IEconomyService service,
        int skip = 0,
        int take = 20,
        CancellationToken cancellationToken = default)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var result = await service.GetPurchaseHistoryAsync(userId!.Value, skip, take, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseCheckoutResponse>, ValidationProblem, ProblemHttpResult>> CreatePurchaseAsync(
        HttpContext context,
        CreatePurchaseRequest request,
        IValidator<CreatePackPurchaseCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new CreatePackPurchaseCommand(
            userId!.Value,
            request.PackId,
            request.CurrencyCode,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider,
            ResolveCheckoutPlatform(context, request.Platform),
            request.AppVersion,
            request.Country,
            request.Locale,
            request.PaymentMethodId);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePackPurchaseAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseCheckoutResponse>, ValidationProblem, ProblemHttpResult>> CreateStripeTokenPurchaseAsync(
        HttpContext context,
        CreateStripeTokenPurchaseRequest request,
        IValidator<CreatePackPurchaseCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var packsResult = await service.ListPacksAsync(cancellationToken);
        if (packsResult.IsFailure)
        {
            return ToClientEconomyProblem(packsResult.Error);
        }

        var pack = ResolveCurrencyPack(request.TokenPackId, packsResult.Value);
        if (pack is null)
        {
            return ToClientEconomyProblem("economy.pack_not_found");
        }

        var command = new CreatePackPurchaseCommand(
            userId!.Value,
            pack.PackId,
            string.IsNullOrWhiteSpace(request.CurrencyCode) ? pack.CurrencyCode : request.CurrencyCode,
            "stripe",
            ResolveCheckoutPlatform(context, request.Platform),
            request.AppVersion,
            request.Country,
            request.Locale,
            null);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePackPurchaseAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseOrderResponse>, ValidationProblem, ProblemHttpResult>> ConfirmPurchaseAsync(
        HttpContext context,
        Guid orderId,
        IValidator<ConfirmPackPurchaseCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new ConfirmPackPurchaseCommand(userId!.Value, orderId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ConfirmPackPurchaseAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseOrderResponse>, ProblemHttpResult>> VerifyStripeCheckoutAsync(
        HttpContext context,
        Guid orderId,
        VerifyStripeCheckoutRequest request,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new VerifyStripeCheckoutSessionCommand(userId!.Value, orderId, request.StripeReferenceId);
        var result = await service.VerifyStripeCheckoutSessionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseOrderResponse>, ValidationProblem, ProblemHttpResult>> VerifyStoreCheckoutAsync(
        HttpContext context,
        Guid orderId,
        VerifyPackStorePurchaseRequest request,
        IValidator<VerifyPackStorePurchaseCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new VerifyPackStorePurchaseCommand(
            userId!.Value,
            orderId,
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

        var result = await service.VerifyPackStorePurchaseAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }
}
