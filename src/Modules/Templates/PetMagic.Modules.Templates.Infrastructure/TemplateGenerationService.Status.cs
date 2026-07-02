using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    internal static string ResolveApiStatus(TemplateGenerationStatus status)
    {
        return status.ToString();
    }

    internal static string ResolveStage(TemplateGenerationJob job)
    {
        if (job.Status == TemplateGenerationStatus.Failed)
        {
            return "failed";
        }

        if (job.Status == TemplateGenerationStatus.Cancelled)
        {
            return "cancelled";
        }

        if (job.Status == TemplateGenerationStatus.Retrying)
        {
            return "retrying";
        }

        if (job.Status == TemplateGenerationStatus.Completed)
        {
            return "completed";
        }

        if (job.Status == TemplateGenerationStatus.Queued)
        {
            return "queued";
        }

        if (job.Status == TemplateGenerationStatus.SubmittingToProvider)
        {
            return string.Equals(job.CurrentProviderStage, "video_preprocessing", StringComparison.OrdinalIgnoreCase)
                ? "submitting_preprocess"
                : "submitting_provider";
        }

        if (job.Status == TemplateGenerationStatus.ProviderQueued)
        {
            return string.Equals(job.CurrentProviderStage, "video_preprocessing", StringComparison.OrdinalIgnoreCase)
                ? "preprocess_provider_queued"
                : string.Equals(job.CurrentProviderStage, "video_generation", StringComparison.OrdinalIgnoreCase)
                    ? "video_provider_queued"
                    : "provider_queued";
        }

        if (job.Status == TemplateGenerationStatus.ProviderProcessing)
        {
            return string.Equals(job.CurrentProviderStage, "video_preprocessing", StringComparison.OrdinalIgnoreCase)
                ? "preprocess_provider_processing"
                : string.Equals(job.CurrentProviderStage, "video_generation", StringComparison.OrdinalIgnoreCase)
                    ? "video_provider_processing"
                    : "provider_processing";
        }

        if (job.Status == TemplateGenerationStatus.ImportingMedia)
        {
            return "finalizing";
        }

        if (job.Status != TemplateGenerationStatus.Processing)
        {
            return "processing";
        }

        if (job.MediaImportCompletedAtUtc is not null
            || job.MotionGenerationCompletedAtUtc is not null
            || (job.Template?.TemplateType == TemplateType.Image && job.PreprocessingCompletedAtUtc is not null))
        {
            return "finalizing";
        }

        if (job.Template?.TemplateType == TemplateType.Video && job.PreprocessingCompletedAtUtc is not null)
        {
            return "generating";
        }

        if (job.StartedAtUtc is not null)
        {
            return "preprocessing";
        }

        return "processing";
    }

    internal static int ResolveProgressPercent(TemplateGenerationJob job)
    {
        return ResolveStage(job) switch
        {
            "completed" => 100,
            "failed" => 100,
            "finalizing" => 90,
            "generating" => 65,
            "preprocessing" => 30,
            "uploading" => 15,
            _ => 10
        };
    }

    private static string ResolveEstimatedDurationLabel(TemplateType? templateType)
    {
        return templateType == TemplateType.Video
            ? "Usually 1-3 minutes"
            : "Usually under 1 minute";
    }

    private static TemplateAssetResponse? MapSourceImageAsset(TemplateGenerationJob job)
    {
        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(job.SourceImageUrl))
        {
            return null;
        }

        return new TemplateAssetResponse(
            job.SourceImageUrl,
            job.SourceImageFileName ?? string.Empty,
            job.SourceImageContentType ?? string.Empty,
            job.SourceImageFileSizeBytes,
            null);
    }
}
