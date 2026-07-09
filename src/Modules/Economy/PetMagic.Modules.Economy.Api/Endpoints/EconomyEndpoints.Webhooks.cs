using System.Buffers;
using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{

    private static async Task<Results<Ok<StoreBillingValidationResponse>, ValidationProblem, ProblemHttpResult>> ValidateGooglePlayBillingAsync(
        HttpContext context,
        GooglePlayBillingValidationRequest request,
        [FromServices] IValidator<ValidateGooglePlayBillingCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new ValidateGooglePlayBillingCommand(
            userId!.Value,
            request.PurchaseToken,
            request.ProductId,
            request.PackageName);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.ValidateGooglePlayBillingAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToStoreValidationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<StoreBillingValidationResponse>, ValidationProblem, ProblemHttpResult>> ValidateAppleAppStoreBillingAsync(
        HttpContext context,
        AppleAppStoreBillingValidationRequest request,
        [FromServices] IValidator<ValidateAppleAppStoreBillingCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new ValidateAppleAppStoreBillingCommand(
            userId!.Value,
            request.SignedTransactionInfo);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.ValidateAppleAppStoreBillingAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToStoreValidationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static ProblemHttpResult ToStoreValidationProblem(PetMagic.BuildingBlocks.Results.Error error)
    {
        var statusCode = error.Code switch
        {
            "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
            "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.store_purchase_invalid" => StatusCodes.Status400BadRequest,
            "economy.store_account_binding_missing" => StatusCodes.Status409Conflict,
            "economy.store_account_binding_mismatch" => StatusCodes.Status409Conflict,
            "economy.store_purchase_inactive" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest,
        };

        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildClientEconomyProblemExtensions(error.Code));
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
            return ToClientEconomyProblem(subjectError);
        }

        var result = await service.GetPurchaseAsync(userId!.Value, orderId, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<StripeWebhookResultResponse>, ProblemHttpResult, ValidationProblem>> StripeWebhookAsync(
        HttpRequest request,
        IValidator<StripeWebhookCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (rawBody, isTooLarge) = await ReadWebhookBodyWithinLimitAsync(
            request,
            MaxEconomyWebhookRequestBodyBytes,
            cancellationToken);
        if (isTooLarge)
        {
            return ToWebhookProblem(
                new PetMagic.BuildingBlocks.Results.Error(
                    InvalidWebhookPayloadCode,
                    "Webhook request body is too large."),
                StatusCodes.Status413PayloadTooLarge);
        }

        var signature = request.Headers["Stripe-Signature"].ToString();

        var command = new StripeWebhookCommand(rawBody, signature);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
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

            return ToWebhookProblem(result.Error, statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<(string RawBody, bool IsTooLarge)> ReadWebhookBodyWithinLimitAsync(
        HttpRequest request,
        int maxBytes,
        CancellationToken cancellationToken)
    {
        if (request.ContentLength is > 0 && request.ContentLength > maxBytes)
        {
            return (string.Empty, true);
        }

        await using var buffer = new MemoryStream();
        var rented = ArrayPool<byte>.Shared.Rent(8192);
        try
        {
            var totalBytes = 0;
            while (true)
            {
                var read = await request.Body.ReadAsync(
                    rented.AsMemory(0, rented.Length),
                    cancellationToken);
                if (read == 0)
                {
                    break;
                }

                totalBytes += read;
                if (totalBytes > maxBytes)
                {
                    return (string.Empty, true);
                }

                buffer.Write(rented, 0, read);
            }

            return (Encoding.UTF8.GetString(buffer.ToArray()), false);
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(rented);
        }
    }

    private static async Task<Results<Ok<StoreWebhookResultResponse>, ProblemHttpResult, ValidationProblem>> AppStoreServerNotificationAsync(
        AppStoreServerNotificationRequest request,
        IValidator<AppStoreServerNotificationCommand> validator,
        IStoreWebhookSecurityValidator securityValidator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new AppStoreServerNotificationCommand(request.SignedPayload);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var securityValidation = securityValidator.ValidateAppStoreSignedPayload(command.SignedPayload);
        if (securityValidation.IsFailure)
        {
            var statusCode = securityValidation.Error.Code switch
            {
                InvalidStoreWebhookSignatureCode => StatusCodes.Status401Unauthorized,
                _ => StatusCodes.Status400BadRequest
            };

            return ToWebhookProblem(securityValidation.Error, statusCode);
        }

        var result = await service.HandleAppStoreServerNotificationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                InvalidStoreWebhookSignatureCode => StatusCodes.Status401Unauthorized,
                InvalidWebhookPayloadCode => StatusCodes.Status400BadRequest,
                _ => StatusCodes.Status400BadRequest
            };
            return ToWebhookProblem(result.Error, statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<StoreWebhookResultResponse>, ProblemHttpResult, ValidationProblem>> GooglePlayDeveloperNotificationAsync(
        HttpRequest httpRequest,
        GooglePlayDeveloperNotificationRequest request,
        IValidator<GooglePlayDeveloperNotificationCommand> validator,
        IStoreWebhookSecurityValidator securityValidator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new GooglePlayDeveloperNotificationCommand(
            request.Message?.Data ?? string.Empty,
            request.Message?.MessageId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var securityValidation = await securityValidator.ValidateGooglePlayPushAsync(httpRequest.Headers.Authorization.ToString(), cancellationToken);
        if (securityValidation.IsFailure)
        {
            var statusCode = securityValidation.Error.Code switch
            {
                InvalidStoreWebhookSignatureCode => StatusCodes.Status401Unauthorized,
                "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
                _ => StatusCodes.Status400BadRequest
            };

            return ToWebhookProblem(securityValidation.Error, statusCode);
        }

        var result = await service.HandleGooglePlayDeveloperNotificationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                InvalidStoreWebhookSignatureCode => StatusCodes.Status401Unauthorized,
                "economy.store_verification_unavailable" => StatusCodes.Status503ServiceUnavailable,
                InvalidWebhookPayloadCode => StatusCodes.Status400BadRequest,
                _ => StatusCodes.Status400BadRequest
            };
            return ToWebhookProblem(result.Error, statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    public sealed record GooglePlayBillingValidationRequest(
        string PurchaseToken,
        string ProductId,
        string PackageName);

    public sealed record AppleAppStoreBillingValidationRequest(
        string SignedTransactionInfo);

    public sealed record AppStoreServerNotificationRequest(string SignedPayload);

    public sealed record GooglePlayDeveloperNotificationRequest(GooglePlayPubSubMessage Message);

    public sealed record GooglePlayPubSubMessage(string Data, string? MessageId);

    private static ProblemHttpResult ToWebhookProblem(PetMagic.BuildingBlocks.Results.Error error, int statusCode)
    {
        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildClientEconomyProblemExtensions(error.Code));
    }

}
