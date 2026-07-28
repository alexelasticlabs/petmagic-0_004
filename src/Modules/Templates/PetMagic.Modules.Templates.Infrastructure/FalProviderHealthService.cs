using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalProviderHealthService(
    TemplatesDbContext dbContext,
    IHttpClientFactory httpClientFactory,
    IMemoryCache memoryCache,
    TemplatesOptions options,
    ILogger<FalProviderHealthService> logger,
    ITemplateGenerationRuntimeSettingsProvider? runtimeSettings = null) : ITemplateAiProviderHealthService
{
    public const string HttpClientName = FalAccountBillingClient.HttpClientName;

    private const string BalanceCacheKey = "templates:fal:provider-balance";
    private const int BalanceResponseMaxChars = 16 * 1024;
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

        var settings = runtimeSettings?.Current
            ?? TemplateGenerationRuntimeSettingsProvider.BuildFallback(options);
        var configuredConcurrency = settings.FalConfiguredConcurrency;
        var inflightRequests = await CountInflightProviderRequestsAsync(cancellationToken);
        if (configuredConcurrency <= 0)
        {
            RecordSnapshot(settings, inflightRequests, balanceUsd: null);
            return Reject("concurrency_unknown", mediaType, tier);
        }

        var usableConcurrency = settings.FalUsableConcurrency;
        if (usableConcurrency <= 0 || inflightRequests >= usableConcurrency)
        {
            RecordSnapshot(settings, inflightRequests, balanceUsd: null);
            return Reject("concurrency_exhausted", mediaType, tier);
        }

        var balance = runtimeSettings is null
            ? await GetCurrentBalanceUsdAsync(cancellationToken)
            : await GetPersistedCurrentBalanceUsdAsync(cancellationToken);
        RecordSnapshot(settings, inflightRequests, balance);
        if (balance is null)
        {
            return Reject("balance_unknown", mediaType, tier);
        }

        if (balance.Value <= settings.FalBalanceCriticalThresholdUsd)
        {
            return Reject("balance_critical", mediaType, tier);
        }

        return Result.Success();
    }

    private async Task<decimal?> GetPersistedCurrentBalanceUsdAsync(CancellationToken cancellationToken)
    {
        var snapshot = await dbContext.TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        return snapshot is not null
            && FalProviderHealthPolicy.IsSnapshotCurrent(snapshot.LastSuccessAtUtc, DateTime.UtcNow)
            && snapshot.BalanceUsd is not null
                ? snapshot.BalanceUsd
                : null;
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
                && (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.PreprocessingProviderRequestId != null
                    || x.MotionProviderRequestId != null),
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
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
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

            var body = await SafeHttpContentReader.ReadRawStringPrefixAsync(
                response.Content,
                cancellationToken,
                BalanceResponseMaxChars);
            using var document = JsonDocument.Parse(body);
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
            logger.LogWarning(
                "fal account billing API check failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
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

    private void RecordSnapshot(
        TemplateGenerationRuntimeSnapshot settings,
        long inflightRequests,
        decimal? balanceUsd)
    {
        TemplateGenerationMetrics.RecordFalProviderCapacitySnapshot(
            settings.FalConfiguredConcurrency,
            inflightRequests,
            balanceUsd,
            settings.FalBalanceLowThresholdUsd,
            settings.FalBalanceCriticalThresholdUsd);
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
