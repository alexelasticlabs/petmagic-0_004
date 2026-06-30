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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetPurchaseHistoryAsync(userId!.Value, skip, take, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
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
            var statusCode = string.Equals(result.Error.Code, "economy.pack_not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var packsResult = await service.ListPacksAsync(cancellationToken);
        if (packsResult.IsFailure)
        {
            return TypedResults.Problem(title: packsResult.Error.Code, detail: packsResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        var pack = ResolveCurrencyPack(request.TokenPackId, packsResult.Value);
        if (pack is null)
        {
            return TypedResults.Problem(title: "economy.pack_not_found", detail: "Currency pack was not found.", statusCode: StatusCodes.Status404NotFound);
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
            var statusCode = string.Equals(result.Error.Code, "economy.pack_not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
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
            var statusCode = string.Equals(result.Error.Code, PurchaseNotFoundCode, StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status409Conflict;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new VerifyStripeCheckoutSessionCommand(userId!.Value, orderId, request.StripeReferenceId);
        var result = await service.VerifyStripeCheckoutSessionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, PurchaseNotFoundCode, StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
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
            var statusCode = result.Error.Code switch
            {
                PurchaseNotFoundCode => StatusCodes.Status404NotFound,
                "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
                "economy.store_purchase_invalid" => StatusCodes.Status400BadRequest,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }
}
