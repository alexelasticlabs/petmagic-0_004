using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static class AdminEconomyEndpoints
{
    private static readonly string[] PurchaseStatusFilters = ["pending", "succeeded", "failed", "refunded"];

    private static readonly string[] PaymentProviderFilters = ["stripe", "app_store", "google_play"];

    private static readonly string[] SubscriptionStatusFilters =
    [
        "active",
        "trialing",
        "graceperiod",
        "grace_period",
        "grace-period",
        "pastdue",
        "past_due",
        "past-due",
        "canceled",
        "cancelled",
        "expired",
        "refunded",
        "revoked",
        "pending"
    ];

    private static readonly string[] SubscriptionEventStatusFilters =
    [
        "active",
        "trialing",
        "graceperiod",
        "grace_period",
        "grace-period",
        "pastdue",
        "past_due",
        "past-due",
        "canceled",
        "cancelled",
        "expired",
        "processed",
        "failed",
        "pending"
    ];

    private static readonly string[] RedeemCodeStatusFilters =
    [
        "all",
        "draft",
        "scheduled",
        "active",
        "paused",
        "exhausted",
        "expired",
        "archived"
    ];

    private static readonly string[] RedeemCodeRewardKindFilters = ["all", "spark"];

    private static readonly string[] RedeemCodeSortModes = ["updated", "usage", "reward", "code", "expiry"];

    public static IEndpointRouteBuilder MapAdminEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/economy")
            .WithTags("Admin.Economy")
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        group.MapGet("/ledger", GetWalletLedgerAsync);
        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/purchases", GetPurchasesAsync);
        group.MapPost("/purchases/{orderId:guid}/refund", RefundPurchaseAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/users/{userId:guid}/subscription-summary", GetUserSubscriptionSummaryAsync);
        group.MapPut("/users/{userId:guid}/premium/revoke", AdminRevokePremiumSubscriptionAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/subscriptions", GetSubscriptionsAsync);
        group.MapGet("/packs", ListPacksAsync);
        group.MapGet("/subscription-plans", ListSubscriptionPlansAsync);
        group.MapGet("/payment-provider-configs", ListPaymentProviderConfigurationsAsync);
        group.MapGet("/subscription-events", GetSubscriptionEventsAsync);
        group.MapPost("/payment-provider-configs", CreatePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/{configurationId:guid}/clone", ClonePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/payment-provider-configs/{configurationId:guid}", DeletePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/test-match", TestPaymentProviderConfigurationMatchAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/packs/{packId:guid}", UpdatePackAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/subscription-plans/{planId}", UpdateSubscriptionPlanAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/payment-provider-configs/{configurationId:guid}", UpdatePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/redeem-codes/metrics", GetRedeemCodeMetricsAsync);
        group.MapGet("/redeem-codes", ListRedeemCodesAsync);
        group.MapGet("/redeem-codes/{redeemCodeId:guid}/activations", ListRedeemCodeActivationsAsync);
        group.MapPost("/redeem-codes", CreateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/redeem-codes/{redeemCodeId:guid}", UpdateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async Task<Results<Ok<OffsetPagedResponse<WalletLedgerItemResponse>>, ProblemHttpResult>> GetWalletLedgerAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? source,
        [FromQuery] Guid? userId,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminWalletLedgerAsync(skip ?? 0, take ?? 50, source, userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminEconomyDashboardMetricsResponse>> GetDashboardMetricsAsync(
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminDashboardMetricsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<PurchaseHistoryItemResponse>>, ProblemHttpResult>> GetPurchasesAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? status,
        [FromQuery] string? provider,
        [FromQuery] string? search,
        [FromQuery] Guid? userId,
        [FromServices] IServiceProvider serviceProvider,
        CancellationToken cancellationToken)
    {
        var invalidFilterProblem = ValidatePurchaseFilters(status, provider);
        if (invalidFilterProblem is not null)
        {
            return invalidFilterProblem;
        }

        var service = serviceProvider.GetRequiredService<IEconomyService>();
        var result = await service.GetAdminPurchaseHistoryAsync(skip ?? 0, take ?? 50, status, provider, search, userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseHistoryItemResponse>, ProblemHttpResult>> RefundPurchaseAsync(
        [FromRoute] Guid orderId,
        [FromBody] AdminRefundPurchaseRequest? request,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, request?.Reason),
            cancellationToken);

        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.purchase_not_found" => StatusCodes.Status404NotFound,
                "economy.purchase_not_refundable" => StatusCodes.Status409Conflict,
                "economy.payment_gateway_failed" => StatusCodes.Status502BadGateway,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ProblemHttpResult>> GetUserSubscriptionSummaryAsync(
        [FromRoute] Guid userId,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetSubscriptionSummaryAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "users.not_found" => StatusCodes.Status404NotFound,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ValidationProblem, ProblemHttpResult>> AdminRevokePremiumSubscriptionAsync(
        [FromRoute] Guid userId,
        [FromBody] AdminRevokePremiumRequest? request,
        [FromServices] IValidator<AdminRevokePremiumSubscriptionCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new AdminRevokePremiumSubscriptionCommand(
            userId,
            string.IsNullOrWhiteSpace(request?.PaymentProvider) ? "stripe" : request.PaymentProvider);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.AdminRevokePremiumSubscriptionAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "users.not_found" => StatusCodes.Status404NotFound,
                "economy.payment_gateway_failed" => StatusCodes.Status502BadGateway,
                _ => StatusCodes.Status400BadRequest,
            };

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<AdminCurrencyPackResponse>>> ListPacksAsync(
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminCurrencyPacksAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<AdminUserSubscriptionResponse>>, ProblemHttpResult>> GetSubscriptionsAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? status,
        [FromQuery] string? provider,
        [FromQuery] string? search,
        [FromServices] IServiceProvider serviceProvider,
        CancellationToken cancellationToken)
    {
        var invalidFilterProblem = ValidateSubscriptionFilters(status, provider);
        if (invalidFilterProblem is not null)
        {
            return invalidFilterProblem;
        }

        var service = serviceProvider.GetRequiredService<IEconomyService>();
        var result = await service.GetAdminSubscriptionsAsync(skip ?? 0, take ?? 50, status, provider, search, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<AdminSubscriptionPlanResponse>>> ListSubscriptionPlansAsync(
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminSubscriptionPlansAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>> ListPaymentProviderConfigurationsAsync(
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminPaymentProviderConfigurationsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<AdminSubscriptionEventResponse>>, ProblemHttpResult>> GetSubscriptionEventsAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? provider,
        [FromQuery] string? status,
        [FromServices] IServiceProvider serviceProvider,
        CancellationToken cancellationToken)
    {
        var invalidFilterProblem = ValidateSubscriptionEventFilters(status, provider);
        if (invalidFilterProblem is not null)
        {
            return invalidFilterProblem;
        }

        var service = serviceProvider.GetRequiredService<IEconomyService>();
        var result = await service.GetAdminSubscriptionEventsAsync(skip ?? 0, take ?? 50, provider, status, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminCurrencyPackResponse>, ValidationProblem, ProblemHttpResult>> UpdatePackAsync(
        [FromRoute] Guid packId,
        [FromBody] UpdatePackRequest request,
        [FromServices] IValidator<UpdateCurrencyPackCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateCurrencyPackCommand(
            packId,
            request.DisplayName,
            request.PriceAmount,
            request.GrantedSpark,
            request.BonusSpark,
            request.IsActive,
            request.SortOrder);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateCurrencyPackAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.pack_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminSubscriptionPlanResponse>, ValidationProblem, ProblemHttpResult>> UpdateSubscriptionPlanAsync(
        [FromRoute] string planId,
        [FromBody] UpdateSubscriptionPlanRequest request,
        [FromServices] IValidator<UpdateSubscriptionPlanCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateSubscriptionPlanCommand(
            planId,
            request.Name,
            request.PriceAmount,
            request.CurrencyCode,
            request.MonthlyTokenLimit,
            request.IsRecommended,
            request.IsActive,
            request.AppleProductId,
            request.GoogleProductId,
            request.StripePriceId,
            request.DisplayOrder);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateSubscriptionPlanAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.premium_plan_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> UpdatePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromBody] UpdatePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<UpdatePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdatePaymentProviderConfigurationCommand(
            configurationId,
            request.Region,
            request.IsEnabled,
            request.IsRecommended,
            request.IsSelectedByDefault,
            request.RequiresExternalWarning,
            request.RequiresStoreDisclosure,
            request.AllowedFromAppVersion,
            request.ExternalCheckoutAllowed,
            request.BonusTokensPercent,
            request.DisplayLabel,
            request.DisplaySubtitle,
            request.WarningTitle,
            request.WarningMessage,
            request.Mode,
            request.Notes);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdatePaymentProviderConfigurationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.payment_provider_config_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> CreatePaymentProviderConfigurationAsync(
        [FromBody] CreatePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<CreatePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new CreatePaymentProviderConfigurationCommand(
            request.Provider,
            request.Platform,
            request.Region,
            request.IsEnabled,
            request.IsRecommended,
            request.IsSelectedByDefault,
            request.RequiresExternalWarning,
            request.RequiresStoreDisclosure,
            request.AllowedFromAppVersion,
            request.ExternalCheckoutAllowed,
            request.BonusTokensPercent,
            request.DisplayLabel,
            request.DisplaySubtitle,
            request.WarningTitle,
            request.WarningMessage,
            request.Mode,
            request.Notes);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreatePaymentProviderConfigurationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.payment_provider_config_exists"
                ? StatusCodes.Status409Conflict
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> ClonePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromBody] ClonePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<ClonePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new ClonePaymentProviderConfigurationCommand(
            configurationId,
            request.Region);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ClonePaymentProviderConfigurationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code switch
            {
                "economy.payment_provider_config_not_found" => StatusCodes.Status404NotFound,
                "economy.payment_provider_config_exists" => StatusCodes.Status409Conflict,
                _ => StatusCodes.Status400BadRequest
            };
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> DeletePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromServices] IValidator<DeletePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new DeletePaymentProviderConfigurationCommand(configurationId);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.DeletePaymentProviderConfigurationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.payment_provider_config_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationMatchResponse>, ValidationProblem, ProblemHttpResult>> TestPaymentProviderConfigurationMatchAsync(
        [FromBody] TestPaymentProviderConfigurationMatchRequest request,
        [FromServices] IValidator<TestPaymentProviderConfigurationMatchQuery> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var query = new TestPaymentProviderConfigurationMatchQuery(
            request.Provider,
            request.Platform,
            request.Country,
            request.AppVersion);

        var validation = await validator.ValidateAsync(query, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.TestPaymentProviderConfigurationMatchAsync(query, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<AdminRedeemCodeResponse>>, ProblemHttpResult>> ListRedeemCodesAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? search,
        [FromQuery] string? status,
        [FromQuery] string? rewardKind,
        [FromQuery] string? sort,
        [FromServices] IServiceProvider serviceProvider,
        CancellationToken cancellationToken)
    {
        var invalidFilterProblem = ValidateRedeemCodeFilters(status, rewardKind, sort);
        if (invalidFilterProblem is not null)
        {
            return invalidFilterProblem;
        }

        var query = new AdminRedeemCodeListQuery(skip ?? 0, take ?? 50, search, status, rewardKind, sort);
        var service = serviceProvider.GetRequiredService<IEconomyService>();
        var result = await service.ListAdminRedeemCodesAsync(query, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminRedeemCodeMetricsResponse>, ProblemHttpResult>> GetRedeemCodeMetricsAsync(
        [FromQuery] string? search,
        [FromQuery] string? status,
        [FromQuery] string? rewardKind,
        [FromServices] IServiceProvider serviceProvider,
        CancellationToken cancellationToken)
    {
        var invalidFilterProblem = ValidateRedeemCodeFilters(status, rewardKind, null);
        if (invalidFilterProblem is not null)
        {
            return invalidFilterProblem;
        }

        var query = new AdminRedeemCodeListQuery(Search: search, Status: status, RewardKind: rewardKind);
        var service = serviceProvider.GetRequiredService<IEconomyService>();
        var result = await service.GetAdminRedeemCodeMetricsAsync(query, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static ProblemHttpResult? ValidateRedeemCodeFilters(string? status, string? rewardKind, string? sort)
    {
        if (!IsAllowedOptionalFilter(status, RedeemCodeStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.redeem_code_status_invalid",
                detail: "Query parameter status must be all, draft, scheduled, active, paused, exhausted, expired, or archived.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (!IsAllowedOptionalFilter(rewardKind, RedeemCodeRewardKindFilters))
        {
            return TypedResults.Problem(
                title: "economy.redeem_code_reward_kind_invalid",
                detail: "Query parameter rewardKind must be all or spark.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (!IsAllowedOptionalFilter(sort, RedeemCodeSortModes))
        {
            return TypedResults.Problem(
                title: "economy.redeem_code_sort_invalid",
                detail: "Query parameter sort must be updated, usage, reward, code, or expiry.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return null;
    }

    private static ProblemHttpResult? ValidatePurchaseFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, PurchaseStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.purchase_status_invalid",
                detail: "Query parameter status must be pending, succeeded, failed, or refunded.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.subscription_status_invalid",
                detail: "Query parameter status is not supported for admin subscription filtering.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidateSubscriptionEventFilters(string? status, string? provider)
    {
        if (!IsAllowedOptionalFilter(status, SubscriptionEventStatusFilters))
        {
            return TypedResults.Problem(
                title: "economy.subscription_event_status_invalid",
                detail: "Query parameter status is not supported for admin subscription event filtering.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        return ValidatePaymentProviderFilter(provider);
    }

    private static ProblemHttpResult? ValidatePaymentProviderFilter(string? provider)
    {
        if (IsAllowedOptionalFilter(provider, PaymentProviderFilters))
        {
            return null;
        }

        return TypedResults.Problem(
            title: "economy.payment_provider_invalid",
            detail: "Query parameter provider must be stripe, app_store, or google_play.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    private static bool IsAllowedOptionalFilter(string? rawValue, string[] allowedValues)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return true;
        }

        var normalized = rawValue.Trim().ToLowerInvariant();
        return allowedValues.Contains(normalized, StringComparer.Ordinal);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>, ProblemHttpResult>> ListRedeemCodeActivationsAsync(
        [FromRoute] Guid redeemCodeId,
        [FromQuery] int skip,
        [FromQuery] int take,
        [FromQuery] Guid? userId,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminRedeemCodeActivationsAsync(redeemCodeId, skip, take, userId, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.redeem_code_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminRedeemCodeResponse>, ValidationProblem, ProblemHttpResult>> CreateRedeemCodeAsync(
        [FromBody] CreateRedeemCodeRequest request,
        [FromServices] IValidator<CreateRedeemCodeCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new CreateRedeemCodeCommand(
            request.Code,
            request.Description,
            request.RewardKind,
            request.RewardValue,
            request.MaxRedemptions,
            request.MaxRedemptionsPerUser,
            request.IsActive,
            request.StartsAtUtc,
            request.ExpiresAtUtc,
            request.CampaignName,
            request.CampaignChannel,
            request.MinimumSuccessfulPurchases,
            request.CreatedBy);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateRedeemCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.redeem_code_exists"
                ? StatusCodes.Status409Conflict
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminRedeemCodeResponse>, ValidationProblem, ProblemHttpResult>> UpdateRedeemCodeAsync(
        [FromRoute] Guid redeemCodeId,
        [FromBody] UpdateRedeemCodeRequest request,
        [FromServices] IValidator<UpdateRedeemCodeCommand> validator,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateRedeemCodeCommand(
            redeemCodeId,
            request.Description,
            request.RewardKind,
            request.RewardValue,
            request.MaxRedemptions,
            request.MaxRedemptionsPerUser,
            request.IsActive,
            request.StartsAtUtc,
            request.ExpiresAtUtc,
            request.CampaignName,
            request.CampaignChannel,
            request.MinimumSuccessfulPurchases,
            request.CreatedBy);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateRedeemCodeAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = result.Error.Code == "economy.redeem_code_not_found"
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.Ok(result.Value);
    }

    public sealed record UpdatePackRequest(
        string DisplayName,
        decimal PriceAmount,
        int GrantedSpark,
        int BonusSpark,
        bool IsActive,
        int SortOrder);

    public sealed record UpdateSubscriptionPlanRequest(
        string Name,
        decimal PriceAmount,
        string CurrencyCode,
        int MonthlyTokenLimit,
        bool IsRecommended,
        bool IsActive,
        string? AppleProductId,
        string? GoogleProductId,
        string? StripePriceId,
        int DisplayOrder);

    public sealed record UpdatePaymentProviderConfigurationRequest(
        string Region,
        bool IsEnabled,
        bool IsRecommended,
        bool IsSelectedByDefault,
        bool RequiresExternalWarning,
        bool RequiresStoreDisclosure,
        string AllowedFromAppVersion,
        bool ExternalCheckoutAllowed,
        int BonusTokensPercent,
        string? DisplayLabel,
        string? DisplaySubtitle,
        string? WarningTitle,
        string? WarningMessage,
        string Mode,
        string? Notes);

    public sealed record CreatePaymentProviderConfigurationRequest(
        string Provider,
        string Platform,
        string Region,
        bool IsEnabled,
        bool IsRecommended,
        bool IsSelectedByDefault,
        bool RequiresExternalWarning,
        bool RequiresStoreDisclosure,
        string AllowedFromAppVersion,
        bool ExternalCheckoutAllowed,
        int BonusTokensPercent,
        string? DisplayLabel,
        string? DisplaySubtitle,
        string? WarningTitle,
        string? WarningMessage,
        string Mode,
        string? Notes);

    public sealed record ClonePaymentProviderConfigurationRequest(string Region);

    public sealed record TestPaymentProviderConfigurationMatchRequest(
        string Provider,
        string Platform,
        string Country,
        string AppVersion);

    public sealed record CreateRedeemCodeRequest(
        string Code,
        string Description,
        string RewardKind,
        int RewardValue,
        int MaxRedemptions,
        int MaxRedemptionsPerUser,
        bool IsActive,
        DateTime? StartsAtUtc,
        DateTime? ExpiresAtUtc,
        string? CampaignName = null,
        string? CampaignChannel = null,
        int MinimumSuccessfulPurchases = 0,
        string? CreatedBy = null);

    public sealed record UpdateRedeemCodeRequest(
        string Description,
        string RewardKind,
        int RewardValue,
        int MaxRedemptions,
        int MaxRedemptionsPerUser,
        bool IsActive,
        DateTime? StartsAtUtc,
        DateTime? ExpiresAtUtc,
        string? CampaignName = null,
        string? CampaignChannel = null,
        int MinimumSuccessfulPurchases = 0,
        string? CreatedBy = null);

    public sealed record AdminRevokePremiumRequest(string? PaymentProvider);

    public sealed record AdminRefundPurchaseRequest(string? Reason);
}
