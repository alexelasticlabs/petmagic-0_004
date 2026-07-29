using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static async Task<Results<Ok<AdminTemplateGenerationControlResponse>, ProblemHttpResult>> GetGenerationControlAsync(
        [FromServices] ITemplateGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAsync(cancellationToken);
        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateGenerationControlResponse>, ProblemHttpResult>> UpdateGenerationControlPolicyAsync(
        HttpContext context,
        [FromBody] UpdateGenerationControlPolicyRequest? request,
        [FromServices] ITemplateGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (actorUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.UpdatePolicyAsync(
            new UpdateAdminTemplateGenerationControlPolicyCommand(
                actorUserId,
                context.Request.Headers["Idempotency-Key"].FirstOrDefault() ?? string.Empty,
                request?.ExpectedRevision ?? 0,
                request?.Reason ?? string.Empty,
                request?.AdmissionEnabled ?? false,
                request?.ConfirmedFalConcurrencyLimit ?? 0,
                request?.ReservedHeadroom ?? 0,
                request?.ApplicationHardCeiling ?? 0),
            cancellationToken);
        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateGenerationControlResponse>, ProblemHttpResult>> RefreshGenerationControlProviderAsync(
        [FromServices] ITemplateGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var result = await service.RefreshProviderAsync(cancellationToken);
        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateProviderAttemptResolutionResponse>, ProblemHttpResult>> ResolveGenerationControlProviderAttemptAsync(
        HttpContext context,
        Guid attemptId,
        [FromBody] ResolveGenerationControlProviderAttemptRequest? request,
        [FromServices] ITemplateGenerationControlService service,
        CancellationToken cancellationToken)
    {
        var (actorUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToAdminTemplateProblem(subjectError);
        }

        var result = await service.ResolveProviderAttemptAsync(
            new ResolveAdminTemplateProviderAttemptCommand(
                actorUserId,
                attemptId,
                context.Request.Headers["Idempotency-Key"].FirstOrDefault() ?? string.Empty,
                request?.ExpectedAttemptVersion ?? -1,
                request?.Resolution ?? string.Empty,
                request?.Reason ?? string.Empty,
                request?.EvidenceReference ?? string.Empty,
                request?.ProviderRequestId,
                request?.ProviderStatusUrl,
                request?.ProviderResponseUrl,
                request?.ProviderCancelUrl),
            cancellationToken);
        return result.IsFailure
            ? ToAdminTemplateProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private sealed record UpdateGenerationControlPolicyRequest(
        long ExpectedRevision,
        string Reason,
        bool AdmissionEnabled,
        int ConfirmedFalConcurrencyLimit,
        int ReservedHeadroom,
        int ApplicationHardCeiling);

    private sealed record ResolveGenerationControlProviderAttemptRequest(
        long ExpectedAttemptVersion,
        string Resolution,
        string Reason,
        string EvidenceReference,
        string? ProviderRequestId,
        string? ProviderStatusUrl,
        string? ProviderResponseUrl,
        string? ProviderCancelUrl);
}
