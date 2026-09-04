using Microsoft.AspNetCore.Http.HttpResults;

namespace PetMagic.Host.Api.Observability;

public static class AdminSystemStatusEndpoints
{
    public static IEndpointRouteBuilder MapAdminSystemStatusEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/admin/system/status", GetSystemStatusAsync)
            .WithTags("Admin.System")
            .AddEndpointFilter(ApplyPrivateResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        endpoints.MapGet("/api/admin/system/operations", GetOperationsStatusAsync)
            .WithTags("Admin.System")
            .AddEndpointFilter(ApplyPrivateResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        endpoints.MapGet("/api/admin/system/operations/problems", GetOperationsProblemsAsync)
            .WithTags("Admin.System")
            .AddEndpointFilter(ApplyPrivateResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }

    private static async Task<Ok<AdminSystemStatusResponse>> GetSystemStatusAsync(
        IAdminSystemStatusService service,
        CancellationToken cancellationToken)
    {
        return TypedResults.Ok(await service.GetAsync(cancellationToken));
    }

    private static async Task<Ok<AdminOperationsStatusDto>> GetOperationsStatusAsync(
        IAdminOperationsStatusService service,
        CancellationToken cancellationToken)
    {
        return TypedResults.Ok(await service.GetAsync(cancellationToken));
    }

    private static async Task<Results<Ok<AdminOperationsProblemListDto>, BadRequest>> GetOperationsProblemsAsync(
        string? source,
        IAdminOperationsProblemService service,
        CancellationToken cancellationToken)
    {
        if (source is not ("email" or "audit" or "push"))
        {
            return TypedResults.BadRequest();
        }

        return TypedResults.Ok(await service.GetAsync(source, cancellationToken));
    }
}
