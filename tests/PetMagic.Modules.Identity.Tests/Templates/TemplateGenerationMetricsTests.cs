using PetMagic.Modules.Templates.Domain.Enums;
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
            "generation_jobs_exhausted_total",
            "generation_lifecycle_events_total",
            "generation_duration_seconds",
            "ai_provider_errors_total");

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
            CompletedAtUtc = now
        };

        TemplateGenerationMetrics.RecordJobQueued(job);
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
        Assert.Contains(
            recorder.Measurements,
            x => x.InstrumentName == "generation_lifecycle_events_total"
                && x.Value == 1
                && Equals(x.Tags["event_type"], "fail")
                && Equals(x.Tags["failure_code"], TemplatesErrors.AiProviderFailed.Code));
    }
}
