using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class AdminTemplateCategoryEndpoints
{
    public static IEndpointRouteBuilder MapAdminTemplateCategoryEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/templates/categories")
            .WithTags("Admin.TemplateCategories")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        group.MapGet("/", ListAsync);
        group.MapPost("/", CreateAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/{categoryId:guid}", UpdateAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/{categoryId:guid}/archive", ChangeArchiveStateAsync)
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/{categoryId:guid}", DeleteAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async Task<Ok<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAsync(
        [FromQuery] bool includeArchived,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminCategoriesAsync(includeArchived, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateCategoryListItemResponse>, ValidationProblem, ProblemHttpResult>> CreateAsync(
        [FromBody] CreateTemplateCategoryCommand command,
        [FromServices] IValidator<CreateTemplateCategoryCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateCategoryAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveCategoryFailureStatusCode(result.Error.Code));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateCategoryListItemResponse>, ValidationProblem, ProblemHttpResult>> UpdateAsync(
        [FromRoute] Guid categoryId,
        [FromBody] UpdateTemplateCategoryRequest request,
        [FromServices] IValidator<UpdateTemplateCategoryCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateTemplateCategoryCommand(categoryId, request.Name);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateCategoryAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveCategoryFailureStatusCode(result.Error.Code));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateCategoryListItemResponse>, ValidationProblem, ProblemHttpResult>> ChangeArchiveStateAsync(
        [FromRoute] Guid categoryId,
        [FromBody] ChangeTemplateCategoryArchiveStateRequest request,
        [FromServices] IValidator<ChangeTemplateCategoryArchiveStateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new ChangeTemplateCategoryArchiveStateCommand(categoryId, request.IsArchived);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ChangeCategoryArchiveStateAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveCategoryFailureStatusCode(result.Error.Code));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteAsync(
        [FromRoute] Guid categoryId,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.DeleteCategoryAsync(categoryId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveCategoryFailureStatusCode(result.Error.Code));
        }

        return TypedResults.NoContent();
    }

    private static int ResolveCategoryFailureStatusCode(string errorCode)
    {
        return errorCode switch
        {
            "templates.category_not_found" => StatusCodes.Status404NotFound,
            "templates.category_already_exists" => StatusCodes.Status409Conflict,
            "templates.category_archived" => StatusCodes.Status409Conflict,
            "templates.category_has_templates" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };
    }

    public sealed record UpdateTemplateCategoryRequest(string Name);

    public sealed record ChangeTemplateCategoryArchiveStateRequest(bool IsArchived);
}
