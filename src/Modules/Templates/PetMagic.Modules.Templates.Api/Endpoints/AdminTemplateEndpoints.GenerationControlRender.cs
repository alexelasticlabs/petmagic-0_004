using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static async Task<IResult> RequestGenerationWorkerScaleAsync(
        HttpContext context,
        [FromBody] AdminRenderScaleRequest? request,
        [FromServices] IAdminGenerationRenderControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var idempotencyValues = context.Request.Headers["Idempotency-Key"];
        var idempotencyKey = idempotencyValues.Count == 1
            ? idempotencyValues[0] ?? string.Empty
            : string.Empty;
        request ??= AdminRenderScaleRequest.Empty;
        var result = await service.RequestScaleAsync(
            adminUserId,
            idempotencyKey,
            new AdminRenderScaleCommand(
                request.TargetInstances,
                request.ExpectedCurrentInstances,
                request.Reason ?? string.Empty,
                request.Confirmed),
            CorrelationContext.ResolveOrCreate(),
            cancellationToken);

        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Accepted(
                $"/api/admin/templates/generation-control/render/operations/{result.Value.OperationId:D}",
                result.Value);
    }

    private static async Task<IResult> GetGenerationWorkerScaleOperationAsync(
        Guid operationId,
        [FromServices] IAdminGenerationRenderControlService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetOperationAsync(operationId, cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<IResult> CancelGenerationWorkerScaleOperationAsync(
        HttpContext context,
        Guid operationId,
        [FromServices] IAdminGenerationRenderControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.CancelOperationAsync(
            adminUserId,
            operationId,
            "cancelled_by_admin",
            CorrelationContext.ResolveOrCreate(),
            cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    public sealed record AdminRenderScaleRequest(
        int TargetInstances,
        int? ExpectedCurrentInstances,
        string? Reason,
        bool Confirmed)
    {
        internal static AdminRenderScaleRequest Empty { get; } = new(0, null, null, false);
    }
}
