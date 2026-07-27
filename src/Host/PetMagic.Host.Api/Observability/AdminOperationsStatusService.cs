using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Host.Api.Observability;

public interface IAdminOperationsStatusService
{
    Task<AdminOperationsStatusDto> GetAsync(CancellationToken cancellationToken = default);
}

public sealed class AdminOperationsStatusService(
    IServiceScopeFactory scopeFactory,
    IMemoryCache memoryCache,
    ILogger<AdminOperationsStatusService> logger) : IAdminOperationsStatusService
{
    public const int CacheDurationSeconds = 15;
    public const int StaleAfterSeconds = 45;

    private const string CacheKey = "admin:operations-status:v1";
    private const string AuditOutboxKind = "admin_audit";
    private static readonly TimeSpan ExecutionTimeout = TimeSpan.FromSeconds(3);
    private static readonly SemaphoreSlim RefreshLock = new(1, 1);

    public async Task<AdminOperationsStatusDto> GetAsync(CancellationToken cancellationToken = default)
    {
        if (memoryCache.TryGetValue<AdminOperationsStatusDto>(CacheKey, out var cached)
            && cached is not null)
        {
            return cached;
        }

        await RefreshLock.WaitAsync(cancellationToken);
        try
        {
            if (memoryCache.TryGetValue<AdminOperationsStatusDto>(CacheKey, out cached)
                && cached is not null)
            {
                return cached;
            }

            using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeoutSource.CancelAfter(ExecutionTimeout);
            var response = await LoadAsync(timeoutSource.Token);
            memoryCache.Set(CacheKey, response, TimeSpan.FromSeconds(CacheDurationSeconds));
            return response;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                "Admin operations status exceeded the bounded execution window. TimeoutMilliseconds={TimeoutMilliseconds}",
                ExecutionTimeout.TotalMilliseconds);
            return BuildResponse(EmptySnapshot(["identity", "economy", "templates", "support"]), DateTime.UtcNow);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        finally
        {
            RefreshLock.Release();
        }
    }

    public static AdminOperationsStatusDto BuildResponse(
        AdminOperationsSnapshot snapshot,
        DateTime generatedAtUtc)
    {
        ArgumentNullException.ThrowIfNull(snapshot);

        var email = BuildQueueStatus(
            snapshot.EmailBacklogCount,
            snapshot.EmailDeadLetterCount,
            snapshot.OldestEmailQueuedAtUtc,
            snapshot.LastEmailSentAtUtc,
            generatedAtUtc,
            snapshot.UnavailableSources.Contains("identity", StringComparer.Ordinal));
        var audit = BuildQueueStatus(
            snapshot.AuditBacklogCount,
            snapshot.AuditDeadLetterCount,
            snapshot.OldestAuditQueuedAtUtc,
            snapshot.LastAuditSentAtUtc,
            generatedAtUtc,
            snapshot.UnavailableSources.Any(source => source is "economy" or "templates" or "support"));
        var push = BuildQueueStatus(
            snapshot.PushBacklogCount,
            snapshot.PushDeadLetterCount,
            snapshot.OldestPushQueuedAtUtc,
            snapshot.LastPushSentAtUtc,
            generatedAtUtc,
            snapshot.UnavailableSources.Any(source => source is "economy" or "templates" or "support"));
        var generationAge = AgeSeconds(generatedAtUtc, snapshot.OldestGenerationQueuedAtUtc);
        var generation = new AdminGenerationOperationsStatusDto(
            snapshot.UnavailableSources.Contains("templates", StringComparer.Ordinal)
                ? "unknown"
                : QueueStatus(snapshot.GenerationQueueDepth, 0, generationAge),
            snapshot.GenerationQueueDepth,
            generationAge);
        var economy = new AdminEconomyOperationsStatusDto(
            snapshot.UnavailableSources.Contains("economy", StringComparer.Ordinal)
                ? "unknown"
                : snapshot.CriticalEconomyIncidentCount > 0
                    ? "unhealthy"
                    : snapshot.OpenEconomyIncidentCount > 0 ? "degraded" : "healthy",
            snapshot.OpenEconomyIncidentCount,
            snapshot.CriticalEconomyIncidentCount);
        var lastSuccessfulRunAtUtc = MaxTimestamp(
            snapshot.LastEmailSentAtUtc,
            snapshot.LastAuditSentAtUtc,
            snapshot.LastPushSentAtUtc,
            snapshot.LastGenerationCompletedAtUtc);
        var heartbeatAge = AgeSeconds(generatedAtUtc, snapshot.GenerationWorkerHeartbeatAtUtc);
        var workers = new AdminWorkerOperationsStatusDto(
            snapshot.UnavailableSources.Contains("templates", StringComparer.Ordinal)
                ? "unknown"
                : heartbeatAge is null or > 120 ? "unhealthy" : heartbeatAge is > 75 ? "degraded" : "healthy",
            lastSuccessfulRunAtUtc,
            snapshot.GenerationWorkerHeartbeatAtUtc,
            heartbeatAge);
        var statuses = new[] { email.Status, audit.Status, push.Status, generation.Status, economy.Status, workers.Status };
        var overallStatus = statuses.Contains("unhealthy", StringComparer.Ordinal)
            ? "unhealthy"
            : statuses.Any(status => status is "degraded" or "unknown") ? "degraded" : "healthy";

        return new AdminOperationsStatusDto(
            overallStatus,
            DateTime.SpecifyKind(generatedAtUtc, DateTimeKind.Utc),
            CacheDurationSeconds,
            StaleAfterSeconds,
            email,
            audit,
            push,
            generation,
            economy,
            workers,
            snapshot.UnavailableSources
                .Distinct(StringComparer.Ordinal)
                .OrderBy(source => source, StringComparer.Ordinal)
                .Take(4)
                .ToArray());
    }

    private async Task<AdminOperationsStatusDto> LoadAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var identityTask = CaptureAsync(
            "identity",
            () => ReadIdentityAsync(scope.ServiceProvider.GetRequiredService<IdentityDbContext>(), cancellationToken),
            cancellationToken);
        var economyTask = CaptureAsync(
            "economy",
            () => ReadEconomyAsync(scope.ServiceProvider.GetRequiredService<EconomyDbContext>(), cancellationToken),
            cancellationToken);
        var templatesTask = CaptureAsync(
            "templates",
            () => ReadTemplatesAsync(scope.ServiceProvider.GetRequiredService<TemplatesDbContext>(), cancellationToken),
            cancellationToken);
        var supportTask = CaptureAsync(
            "support",
            () => ReadSupportAsync(scope.ServiceProvider.GetRequiredService<SupportChatDbContext>(), cancellationToken),
            cancellationToken);

        await Task.WhenAll(identityTask, economyTask, templatesTask, supportTask);

        var identity = await identityTask;
        var economy = await economyTask;
        var templates = await templatesTask;
        var support = await supportTask;
        var unavailableSources = new List<string>(4);
        if (!identity.IsAvailable) unavailableSources.Add(identity.Source);
        if (!economy.IsAvailable) unavailableSources.Add(economy.Source);
        if (!templates.IsAvailable) unavailableSources.Add(templates.Source);
        if (!support.IsAvailable) unavailableSources.Add(support.Source);
        var outboxes = new[] { economy.Value?.Outbox, templates.Value?.Outbox, support.Value?.Outbox }
            .Where(snapshot => snapshot is not null)
            .Cast<OutboxSnapshot>()
            .ToArray();

        var snapshot = new AdminOperationsSnapshot(
            identity.Value?.BacklogCount ?? 0,
            identity.Value?.DeadLetterCount ?? 0,
            identity.Value?.OldestQueuedAtUtc,
            identity.Value?.LastSentAtUtc,
            outboxes.Sum(item => item.AuditBacklogCount),
            outboxes.Sum(item => item.AuditDeadLetterCount),
            MinTimestamp(outboxes.Select(item => item.OldestAuditQueuedAtUtc)),
            MaxTimestamp(outboxes.Select(item => item.LastAuditSentAtUtc)),
            outboxes.Sum(item => item.PushBacklogCount),
            outboxes.Sum(item => item.PushDeadLetterCount),
            MinTimestamp(outboxes.Select(item => item.OldestPushQueuedAtUtc)),
            MaxTimestamp(outboxes.Select(item => item.LastPushSentAtUtc)),
            templates.Value?.GenerationQueueDepth ?? 0,
            templates.Value?.OldestGenerationQueuedAtUtc,
            templates.Value?.LastGenerationCompletedAtUtc,
            economy.Value?.OpenIncidentCount ?? 0,
            economy.Value?.CriticalIncidentCount ?? 0,
            templates.Value?.GenerationWorkerHeartbeatAtUtc,
            unavailableSources);

        return BuildResponse(snapshot, DateTime.UtcNow);
    }

    private async Task<SourceResult<T>> CaptureAsync<T>(
        string source,
        Func<Task<T>> read,
        CancellationToken cancellationToken)
    {
        try
        {
            return new SourceResult<T>(source, await read(), true);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Admin operations source is unavailable. Source={Source} ExceptionType={ExceptionType}",
                source,
                exception.GetType().Name);
            return new SourceResult<T>(source, default, false);
        }
    }

    private static async Task<IdentitySnapshot> ReadIdentityAsync(
        IdentityDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var backlogQuery = dbContext.EmailDispatchJobs
            .AsNoTracking()
            .Where(job => job.Status == EmailDispatchStatus.Queued || job.Status == EmailDispatchStatus.Processing);
        var backlogCount = await backlogQuery.CountAsync(cancellationToken);
        var oldestQueuedAtUtc = await backlogQuery
            .Select(job => (DateTime?)job.QueuedAtUtc)
            .MinAsync(cancellationToken);
        var deadLetterCount = await dbContext.EmailDispatchJobs
            .AsNoTracking()
            .CountAsync(job => job.Status == EmailDispatchStatus.Failed, cancellationToken);
        var lastSentAtUtc = await dbContext.EmailDispatchJobs
            .AsNoTracking()
            .Where(job => job.Status == EmailDispatchStatus.Sent)
            .Select(job => job.SentAtUtc)
            .MaxAsync(cancellationToken);

        return new IdentitySnapshot(backlogCount, deadLetterCount, oldestQueuedAtUtc, lastSentAtUtc);
    }

    private static async Task<EconomySnapshot> ReadEconomyAsync(
        EconomyDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var outbox = await ReadOutboxAsync(dbContext.PushOutboxMessages.AsNoTracking(), cancellationToken);
        var openIncidents = dbContext.EconomyIncidents
            .AsNoTracking()
            .Where(incident => incident.Status == "Open");
        var openIncidentCount = await openIncidents.CountAsync(cancellationToken);
        var criticalIncidentCount = await openIncidents
            .CountAsync(incident => incident.Severity == "Critical", cancellationToken);

        return new EconomySnapshot(outbox, openIncidentCount, criticalIncidentCount);
    }

    private static async Task<TemplatesSnapshot> ReadTemplatesAsync(
        TemplatesDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var outbox = await ReadOutboxAsync(dbContext.PushOutboxMessages.AsNoTracking(), cancellationToken);
        var activeJobs = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job => job.Status != TemplateGenerationStatus.Completed
                && job.Status != TemplateGenerationStatus.Failed
                && job.Status != TemplateGenerationStatus.Cancelled);
        var generationQueueDepth = await activeJobs.CountAsync(cancellationToken);
        var oldestGenerationQueuedAtUtc = await activeJobs
            .Select(job => (DateTime?)job.QueuedAtUtc)
            .MinAsync(cancellationToken);
        var lastGenerationCompletedAtUtc = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job => job.Status == TemplateGenerationStatus.Completed)
            .Select(job => job.CompletedAtUtc)
            .MaxAsync(cancellationToken);
        var generationWorkerHeartbeatAtUtc = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(fingerprint => fingerprint.Component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            .Select(fingerprint => (DateTime?)fingerprint.LastSeenAtUtc)
            .MaxAsync(cancellationToken);

        return new TemplatesSnapshot(
            outbox,
            generationQueueDepth,
            oldestGenerationQueuedAtUtc,
            lastGenerationCompletedAtUtc,
            generationWorkerHeartbeatAtUtc);
    }

    private static async Task<SupportSnapshot> ReadSupportAsync(
        SupportChatDbContext dbContext,
        CancellationToken cancellationToken)
    {
        return new SupportSnapshot(
            await ReadOutboxAsync(dbContext.PushOutboxMessages.AsNoTracking(), cancellationToken));
    }

    private static async Task<OutboxSnapshot> ReadOutboxAsync(
        IQueryable<PushOutboxMessage> query,
        CancellationToken cancellationToken)
    {
        var auditPending = query.Where(message => message.Kind == AuditOutboxKind
            && (message.Status == PushOutboxStatus.Queued || message.Status == PushOutboxStatus.Processing));
        var pushPending = query.Where(message => message.Kind != AuditOutboxKind
            && (message.Status == PushOutboxStatus.Queued || message.Status == PushOutboxStatus.Processing));

        return new OutboxSnapshot(
            await auditPending.CountAsync(cancellationToken),
            await query.CountAsync(
                message => message.Kind == AuditOutboxKind && message.Status == PushOutboxStatus.DeadLetter,
                cancellationToken),
            await auditPending.Select(message => (DateTime?)message.CreatedAtUtc).MinAsync(cancellationToken),
            await query
                .Where(message => message.Kind == AuditOutboxKind && message.Status == PushOutboxStatus.Sent)
                .Select(message => message.SentAtUtc)
                .MaxAsync(cancellationToken),
            await pushPending.CountAsync(cancellationToken),
            await query.CountAsync(
                message => message.Kind != AuditOutboxKind && message.Status == PushOutboxStatus.DeadLetter,
                cancellationToken),
            await pushPending.Select(message => (DateTime?)message.CreatedAtUtc).MinAsync(cancellationToken),
            await query
                .Where(message => message.Kind != AuditOutboxKind && message.Status == PushOutboxStatus.Sent)
                .Select(message => message.SentAtUtc)
                .MaxAsync(cancellationToken));
    }

    private static AdminOperationsQueueStatusDto BuildQueueStatus(
        int backlogCount,
        int deadLetterCount,
        DateTime? oldestQueuedAtUtc,
        DateTime? lastSuccessfulRunAtUtc,
        DateTime nowUtc,
        bool unavailable)
    {
        var oldestAge = AgeSeconds(nowUtc, oldestQueuedAtUtc);
        return new AdminOperationsQueueStatusDto(
            unavailable ? "unknown" : QueueStatus(backlogCount, deadLetterCount, oldestAge),
            backlogCount,
            deadLetterCount,
            oldestAge,
            lastSuccessfulRunAtUtc);
    }

    private static string QueueStatus(int backlogCount, int deadLetterCount, long? oldestAgeSeconds)
    {
        if (deadLetterCount > 0 || oldestAgeSeconds is > 900)
        {
            return "unhealthy";
        }

        return backlogCount > 100 || oldestAgeSeconds is > 300 ? "degraded" : "healthy";
    }

    private static long? AgeSeconds(DateTime nowUtc, DateTime? timestampUtc)
    {
        return timestampUtc is null
            ? null
            : Math.Max(0, (long)(nowUtc - timestampUtc.Value).TotalSeconds);
    }

    private static DateTime? MinTimestamp(IEnumerable<DateTime?> values)
    {
        var timestamps = values.Where(value => value.HasValue).Select(value => value!.Value).ToArray();
        return timestamps.Length == 0 ? null : timestamps.Min();
    }

    private static DateTime? MaxTimestamp(IEnumerable<DateTime?> values)
    {
        var timestamps = values.Where(value => value.HasValue).Select(value => value!.Value).ToArray();
        return timestamps.Length == 0 ? null : timestamps.Max();
    }

    private static DateTime? MaxTimestamp(params DateTime?[] values) => MaxTimestamp(values.AsEnumerable());

    private static AdminOperationsSnapshot EmptySnapshot(IReadOnlyList<string> unavailableSources) =>
        new(0, 0, null, null, 0, 0, null, null, 0, 0, null, null, 0, null, null, 0, 0, null, unavailableSources);

    private sealed record SourceResult<T>(string Source, T? Value, bool IsAvailable);
    private sealed record IdentitySnapshot(int BacklogCount, int DeadLetterCount, DateTime? OldestQueuedAtUtc, DateTime? LastSentAtUtc);
    private sealed record EconomySnapshot(OutboxSnapshot Outbox, int OpenIncidentCount, int CriticalIncidentCount);
    private sealed record TemplatesSnapshot(
        OutboxSnapshot Outbox,
        int GenerationQueueDepth,
        DateTime? OldestGenerationQueuedAtUtc,
        DateTime? LastGenerationCompletedAtUtc,
        DateTime? GenerationWorkerHeartbeatAtUtc);
    private sealed record SupportSnapshot(OutboxSnapshot Outbox);
    private sealed record OutboxSnapshot(
        int AuditBacklogCount,
        int AuditDeadLetterCount,
        DateTime? OldestAuditQueuedAtUtc,
        DateTime? LastAuditSentAtUtc,
        int PushBacklogCount,
        int PushDeadLetterCount,
        DateTime? OldestPushQueuedAtUtc,
        DateTime? LastPushSentAtUtc);
}
