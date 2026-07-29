using System.Security.Claims;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class AdminNotificationEndpoints
{
    public static IEndpointRouteBuilder MapAdminNotificationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/notifications")
            .WithTags("Admin.Notifications")
            .AddEndpointFilter(ApplyPrivateResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("ModeratorOrAdmin");

        group.MapGet("", ListAsync);
        group.MapPost("/{notificationId:guid}/read", MarkReadAsync);
        group.MapPost("/read-all", MarkAllReadAsync);
        group.MapPost("/{notificationId:guid}/archive", ArchiveAsync);
        group.MapPost("/{notificationId:guid}/acknowledge", AcknowledgeAsync);
        return endpoints;
    }

    private static async Task<IResult> ListAsync(
        [FromQuery] string? cursor,
        [FromQuery] int? take,
        [FromQuery] string? state,
        [FromQuery] string? category,
        [FromQuery] string? priority,
        HttpContext httpContext,
        [FromServices] IAdminNotificationService service,
        CancellationToken cancellationToken)
    {
        if (!TryResolveAudience(httpContext.User, out var userId, out var roles))
        {
            return IdentityClientProblems.InvalidSubject();
        }

        var result = await service.ListAsync(
            userId,
            roles,
            new AdminNotificationsQuery(cursor, take, state, category, priority),
            cancellationToken);
        return result.IsSuccess
            ? TypedResults.Ok(result.Value)
            : IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
    }

    private static async Task<IResult> MarkReadAsync(
        [FromRoute] Guid notificationId,
        HttpContext httpContext,
        [FromServices] IAdminNotificationService service,
        CancellationToken cancellationToken)
    {
        if (!TryResolveAudience(httpContext.User, out var userId, out var roles))
        {
            return IdentityClientProblems.InvalidSubject();
        }

        var result = await service.MarkReadAsync(notificationId, userId, roles, cancellationToken);
        return result.IsSuccess
            ? TypedResults.Ok(result.Value)
            : IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
    }

    private static async Task<IResult> MarkAllReadAsync(
        [FromBody] AdminNotificationReadAllCommand command,
        HttpContext httpContext,
        [FromServices] IAdminNotificationService service,
        CancellationToken cancellationToken)
    {
        if (!TryResolveAudience(httpContext.User, out var userId, out var roles))
        {
            return IdentityClientProblems.InvalidSubject();
        }

        var result = await service.MarkAllReadAsync(
            userId,
            roles,
            command.CutoffUtc,
            cancellationToken);
        return result.IsSuccess
            ? TypedResults.Ok(new { updatedCount = result.Value })
            : IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
    }

    private static async Task<IResult> ArchiveAsync(
        [FromRoute] Guid notificationId,
        HttpContext httpContext,
        [FromServices] IAdminNotificationService service,
        CancellationToken cancellationToken)
    {
        if (!TryResolveAudience(httpContext.User, out var userId, out var roles))
        {
            return IdentityClientProblems.InvalidSubject();
        }

        var result = await service.ArchiveAsync(notificationId, userId, roles, cancellationToken);
        return result.IsSuccess
            ? TypedResults.Ok(result.Value)
            : IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
    }

    private static async Task<IResult> AcknowledgeAsync(
        [FromRoute] Guid notificationId,
        [FromBody] AdminNotificationAcknowledgeCommand command,
        HttpContext httpContext,
        [FromServices] IAdminNotificationService service,
        CancellationToken cancellationToken)
    {
        if (!TryResolveAudience(httpContext.User, out var userId, out var roles))
        {
            return IdentityClientProblems.InvalidSubject();
        }

        if (!TryParseIfMatch(httpContext.Request.Headers.IfMatch.ToString(), out var expectedVersion))
        {
            return IdentityClientProblems.ToProblem(
                AdminNotificationErrors.VersionInvalid,
                StatusCodes.Status428PreconditionRequired);
        }

        var result = await service.AcknowledgeAsync(
            notificationId,
            userId,
            roles,
            command.Reason,
            expectedVersion,
            cancellationToken);
        return result.Status switch
        {
            AdminNotificationAcknowledgeStatus.Acknowledged
                or AdminNotificationAcknowledgeStatus.IdempotentReplay => TypedResults.Ok(result.Notification),
            AdminNotificationAcknowledgeStatus.Conflict => Results.Json(
                new
                {
                    code = result.Error.Code,
                    current = result.Notification,
                },
                statusCode: StatusCodes.Status409Conflict),
            AdminNotificationAcknowledgeStatus.NotFound => IdentityClientProblems.ToProblem(
                result.Error,
                StatusCodes.Status404NotFound),
            _ => IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest),
        };
    }

    private static bool TryResolveAudience(
        ClaimsPrincipal principal,
        out Guid userId,
        out IReadOnlyCollection<string> roles)
    {
        var rawUserId = principal.FindFirstValue("sub")
            ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
        roles = principal.FindAll(ClaimTypes.Role)
            .Select(claim => claim.Value)
            .Where(role => role is "Admin" or "Moderator")
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        return Guid.TryParse(rawUserId, out userId) && roles.Count > 0;
    }

    private static bool TryParseIfMatch(string value, out int version)
    {
        var normalized = value.Trim();
        if (normalized.StartsWith("W/", StringComparison.OrdinalIgnoreCase))
        {
            normalized = normalized[2..].Trim();
        }

        normalized = normalized.Trim('"');
        return int.TryParse(normalized, out version) && version > 0;
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
}
