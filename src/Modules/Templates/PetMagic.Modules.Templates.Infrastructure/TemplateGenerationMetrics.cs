using System.Diagnostics.Metrics;
using System.Threading;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationMetrics
{
    public const string MeterName = "PetMagic.Modules.Templates";

    private static readonly Meter Meter = new(MeterName);

    private static readonly UpDownCounter<long> QueuedJobs = Meter.CreateUpDownCounter<long>(
        "generation_jobs_queued",
        unit: "{job}",
        description: "Delta count of template generation jobs currently queued.");

    private static readonly UpDownCounter<long> ProcessingJobs = Meter.CreateUpDownCounter<long>(
        "generation_jobs_processing",
        unit: "{job}",
        description: "Delta count of template generation jobs currently processing.");

    private static readonly Counter<long> FailedJobsTotal = Meter.CreateCounter<long>(
        "generation_jobs_failed_total",
        unit: "{job}",
        description: "Number of template generation jobs that reached Failed status.");

    private static readonly Counter<long> LifecycleEventsTotal = Meter.CreateCounter<long>(
        "generation_lifecycle_events_total",
        unit: "{event}",
        description: "Number of template generation lifecycle events by stage.");

    private static readonly Counter<long> ExhaustedJobsTotal = Meter.CreateCounter<long>(
        "generation_jobs_exhausted_total",
        unit: "{job}",
        description: "Number of template generation jobs that exhausted all retry attempts.");

    private static readonly Histogram<double> GenerationDurationSeconds = Meter.CreateHistogram<double>(
        "generation_duration_seconds",
        unit: "s",
        description: "Duration of terminal template generation jobs from queue/start to completion.");

    private static readonly Counter<long> AiProviderErrorsTotal = Meter.CreateCounter<long>(
        "ai_provider_errors_total",
        unit: "{error}",
        description: "Number of template AI provider failures.");

    private static readonly Counter<long> QueuedJobsWithoutChargeTotal = Meter.CreateCounter<long>(
        "generation_jobs_queued_without_charge_total",
        unit: "{job}",
        description: "Number of queued template generation jobs found without a charge.");

    private static readonly Counter<long> RefundedJobsTotal = Meter.CreateCounter<long>(
        "generation_jobs_refunded_total",
        unit: "{job}",
        description: "Number of template generation jobs refunded.");

    private static readonly Counter<long> DuplicateRefundAttemptsTotal = Meter.CreateCounter<long>(
        "generation_duplicate_refund_attempts_total",
        unit: "{attempt}",
        description: "Number of duplicate template generation refund attempts.");

    private static readonly Counter<long> FalTimeoutsTotal = Meter.CreateCounter<long>(
        "generation_fal_timeouts_total",
        unit: "{timeout}",
        description: "Number of fal queue timeouts by media type and stage.");

    private static readonly Counter<long> SseDeliveryFailuresTotal = Meter.CreateCounter<long>(
        "generation_sse_delivery_failures_total",
        unit: "{failure}",
        description: "Number of template generation SSE delivery or polling failures.");

    private static readonly Histogram<long> QueueDepth = Meter.CreateHistogram<long>(
        "generation_queue_depth",
        unit: "{job}",
        description: "Current count of claimable queued template generation jobs observed by the worker.");

    private static readonly Histogram<long> ActiveJobs = Meter.CreateHistogram<long>(
        "generation_active_jobs",
        unit: "{job}",
        description: "Current count of active processing template generation jobs by lane.");

    private static readonly Histogram<double> OldestQueuedJobAgeSeconds = Meter.CreateHistogram<double>(
        "generation_oldest_queued_job_age_seconds",
        unit: "s",
        description: "Observed age of the oldest claimable queued template generation job.");

    private static readonly Histogram<double> OldestProcessingJobAgeSeconds = Meter.CreateHistogram<double>(
        "generation_oldest_processing_job_age_seconds",
        unit: "s",
        description: "Observed age of the oldest processing template generation job.");

    private static readonly Histogram<double> QueueWaitSeconds = Meter.CreateHistogram<double>(
        "generation_queue_wait_seconds",
        unit: "s",
        description: "Observed time between queue entry and claim by media type and tier.");

    private static readonly Histogram<double> EtaAccuracyErrorSeconds = Meter.CreateHistogram<double>(
        "generation_eta_accuracy_error_seconds",
        unit: "s",
        description: "Absolute difference between queued ETA and actual completion time.");

    private static readonly Counter<long> RejectedJobsTotal = Meter.CreateCounter<long>(
        "generation_jobs_rejected_total",
        unit: "{job}",
        description: "Number of generation jobs rejected before charge by reason.");

    private static readonly Counter<long> CancelledJobsTotal = Meter.CreateCounter<long>(
        "generation_jobs_cancelled_total",
        unit: "{job}",
        description: "Number of generation jobs cancelled while queued.");

    private static readonly Counter<long> SchedulerClaimAttemptsTotal = Meter.CreateCounter<long>(
        "generation_scheduler_claim_attempts_total",
        unit: "{attempt}",
        description: "Scheduler claim attempts by media type and result.");

    private static readonly Counter<long> SchedulerNoSlotSkipsTotal = Meter.CreateCounter<long>(
        "generation_scheduler_no_slot_skips_total",
        unit: "{skip}",
        description: "Scheduler loops skipped because no global or media slot was available.");

    private static readonly Counter<long> SchedulerBorrowedVideoStartsTotal = Meter.CreateCounter<long>(
        "generation_scheduler_borrowed_video_starts_total",
        unit: "{job}",
        description: "Number of video jobs started using borrowed image/global capacity.");

    private static readonly Counter<long> SchedulerVideoBorrowDeniedTotal = Meter.CreateCounter<long>(
        "generation_scheduler_video_borrow_denied_total",
        unit: "{denial}",
        description: "Number of times video borrowing was denied by scheduler guardrails.");

    private static readonly Counter<long> SchedulerBorrowingCapViolationsTotal = Meter.CreateCounter<long>(
        "generation_scheduler_borrowing_cap_violations_total",
        unit: "{violation}",
        description: "Detected elastic lane borrowing cap violations.");

    private static readonly Counter<long> FalProviderRejectedDueToCapacityTotal = Meter.CreateCounter<long>(
        "fal_provider_rejected_due_to_capacity",
        unit: "{rejection}",
        description: "Number of generation requests rejected before charge because fal provider capacity or balance was unavailable.");

    private static readonly Counter<long> FalProviderSubmitFailuresTotal = Meter.CreateCounter<long>(
        "fal_provider_submit_failures",
        unit: "{failure}",
        description: "Number of fal provider submit failures.");

    private static readonly Counter<long> FalProviderRateLimitErrorsTotal = Meter.CreateCounter<long>(
        "fal_provider_rate_limit_errors",
        unit: "{error}",
        description: "Number of fal provider rate limit responses.");

    private static readonly Histogram<double> FalProviderQueueWaitSeconds = Meter.CreateHistogram<double>(
        "fal_provider_queue_wait_seconds",
        unit: "s",
        description: "Observed time a fal request has spent in provider queue before reaching IN_PROGRESS or completion.");

    private static long falConfiguredConcurrency;
    private static long falInflightRequests;
    private static long falBalanceLow;
    private static long falBalanceCritical;
    private static long falBalanceUsdScaled = long.MinValue;
    private static long activeImageNativeSlots;
    private static long activeVideoNativeSlots;
    private static long activeVideoBorrowedSlots;
    private static long imageProtectedCapacityAvailable;

    private static readonly ObservableGauge<long> FalProviderConfiguredConcurrency = Meter.CreateObservableGauge(
        "fal_provider_configured_concurrency",
        () => Volatile.Read(ref falConfiguredConcurrency),
        unit: "{request}",
        description: "Configured fal provider account concurrency limit.");

    private static readonly ObservableGauge<long> FalProviderInflightRequests = Meter.CreateObservableGauge(
        "fal_provider_inflight_requests",
        () => Volatile.Read(ref falInflightRequests),
        unit: "{request}",
        description: "Current count of PetMagic fal provider requests in flight.");

    private static readonly ObservableGauge<long> FalProviderBalanceLow = Meter.CreateObservableGauge(
        "fal_provider_balance_low",
        () => Volatile.Read(ref falBalanceLow),
        unit: "{state}",
        description: "Whether fal provider balance is below the configured low threshold.");

    private static readonly ObservableGauge<long> FalProviderBalanceCritical = Meter.CreateObservableGauge(
        "fal_provider_balance_critical",
        () => Volatile.Read(ref falBalanceCritical),
        unit: "{state}",
        description: "Whether fal provider balance is below the configured critical threshold.");

    private static readonly ObservableGauge<double> FalProviderBalanceUsd = Meter.CreateObservableGauge(
        "fal_provider_balance_usd",
        ObserveFalBalanceUsd,
        unit: "USD",
        description: "Current fal provider credit balance in USD, when account billing API is available.");

    private static readonly ObservableGauge<long> SchedulerActiveImageNativeSlots = Meter.CreateObservableGauge(
        "generation_scheduler_active_image_native_slots",
        () => Volatile.Read(ref activeImageNativeSlots),
        unit: "{slot}",
        description: "Current active image jobs counted against native image capacity.");

    private static readonly ObservableGauge<long> SchedulerActiveVideoNativeSlots = Meter.CreateObservableGauge(
        "generation_scheduler_active_video_native_slots",
        () => Volatile.Read(ref activeVideoNativeSlots),
        unit: "{slot}",
        description: "Current active video jobs counted against reserved/native video capacity.");

    private static readonly ObservableGauge<long> SchedulerActiveVideoBorrowedSlots = Meter.CreateObservableGauge(
        "generation_scheduler_active_video_borrowed_slots",
        () => Volatile.Read(ref activeVideoBorrowedSlots),
        unit: "{slot}",
        description: "Current active video jobs estimated to be using borrowed capacity.");

    private static readonly ObservableGauge<long> SchedulerImageProtectedCapacityAvailable = Meter.CreateObservableGauge(
        "generation_scheduler_image_protected_capacity_available",
        () => Volatile.Read(ref imageProtectedCapacityAvailable),
        unit: "{slot}",
        description: "Current image protected capacity available while elastic borrowing is evaluated.");

    public static void RecordJobQueued(TemplateGenerationJob job)
    {
        QueuedJobs.Add(1, JobTags(job));
        RecordLifecycleEvent(job, "start", "queued", null);
    }

    public static void RecordJobClaimed(TemplateGenerationJob job)
    {
        var tags = JobTags(job);
        QueuedJobs.Add(-1, tags);
        ProcessingJobs.Add(1, tags);
        QueueWaitSeconds.Record(Math.Max(0, (DateTime.UtcNow - job.QueuedAtUtc).TotalSeconds), JobTags(job));
        RecordLifecycleEvent(job, "stage", "processing", null);
    }

    public static void RecordJobRequeued(TemplateGenerationJob job)
    {
        var tags = JobTags(job);
        ProcessingJobs.Add(-1, tags);
        QueuedJobs.Add(1, tags);
        RecordLifecycleEvent(job, "stage", "requeued", null);
    }

    public static void RecordJobCompleted(TemplateGenerationJob job)
    {
        ProcessingJobs.Add(-1, JobTags(job));
        RecordLifecycleEvent(job, "end", "completed", null);
        RecordGenerationDuration(job, "completed", null);
        RecordEtaAccuracy(job);
    }

    public static void RecordJobFailed(TemplateGenerationJob job, TemplateGenerationStatus previousStatus, string failureCode)
    {
        if (previousStatus == TemplateGenerationStatus.Queued)
        {
            QueuedJobs.Add(-1, JobTags(job));
        }
        else if (previousStatus == TemplateGenerationStatus.Processing)
        {
            ProcessingJobs.Add(-1, JobTags(job));
        }

        FailedJobsTotal.Add(
            1,
            TerminalJobTags(job, "failed", failureCode));
        RecordLifecycleEvent(job, "fail", "failed", failureCode);
        RecordGenerationDuration(job, "failed", failureCode);
    }

    public static void RecordJobStage(TemplateGenerationJob job, string stage)
    {
        RecordLifecycleEvent(job, "stage", stage, null);
    }

    public static void RecordJobExhausted(TemplateGenerationJob job, string failureCode)
    {
        ExhaustedJobsTotal.Add(1, TerminalJobTags(job, "failed", failureCode));
    }

    public static void RecordAiProviderError(string provider, string stage, string errorCode, string? model = null)
    {
        AiProviderErrorsTotal.Add(
            1,
            new KeyValuePair<string, object?>("provider", provider),
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("error_code", errorCode),
            new KeyValuePair<string, object?>("model", string.IsNullOrWhiteSpace(model) ? "unknown" : model));
    }

    public static void RecordQueuedWithoutCharge(TemplateGenerationJob job)
    {
        QueuedJobsWithoutChargeTotal.Add(1, JobTags(job));
    }

    public static void RecordJobRefunded(TemplateGenerationJob job)
    {
        RefundedJobsTotal.Add(1, JobTags(job));
    }

    public static void RecordDuplicateRefundAttempt(TemplateGenerationJob job)
    {
        DuplicateRefundAttemptsTotal.Add(1, JobTags(job));
    }

    public static void RecordFalTimeout(string mediaType, string stage, string? model = null)
    {
        FalTimeoutsTotal.Add(
            1,
            new KeyValuePair<string, object?>("media_type", mediaType),
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("model", string.IsNullOrWhiteSpace(model) ? "unknown" : model));
    }

    public static void RecordSseDeliveryFailure(string topic)
    {
        SseDeliveryFailuresTotal.Add(1, new KeyValuePair<string, object?>("topic", topic));
    }

    public static void RecordQueueSnapshot(
        long queueDepth,
        double? oldestQueuedJobAgeSeconds,
        double? oldestProcessingJobAgeSeconds)
    {
        QueueDepth.Record(Math.Max(0, queueDepth));
        if (oldestQueuedJobAgeSeconds is not null)
        {
            OldestQueuedJobAgeSeconds.Record(Math.Max(0, oldestQueuedJobAgeSeconds.Value));
        }

        if (oldestProcessingJobAgeSeconds is not null)
        {
            OldestProcessingJobAgeSeconds.Record(Math.Max(0, oldestProcessingJobAgeSeconds.Value));
        }
    }

    public static void RecordLaneQueueSnapshot(
        string mediaType,
        string tier,
        long queueDepth,
        long activeJobs,
        double? oldestQueuedJobAgeSeconds,
        double? oldestProcessingJobAgeSeconds)
    {
        var tags = LaneTags(mediaType, tier);
        QueueDepth.Record(Math.Max(0, queueDepth), tags);
        ActiveJobs.Record(Math.Max(0, activeJobs), tags);
        if (oldestQueuedJobAgeSeconds is not null)
        {
            OldestQueuedJobAgeSeconds.Record(Math.Max(0, oldestQueuedJobAgeSeconds.Value), tags);
        }

        if (oldestProcessingJobAgeSeconds is not null)
        {
            OldestProcessingJobAgeSeconds.Record(Math.Max(0, oldestProcessingJobAgeSeconds.Value), tags);
        }
    }

    public static void RecordJobRejected(string reason, string mediaType, string tier)
    {
        RejectedJobsTotal.Add(
            1,
            new KeyValuePair<string, object?>("reason", reason),
            new KeyValuePair<string, object?>("media_type", mediaType),
            new KeyValuePair<string, object?>("tier", tier),
            new KeyValuePair<string, object?>("lane", TemplateGenerationQueue.ResolveLane(mediaType, tier)));
    }

    public static void RecordJobCancelled(TemplateGenerationJob job)
    {
        CancelledJobsTotal.Add(1, JobTags(job));
    }

    public static void RecordSchedulerClaimAttempt(string mediaType, string result)
    {
        SchedulerClaimAttemptsTotal.Add(
            1,
            new KeyValuePair<string, object?>("media_type", mediaType),
            new KeyValuePair<string, object?>("result", result));
    }

    public static void RecordSchedulerNoSlotSkip(string scope)
    {
        SchedulerNoSlotSkipsTotal.Add(1, new KeyValuePair<string, object?>("scope", scope));
    }

    public static void RecordSchedulerCapacitySnapshot(
        long activeImage,
        long activeVideo,
        int videoReserved,
        int imageProtected)
    {
        Volatile.Write(ref activeImageNativeSlots, Math.Max(0, activeImage));
        Volatile.Write(ref activeVideoNativeSlots, Math.Min(Math.Max(0, activeVideo), Math.Max(0, videoReserved)));
        Volatile.Write(ref activeVideoBorrowedSlots, Math.Max(0, activeVideo - Math.Max(0, videoReserved)));
        Volatile.Write(ref imageProtectedCapacityAvailable, Math.Max(0, Math.Max(0, imageProtected) - Math.Max(0, activeImage)));
    }

    public static void RecordBorrowedVideoStart(string tier)
    {
        SchedulerBorrowedVideoStartsTotal.Add(
            1,
            new KeyValuePair<string, object?>("tier", TemplateGenerationQueue.NormalizeTier(tier)));
    }

    public static void RecordVideoBorrowDenied(string reason)
    {
        SchedulerVideoBorrowDeniedTotal.Add(
            1,
            new KeyValuePair<string, object?>("reason", string.IsNullOrWhiteSpace(reason) ? "unknown" : reason));
    }

    public static void RecordBorrowingCapViolation(string scope)
    {
        SchedulerBorrowingCapViolationsTotal.Add(
            1,
            new KeyValuePair<string, object?>("scope", string.IsNullOrWhiteSpace(scope) ? "unknown" : scope));
    }

    public static void RecordFalProviderCapacitySnapshot(
        int configuredConcurrency,
        long inflightRequests,
        decimal? balanceUsd,
        decimal lowThresholdUsd,
        decimal criticalThresholdUsd)
    {
        Volatile.Write(ref falConfiguredConcurrency, Math.Max(0, configuredConcurrency));
        Volatile.Write(ref falInflightRequests, Math.Max(0, inflightRequests));

        if (balanceUsd is null)
        {
            Volatile.Write(ref falBalanceUsdScaled, long.MinValue);
            Volatile.Write(ref falBalanceLow, 0);
            Volatile.Write(ref falBalanceCritical, 0);
            return;
        }

        Volatile.Write(ref falBalanceUsdScaled, (long)Math.Round(balanceUsd.Value * 100m, MidpointRounding.AwayFromZero));
        Volatile.Write(ref falBalanceLow, balanceUsd.Value <= lowThresholdUsd ? 1 : 0);
        Volatile.Write(ref falBalanceCritical, balanceUsd.Value <= criticalThresholdUsd ? 1 : 0);
    }

    public static void RecordFalProviderRejectedDueToCapacity(string reason, string mediaType, string tier)
    {
        FalProviderRejectedDueToCapacityTotal.Add(
            1,
            new KeyValuePair<string, object?>("reason", reason),
            new KeyValuePair<string, object?>("media_type", mediaType),
            new KeyValuePair<string, object?>("tier", tier),
            new KeyValuePair<string, object?>("lane", TemplateGenerationQueue.ResolveLane(mediaType, tier)));
    }

    public static void RecordFalProviderSubmitFailure(string stage, string model, string statusCode)
    {
        FalProviderSubmitFailuresTotal.Add(
            1,
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("model", string.IsNullOrWhiteSpace(model) ? "unknown" : model),
            new KeyValuePair<string, object?>("status_code", statusCode));
    }

    public static void RecordFalProviderRateLimitError(string stage, string model)
    {
        FalProviderRateLimitErrorsTotal.Add(
            1,
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("model", string.IsNullOrWhiteSpace(model) ? "unknown" : model));
    }

    public static void RecordFalProviderQueueWait(string mediaType, string stage, string? model, DateTime? submittedAtUtc)
    {
        if (submittedAtUtc is null)
        {
            return;
        }

        FalProviderQueueWaitSeconds.Record(
            Math.Max(0, (DateTime.UtcNow - submittedAtUtc.Value).TotalSeconds),
            new KeyValuePair<string, object?>("media_type", mediaType),
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("model", string.IsNullOrWhiteSpace(model) ? "unknown" : model));
    }

    private static void RecordGenerationDuration(TemplateGenerationJob job, string terminalStatus, string? failureCode)
    {
        var end = job.CompletedAtUtc ?? job.UpdatedAtUtc;
        var start = job.StartedAtUtc ?? job.QueuedAtUtc;
        var durationSeconds = Math.Max(0, (end - start).TotalSeconds);
        GenerationDurationSeconds.Record(durationSeconds, TerminalJobTags(job, terminalStatus, failureCode));
    }

    private static void RecordEtaAccuracy(TemplateGenerationJob job)
    {
        if (job.EstimatedCompletionAtQueueUtc is null || job.CompletedAtUtc is null)
        {
            return;
        }

        EtaAccuracyErrorSeconds.Record(
            Math.Abs((job.CompletedAtUtc.Value - job.EstimatedCompletionAtQueueUtc.Value).TotalSeconds),
            JobTags(job));
    }

    private static void RecordLifecycleEvent(
        TemplateGenerationJob job,
        string eventType,
        string stage,
        string? failureCode)
    {
        LifecycleEventsTotal.Add(
            1,
            new KeyValuePair<string, object?>("template_type", ResolveTemplateType(job)),
            new KeyValuePair<string, object?>("event_type", eventType),
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("failure_code", string.IsNullOrWhiteSpace(failureCode) ? "none" : failureCode),
            new KeyValuePair<string, object?>("admin_test", job.UserId == TemplateGenerationService.AdminTestUserId));
    }

    private static KeyValuePair<string, object?>[] JobTags(TemplateGenerationJob job)
    {
        return
        [
            new("template_type", ResolveTemplateType(job)),
            new("media_type", TemplateGenerationQueue.ResolveMediaType(job)),
            new("tier", TemplateGenerationQueue.NormalizeTier(job.QueueTier)),
            new("lane", TemplateGenerationQueue.ResolveLane(TemplateGenerationQueue.ResolveMediaType(job), job.QueueTier)),
            new("admin_test", job.UserId == TemplateGenerationService.AdminTestUserId)
        ];
    }

    private static KeyValuePair<string, object?>[] LaneTags(string mediaType, string tier)
    {
        var normalizedMediaType = TemplateGenerationQueue.NormalizeMediaType(mediaType);
        var normalizedTier = TemplateGenerationQueue.NormalizeTier(tier);
        return
        [
            new("media_type", normalizedMediaType),
            new("tier", normalizedTier),
            new("lane", TemplateGenerationQueue.ResolveLane(normalizedMediaType, normalizedTier))
        ];
    }

    private static IEnumerable<Measurement<double>> ObserveFalBalanceUsd()
    {
        var scaled = Volatile.Read(ref falBalanceUsdScaled);
        if (scaled == long.MinValue)
        {
            return [];
        }

        return [new Measurement<double>(scaled / 100d)];
    }

    private static KeyValuePair<string, object?>[] TerminalJobTags(
        TemplateGenerationJob job,
        string terminalStatus,
        string? failureCode)
    {
        return
        [
            new("template_type", ResolveTemplateType(job)),
            new("media_type", TemplateGenerationQueue.ResolveMediaType(job)),
            new("tier", TemplateGenerationQueue.NormalizeTier(job.QueueTier)),
            new("lane", TemplateGenerationQueue.ResolveLane(TemplateGenerationQueue.ResolveMediaType(job), job.QueueTier)),
            new("terminal_status", terminalStatus),
            new("failure_code", string.IsNullOrWhiteSpace(failureCode) ? "none" : failureCode),
            new("admin_test", job.UserId == TemplateGenerationService.AdminTestUserId)
        ];
    }

    private static string ResolveTemplateType(TemplateGenerationJob job)
    {
        return job.Template is null ? "unknown" : job.Template.TemplateType.ToString();
    }
}
