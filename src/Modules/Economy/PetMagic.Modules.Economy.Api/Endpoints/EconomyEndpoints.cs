using System.Security.Claims;
using System.Text;
using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static class EconomyEndpoints
{
    private const string InvalidSubjectCode = "economy.invalid_subject";
    private const string InvalidSubjectMessage = "Invalid access token subject.";
    private const string InsufficientBalanceCode = "economy.insufficient_balance";
    private const string PurchaseNotFoundCode = "economy.purchase_not_found";
    private const string InvalidStripeSignatureCode = "economy.invalid_stripe_signature";
    private const string InvalidWebhookPayloadCode = "economy.invalid_webhook_payload";

    public static IEndpointRouteBuilder MapEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/economy")
            .WithTags("Economy")
            .RequireRateLimiting("economy");

        group.MapGet("/wallet", GetWalletAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-weekly", ClaimWeeklyAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-ad", ClaimAdRewardAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/spend", SpendAsync)
            .RequireAuthorization();

        group.MapGet("/packs", ListPacksAsync)
            .AllowAnonymous();

        group.MapPost("/purchases/create", CreatePurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/{orderId:guid}/confirm", ConfirmPurchaseAsync)
            .RequireAuthorization();

        group.MapGet("/purchases/{orderId:guid}", GetPurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/webhooks/stripe", StripeWebhookAsync)
            .AllowAnonymous();

        return endpoints;
    }

    private static async Task<Results<Ok<WalletStateResponse>, ProblemHttpResult>> GetWalletAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, isPremium, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetWalletAsync(userId!.Value, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<WalletOperationResponse>, ValidationProblem, ProblemHttpResult>> ClaimWeeklyAsync(
        HttpContext context,
        IValidator<ClaimWeeklyGrantCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, isPremium, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new ClaimWeeklyGrantCommand(userId!.Value, isPremium);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ClaimWeeklyGrantAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status409Conflict);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<WalletOperationResponse>, ValidationProblem, ProblemHttpResult>> ClaimAdRewardAsync(
        HttpContext context,
        IValidator<ClaimAdRewardCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new ClaimAdRewardCommand(userId!.Value);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ClaimAdRewardAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status409Conflict);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<WalletOperationResponse>, ValidationProblem, ProblemHttpResult>> SpendAsync(
        HttpContext context,
        SpendRequest request,
        IValidator<SpendBalanceCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new SpendBalanceCommand(userId!.Value, request.Amount, request.Reason);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SpendAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, InsufficientBalanceCode, StringComparison.Ordinal)
                ? StatusCodes.Status409Conflict
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPacksAsync(cancellationToken);
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
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

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

    private static async Task<Results<Ok<PurchaseOrderResponse>, ProblemHttpResult>> GetPurchaseAsync(
        HttpContext context,
        Guid orderId,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetPurchaseAsync(userId!.Value, orderId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<StripeWebhookResultResponse>, ProblemHttpResult, ValidationProblem>> StripeWebhookAsync(
        HttpRequest request,
        IValidator<StripeWebhookCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(request.Body, Encoding.UTF8, detectEncodingFromByteOrderMarks: false, leaveOpen: true);
        var rawBody = await reader.ReadToEndAsync(cancellationToken);
        var signature = request.Headers["Stripe-Signature"].ToString();

        var command = new StripeWebhookCommand(rawBody, signature);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.HandleStripeWebhookAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                InvalidStripeSignatureCode => StatusCodes.Status401Unauthorized,
                InvalidWebhookPayloadCode => StatusCodes.Status400BadRequest,
                _ => StatusCodes.Status400BadRequest
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static (Guid? UserId, bool IsPremium, PetMagic.BuildingBlocks.Results.Error? Error) TryGetSubject(HttpContext context)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return (null, false, new PetMagic.BuildingBlocks.Results.Error(InvalidSubjectCode, InvalidSubjectMessage));
        }

        var premiumRaw = context.User.FindFirstValue("premium");
        var isPremium = string.Equals(premiumRaw, "true", StringComparison.OrdinalIgnoreCase);
        return (userId, isPremium, null);
    }

    public sealed record SpendRequest(int Amount, string Reason);

    public sealed record CreatePurchaseRequest(Guid PackId, string CurrencyCode, string PaymentProvider = "stripe");
}
