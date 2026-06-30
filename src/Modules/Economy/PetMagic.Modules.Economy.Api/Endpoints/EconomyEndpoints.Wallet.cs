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

    private static async Task<Results<NoContent, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext context,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(
                userId!.Value,
                request.Token,
                request.Platform,
                request.DeviceId,
                request.AppVersion,
                request.Locale),
            cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext context,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var (userId, _, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.UnregisterPushTokenAsync(
            new UnregisterEconomyPushTokenCommand(userId!.Value, request.Token),
            cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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

    private static async Task<Ok<BillingProductsResponse>> GetBillingProductsAsync(
        IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListBillingProductsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    public sealed record SpendRequest(int Amount, string Reason);

    public sealed record RedeemCodeRequest(string Code);

    public sealed record ReferralCodeRequest(string Code);

    public sealed record RegisterPushTokenRequest(string Token, string Platform, string? DeviceId, string? AppVersion, string? Locale);

    public sealed record UnregisterPushTokenRequest(string Token);

}
