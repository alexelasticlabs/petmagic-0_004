using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationProviderCallbackService(
    TemplatesOptions options,
    ITemplateGenerationProviderAttemptStore? attemptStore = null) : ITemplateGenerationProviderCallbackService
{
    public async Task<Result<FalProviderWebhookResponse>> ProcessFalWebhookAsync(
        FalProviderWebhookCommand command,
        CancellationToken cancellationToken)
    {
        if (!options.GenerationSchedulerV2Enabled || attemptStore is null)
        {
            // Legacy submissions do not include a callback token. Keep the public endpoint
            // harmless and resolvable while Scheduler V2 is disabled during rollout.
            return Result.Success(new FalProviderWebhookResponse(
                command.RequestId,
                null,
                "scheduler_disabled"));
        }

        var callbackTokenHash = string.IsNullOrWhiteSpace(command.CallbackToken)
            ? null
            : Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(command.CallbackToken.Trim())));
        var persistedPayload = JsonSerializer.Serialize(new PersistedFalWebhook(
            command.RequestId,
            command.Status,
            command.Payload,
            command.Error,
            command.ReceivedAtUtc));
        var canonicalDelivery = JsonSerializer.Serialize(new
        {
            RequestId = command.RequestId.Trim(),
            Status = command.Status.Trim(),
            command.Payload,
            command.Error
        });
        var deduplicationKey = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            canonicalDelivery)));

        await attemptStore.EnqueueWebhookAsync(
            TemplateAiProviders.Fal.ToLowerInvariant(),
            deduplicationKey,
            callbackTokenHash,
            command.RequestId,
            command.Status,
            persistedPayload,
            command.ReceivedAtUtc,
            cancellationToken);

        return Result.Success(new FalProviderWebhookResponse(
            command.RequestId,
            null,
            "queued"));
    }

    internal sealed record PersistedFalWebhook(
        string RequestId,
        string Status,
        JsonElement Payload,
        string? Error,
        DateTime ReceivedAtUtc);
}
