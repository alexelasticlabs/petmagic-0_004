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
        var service = serviceProvider.GetRequiredService<IEconomyAdminService>();
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
        var service = serviceProvider.GetRequiredService<IEconomyAdminService>();
        var result = await service.GetAdminRedeemCodeMetricsAsync(query, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<AdminRedeemCodeRedemptionResponse>>, ProblemHttpResult>> ListRedeemCodeActivationsAsync(
        [FromRoute] Guid redeemCodeId,
        [FromQuery] int skip,
        [FromQuery] int take,
        [FromQuery] Guid? userId,
        [FromServices] IEconomyAdminService service,
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
        [FromServices] IEconomyAdminService service,
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
        [FromServices] IEconomyAdminService service,
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
}
