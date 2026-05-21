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
    private const string InvalidStoreWebhookSignatureCode = "economy.invalid_store_webhook_signature";
    private const string InvalidWebhookPayloadCode = "economy.invalid_webhook_payload";

    public static IEndpointRouteBuilder MapEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/economy")
            .WithTags("Economy")
            .RequireRateLimiting("economy");

        group.MapGet("/wallet", GetWalletAsync)
            .RequireAuthorization();

        group.MapGet("/wallet/ledger", GetWalletLedgerAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-weekly", ClaimWeeklyAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-ad", ClaimAdRewardAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/spend", SpendAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/redeem", RedeemCodeAsync)
            .RequireAuthorization();

        group.MapGet("/rewards", GetRewardsSummaryAsync)
            .RequireAuthorization();

        group.MapPost("/referrals/activate", ActivateReferralCodeAsync)
            .RequireAuthorization();

        group.MapGet("/packs", ListPacksAsync)
            .AllowAnonymous();

        group.MapGet("/wallet/checkout-config", GetWalletCheckoutConfigAsync)
            .AllowAnonymous();

        group.MapGet("/premium/plans", ListPremiumPlansAsync)
            .AllowAnonymous();

        group.MapGet("/subscriptions/paywall-config", GetPaywallConfigAsync)
            .AllowAnonymous();

        group.MapGet("/premium/status", GetPremiumStatusAsync)
            .RequireAuthorization();

        group.MapGet("/me/subscription", GetSubscriptionSummaryAsync)
            .RequireAuthorization();

        group.MapPost("/premium/checkout", CreatePremiumCheckoutAsync)
            .RequireAuthorization();

        group.MapPost("/premium/manage", CreatePremiumBillingPortalAsync)
            .RequireAuthorization();

        group.MapPost("/premium/store/verify", VerifyPremiumStorePurchaseAsync)
            .RequireAuthorization();

        group.MapGet("/payment-methods", ListPaymentMethodsAsync)
            .RequireAuthorization();

        group.MapPost("/payment-methods/setup", CreatePaymentMethodSetupAsync)
            .RequireAuthorization();

        group.MapDelete("/payment-methods/{paymentMethodId:guid}", RemovePaymentMethodAsync)
            .RequireAuthorization();

        group.MapGet("/purchases", ListPurchasesAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/create", CreatePurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/{orderId:guid}/confirm", ConfirmPurchaseAsync)
            .RequireAuthorization();

        group.MapGet("/purchases/{orderId:guid}", GetPurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/webhooks/stripe", StripeWebhookAsync)
            .AllowAnonymous();

        group.MapPost("/webhooks/app-store", AppStoreServerNotificationAsync)
            .AllowAnonymous();

        group.MapPost("/webhooks/google-play", GooglePlayDeveloperNotificationAsync)
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

    private static async Task<Results<Ok<OffsetPagedResponse<WalletLedgerItemResponse>>, ProblemHttpResult>> GetWalletLedgerAsync(
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

        var result = await service.GetWalletLedgerAsync(userId!.Value, skip, take, cancellationToken);
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

    private static async Task<Results<Ok<RedeemCodeAppliedResponse>, ValidationProblem, ProblemHttpResult>> RedeemCodeAsync(
        HttpContext context,
        RedeemCodeRequest request,
        IValidator<ApplyRedeemCodeCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new ApplyRedeemCodeCommand(userId!.Value, request.Code);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ApplyRedeemCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.redeem_code_not_found" => StatusCodes.Status404NotFound,
                "economy.redeem_code_already_used" => StatusCodes.Status409Conflict,
                "economy.redeem_code_user_limit_reached" => StatusCodes.Status409Conflict,
                "economy.redeem_code_exhausted" => StatusCodes.Status409Conflict,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<RewardsSummaryResponse>, ProblemHttpResult>> GetRewardsSummaryAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetRewardsSummaryAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<ReferralCodeAppliedResponse>, ValidationProblem, ProblemHttpResult>> ActivateReferralCodeAsync(
        HttpContext context,
        ReferralCodeRequest request,
        IValidator<ApplyReferralCodeCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new ApplyReferralCodeCommand(userId!.Value, request.Code);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ApplyReferralCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.referral_code_not_found" => StatusCodes.Status404NotFound,
                "economy.referral_self_referral" => StatusCodes.Status409Conflict,
                "economy.referral_already_linked" => StatusCodes.Status409Conflict,
                "economy.referral_paid_user_ineligible" => StatusCodes.Status409Conflict,
                _ => StatusCodes.Status400BadRequest,
            };

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

    private static async Task<Ok<WalletCheckoutConfigResponse>> GetWalletCheckoutConfigAsync(
        IEconomyService service,
        string platform,
        string appVersion,
        string country,
        string locale,
        CancellationToken cancellationToken)
    {
        var result = await service.GetWalletCheckoutConfigAsync(
            new GetWalletCheckoutConfigQuery(platform, appVersion, country, locale),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<PremiumPlanResponse>>> ListPremiumPlansAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPremiumPlansAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<PaywallConfigResponse>> GetPaywallConfigAsync(
        IEconomyService service,
        string platform,
        string appVersion,
        string country,
        string locale,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPaywallConfigAsync(
            new GetPaywallConfigQuery(platform, appVersion, country, locale),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PremiumStatusResponse>, ProblemHttpResult>> GetPremiumStatusAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetPremiumStatusAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ProblemHttpResult>> GetSubscriptionSummaryAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.GetSubscriptionSummaryAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<PaymentMethodResponse>>, ProblemHttpResult>> ListPaymentMethodsAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.ListPaymentMethodsAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PaymentMethodSetupResponse>, ValidationProblem, ProblemHttpResult>> CreatePaymentMethodSetupAsync(
        HttpContext context,
        PaymentMethodSetupRequest request,
        IValidator<CreatePaymentMethodSetupCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new CreatePaymentMethodSetupCommand(
            userId!.Value,
            string.IsNullOrWhiteSpace(request.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePaymentMethodSetupAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> RemovePaymentMethodAsync(
        HttpContext context,
        Guid paymentMethodId,
        IValidator<RemovePaymentMethodCommand> validator,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new RemovePaymentMethodCommand(userId!.Value, paymentMethodId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RemovePaymentMethodAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.payment_method_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

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
            request.Platform,
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
            request.Platform,
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
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var securityValidation = securityValidator.ValidateAppStoreSignedPayload(command.SignedPayload);
        if (securityValidation.IsFailure)
        {
            var statusCode = securityValidation.Error.Code switch
            {
                InvalidStoreWebhookSignatureCode => StatusCodes.Status401Unauthorized,
                _ => StatusCodes.Status400BadRequest
            };

            return TypedResults.Problem(title: securityValidation.Error.Code, detail: securityValidation.Error.Message, statusCode: statusCode);
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
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
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
        var command = new GooglePlayDeveloperNotificationCommand(request.Message.Data, request.Message.MessageId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
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

            return TypedResults.Problem(title: securityValidation.Error.Code, detail: securityValidation.Error.Message, statusCode: statusCode);
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

    public sealed record RedeemCodeRequest(string Code);

    public sealed record ReferralCodeRequest(string Code);

    public sealed record PaymentMethodSetupRequest(string PaymentProvider = "stripe");

    public sealed record CreatePurchaseRequest(
        Guid PackId,
        string CurrencyCode,
        string PaymentProvider = "stripe",
        string Platform = "web",
        string AppVersion = "1.0.0",
        string Country = "*",
        string Locale = "en",
        Guid? PaymentMethodId = null);

    public sealed record CreatePremiumCheckoutRequest(
        string PlanCode,
        string PaymentProvider = "stripe",
        string Platform = "web",
        string AppVersion = "1.0.0",
        string Country = "*",
        string Locale = "en");

    public sealed record CreatePremiumBillingPortalRequest(string PaymentProvider = "stripe");

    public sealed record VerifyPremiumStorePurchaseRequest(
        string PlanCode,
        string PaymentProvider,
        string ProductId,
        string ServerVerificationData,
        string? LocalVerificationData,
        string? PurchaseId,
        string? TransactionDate);

    public sealed record AppStoreServerNotificationRequest(string SignedPayload);

    public sealed record GooglePlayDeveloperNotificationRequest(GooglePlayPubSubMessage Message);

    public sealed record GooglePlayPubSubMessage(string Data, string? MessageId);
}
