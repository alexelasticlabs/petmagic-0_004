using System.Globalization;
using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
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

        [FromQuery] string? visibility,

        [FromQuery] string? readiness,

        [FromQuery] string? sort,

        [FromQuery] int? skip,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var filterProblem = ValidateCatalogFilters(type, status, access, visibility, readiness, sort);

        if (filterProblem is not null)

        {

            return filterProblem;

        }


        var result = await service.ListAdminAsync(

            new AdminTemplateCatalogQuery(
                type,
                status,
                search,
                category,
                access,
                sort,
                skip,
                take,
                visibility,
                readiness),

            cancellationToken);


        if (result.IsFailure)

        {

            return ToAdminTemplateProblem(result.Error);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminTemplatesAnalyticsOverviewResponse>, ProblemHttpResult>> GetAnalyticsOverviewAsync(

        HttpContext context,

        [FromQuery] int? periodDays,

        [FromQuery] string? templateType,

        [FromQuery] string? category,

        [FromQuery] string? status,

        [FromQuery] string? access,

        [FromQuery] string? sort,

        [FromQuery] int? take,

        [FromQuery] int? skip,

        [FromQuery] Guid[]? templateIds,

        CancellationToken cancellationToken)

    {

        var filterProblem = ValidateAnalyticsFilters(templateType, status, access, sort, templateIds);

        if (filterProblem is not null)

        {

            return filterProblem;

        }

        var service = context.RequestServices.GetRequiredService<ITemplatesService>();

        var result = await service.GetAdminTemplatesAnalyticsAsync(

            new AdminTemplatesAnalyticsQuery(periodDays, templateType, category, status, access, sort, take, skip, templateIds),

            cancellationToken);


        if (result.IsFailure)

        {

            return ToAdminTemplateProblem(result.Error);

        }


        return TypedResults.Ok(result.Value);

    }


    private static ProblemHttpResult? ValidateCatalogFilters(

        string? type,

        string? status,

        string? access,

        string? visibility,

        string? readiness,

        string? sort)

    {

        if (!IsNeutralFilter(type) && !IsDefinedEnumName<TemplateType>(type))

        {

            return InvalidCatalogFilterProblem("templates.invalid_type");

        }


        var normalizedStatus = status?.Trim();

        if (!IsNeutralFilter(normalizedStatus)

            && !string.Equals(normalizedStatus, "not_archived", StringComparison.OrdinalIgnoreCase)

            && !IsDefinedEnumName<TemplateStatus>(status))

        {

            return InvalidCatalogFilterProblem("templates.invalid_status");

        }


        if (!IsNeutralFilter(access)

            && !IsOneOf(access, "premium", "free"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_access");

        }


        if (!IsNeutralFilter(visibility)

            && !IsOneOf(visibility, "public", "qa_only"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_visibility");

        }


        if (!IsNeutralFilter(readiness)

            && !IsOneOf(readiness, "ready", "missing_preview"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_readiness");

        }


        if (!IsNeutralFilter(sort)

            && !IsOneOf(sort, "newest", "updated", "title", "tokens"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_sort");

        }


        return null;

    }


    private static ProblemHttpResult? ValidateAnalyticsFilters(

        string? templateType,

        string? status,

        string? access,

        string? sort,

        IReadOnlyCollection<Guid>? templateIds)

    {

        if (!IsNeutralFilter(templateType) && !IsDefinedEnumName<TemplateType>(templateType))

        {

            return InvalidCatalogFilterProblem("templates.invalid_type");

        }


        if (!IsNeutralFilter(status) && !IsDefinedEnumName<TemplateStatus>(status))

        {

            return InvalidCatalogFilterProblem("templates.invalid_status");

        }


        if (!IsNeutralFilter(access)

            && !IsOneOf(access, "premium", "free"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_access");

        }


        if (!IsNeutralFilter(sort)

            && !IsOneOf(sort, "views", "starts", "conversion", "cost", "tokens", "updated"))

        {

            return InvalidCatalogFilterProblem("templates.invalid_sort");

        }


        if (templateIds is { Count: > 100 })

        {

            return InvalidCatalogFilterProblem("templates.too_many_template_ids");

        }


        return null;

    }


    private static ProblemHttpResult? ValidateAnalyticsFeedbackFilters(string? type)

    {

        return !IsNeutralFilter(type)

            && !IsOneOf(type, TemplateAnalyticsEventTypes.Complaint, TemplateAnalyticsEventTypes.Feedback)

            ? InvalidCatalogFilterProblem("templates.invalid_type")

            : null;

    }


    private static ProblemHttpResult? ValidateGenerationFilters(string? status)

    {

        if (IsNeutralFilter(status))

        {

            return null;

        }


        return IsOneOf(status, "pending", "running", "completed", "failed", "cancelled", "cancelling", "retrying")

            ? null

            : InvalidGenerationStatusFilterProblem();

    }


    private static ProblemHttpResult InvalidCatalogFilterProblem(string errorCode)

    {

        return TypedResults.Problem(

            title: errorCode,

            statusCode: StatusCodes.Status400BadRequest,

            extensions: BuildAdminTemplateProblemExtensions(errorCode));

    }


    private static ProblemHttpResult InvalidGenerationStatusFilterProblem()

    {

        return TypedResults.Problem(

            title: "templates.invalid_status",

            statusCode: StatusCodes.Status400BadRequest,

            extensions: BuildAdminTemplateProblemExtensions("templates.invalid_status"));

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
