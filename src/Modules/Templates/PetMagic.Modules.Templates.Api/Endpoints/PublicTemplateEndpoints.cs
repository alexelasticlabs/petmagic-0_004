using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class PublicTemplateEndpoints
{
    public static IEndpointRouteBuilder MapPublicTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Templates")
            .RequireRateLimiting("templates");

        group.MapGet("/", ListAsync).AllowAnonymous();
        group.MapGet("/{templateId:guid}", GetAsync).AllowAnonymous();

        return endpoints;
    }

    private static async Task<Ok<IReadOnlyList<PublicTemplateListItemResponse>>> ListAsync(
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] string[]? tags,
        [FromQuery] bool? premiumOnly,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        TemplateType? templateType = Enum.TryParse<TemplateType>(type, true, out var parsedType)
            ? parsedType
            : null;
        var result = await service.ListPublicAsync(templateType, category, tags, premiumOnly, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplateResponse>, ProblemHttpResult>> GetAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPublicAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }
}
