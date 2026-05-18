using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static class AdminUserEndpoints
{
    public static IEndpointRouteBuilder MapAdminUserEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/users")
            .WithTags("Admin.Users")
            .RequireAuthorization("ModeratorOrAdmin");

        group.MapGet("/", ListUsersAsync);
        group.MapGet("/{userId:guid}", GetUserAsync);
        group.MapGet("/{userId:guid}/analytics", GetUserAnalyticsAsync);
        group.MapPost("/emails", SendBulkEmailAsync).RequireAuthorization("AdminOnly");
        group.MapPut("/{userId:guid}/role", AssignRoleAsync).RequireAuthorization("AdminOnly");
        group.MapDelete("/{userId:guid}/role", RevokeRoleAsync).RequireAuthorization("AdminOnly");
        group.MapPut("/{userId:guid}/premium", SetPremiumStatusAsync);
        group.MapPut("/{userId:guid}/active", SetActiveStatusAsync);

        return endpoints;
    }

    private static async Task<Results<Ok<IReadOnlyList<UserListItemResponse>>, ProblemHttpResult>> ListUsersAsync(
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListUsersAsync(cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status404NotFound);
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
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: StatusCodes.Status404NotFound);
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
        var command = new AssignRoleCommand(userId, request.Role);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        if (request.Role is SystemRoles.Admin or SystemRoles.Moderator)
        {
            var isAdmin = httpContext.User.IsInRole(SystemRoles.Admin);
            if (!isAdmin)
            {
                return TypedResults.Problem(
                    title: "users.role_not_allowed",
                    detail: "Only Admin can assign Admin or Moderator roles.",
                    statusCode: StatusCodes.Status403Forbidden);
            }
        }

        var result = await service.AssignRoleAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> SetPremiumStatusAsync(
        [FromRoute] Guid userId,
        [FromBody] SetPremiumStatusRequest request,
        [FromServices] IValidator<SetPremiumStatusCommand> validator,
        [FromServices] IIdentityService service,
        CancellationToken cancellationToken)
    {
        var command = new SetPremiumStatusCommand(userId, request.IsPremium);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SetPremiumStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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
        var command = new RevokeRoleCommand(userId, request.Role);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RevokeRoleAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SetUserActiveStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
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
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SendBulkEmailAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Accepted((string?)null);
    }

    public sealed record AssignRoleRequest(string Role);

    public sealed record RevokeRoleRequest(string Role);

    public sealed record SetPremiumStatusRequest(bool IsPremium);

    public sealed record SetActiveStatusRequest(bool IsActive);

    public sealed record SendBulkEmailRequest(string Audience, string Subject, string Body, IReadOnlyList<Guid>? UserIds);
}
