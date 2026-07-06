namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class GenerationObservabilityReleaseGateTests
{
    private static readonly string[] RequiredMetrics =
    [
        "fal_provider_balance_low",
        "fal_provider_balance_critical",
        "fal_provider_balance_usd",
        "fal_provider_configured_concurrency",
        "fal_provider_inflight_requests",
        "fal_provider_rejected_due_to_capacity",
        "fal_provider_submit_failures",
        "fal_provider_rate_limit_errors",
        "fal_provider_queue_wait_seconds_bucket",
        "generation_webhook_delivery_failures_total",
        "generation_webhook_signature_failures_total",
        "generation_queue_depth_bucket",
        "generation_oldest_queued_job_age_seconds_bucket",
        "generation_active_jobs_bucket",
        "generation_scheduler_active_image_native_slots",
        "generation_scheduler_active_video_native_slots",
        "generation_scheduler_active_video_borrowed_slots",
        "generation_scheduler_video_borrow_denied_total",
        "generation_scheduler_borrowing_cap_violations_total",
        "generation_jobs_accepted_total",
        "generation_jobs_rejected_total",
        "generation_jobs_cancelled_total",
        "generation_jobs_queued_without_charge_total",
        "generation_jobs_refunded_total",
        "generation_duplicate_refund_attempts_total",
        "generation_refund_failures_total",
        "generation_cancel_refunds_total",
        "generation_fal_timeouts_total",
        "generation_sse_delivery_failures_total",
        "generation_stuck_stage_age_seconds_bucket",
        "generation_jobs_failed_total",
        "generation_jobs_exhausted_total",
        "generation_retry_attempts_total",
        "ai_provider_errors_total",
        "generation_media_import_failures_total",
        "generation_preview_404_total",
        "generation_r2_upload_failures_total"
    ];

    private static readonly string[] RequiredAlerts =
    [
        "PetMagicFalProviderBalanceLow",
        "PetMagicFalProviderBalanceCritical",
        "PetMagicFalProviderCapacityRejected",
        "PetMagicFalProviderSubmitFailures",
        "PetMagicFalProviderRateLimitErrors",
        "PetMagicFalWebhookDeliveryFailures",
        "PetMagicFalWebhookSignatureFailures",
        "PetMagicGenerationQueueBacklog",
        "PetMagicGenerationWaitTooLongHigh",
        "PetMagicGenerationQueuedWithoutCharge",
        "PetMagicGenerationRefundFailures",
        "PetMagicGenerationDuplicateRefundAttempt",
        "PetMagicGenerationVideoBorrowDeniedByImageBacklog",
        "PetMagicGenerationBorrowingCapViolation",
        "PetMagicGenerationStuckProviderQueued",
        "PetMagicGenerationStuckProviderProcessing",
        "PetMagicGenerationStuckImportingMedia",
        "PetMagicGenerationFailuresHigh",
        "PetMagicGenerationRetryRateHigh",
        "PetMagicGenerationRetriesExhausted",
        "PetMagicGenerationMediaImportFailures",
        "PetMagicTemplatePreview404",
        "PetMagicR2UploadFailures"
    ];

    [Fact]
    public void GenerationReleaseGateDocsSmokeAndAlerts_ShouldContainRequiredMetricsAndAlerts()
    {
        var runbook = File.ReadAllText(RepositoryPath("docs", "observability", "generation-release-gate.md"));
        var observability = File.ReadAllText(RepositoryPath("docs", "OBSERVABILITY.md"));
        var smoke = File.ReadAllText(RepositoryPath("scripts", "qa", "run-staging-generation-scheduler-smoke.mjs"));
        var alerts = File.ReadAllText(RepositoryPath("deploy", "monitoring", "prometheus", "petmagic-alerts.yml"));

        foreach (var metric in RequiredMetrics)
        {
            Assert.Contains(metric, runbook, StringComparison.Ordinal);
            Assert.Contains(metric, observability, StringComparison.Ordinal);
            Assert.Contains(metric, alerts + smoke, StringComparison.Ordinal);
        }

        foreach (var alert in RequiredAlerts)
        {
            Assert.Contains(alert, alerts, StringComparison.Ordinal);
            Assert.Contains(alert, runbook, StringComparison.Ordinal);
        }

        Assert.Contains("prometheus.required_generation_metrics_present", smoke, StringComparison.Ordinal);
        Assert.Contains("production-blocking", runbook, StringComparison.OrdinalIgnoreCase);
    }

    private static string RepositoryPath(params string[] segments)
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null && !File.Exists(Path.Combine(current.FullName, "PetMagic.slnx")))
        {
            current = current.Parent;
        }

        if (current is null)
        {
            throw new DirectoryNotFoundException("Could not locate repository root.");
        }

        return Path.Combine([current.FullName, .. segments]);
    }
}
