using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class AdminGenerationRenderControlService(
    TemplatesDbContext dbContext,
    IRenderGenerationWorkerClient renderClient,
    ITemplateGenerationRuntimeSettingsProvider runtimeSettingsProvider,
    IAdminAuditLog? adminAuditLog = null,
    ILogger<AdminGenerationRenderControlService>? logger = null)
    : IAdminGenerationRenderControlService
{
    internal const string StatusRequested = "requested";
    internal const string StatusDraining = "draining";
    internal const string StatusScaling = "scaling";
    internal const string StatusVerifying = "verifying";
    internal const string StatusCompleted = "completed";
    internal const string StatusFailed = "failed";
    internal const string StatusCancelled = "cancelled";

    private const int MinimumInstances = 1;
    private const int MaximumInstances = 8;
    private const int MinimumReasonLength = 3;
    private const int MaximumReasonLength = 500;
    private const int MaximumIdempotencyKeyLength = 256;

    private static readonly string[] ActiveStatuses =
    [
        StatusRequested,
        StatusDraining,
        StatusScaling,
        StatusVerifying
    ];

    private static readonly string[] DrainCleanupStatuses =
    [
        StatusFailed,
        StatusCancelled
    ];

    private static readonly DateTime NoFurtherAttemptUtc =
        DateTime.SpecifyKind(DateTime.MaxValue, DateTimeKind.Utc);

    public async Task<Result<AdminRenderScaleOperationResponse>> RequestScaleAsync(
        Guid actorUserId,
        string idempotencyKey,
        AdminRenderScaleCommand command,
        string correlationId,
        CancellationToken cancellationToken)
    {
        var normalizedKey = Normalize(idempotencyKey);
        var normalizedReason = Normalize(command.Reason);
        if (actorUserId == Guid.Empty
            || command.TargetInstances is < MinimumInstances or > MaximumInstances
            || command.ExpectedCurrentInstances is not (>= MinimumInstances and <= MaximumInstances))
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                command.TargetInstances is < MinimumInstances or > MaximumInstances
                    ? RenderGenerationWorkerErrors.InvalidTarget(MinimumInstances, MaximumInstances)
                    : AdminGenerationRenderControlErrors.InvalidRequest);
        }

        if (!command.Confirmed)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.ConfirmationRequired);
        }

        if (normalizedReason is null
            || normalizedReason.Length is < MinimumReasonLength or > MaximumReasonLength)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.ReasonRequired);
        }

        if (normalizedKey is null || normalizedKey.Length > MaximumIdempotencyKeyLength)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.IdempotencyKeyInvalid);
        }

        if (!renderClient.IsConfigured)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(RenderGenerationWorkerErrors.NotConfigured);
        }

        var requestHash = CreateRequestHash(command, normalizedReason);
        var existing = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.ActorUserId == actorUserId && item.IdempotencyKey == normalizedKey,
                cancellationToken);
        if (existing is not null)
        {
            return string.Equals(existing.RequestHash, requestHash, StringComparison.Ordinal)
                ? Result.Success(Map(existing))
                : Result.Failure<AdminRenderScaleOperationResponse>(
                    AdminGenerationRenderControlErrors.IdempotencyConflict);
        }

        var newClaimsPaused = await dbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .Where(item => item.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId)
            .Select(item => item.NewClaimsPaused)
            .SingleOrDefaultAsync(cancellationToken);
        if (newClaimsPaused)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.OperationInProgress);
        }

        var activeOperationExists = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .AnyAsync(item => ActiveStatuses.Contains(item.Status)
                || (DrainCleanupStatuses.Contains(item.Status)
                    && item.NextAttemptAtUtc < NoFurtherAttemptUtc),
                cancellationToken);
        if (activeOperationExists)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.OperationInProgress);
        }

        var now = DateTime.UtcNow;
        var operation = new TemplateRenderScaleOperation
        {
            Id = Guid.NewGuid(),
            ActorUserId = actorUserId,
            IdempotencyKey = normalizedKey,
            RequestHash = requestHash,
            Status = StatusRequested,
            InitialInstances = command.ExpectedCurrentInstances,
            TargetInstances = command.TargetInstances,
            LoopsPerInstance = runtimeSettingsProvider.Current.WorkerLoopsPerInstance,
            Reason = normalizedReason,
            CorrelationId = SafeLogValues.SanitizeText(correlationId, CorrelationContext.MaxLength),
            AttemptCount = 0,
            NextAttemptAtUtc = now,
            Version = 0,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateRenderScaleOperations.Add(operation);
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            CreateAuditEntry(
                operation,
                "admin.templates.render_scale.requested",
                oldValue: $"instances={command.ExpectedCurrentInstances?.ToString() ?? "unknown"}",
                newValue: $"instances={command.TargetInstances}",
                eventId: operation.Id,
                occurredAtUtc: now));

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            dbContext.ChangeTracker.Clear();
            existing = await dbContext.TemplateRenderScaleOperations
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.ActorUserId == actorUserId && item.IdempotencyKey == normalizedKey,
                    cancellationToken);
            if (existing is not null)
            {
                return string.Equals(existing.RequestHash, requestHash, StringComparison.Ordinal)
                    ? Result.Success(Map(existing))
                    : Result.Failure<AdminRenderScaleOperationResponse>(
                        AdminGenerationRenderControlErrors.IdempotencyConflict);
            }

            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.OperationInProgress);
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);
        return Result.Success(Map(operation));
    }

    public async Task<Result<AdminRenderScaleOperationResponse>> GetOperationAsync(
        Guid operationId,
        CancellationToken cancellationToken)
    {
        var operation = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == operationId, cancellationToken);
        return operation is null
            ? Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.OperationNotFound)
            : Result.Success(Map(operation));
    }

    public async Task<Result<AdminRenderScaleOperationResponse>> CancelOperationAsync(
        Guid actorUserId,
        Guid operationId,
        string reason,
        string correlationId,
        CancellationToken cancellationToken)
    {
        var normalizedReason = Normalize(reason);
        if (actorUserId == Guid.Empty
            || normalizedReason is null
            || normalizedReason.Length is < MinimumReasonLength or > MaximumReasonLength)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.ReasonRequired);
        }

        var operation = await dbContext.TemplateRenderScaleOperations
            .SingleOrDefaultAsync(item => item.Id == operationId, cancellationToken);
        if (operation is null)
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.OperationNotFound);
        }

        if (operation.Status is not (StatusRequested or StatusDraining))
        {
            return Result.Failure<AdminRenderScaleOperationResponse>(
                AdminGenerationRenderControlErrors.CancellationNotAllowed);
        }

        var now = DateTime.UtcNow;
        var previousStatus = operation.Status;
        operation.Status = StatusCancelled;
        operation.CancelledAtUtc = now;
        operation.UpdatedAtUtc = now;
        operation.Version++;
        operation.NextAttemptAtUtc = now;
        operation.ErrorCode = null;
        operation.ErrorMessage = null;
        operation.CorrelationId = SafeLogValues.SanitizeText(correlationId, CorrelationContext.MaxLength);
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            CreateAuditEntry(
                operation,
                "admin.templates.render_scale.cancelled",
                previousStatus,
                StatusCancelled,
                Guid.NewGuid(),
                now,
                $"requestReason={operation.Reason};cancelReason={normalizedReason}"));
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            var currentOperationExists = await dbContext.TemplateRenderScaleOperations
                .AsNoTracking()
                .AnyAsync(item => item.Id == operationId, cancellationToken);
            return Result.Failure<AdminRenderScaleOperationResponse>(
                currentOperationExists
                    ? AdminGenerationRenderControlErrors.CancellationNotAllowed
                    : AdminGenerationRenderControlErrors.OperationNotFound);
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);
        return Result.Success(Map(operation));
    }

    internal static AdminRenderScaleOperationResponse Map(TemplateRenderScaleOperation operation) => new(
        operation.Id,
        operation.Status,
        operation.InitialInstances,
        operation.TargetInstances,
        operation.LoopsPerInstance,
        operation.Reason,
        operation.CreatedAtUtc,
        operation.UpdatedAtUtc,
        operation.DrainStartedAtUtc,
        operation.ScaleRequestedAtUtc,
        operation.CompletedAtUtc,
        operation.CancelledAtUtc,
        operation.ErrorCode,
        operation.Status is StatusRequested or StatusDraining);

    internal static AdminAuditEntry CreateAuditEntry(
        TemplateRenderScaleOperation operation,
        string action,
        string? oldValue,
        string? newValue,
        Guid eventId,
        DateTime occurredAtUtc,
        string? details = null) => new(
            action,
            nameof(TemplateRenderScaleOperation),
            operation.Id.ToString("D"),
            oldValue,
            newValue,
            details ?? $"reason={operation.Reason};targetInstances={operation.TargetInstances}",
            null,
            eventId,
            operation.ActorUserId,
            operation.CorrelationId)
        {
            OccurredAtUtc = occurredAtUtc
        };

    private static string CreateRequestHash(AdminRenderScaleCommand command, string normalizedReason)
    {
        var payload = string.Join(
            '|',
            command.TargetInstances,
            command.ExpectedCurrentInstances?.ToString() ?? "null",
            normalizedReason);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload))).ToLowerInvariant();
    }

    private static string? Normalize(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }
}
