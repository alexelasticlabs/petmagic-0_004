using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static async Task<Results<Ok<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>, ProblemHttpResult>> ListPaymentProviderConfigurationsAsync(
        [FromServices] IEconomyAdminService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminPaymentProviderConfigurationsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> UpdatePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromBody] UpdatePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<UpdatePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> CreatePaymentProviderConfigurationAsync(
        [FromBody] CreatePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<CreatePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationResponse>, ValidationProblem, ProblemHttpResult>> ClonePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromBody] ClonePaymentProviderConfigurationRequest request,
        [FromServices] IValidator<ClonePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> DeletePaymentProviderConfigurationAsync(
        [FromRoute] Guid configurationId,
        [FromServices] IValidator<DeletePaymentProviderConfigurationCommand> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<AdminPaymentProviderConfigurationMatchResponse>, ValidationProblem, ProblemHttpResult>> TestPaymentProviderConfigurationMatchAsync(
        [FromBody] TestPaymentProviderConfigurationMatchRequest request,
        [FromServices] IValidator<TestPaymentProviderConfigurationMatchQuery> validator,
        [FromServices] IEconomyAdminService service,
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
            return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

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
}
