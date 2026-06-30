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

    private static async Task<Results<Ok<AdminTemplateCatalogPageResponse>, ProblemHttpResult>> ListAsync(

        [FromQuery] string? type,

        [FromQuery] string? status,

        [FromQuery] string? search,

        [FromQuery] string? category,

        [FromQuery] string? access,

        [FromQuery] string? sort,

        [FromQuery] int? skip,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var filterProblem = ValidateCatalogFilters(type, status, access, sort);

        if (filterProblem is not null)

        {

            return filterProblem;

        }


        var result = await service.ListAdminAsync(

            new AdminTemplateCatalogQuery(type, status, search, category, access, sort, skip, take),

            cancellationToken);


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Ok<AdminTemplatesAnalyticsOverviewResponse>> GetAnalyticsOverviewAsync(

        [FromQuery] int? periodDays,

        [FromQuery] string? templateType,

        [FromQuery] string? category,

        [FromQuery] string? status,

        [FromQuery] string? access,

        [FromQuery] string? sort,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminTemplatesAnalyticsAsync(

            new AdminTemplatesAnalyticsQuery(periodDays, templateType, category, status, access, sort, take),

            cancellationToken);


        return TypedResults.Ok(result.Value);

    }


    private static ProblemHttpResult? ValidateCatalogFilters(

        string? type,

        string? status,

        string? access,

        string? sort)

    {

        if (!IsNeutralFilter(type) && !IsDefinedEnumName<TemplateType>(type))

        {

            return InvalidCatalogFilterProblem(

                "templates.invalid_type",

                "Query parameter type must be Image or Video.");

        }


        var normalizedStatus = status?.Trim();

        if (!IsNeutralFilter(normalizedStatus)

            && !string.Equals(normalizedStatus, "not_archived", StringComparison.OrdinalIgnoreCase)

            && !IsDefinedEnumName<TemplateStatus>(status))

        {

            return InvalidCatalogFilterProblem(

                "templates.invalid_status",

                "Query parameter status must be Draft, Active, Archived, or not_archived.");

        }


        if (!IsNeutralFilter(access)

            && !IsOneOf(access, "premium", "free"))

        {

            return InvalidCatalogFilterProblem(

                "templates.invalid_access",

                "Query parameter access must be premium or free.");

        }


        if (!IsNeutralFilter(sort)

            && !IsOneOf(sort, "newest", "updated", "title", "tokens"))

        {

            return InvalidCatalogFilterProblem(

                "templates.invalid_sort",

                "Query parameter sort must be newest, updated, title, or tokens.");

        }


        return null;

    }


    private static ProblemHttpResult? ValidateGenerationFilters(string? status)

    {

        if (IsNeutralFilter(status))

        {

            return null;

        }


        return IsOneOf(status, "pending", "running", "completed", "failed", "cancelled", "retrying")

            ? null

            : InvalidCatalogFilterProblem(

                "templates.invalid_status",

                "Query parameter status must be one of: pending, running, completed, failed, cancelled, retrying.");

    }


    private static ProblemHttpResult InvalidCatalogFilterProblem(string title, string detail)

    {

        return TypedResults.Problem(

            title: title,

            detail: detail,

            statusCode: StatusCodes.Status400BadRequest);

    }


    private static bool IsNeutralFilter(string? raw)

    {

        return string.IsNullOrWhiteSpace(raw)

            || string.Equals(raw.Trim(), "all", StringComparison.OrdinalIgnoreCase);

    }


    private static bool IsDefinedEnumName<TEnum>(string? raw)

        where TEnum : struct, Enum

    {

        if (string.IsNullOrWhiteSpace(raw))

        {

            return false;

        }


        var normalized = raw.Trim();

        return Enum.GetNames<TEnum>().Any(name =>

            string.Equals(name, normalized, StringComparison.OrdinalIgnoreCase));

    }


    private static bool IsOneOf(string? raw, params string[] values)

    {

        if (string.IsNullOrWhiteSpace(raw))

        {

            return false;

        }


        var normalized = raw.Trim();

        return values.Any(value => string.Equals(value, normalized, StringComparison.OrdinalIgnoreCase));

    }
}
