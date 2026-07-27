using System.Globalization;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class AdminAuditEndpoints
{
    public static IEndpointRouteBuilder MapAdminAuditEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/audit-events")
            .WithTags("Admin.Audit")
            .AddEndpointFilter(ApplyPrivateAdminAuditResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        group.MapGet("", ListAuditEventsAsync);
        group.MapGet("/{eventId:guid}", GetAuditEventAsync);

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateAdminAuditResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }

    private static async Task<Results<Ok<AdminAuditEventsPageResponse>, ProblemHttpResult>> ListAuditEventsAsync(
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? search,
        [FromQuery] string? category,
        [FromQuery] Guid? actorUserId,
        [FromQuery] Guid? subjectUserId,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        HttpContext httpContext,
        [FromServices] IAdminAuditQueryService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAsync(
            new AdminAuditEventsQuery(
                skip,
                take,
                search,
                category,
                actorUserId,
                subjectUserId,
                fromUtc,
                toUtc),
            cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        httpContext.Response.Headers["X-Pagination-Skip"] = result.Value.Skip.ToString(CultureInfo.InvariantCulture);
        httpContext.Response.Headers["X-Pagination-Take"] = result.Value.Take.ToString(CultureInfo.InvariantCulture);
        httpContext.Response.Headers["X-Pagination-Has-More"] = result.Value.HasMore ? "true" : "false";

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminAuditEventDetailResponse>, ProblemHttpResult>> GetAuditEventAsync(
        [FromRoute] Guid eventId,
        [FromServices] IAdminAuditQueryService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAsync(eventId, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }
}
