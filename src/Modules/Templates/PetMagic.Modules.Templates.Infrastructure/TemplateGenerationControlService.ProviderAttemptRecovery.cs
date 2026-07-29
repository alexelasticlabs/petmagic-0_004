using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationControlService
{
    private const int ProviderAttemptRecoveryDefaultTake = 50;
    private const int ProviderAttemptRecoveryMaxTake = 100;
    private const string ProviderAttemptRecoveryEvidenceNeeded =
        "correlated_accepted_or_confirmed_not_found";

    public async Task<Result<AdminTemplateProviderAttemptRecoveryPageResponse>> ListProviderAttemptRecoveryAsync(
        AdminTemplateProviderAttemptRecoveryQuery query,
        CancellationToken cancellationToken)
    {
        var skip = query.Skip ?? 0;
        var take = query.Take ?? ProviderAttemptRecoveryDefaultTake;
        if (skip < 0 || take <= 0 || take > ProviderAttemptRecoveryMaxTake)
        {
            return Result.Failure<AdminTemplateProviderAttemptRecoveryPageResponse>(
                TemplatesErrors.ProviderAttemptRecoveryQueryInvalid);
        }

        var unresolved = dbContext.TemplateGenerationProviderAttempts
            .AsNoTracking()
            .Where(attempt =>
                attempt.State == TemplateGenerationProviderAttemptState.SubmissionUnknown
                && attempt.Provider == "fal"
                && attempt.NextPollAtUtc == null);
        var totalCount = await unresolved.CountAsync(cancellationToken);
        var rows = await unresolved
            .OrderBy(attempt => attempt.CreatedAtUtc)
            .ThenBy(attempt => attempt.Id)
            .Skip(skip)
            .Take(take)
            .Select(attempt => new ProviderAttemptRecoveryRow(
                attempt.Id,
                attempt.GenerationJobId,
                attempt.Stage,
                attempt.Ordinal,
                attempt.State,
                attempt.Version,
                attempt.ProviderRequestId,
                attempt.CreatedAtUtc,
                attempt.UpdatedAtUtc,
                attempt.SubmittedAtUtc,
                attempt.SubmissionDeadlineAtUtc,
                attempt.ProcessingDeadlineAtUtc,
                attempt.ReconciliationDeadlineAtUtc,
                attempt.LastErrorCode))
            .ToArrayAsync(cancellationToken);

        var items = rows
            .Select(row => new AdminTemplateProviderAttemptRecoveryItemResponse(
                row.AttemptId,
                row.GenerationId,
                ToSnakeCase(row.Stage.ToString()),
                row.Ordinal,
                ToSnakeCase(row.State.ToString()),
                row.AttemptVersion,
                row.ProviderRequestId,
                row.CreatedAtUtc,
                row.UpdatedAtUtc,
                row.SubmittedAtUtc,
                row.SubmissionDeadlineAtUtc,
                row.ProcessingDeadlineAtUtc,
                row.ReconciliationDeadlineAtUtc,
                AdminFailureMessageSanitizer.SanitizeCode(row.ErrorCode),
                ProviderAttemptRecoveryEvidenceNeeded))
            .ToArray();

        return Result.Success(new AdminTemplateProviderAttemptRecoveryPageResponse(
            items,
            totalCount,
            skip,
            take,
            skip < totalCount - items.Length,
            DateTime.UtcNow));
    }

    private sealed record ProviderAttemptRecoveryRow(
        Guid AttemptId,
        Guid GenerationId,
        TemplateGenerationProviderAttemptStage Stage,
        int Ordinal,
        TemplateGenerationProviderAttemptState State,
        long AttemptVersion,
        string? ProviderRequestId,
        DateTime CreatedAtUtc,
        DateTime UpdatedAtUtc,
        DateTime? SubmittedAtUtc,
        DateTime SubmissionDeadlineAtUtc,
        DateTime ProcessingDeadlineAtUtc,
        DateTime ReconciliationDeadlineAtUtc,
        string? ErrorCode);
}
