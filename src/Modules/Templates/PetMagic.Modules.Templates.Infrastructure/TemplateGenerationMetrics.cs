using System.Diagnostics.Metrics;

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

    private static readonly Histogram<double> GenerationDurationSeconds = Meter.CreateHistogram<double>(
        "generation_duration_seconds",
        unit: "s",
        description: "Duration of terminal template generation jobs from queue/start to completion.");

    private static readonly Counter<long> AiProviderErrorsTotal = Meter.CreateCounter<long>(
        "ai_provider_errors_total",
        unit: "{error}",
        description: "Number of template AI provider failures.");

    public static void RecordJobQueued(TemplateGenerationJob job)
    {
        QueuedJobs.Add(1, JobTags(job));
    }

    public static void RecordJobClaimed(TemplateGenerationJob job)
    {
        var tags = JobTags(job);
        QueuedJobs.Add(-1, tags);
        ProcessingJobs.Add(1, tags);
    }

    public static void RecordJobRequeued(TemplateGenerationJob job)
    {
        var tags = JobTags(job);
        ProcessingJobs.Add(-1, tags);
        QueuedJobs.Add(1, tags);
    }

    public static void RecordJobCompleted(TemplateGenerationJob job)
    {
        ProcessingJobs.Add(-1, JobTags(job));
        RecordGenerationDuration(job, "completed", null);
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
        RecordGenerationDuration(job, "failed", failureCode);
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

    private static void RecordGenerationDuration(TemplateGenerationJob job, string terminalStatus, string? failureCode)
    {
        var end = job.CompletedAtUtc ?? job.UpdatedAtUtc;
        var start = job.StartedAtUtc ?? job.QueuedAtUtc;
        var durationSeconds = Math.Max(0, (end - start).TotalSeconds);
        GenerationDurationSeconds.Record(durationSeconds, TerminalJobTags(job, terminalStatus, failureCode));
    }

    private static KeyValuePair<string, object?>[] JobTags(TemplateGenerationJob job)
    {
        return
        [
            new("template_type", ResolveTemplateType(job)),
            new("admin_test", job.UserId == TemplateGenerationService.AdminTestUserId)
        ];
    }

    private static KeyValuePair<string, object?>[] TerminalJobTags(
        TemplateGenerationJob job,
        string terminalStatus,
        string? failureCode)
    {
        return
        [
            new("template_type", ResolveTemplateType(job)),
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
