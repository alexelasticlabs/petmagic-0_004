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

    private static async Task<Ok<AdminTemplateOfTheDayScheduleResponse>> ListTemplateOfTheDayScheduleAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminTemplateOfTheDayScheduleAsync(skip, take, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminTemplateOfTheDayResponse?>> GetCurrentTemplateOfTheDayAsync(
        [FromQuery] DateOnly? date,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminCurrentTemplateOfTheDayAsync(date, cancellationToken);
        AdminTemplateOfTheDayResponse? value = result.Value;
        return TypedResults.Ok<AdminTemplateOfTheDayResponse?>(value);
    }

    private static async Task<Ok<AdminTemplateOfTheDaySettingsResponse>> GetTemplateOfTheDaySettingsAsync(
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTemplateOfTheDaySettingsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminTemplateOfTheDaySettingsResponse>> UpdateTemplateOfTheDaySettingsAsync(
        [FromBody] TemplateOfTheDaySettingsRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.UpdateAdminTemplateOfTheDaySettingsAsync(
            new UpdateTemplateOfTheDaySettingsCommand(
                request.AutoModeEnabled,
                request.AllowedTypes,
                request.ExcludeRecentDays,
                ResolveAdminUserId(httpContext)),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse>, ProblemHttpResult>> CreateTemplateOfTheDayAsync(
        [FromBody] TemplateOfTheDayRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                request.TemplateId,
                request.StartDate,
                request.EndDate,
                request.IsActive,
                request.IsManual,
                request.Priority,
                request.TitleOverride,
                request.SubtitleOverride,
                request.BadgeTextOverride,
                ResolveAdminUserId(httpContext)),
            cancellationToken);

        return result.IsFailure ? ToTemplateOfTheDayProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse>, ProblemHttpResult>> UpdateTemplateOfTheDayAsync(
        Guid id,
        [FromBody] TemplateOfTheDayRequest request,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.UpdateTemplateOfTheDayAsync(
            new UpdateTemplateOfTheDayCommand(
                id,
                request.TemplateId,
                request.StartDate,
                request.EndDate,
                request.IsActive,
                request.IsManual,
                request.Priority,
                request.TitleOverride,
                request.SubtitleOverride,
                request.BadgeTextOverride),
            cancellationToken);

        return result.IsFailure ? ToTemplateOfTheDayProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteTemplateOfTheDayAsync(
        Guid id,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.DeleteTemplateOfTheDayAsync(id, cancellationToken);
        return result.IsFailure ? ToTemplateOfTheDayDeleteProblem(result.Error) : TypedResults.NoContent();
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse>, ProblemHttpResult>> AutoPickTemplateOfTheDayAsync(
        [FromBody] AutoPickTemplateOfTheDayRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(
                request.Date,
                request.AllowedTypes,
                request.ExcludeRecentDays,
                ResolveAdminUserId(httpContext),
                Force: true),
            cancellationToken);

        return result.IsFailure ? ToTemplateOfTheDayProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static Guid? ResolveAdminUserId(HttpContext httpContext)
    {
        var raw = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? httpContext.User.FindFirstValue("sub");

        return Guid.TryParse(raw, out var userId) ? userId : null;
    }

    private static ProblemHttpResult ToTemplateOfTheDayProblem(PetMagic.BuildingBlocks.Results.Error error)
    {
        var statusCode = error.Code switch
        {
            "templates.not_found" => StatusCodes.Status404NotFound,
            "templates.template_of_the_day_template_unavailable" => StatusCodes.Status404NotFound,
            "templates.template_of_the_day_date_occupied" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return TypedResults.Problem(title: error.Code, detail: error.Message, statusCode: statusCode);
    }

    private static ProblemHttpResult ToTemplateOfTheDayDeleteProblem(PetMagic.BuildingBlocks.Results.Error error)
    {
        var statusCode = string.Equals(error.Code, "templates.not_found", StringComparison.Ordinal)
            ? StatusCodes.Status404NotFound
            : StatusCodes.Status400BadRequest;

        return TypedResults.Problem(title: error.Code, detail: error.Message, statusCode: statusCode);
    }

    public sealed record TemplateOfTheDayRequest(
        Guid TemplateId,
        DateOnly StartDate,
        DateOnly? EndDate,
        bool IsActive,
        bool IsManual,
        int Priority,
        string? TitleOverride,
        string? SubtitleOverride,
        string? BadgeTextOverride);

    public sealed record AutoPickTemplateOfTheDayRequest(
        DateOnly Date,
        string? AllowedTypes,
        int? ExcludeRecentDays);

    public sealed record TemplateOfTheDaySettingsRequest(
        bool AutoModeEnabled,
        string? AllowedTypes,
        int? ExcludeRecentDays);
}
