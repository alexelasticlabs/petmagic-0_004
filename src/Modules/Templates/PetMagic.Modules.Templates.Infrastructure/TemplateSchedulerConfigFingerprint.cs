using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class TemplateSchedulerConfigFingerprint
{
    public const string ApiComponent = "api";
    public const string GenerationWorkerComponent = "generation-worker";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false
    };

    public static TemplateSchedulerConfigFingerprintResult Create(
        TemplatesOptions options,
        string profileName,
        string component)
    {
        var normalized = BuildNormalizedSchedulerConfig(options);
        var canonicalJson = JsonSerializer.Serialize(normalized, JsonOptions);
        var checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalJson))).ToLowerInvariant();
        var dump = new SortedDictionary<string, object?>(StringComparer.Ordinal)
        {
            ["checksum"] = checksum,
            ["component"] = NormalizeText(component),
            ["profileName"] = NormalizeText(profileName),
            ["scheduler"] = normalized
        };

        return new TemplateSchedulerConfigFingerprintResult(
            checksum,
            canonicalJson,
            JsonSerializer.Serialize(dump, JsonOptions));
    }

    private static SortedDictionary<string, object?> BuildNormalizedSchedulerConfig(TemplatesOptions options)
    {
        return new SortedDictionary<string, object?>(StringComparer.Ordinal)
        {
            ["generationSchedulerV2Enabled"] = options.GenerationSchedulerV2Enabled,
            ["admission"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["cancelQueuedGenerationEnabled"] = options.CancelQueuedGenerationEnabled,
                ["freeUserMaxActiveGenerations"] = options.FreeUserMaxActiveGenerations,
                ["premiumUserMaxActiveGenerations"] = options.PremiumUserMaxActiveGenerations,
                ["privilegedUserMaxActiveGenerations"] = options.PrivilegedUserMaxActiveGenerations,
                ["queueMaxSize"] = options.QueueMaxSize
            },
            ["concurrency"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["maxAiProviderRequestsPerMinute"] = options.MaxAiProviderRequestsPerMinute,
            },
            ["elasticBorrowing"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["allowVideoBorrowWhenImageEstimatedWaitBelowSeconds"] = options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds,
                ["allowVideoBorrowWhenImageQueueEmpty"] = options.AllowVideoBorrowWhenImageQueueEmpty,
                ["borrowedVideoMaxAgeSeconds"] = options.BorrowedVideoMaxAgeSeconds,
                ["borrowingPriorityTiers"] = NormalizeCsvSet(options.BorrowingPriorityTiers),
                ["enableElasticLaneBorrowing"] = options.EnableElasticLaneBorrowing,
                ["videoBorrowReleaseMode"] = NormalizeText(options.VideoBorrowReleaseMode)
            },
            ["estimates"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["estimatedImageGenerationSeconds"] = options.EstimatedImageGenerationSeconds,
                ["estimatedVideoGenerationSeconds"] = options.EstimatedVideoGenerationSeconds,
                ["estimatedVideoPreprocessingSeconds"] = options.EstimatedVideoPreprocessingSeconds
            },
            ["provider"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["aiProvider"] = NormalizeText(options.AiProvider),
                ["falImageMaxPollingAttempts"] = options.Fal.ImageMaxPollingAttempts,
                ["falImagePreprocessingMaxPollingAttempts"] = options.Fal.ImagePreprocessingMaxPollingAttempts,
                ["falMaxPollingAttempts"] = options.Fal.MaxPollingAttempts,
                ["falPollIntervalMilliseconds"] = options.Fal.PollIntervalMilliseconds,
                ["falStartTimeoutSeconds"] = options.Fal.StartTimeoutSeconds,
                ["falVideoMaxPollingAttempts"] = options.Fal.VideoMaxPollingAttempts
            },
            ["queuePriority"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["adminQueuePriorityScore"] = options.AdminQueuePriorityScore,
                ["freeQueuePriorityScore"] = options.FreeQueuePriorityScore,
                ["premiumQueuePriorityScore"] = options.PremiumQueuePriorityScore,
                ["privilegedQueuePriorityScore"] = options.PrivilegedQueuePriorityScore,
                ["queuePriorityAgingBoost"] = options.QueuePriorityAgingBoost,
                ["queuePriorityAgingIntervalSeconds"] = options.QueuePriorityAgingIntervalSeconds
            },
            ["recovery"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["jobLockTimeoutMilliseconds"] = options.JobLockTimeoutMilliseconds,
                ["maxGenerationAttempts"] = options.MaxGenerationAttempts,
                ["maxRefundAttempts"] = options.MaxRefundAttempts,
                ["orphanQueuedJobTimeoutMilliseconds"] = options.OrphanQueuedJobTimeoutMilliseconds,
                ["providerReconciliationClaimLeaseMilliseconds"] = options.ProviderReconciliationClaimLeaseMilliseconds,
                ["refundRetryDelayMilliseconds"] = options.RefundRetryDelayMilliseconds,
                ["staleProcessingRecoveryDelayMilliseconds"] = options.StaleProcessingRecoveryDelayMilliseconds
            },
            ["waitThresholds"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["freeImageMaxEstimatedWaitSeconds"] = options.FreeImageMaxEstimatedWaitSeconds,
                ["freeVideoMaxEstimatedWaitSeconds"] = options.FreeVideoMaxEstimatedWaitSeconds,
                ["premiumImageMaxEstimatedWaitSeconds"] = options.PremiumImageMaxEstimatedWaitSeconds,
                ["premiumVideoMaxEstimatedWaitSeconds"] = options.PremiumVideoMaxEstimatedWaitSeconds,
                ["privilegedImageMaxEstimatedWaitSeconds"] = options.PrivilegedImageMaxEstimatedWaitSeconds,
                ["privilegedVideoMaxEstimatedWaitSeconds"] = options.PrivilegedVideoMaxEstimatedWaitSeconds
            }
        };
    }

    private static string NormalizeText(string? value) =>
        string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim().ToLowerInvariant();

    private static string[] NormalizeCsvSet(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return [];
        }

        return value
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(NormalizeText)
            .Where(x => x.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
    }
}

public sealed record TemplateSchedulerConfigFingerprintResult(
    string Checksum,
    string CanonicalJson,
    string SanitizedDumpJson);
