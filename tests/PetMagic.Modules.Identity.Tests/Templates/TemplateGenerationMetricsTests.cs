using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Identity.Tests.Host;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationMetricsTests
{
    [Fact]
    public void TemplateGenerationMetrics_ShouldEmitQueueTerminalAndProviderInstruments()
    {
        using var recorder = new MeterMeasurementRecorder(
            TemplateGenerationMetrics.MeterName,
            "generation_jobs_queued",
            "generation_jobs_processing",
            "generation_jobs_failed_total",
            "generation_jobs_accepted_total",
            "generation_jobs_exhausted_total",
            "generation_lifecycle_events_total",
            "generation_duration_seconds",
            "ai_provider_errors_total",
            "generation_jobs_queued_without_charge_total",
            "generation_jobs_refunded_total",
            "generation_duplicate_refund_attempts_total",
            "generation_refund_failures_total",
            "generation_cancel_refunds_total",
            "generation_fal_timeouts_total",
            "generation_sse_delivery_failures_total",
            "generation_queue_depth",
            "generation_oldest_queued_job_age_seconds",
            "generation_oldest_processing_job_age_seconds",
            "generation_stuck_stage_age_seconds",
            "generation_active_jobs",
            "generation_queue_wait_seconds",
            "generation_eta_accuracy_error_seconds",
            "generation_jobs_rejected_total",
            "generation_jobs_cancelled_total",
            "generation_retry_attempts_total",
            "generation_media_import_failures_total",
            "generation_preview_404_total",
            "generation_r2_upload_failures_total",
            "generation_scheduler_claim_attempts_total",
            "generation_scheduler_no_slot_skips_total",
            "generation_scheduler_borrowed_video_starts_total",
            "generation_scheduler_video_borrow_denied_total",
            "generation_scheduler_borrowing_cap_violations_total",
            "generation_scheduler_active_image_native_slots",
            "generation_scheduler_active_video_native_slots",
            "generation_scheduler_active_video_borrowed_slots",
            "generation_scheduler_image_protected_capacity_available",
            "fal_provider_rejected_due_to_capacity",
            "fal_provider_submit_failures",
            "fal_provider_rate_limit_errors",
            "fal_provider_queue_wait_seconds",
            "fal_provider_configured_concurrency",
            "fal_provider_inflight_requests",
            "fal_provider_balance_low",
            "fal_provider_balance_critical",
            "fal_provider_balance_usd");

        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = "Metrics Template",
            ShortDescription = "Metrics",
            Category = "Tests",
            Tags = "metrics",
            ImageModel = "openai/gpt-image-2/edit",
            Status = TemplateStatus.Active,
            CreatedAtUtc = now.AddMinutes(-5),
            UpdatedAtUtc = now.AddMinutes(-5)
        };
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Queued,
            TokenCost = 10,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = now.AddMinutes(-3),
            QueuedAtUtc = now.AddMinutes(-3),
            StartedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now,
            CompletedAtUtc = now,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierPremium,
            EstimatedCompletionAtQueueUtc = now.AddSeconds(-15)
        };

        TemplateGenerationMetrics.RecordJobQueued(job);
        TemplateGenerationMetrics.RecordJobAccepted(job);
        TemplateGenerationMetrics.RecordJobClaimed(job);
        TemplateGenerationMetrics.RecordJobCompleted(job);
        TemplateGenerationMetrics.RecordJobStage(job, "finalizing");
        job.Status = TemplateGenerationStatus.Processing;
        job.CompletedAtUtc = now.AddSeconds(30);
        TemplateGenerationMetrics.RecordJobFailed(job, TemplateGenerationStatus.Processing, TemplatesErrors.AiProviderFailed.Code);
        TemplateGenerationMetrics.RecordJobExhausted(job, TemplatesErrors.GenerationAttemptsExceeded.Code);
        TemplateGenerationMetrics.RecordAiProviderError(
            "fal",
            "submit",
            TemplatesErrors.AiProviderFailed.Code,
            "openai/gpt-image-2/edit");
        TemplateGenerationMetrics.RecordQueuedWithoutCharge(job);
        TemplateGenerationMetrics.RecordJobRefunded(job);
        TemplateGenerationMetrics.RecordDuplicateRefundAttempt(job);
        TemplateGenerationMetrics.RecordRefundFailure(job, TemplatesErrors.MediaStorageFailed.Code);
        TemplateGenerationMetrics.RecordCancelRefund(job);
        TemplateGenerationMetrics.RecordFalTimeout("video", "video_generation", "fal-ai/kling-video/v3/pro/motion-control");
        TemplateGenerationMetrics.RecordSseDeliveryFailure(TemplateFeedRealtimeTopics.GenerationStatusChanged);
        TemplateGenerationMetrics.RecordQueueSnapshot(3, 120, 45);
        TemplateGenerationMetrics.RecordLaneQueueSnapshot("image", "premium", 2, 1, 30, 15);
        TemplateGenerationMetrics.RecordStuckStageAge("ProviderQueued", "image", "premium", 900);
        TemplateGenerationMetrics.RecordJobRejected(
            TemplatesErrors.GenerationWaitTooLong.Code,
            TemplateGenerationQueue.MediaTypeImage,
            TemplateGenerationQueue.TierPremium);
        TemplateGenerationMetrics.RecordJobCancelled(job);
        TemplateGenerationMetrics.RecordRetryAttempt(job, "claim_retry");
        TemplateGenerationMetrics.RecordMediaImportFailure("video", "http_404");
        TemplateGenerationMetrics.RecordPreviewNotFound("preview");
        TemplateGenerationMetrics.RecordR2UploadFailure("store");
        TemplateGenerationMetrics.RecordSchedulerClaimAttempt("image", "claimed");
        TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("video");
        TemplateGenerationMetrics.RecordSchedulerCapacitySnapshot(activeImage: 2, activeVideo: 5, videoReserved: 3, imageProtected: 4);
        TemplateGenerationMetrics.RecordBorrowedVideoStart(TemplateGenerationQueue.TierPremium);
        TemplateGenerationMetrics.RecordVideoBorrowDenied("image_backlog");
        TemplateGenerationMetrics.RecordBorrowingCapViolation("video_borrow");
        TemplateGenerationMetrics.RecordFalProviderCapacitySnapshot(30, 12, 80m, 100m, 25m);
        TemplateGenerationMetrics.RecordFalProviderRejectedDueToCapacity(
            "balance_unknown",
            TemplateGenerationQueue.MediaTypeImage,
            TemplateGenerationQueue.TierPremium);
        TemplateGenerationMetrics.RecordFalProviderSubmitFailure("image_generation", "openai/gpt-image-2/edit", "429");
        TemplateGenerationMetrics.RecordFalProviderRateLimitError("image_generation", "openai/gpt-image-2/edit");
        TemplateGenerationMetrics.RecordFalProviderQueueWait(
            TemplateGenerationQueue.MediaTypeImage,
            "image_generation",
            "openai/gpt-image-2/edit",
            DateTime.UtcNow.AddSeconds(-45));
        recorder.CollectObservableInstruments();

        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_jobs_queued" && x.Value == 1);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_jobs_processing" && x.Value == 1);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_duration_seconds"
                && x.Value >= 120
                && Equals(x.Tags["terminal_status"], "completed"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_jobs_failed_total"
                && x.Value == 1
                && Equals(x.Tags["terminal_status"], "failed")
                && Equals(x.Tags["failure_code"], TemplatesErrors.AiProviderFailed.Code));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_duration_seconds"
                && x.Value >= 150
                && Equals(x.Tags["terminal_status"], "failed")
                && Equals(x.Tags["failure_code"], TemplatesErrors.AiProviderFailed.Code));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "ai_provider_errors_total"
                && x.Value == 1
                && Equals(x.Tags["provider"], "fal")
                && Equals(x.Tags["stage"], "submit"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_jobs_exhausted_total"
                && x.Value == 1
                && Equals(x.Tags["failure_code"], TemplatesErrors.GenerationAttemptsExceeded.Code));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_lifecycle_events_total"
                && x.Value == 1
                && Equals(x.Tags["event_type"], "start")
                && Equals(x.Tags["stage"], "queued"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_lifecycle_events_total"
                && x.Value == 1
                && Equals(x.Tags["event_type"], "stage")
                && Equals(x.Tags["stage"], "finalizing"));
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_jobs_accepted_total" && x.Value == 1);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_lifecycle_events_total"
                && x.Value == 1
                && Equals(x.Tags["event_type"], "fail")
                && Equals(x.Tags["failure_code"], TemplatesErrors.AiProviderFailed.Code));
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_jobs_queued_without_charge_total" && x.Value == 1);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_jobs_refunded_total" && x.Value == 1);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_duplicate_refund_attempts_total" && x.Value == 1);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_refund_failures_total"
                && x.Value == 1
                && Equals(x.Tags["error_code"], TemplatesErrors.MediaStorageFailed.Code));
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_cancel_refunds_total" && x.Value == 1);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_fal_timeouts_total"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "video")
                && Equals(x.Tags["stage"], "video_generation"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_sse_delivery_failures_total"
                && x.Value == 1
                && Equals(x.Tags["topic"], TemplateFeedRealtimeTopics.GenerationStatusChanged));
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_queue_depth" && x.Value == 3);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_oldest_queued_job_age_seconds" && x.Value == 120);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_oldest_processing_job_age_seconds" && x.Value == 45);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_stuck_stage_age_seconds"
                && x.Value == 900
                && Equals(x.Tags["stage"], "ProviderQueued"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_jobs_queued"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium")
                && Equals(x.Tags["lane"], "image:premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_queue_wait_seconds"
                && x.Value >= 60
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_eta_accuracy_error_seconds"
                && x.Value >= 15
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_retry_attempts_total"
                && x.Value == 1
                && Equals(x.Tags["reason"], "claim_retry"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_media_import_failures_total"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "video")
                && Equals(x.Tags["reason"], "http_404"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_preview_404_total"
                && x.Value == 1
                && Equals(x.Tags["role"], "preview"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_r2_upload_failures_total"
                && x.Value == 1
                && Equals(x.Tags["operation"], "store"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_active_jobs"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_jobs_rejected_total"
                && x.Value == 1
                && Equals(x.Tags["reason"], TemplatesErrors.GenerationWaitTooLong.Code)
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_jobs_cancelled_total"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["tier"], "premium"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_scheduler_claim_attempts_total"
                && x.Value == 1
                && Equals(x.Tags["media_type"], "image")
                && Equals(x.Tags["result"], "claimed"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_scheduler_no_slot_skips_total"
                && x.Value == 1
                && Equals(x.Tags["scope"], "video"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_scheduler_borrowed_video_starts_total"
                && x.Value == 1
                && Equals(x.Tags["tier"], TemplateGenerationQueue.TierPremium));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_scheduler_video_borrow_denied_total"
                && x.Value == 1
                && Equals(x.Tags["reason"], "image_backlog"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_scheduler_borrowing_cap_violations_total"
                && x.Value == 1
                && Equals(x.Tags["scope"], "video_borrow"));
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_scheduler_active_image_native_slots" && x.Value == 2);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_scheduler_active_video_native_slots" && x.Value == 3);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_scheduler_active_video_borrowed_slots" && x.Value == 2);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "generation_scheduler_image_protected_capacity_available" && x.Value == 2);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "fal_provider_configured_concurrency" && x.Value == 30);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "fal_provider_inflight_requests" && x.Value == 12);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "fal_provider_balance_low" && x.Value == 1);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "fal_provider_balance_critical" && x.Value == 0);
        Assert.Contains(recorder.Measurements, x => x.InstrumentName == "fal_provider_balance_usd" && x.Value == 80);
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "fal_provider_rejected_due_to_capacity"
                && x.Value == 1
                && Equals(x.Tags["reason"], "balance_unknown"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "fal_provider_submit_failures"
                && x.Value == 1
                && Equals(x.Tags["status_code"], "429"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "fal_provider_rate_limit_errors"
                && x.Value == 1
                && Equals(x.Tags["stage"], "image_generation"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "fal_provider_queue_wait_seconds"
                && x.Value >= 40
                && Equals(x.Tags["stage"], "image_generation"));
    }

    [Fact]
    public void TemplateGenerationMetrics_ShouldCountOnlyFullFeedInvalidations_AsFullInvalidations()
    {
        using var recorder = new MeterMeasurementRecorder(
            TemplateGenerationMetrics.MeterName,
            "sse_events_published_count",
            "sse_full_invalidation_count");

        TemplateGenerationMetrics.RecordSseEventPublished(TemplateFeedInvalidationScopes.Template);
        TemplateGenerationMetrics.RecordSseEventPublished(TemplateFeedInvalidationScopes.Category);
        TemplateGenerationMetrics.RecordSseEventPublished(TemplateFeedInvalidationScopes.TemplateOfTheDay);
        TemplateGenerationMetrics.RecordSseEventPublished(TemplateFeedInvalidationScopes.Full);
        TemplateGenerationMetrics.RecordSseFullInvalidation();

        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "sse_events_published_count"
                && x.Value == 1
                && Equals(x.Tags["scope"], TemplateFeedInvalidationScopes.Template));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "sse_events_published_count"
                && x.Value == 1
                && Equals(x.Tags["scope"], TemplateFeedInvalidationScopes.Category));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "sse_events_published_count"
                && x.Value == 1
                && Equals(x.Tags["scope"], TemplateFeedInvalidationScopes.TemplateOfTheDay));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "sse_events_published_count"
                && x.Value == 1
                && Equals(x.Tags["scope"], TemplateFeedInvalidationScopes.Full));
        Assert.Single(
            recorder.Measurements,
            x => x.InstrumentName == "sse_full_invalidation_count" && x.Value == 1);
    }

    [Fact]
    public void TemplateGenerationApiMetrics_ShouldEmitWebhookInstruments()
    {
        using var recorder = new MeterMeasurementRecorder(
            TemplateGenerationApiMetrics.MeterName,
            "generation_webhook_signature_failures_total",
            "generation_webhook_delivery_failures_total");

        TemplateGenerationApiMetrics.RecordWebhookSignatureFailure("signature_mismatch");
        TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure("invalid_payload");

        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_webhook_signature_failures_total"
                && x.Value == 1
                && Equals(x.Tags["reason"], "signature_mismatch"));
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_webhook_delivery_failures_total"
                && x.Value == 1
                && Equals(x.Tags["reason"], "invalid_payload"));
    }
}
