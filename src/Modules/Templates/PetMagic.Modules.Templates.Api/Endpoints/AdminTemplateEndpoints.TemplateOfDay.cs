using System.Globalization;
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

    private static async Task<Results<Ok<AdminTemplateOfTheDayScheduleResponse>, ProblemHttpResult>> ListTemplateOfTheDayScheduleAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminTemplateOfTheDayScheduleAsync(skip, take, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminTemplateProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse?>, ProblemHttpResult>> GetCurrentTemplateOfTheDayAsync(
        [FromQuery] DateOnly? date,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminCurrentTemplateOfTheDayAsync(date, cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminTemplateProblem(result.Error);
        }

        AdminTemplateOfTheDayResponse? value = result.Value;
        return TypedResults.Ok<AdminTemplateOfTheDayResponse?>(value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDaySettingsResponse>, ProblemHttpResult>> GetTemplateOfTheDaySettingsAsync(
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTemplateOfTheDaySettingsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToAdminTemplateProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDaySettingsResponse>, ProblemHttpResult>> UpdateTemplateOfTheDaySettingsAsync(
        [FromBody] TemplateOfTheDaySettingsRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(httpContext);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.UpdateAdminTemplateOfTheDaySettingsAsync(
            new UpdateTemplateOfTheDaySettingsCommand(
                request.AutoModeEnabled,
                request.AllowedTypes,
                request.ExcludeRecentDays,
                adminUserId),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToAdminTemplateProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse>, ProblemHttpResult>> CreateTemplateOfTheDayAsync(
        [FromBody] TemplateOfTheDayRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(httpContext);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

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
                adminUserId),
            cancellationToken);

        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
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

        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteTemplateOfTheDayAsync(
        Guid id,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.DeleteTemplateOfTheDayAsync(id, cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.NoContent();
    }

    private static async Task<Results<Ok<AdminTemplateOfTheDayResponse>, ProblemHttpResult>> AutoPickTemplateOfTheDayAsync(
        [FromBody] AutoPickTemplateOfTheDayRequest request,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(httpContext);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(
                request.Date,
                request.AllowedTypes,
                request.ExcludeRecentDays,
                adminUserId,
                Force: true),
            cancellationToken);

        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
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
