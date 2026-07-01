using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static async Task<Results<Ok<OffsetPagedResponse<WalletLedgerItemResponse>>, ProblemHttpResult>> GetWalletLedgerAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? source,
        [FromQuery] Guid? userId,
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminWalletLedgerAsync(skip ?? 0, take ?? 50, source, userId, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminEconomyDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminDashboardMetricsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

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

        var service = serviceProvider.GetRequiredService<IEconomyAdminService>();
        var result = await service.GetAdminPurchaseHistoryAsync(skip ?? 0, take ?? 50, status, provider, search, userId, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PurchaseHistoryItemResponse>, ValidationProblem, ProblemHttpResult>> RefundPurchaseAsync(
        [FromRoute] Guid orderId,
        [FromBody] AdminRefundPurchaseRequest? request,
        [FromServices] IValidator<AdminRefundPurchaseCommand> validator,
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var command = new AdminRefundPurchaseCommand(orderId, request?.Reason);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RefundAdminPurchaseAsync(command, cancellationToken);

        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SubscriptionSummaryResponse>, ValidationProblem, ProblemHttpResult>> AdminRevokePremiumSubscriptionAsync(
        [FromRoute] Guid userId,
        [FromBody] AdminRevokePremiumRequest? request,
        [FromServices] IValidator<AdminRevokePremiumSubscriptionCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminCurrencyPackResponse>>, ProblemHttpResult>> ListPacksAsync(
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminCurrencyPacksAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

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

        var service = serviceProvider.GetRequiredService<IEconomyAdminService>();
        var result = await service.GetAdminSubscriptionsAsync(skip ?? 0, take ?? 50, status, provider, search, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminSubscriptionPlanResponse>>, ProblemHttpResult>> ListSubscriptionPlansAsync(
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminSubscriptionPlansAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

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

        var service = serviceProvider.GetRequiredService<IEconomyAdminService>();
        var result = await service.GetAdminSubscriptionEventsAsync(skip ?? 0, take ?? 50, provider, status, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminCurrencyPackResponse>, ValidationProblem, ProblemHttpResult>> UpdatePackAsync(
        [FromRoute] Guid packId,
        [FromBody] UpdatePackRequest request,
        [FromServices] IValidator<UpdateCurrencyPackCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminSubscriptionPlanResponse>, ValidationProblem, ProblemHttpResult>> UpdateSubscriptionPlanAsync(
        [FromRoute] string planId,
        [FromBody] UpdateSubscriptionPlanRequest request,
        [FromServices] IValidator<UpdateSubscriptionPlanCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
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

    public sealed record AdminRevokePremiumRequest(string? PaymentProvider);

    public sealed record AdminRefundPurchaseRequest(string? Reason);
}
