using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalProviderHealthService(
    TemplatesDbContext dbContext,
    IHttpClientFactory httpClientFactory,
    IMemoryCache memoryCache,
    TemplatesOptions options,
    ILogger<FalProviderHealthService> logger) : ITemplateAiProviderHealthService
{
    public const string HttpClientName = "FalPlatformApi";

    private const string BalanceCacheKey = "templates:fal:provider-balance";
    private static readonly TimeSpan BalanceCacheTtl = TimeSpan.FromSeconds(60);

    public async Task<Result> EnsureCanAcceptGenerationAsync(
        string mediaType,
        string tier,
        CancellationToken cancellationToken)
    {
        if (!IsFalProvider())
        {
            return Result.Success();
        }

        var configuredConcurrency = options.FalProviderConcurrencyLimit;
        var inflightRequests = await CountInflightProviderRequestsAsync(cancellationToken);
        if (configuredConcurrency <= 0)
        {
            RecordSnapshot(configuredConcurrency, inflightRequests, balanceUsd: null);
            return Reject("concurrency_unknown", mediaType, tier);
        }

        var usableConcurrency = configuredConcurrency - options.FalProviderReservedConcurrency;
        if (usableConcurrency <= 0 || inflightRequests >= usableConcurrency)
        {
            RecordSnapshot(configuredConcurrency, inflightRequests, balanceUsd: null);
            return Reject("concurrency_exhausted", mediaType, tier);
        }

        var balance = await GetCurrentBalanceUsdAsync(cancellationToken);
        RecordSnapshot(configuredConcurrency, inflightRequests, balance);
        if (balance is null)
        {
            return Reject("balance_unknown", mediaType, tier);
        }

        if (balance.Value <= options.FalProviderBalanceCriticalThresholdUsd)
        {
            return Reject("balance_critical", mediaType, tier);
        }

        return Result.Success();
    }

    private bool IsFalProvider()
    {
        return string.Equals(options.AiProvider, TemplateAiProviders.Fal, StringComparison.OrdinalIgnoreCase);
    }

    private Task<long> CountInflightProviderRequestsAsync(CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.Status == TemplateGenerationStatus.ProviderQueued
                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                && x.ProviderCompletedAtUtc == null
                && (x.PreprocessingProviderRequestId != null || x.MotionProviderRequestId != null),
                cancellationToken);
    }

    private async Task<decimal?> GetCurrentBalanceUsdAsync(CancellationToken cancellationToken)
    {
        if (memoryCache.TryGetValue<decimal?>(BalanceCacheKey, out var cached))
        {
            return cached;
        }

        if (string.IsNullOrWhiteSpace(options.Fal.ApiKey))
        {
            return null;
        }

        try
        {
            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                "https://api.fal.ai/v1/account/billing?expand=credits");
            request.Headers.Authorization = new AuthenticationHeaderValue("Key", options.Fal.ApiKey);

            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .SendAsync(request, cancellationToken);
            if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            {
                logger.LogWarning("fal account billing API rejected the configured API key. StatusCode={StatusCode}", response.StatusCode);
                memoryCache.Set<decimal?>(BalanceCacheKey, null, TimeSpan.FromSeconds(15));
                return null;
            }

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("fal account billing API check failed. StatusCode={StatusCode}", response.StatusCode);
                memoryCache.Set<decimal?>(BalanceCacheKey, null, TimeSpan.FromSeconds(15));
                return null;
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var balance = ReadBalanceUsd(document.RootElement);
            memoryCache.Set(BalanceCacheKey, balance, BalanceCacheTtl);
            return balance;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "fal account billing API check failed.");
            memoryCache.Set<decimal?>(BalanceCacheKey, null, TimeSpan.FromSeconds(15));
            return null;
        }
    }

    private static decimal? ReadBalanceUsd(JsonElement root)
    {
        if (!root.TryGetProperty("credits", out var credits)
            || credits.ValueKind != JsonValueKind.Object
            || !credits.TryGetProperty("current_balance", out var balanceElement))
        {
            return null;
        }

        return balanceElement.ValueKind switch
        {
            JsonValueKind.Number when balanceElement.TryGetDecimal(out var numeric) => numeric,
            JsonValueKind.String when decimal.TryParse(
                balanceElement.GetString(),
                System.Globalization.NumberStyles.Number,
                System.Globalization.CultureInfo.InvariantCulture,
                out var parsed) => parsed,
            _ => null
        };
    }

    private void RecordSnapshot(int configuredConcurrency, long inflightRequests, decimal? balanceUsd)
    {
        TemplateGenerationMetrics.RecordFalProviderCapacitySnapshot(
            configuredConcurrency,
            inflightRequests,
            balanceUsd,
            options.FalProviderBalanceLowThresholdUsd,
            options.FalProviderBalanceCriticalThresholdUsd);
    }

    private static Result Reject(string reason, string mediaType, string tier)
    {
        TemplateGenerationMetrics.RecordFalProviderRejectedDueToCapacity(reason, mediaType, tier);
        TemplateGenerationMetrics.RecordJobRejected(reason, mediaType, tier);
        return Result.Failure(new Error(
            TemplatesErrors.ProviderCapacityUnavailable.Code,
            TemplatesErrors.ProviderCapacityUnavailable.Message,
            new Dictionary<string, object?>
            {
                ["reason"] = reason,
                ["mediaType"] = mediaType,
                ["tier"] = tier,
                ["canRetry"] = true
            }));
    }
}
