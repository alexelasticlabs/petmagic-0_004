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

    private static async Task<Results<Ok<WalletStateResponse>, ProblemHttpResult>> GetWalletAsync(
        HttpContext context,
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, isPremium, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var result = await service.GetWalletAsync(userId!.Value, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
        }

        var result = await service.GetWalletLedgerAsync(userId!.Value, skip, take, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext context,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] IValidator<RegisterEconomyPushTokenCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new RegisterEconomyPushTokenCommand(
            userId!.Value,
            request.Token,
            request.Platform,
            request.DeviceId,
            request.AppVersion,
            request.Locale);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RegisterPushTokenAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext context,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] IValidator<UnregisterEconomyPushTokenCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientEconomyProblem(subjectError);
        }

        var command = new UnregisterEconomyPushTokenCommand(userId!.Value, request.Token);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UnregisterPushTokenAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.NoContent();
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
        }

        var result = await service.GetRewardsSummaryAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientEconomyProblem(result.Error);
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
            return ToClientEconomyProblem(subjectError);
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
            return ToClientEconomyProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<CurrencyPackResponse>>, ProblemHttpResult>> ListPacksAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPacksAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicEconomyProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<WalletCheckoutConfigResponse>, ProblemHttpResult>> GetWalletCheckoutConfigAsync(
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

        if (result.IsFailure)
        {
            return ToPublicEconomyProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<PremiumPlanResponse>>, ProblemHttpResult>> ListPremiumPlansAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPremiumPlansAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicEconomyProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PaywallConfigResponse>, ProblemHttpResult>> GetPaywallConfigAsync(
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

        if (result.IsFailure)
        {
            return ToPublicEconomyProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<BillingProductsResponse>, ProblemHttpResult>> GetBillingProductsAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListBillingProductsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicEconomyProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static ProblemHttpResult ToPublicEconomyProblem(string errorCode)
    {
        var statusCode = errorCode switch
        {
            "economy.pack_not_found" => StatusCodes.Status404NotFound,
            "economy.premium_plan_not_found" => StatusCodes.Status404NotFound,
            "economy.payment_provider_unsupported" => StatusCodes.Status400BadRequest,
            "economy.payment_provider_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "economy.payment_provider_config_not_found" => StatusCodes.Status503ServiceUnavailable,
            "economy.premium_billing_unavailable" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status503ServiceUnavailable,
        };

        var detail = errorCode switch
        {
            "economy.pack_not_found" => "Billing product was not found.",
            "economy.premium_plan_not_found" => "Premium plan was not found.",
            "economy.payment_provider_unsupported" => "Payment provider is not supported for this request.",
            "economy.payment_provider_unavailable" => "Billing is not available for this request.",
            _ => "Billing configuration is temporarily unavailable.",
        };

        return TypedResults.Problem(title: errorCode, detail: detail, statusCode: statusCode);
    }

    public sealed record SpendRequest(int Amount, string Reason);

    public sealed record RedeemCodeRequest(string Code);

    public sealed record ReferralCodeRequest(string Code);

    public sealed record RegisterPushTokenRequest(string Token, string Platform, string? DeviceId, string? AppVersion, string? Locale);

    public sealed record UnregisterPushTokenRequest(string Token);

}
