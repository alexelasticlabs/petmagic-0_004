using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static class AdminEconomyEndpoints
{
    public static IEndpointRouteBuilder MapAdminEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/economy")
            .WithTags("Admin.Economy")
            .RequireAuthorization("ModeratorOrAdmin");

        group.MapGet("/ledger", GetWalletLedgerAsync);
        group.MapGet("/purchases", GetPurchasesAsync);
        group.MapGet("/packs", ListPacksAsync);
        group.MapPut("/packs/{packId:guid}", UpdatePackAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/redeem-codes", ListRedeemCodesAsync);
        group.MapPost("/redeem-codes", CreateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/redeem-codes/{redeemCodeId:guid}", UpdateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async Task<Results<Ok<OffsetPagedResponse<WalletLedgerItemResponse>>, ProblemHttpResult>> GetWalletLedgerAsync(
        [FromQuery] int skip,
        [FromQuery] int take,
        [FromQuery] string? source,
        [FromQuery] Guid? userId,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminWalletLedgerAsync(skip, take, source, userId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<OffsetPagedResponse<PurchaseHistoryItemResponse>>, ProblemHttpResult>> GetPurchasesAsync(
        [FromQuery] int skip,
        [FromQuery] int take,
        [FromQuery] string? status,
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminPurchaseHistoryAsync(skip, take, status, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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

    private static async Task<Ok<IReadOnlyList<AdminRedeemCodeResponse>>> ListRedeemCodesAsync(
        [FromServices] IEconomyService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminRedeemCodesAsync(cancellationToken);
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
            request.RewardSpark,
            request.MaxRedemptions,
            request.IsActive,
            request.StartsAtUtc,
            request.ExpiresAtUtc);

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
            request.RewardSpark,
            request.MaxRedemptions,
            request.IsActive,
            request.StartsAtUtc,
            request.ExpiresAtUtc);

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

    public sealed record CreateRedeemCodeRequest(
        string Code,
        string Description,
        int RewardSpark,
        int MaxRedemptions,
        bool IsActive,
        DateTime? StartsAtUtc,
        DateTime? ExpiresAtUtc);

    public sealed record UpdateRedeemCodeRequest(
        string Description,
        int RewardSpark,
        int MaxRedemptions,
        bool IsActive,
        DateTime? StartsAtUtc,
        DateTime? ExpiresAtUtc);
}
