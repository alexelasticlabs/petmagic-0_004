using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class FeedbackService
{
    private void AddFeedbackAnalytics(
        TemplateGenerationFeedback feedback,
        TemplateGenerationJob? generation,
        string eventType,
        DateTime now)
    {
        if (feedback.TemplateId is not Guid templateId)
        {
            return;
        }

        var metadata = JsonSerializer.Serialize(new
        {
            feedbackType = feedback.Type,
            category = feedback.Category,
            rating = feedback.Rating,
            generationId = feedback.GenerationId,
            templateId,
            platform = feedback.Platform,
            userPlan = (string?)null
        });

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            UserId = feedback.UserId,
            GenerationId = feedback.GenerationId,
            EventType = eventType,
            Source = feedback.SourceScreen,
            DeviceClass = feedback.Platform ?? "unknown",
            CountryCode = feedback.Locale ?? string.Empty,
            FeedbackMessage = feedback.Message ?? feedback.Comment,
            MetadataJson = metadata.Length <= 2000 ? metadata : metadata[..2000],
            ModerationStatus = "approved",
            CreatedAtUtc = now
        });
    }

    private static string ResolveProviderName(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return string.Empty;
        }

        if (!string.IsNullOrWhiteSpace(generation.MotionProviderRequestId))
        {
            return "fal";
        }

        if (!string.IsNullOrWhiteSpace(generation.PreprocessingProviderRequestId))
        {
            return "fal";
        }

        return string.Empty;
    }

    private static string? ResolveModel(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return null;
        }

        return !string.IsNullOrWhiteSpace(generation.UsedKlingModel)
            ? generation.UsedKlingModel
            : generation.UsedPreprocessingModel;
    }

    private static string? ResolveProviderRequestId(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return null;
        }

        return !string.IsNullOrWhiteSpace(generation.MotionProviderRequestId)
            ? generation.MotionProviderRequestId
            : generation.PreprocessingProviderRequestId;
    }

    private static double? ResolveGenerationDurationSeconds(TemplateGenerationJob? generation)
    {
        if (generation?.StartedAtUtc is not DateTime startedAt || generation.CompletedAtUtc is not DateTime completedAt)
        {
            return null;
        }

        return Math.Max(0, (completedAt - startedAt).TotalSeconds);
    }

    private static int? NormalizeRating(int? rating)
    {
        if (rating is null)
        {
            return null;
        }

        return Math.Clamp(rating.Value, -1, 1);
    }

    private static string NormalizeType(string value)
    {
        _ = TryNormalizeType(value, allowUnknownAsGeneral: true, out var normalized);
        return normalized;
    }

    private static bool TryValidateAdminFilters(AdminFeedbackQuery query, out Error error)
    {
        if (!string.IsNullOrWhiteSpace(query.Status)
            && !TryNormalizeStatus(query.Status, out _))
        {
            error = TemplatesErrors.InvalidFeedbackStatus;
            return false;
        }

        if (!string.IsNullOrWhiteSpace(query.Priority)
            && !TryNormalizePriority(query.Priority, out _))
        {
            error = TemplatesErrors.InvalidFeedbackPriority;
            return false;
        }

        if (!string.IsNullOrWhiteSpace(query.Type)
            && !TryNormalizeType(query.Type, allowUnknownAsGeneral: false, out _))
        {
            error = TemplatesErrors.InvalidFeedbackType;
            return false;
        }

        error = Error.None;
        return true;
    }

    private static bool TryNormalizeType(string value, bool allowUnknownAsGeneral, out string normalized)
    {
        normalized = NormalizeText(value, 32);
        if (normalized is "GenerationResult" or "GenerationFailure" or "BugReport" or "FeatureRequest" or "PaymentIssue" or "General")
        {
            return true;
        }

        if (allowUnknownAsGeneral)
        {
            normalized = "General";
            return true;
        }

        return false;
    }

    private static bool TryNormalizeStatus(string? value, out string normalized)
    {
        normalized = NormalizeText(value ?? "New", 24);
        return normalized is "New" or "InReview" or "Resolved" or "Dismissed";
    }

    private static bool TryNormalizePriority(string? value, out string normalized)
    {
        normalized = NormalizeText(value ?? "Low", 24);
        return normalized is "Low" or "Medium" or "High" or "Critical";
    }

    private static string ResolvePriority(string type, string category, int? rating)
    {
        if (type == "PaymentIssue" || category.Contains("payment", StringComparison.OrdinalIgnoreCase) || category.Contains("оплат", StringComparison.OrdinalIgnoreCase))
        {
            return "Critical";
        }

        if (category.Contains("inappropriate", StringComparison.OrdinalIgnoreCase) || category.Contains("неподход", StringComparison.OrdinalIgnoreCase))
        {
            return "High";
        }

        if (rating < 0 || category.Contains("quality", StringComparison.OrdinalIgnoreCase) || category.Contains("кач", StringComparison.OrdinalIgnoreCase))
        {
            return "Medium";
        }

        return "Low";
    }

    private static string NormalizeText(string value, int maxLength)
    {
        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return null;
        }

        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }
}
