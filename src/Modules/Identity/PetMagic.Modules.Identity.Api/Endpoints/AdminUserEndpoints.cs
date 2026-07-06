using System.Globalization;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class AdminUserEndpoints
{
    private const int MaxAdminUserMutationRequestBodyBytes = 8 * 1024;
    private const int MaxAdminBulkEmailRequestBodyBytes = 64 * 1024;

    public static IEndpointRouteBuilder MapAdminUserEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/users")
            .WithTags("Admin.Users")
            .AddEndpointFilter(ApplyPrivateAdminUserResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        group.MapGet("", ListUsersAsync);
        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/{userId:guid}", GetUserAsync);
        group.MapGet("/{userId:guid}/analytics", GetUserAnalyticsAsync);
        group.MapPost("/{userId:guid}/wallet", AdjustWalletAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));
        group.MapPost("/emails", SendBulkEmailAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminBulkEmailRequestBodyBytes));
        group.MapPut("/{userId:guid}/role", AssignRoleAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));
        group.MapDelete("/{userId:guid}/role", RevokeRoleAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));
        group.MapDelete("/{userId:guid}", DeleteUserAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));
        group.MapPut("/{userId:guid}/active", SetActiveStatusAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminUserMutationRequestBodyBytes));

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateAdminUserResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }

    private static async Task<Results<Ok<UserListPageResponse>, ProblemHttpResult>> ListUsersAsync(
        [FromQuery] int skip,
        [FromQuery] int take,
        [FromQuery] string? search,
        [FromQuery] string? role,
        [FromQuery] string? status,
        [FromQuery] bool? isPremium,
        [FromQuery] string? sort,
        HttpContext httpContext,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListUsersAsync(
            skip,
            take,
            search,
            role,
            status,
            isPremium,
            sort,
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

    private static async Task<Results<Ok<AdminUserDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminUserDashboardMetricsAsync(cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminUserWalletOperationResponse>, ValidationProblem, ProblemHttpResult>> AdjustWalletAsync(
        [FromRoute] Guid userId,
        [FromBody] AdjustWalletRequest request,
        [FromServices] IValidator<AdminAdjustUserWalletCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new AdminAdjustUserWalletCommand(userId, request.Operation, request.Amount, request.Reason);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.AdjustAdminUserWalletAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminUserDetailResponse>, ProblemHttpResult>> GetUserAsync(
        [FromRoute] Guid userId,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminUserAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminUserAnalyticsResponse>, ProblemHttpResult>> GetUserAnalyticsAsync(
        [FromRoute] Guid userId,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminUserAnalyticsAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> AssignRoleAsync(
        [FromRoute] Guid userId,
        [FromBody] AssignRoleRequest request,
        [FromServices] IValidator<AssignRoleCommand> validator,
        HttpContext httpContext,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new AssignRoleCommand(userId, NormalizeSystemRole(request.Role));
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        if (command.Role is SystemRoles.Admin or SystemRoles.Moderator)
        {
            var isAdmin = httpContext.User.IsInRole(SystemRoles.Admin);
            if (!isAdmin)
            {
                return IdentityClientProblems.ToProblem(
                    new Error("users.role_not_allowed", "Only Admin can assign Admin or Moderator roles."),
                    StatusCodes.Status403Forbidden);
            }
        }

        var result = await service.AssignRoleAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> RevokeRoleAsync(
        [FromRoute] Guid userId,
        [FromBody] RevokeRoleRequest request,
        [FromServices] IValidator<RevokeRoleCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new RevokeRoleCommand(userId, NormalizeSystemRole(request.Role));
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.RevokeRoleAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> SetActiveStatusAsync(
        [FromRoute] Guid userId,
        [FromBody] SetActiveStatusRequest request,
        [FromServices] IValidator<SetUserActiveStatusCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new SetUserActiveStatusCommand(userId, request.IsActive);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.SetUserActiveStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> DeleteUserAsync(
        [FromRoute] Guid userId,
        [FromServices] IValidator<DeleteAdminUserCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new DeleteAdminUserCommand(userId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.DeleteAdminUserAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Accepted, ValidationProblem, ProblemHttpResult>> SendBulkEmailAsync(
        [FromBody] SendBulkEmailRequest request,
        [FromServices] IValidator<SendBulkEmailCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new SendBulkEmailCommand(request.Audience, request.Subject, request.Body, request.UserIds);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.SendBulkEmailAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    private static string NormalizeSystemRole(string? role)
    {
        var normalizedRole = role?.Trim();
        if (string.IsNullOrWhiteSpace(normalizedRole))
        {
            return string.Empty;
        }

        foreach (var supportedRole in SystemRoles.All)
        {
            if (string.Equals(supportedRole, normalizedRole, StringComparison.OrdinalIgnoreCase))
            {
                return supportedRole;
            }
        }

        return normalizedRole;
    }

    public sealed record AssignRoleRequest(string? Role);

    public sealed record RevokeRoleRequest(string? Role);

    public sealed record SetActiveStatusRequest(bool IsActive);

    public sealed record SendBulkEmailRequest(string Audience, string Subject, string Body, IReadOnlyList<Guid>? UserIds);

    public sealed record AdjustWalletRequest(string Operation, int Amount, string Reason);
}
