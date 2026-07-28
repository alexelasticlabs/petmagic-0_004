using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static async Task<Results<Ok<AdminGenerationControlResponse>, ProblemHttpResult>> GetGenerationControlAsync(
        HttpContext context,
        [FromServices] IAdminGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.GetAsync(adminUserId, cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminGenerationControlResponse>, ProblemHttpResult>> UpdateGenerationControlAsync(
        HttpContext context,
        [FromBody] UpdateGenerationControlRequest? request,
        [FromServices] IAdminGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        request ??= UpdateGenerationControlRequest.Empty;
        var result = await service.UpdateAsync(
            new UpdateAdminGenerationControlCommand(
                request.ExpectedVersion,
                request.GlobalMaxConcurrent,
                request.ImageMaxConcurrent,
                request.ImageProtectedConcurrent,
                request.VideoGuaranteedConcurrent,
                request.VideoMaxConcurrent,
                request.VideoBorrowMaxConcurrent,
                request.WorkerLoopsPerInstance,
                request.FalConfiguredConcurrency,
                request.FalReservedConcurrency,
                request.FalBalanceLowThresholdUsd,
                request.FalBalanceCriticalThresholdUsd,
                request.Reason ?? string.Empty,
                adminUserId,
                ResolveModerationActorRole(context),
                CorrelationContext.ResolveOrCreate()),
            cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminGenerationControlResponse>, ProblemHttpResult>> RefreshGenerationProviderAsync(
        HttpContext context,
        [FromServices] IAdminGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.RefreshProviderAsync(adminUserId, cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminGenerationOperationalAlertResponse>, ProblemHttpResult>> AcknowledgeGenerationAlertAsync(
        HttpContext context,
        Guid alertId,
        [FromServices] IAdminGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.AcknowledgeAlertAsync(alertId, adminUserId, cancellationToken);
        return result.IsFailure ? ToAdminTemplateProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    public sealed record UpdateGenerationControlRequest(
        long ExpectedVersion,
        int GlobalMaxConcurrent,
        int ImageMaxConcurrent,
        int ImageProtectedConcurrent,
        int VideoGuaranteedConcurrent,
        int VideoMaxConcurrent,
        int VideoBorrowMaxConcurrent,
        int WorkerLoopsPerInstance,
        int FalConfiguredConcurrency,
        int FalReservedConcurrency,
        decimal FalBalanceLowThresholdUsd,
        decimal FalBalanceCriticalThresholdUsd,
        string? Reason)
    {
        internal static UpdateGenerationControlRequest Empty { get; } = new(
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, null);
    }
}
