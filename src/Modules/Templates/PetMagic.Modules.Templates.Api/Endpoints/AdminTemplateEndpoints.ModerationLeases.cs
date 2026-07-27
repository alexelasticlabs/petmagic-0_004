using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static async Task<Results<Ok<AdminModerationQueueItemResponse>, ProblemHttpResult>> ClaimModerationItemAsync(
        HttpContext context,
        Guid eventId,
        [FromBody] AdminModerationClaimRequest? request,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (actorUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.ClaimAdminModerationItemAsync(
            new AdminModerationClaimCommand(
                eventId,
                actorUserId,
                ResolveModerationActorRole(context),
                request?.ExpectedVersion,
                request?.LeaseMinutes),
            cancellationToken);

        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminModerationQueueItemResponse>, ProblemHttpResult>> ReleaseModerationItemAsync(
        HttpContext context,
        Guid eventId,
        [FromBody] AdminModerationReleaseRequest? request,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (actorUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.ReleaseAdminModerationItemAsync(
            new AdminModerationReleaseCommand(
                eventId,
                actorUserId,
                ResolveModerationActorRole(context),
                request?.ExpectedVersion,
                request?.Reason ?? string.Empty,
                context.User.IsInRole("Admin")),
            cancellationToken);

        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminModerationQueueItemResponse>, ProblemHttpResult>> HandoffModerationItemAsync(
        HttpContext context,
        Guid eventId,
        [FromBody] AdminModerationHandoffRequest? request,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var (actorUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.HandoffAdminModerationItemAsync(
            new AdminModerationHandoffCommand(
                eventId,
                actorUserId,
                ResolveModerationActorRole(context),
                request?.AssigneeUserId ?? Guid.Empty,
                request?.ExpectedVersion,
                request?.Reason ?? string.Empty,
                request?.LeaseMinutes),
            cancellationToken);

        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static string ResolveModerationActorRole(HttpContext context) =>
        context.User.IsInRole("Admin") ? "Admin" : "Moderator";

    public sealed record AdminModerationClaimRequest(
        long? ExpectedVersion,
        int? LeaseMinutes = null);

    public sealed record AdminModerationReleaseRequest(
        long? ExpectedVersion,
        string Reason);

    public sealed record AdminModerationHandoffRequest(
        Guid AssigneeUserId,
        long? ExpectedVersion,
        string Reason,
        int? LeaseMinutes = null);
}
