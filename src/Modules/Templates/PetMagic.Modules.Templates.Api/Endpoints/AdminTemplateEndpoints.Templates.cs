using System.Globalization;
using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> CreateImageAsync(
        [FromBody] CreateImageTemplateCommand command,
        [FromServices] IValidator<CreateImageTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateImageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> UpdateImageAsync(
        [FromRoute] Guid templateId,
        [FromBody] UpdateImageTemplateRequest request,
        [FromServices] IValidator<UpdateImageTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateImageTemplateCommand(
            templateId,
            request.Title,
            request.ShortDescription,
            request.Category,
            request.Tags,
            request.IsPremium,
            request.TokenCost,
            request.PromoBadgeMode,
            request.PreviewAsset,
            request.ImageModel,
            request.ImagePrompt,
            request.Status,
            request.PetPhotoRequirements,
            request.SupportsGenerationResultInput,
            request.RequiredInputMediaType,
            request.RecommendedAfterImageGeneration,
            request.SupportsGenerateSimilar,
            request.DefaultVariationStrength);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateImageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> CreateVideoAsync(
        [FromBody] CreateVideoTemplateCommand command,
        [FromServices] IValidator<CreateVideoTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateVideoAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> UpdateVideoAsync(
        [FromRoute] Guid templateId,
        [FromBody] UpdateVideoTemplateRequest request,
        [FromServices] IValidator<UpdateVideoTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateVideoTemplateCommand(
            templateId,
            request.Title,
            request.ShortDescription,
            request.Category,
            request.Tags,
            request.IsPremium,
            request.TokenCost,
            request.PromoBadgeMode,
            request.MusicDescription,
            request.PreviewAsset,
            request.ReferenceMotionAsset,
            request.PreprocessingModel,
            request.PreprocessingPrompt,
            request.KlingModel,
            request.KlingPrompt,
            request.KeepOriginalSound,
            request.Status,
            request.PetPhotoRequirements,
            request.SupportsGenerationResultInput,
            request.RequiredInputMediaType,
            request.RecommendedAfterImageGeneration,
            request.SupportsGenerateSimilar,
            request.DefaultVariationStrength);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateVideoAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> ChangeStatusAsync(
        [FromRoute] Guid templateId,
        [FromBody] ChangeTemplateStatusRequest request,
        [FromServices] IValidator<ChangeTemplateStatusCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new ChangeTemplateStatusCommand(templateId, request.Status);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ChangeStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteAsync(
        [FromRoute] Guid templateId,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.DeleteAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "templates.not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

    public sealed record UpdateImageTemplateRequest(
        string Title,
        string ShortDescription,
        string Category,
        IReadOnlyList<string> Tags,
        bool IsPremium,
        int TokenCost,
        string PromoBadgeMode,
        TemplateAssetCommand? PreviewAsset,
        string ImageModel,
        string ImagePrompt,
        string? Status = null,
        IReadOnlyList<string>? PetPhotoRequirements = null,
        bool SupportsGenerationResultInput = false,
        string? RequiredInputMediaType = null,
        bool RecommendedAfterImageGeneration = false,
        bool SupportsGenerateSimilar = true,
        string DefaultVariationStrength = "medium");

    public sealed record UpdateVideoTemplateRequest(
        string Title,
        string ShortDescription,
        string Category,
        IReadOnlyList<string> Tags,
        bool IsPremium,
        int TokenCost,
        string PromoBadgeMode,
        string MusicDescription,
        TemplateAssetCommand? PreviewAsset,
        TemplateAssetCommand? ReferenceMotionAsset,
        string PreprocessingModel,
        string PreprocessingPrompt,
        string KlingModel,
        string KlingPrompt,
        bool KeepOriginalSound,
        string? Status = null,
        IReadOnlyList<string>? PetPhotoRequirements = null,
        bool SupportsGenerationResultInput = false,
        string? RequiredInputMediaType = null,
        bool RecommendedAfterImageGeneration = false,
        bool SupportsGenerateSimilar = true,
        string DefaultVariationStrength = "medium");

    public sealed record ChangeTemplateStatusRequest(string Status);

    public sealed record AdminModerationDecisionRequest(string Action, string Reason);
}
