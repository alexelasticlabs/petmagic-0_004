using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed record ProviderQueueSubmission(
    string RequestId,
    string StatusUrl,
    string ResponseUrl,
    string? CancelUrl = null);

internal interface IAsyncImageGenerationQueue
{
    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken);

    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        int? seed,
        string callbackToken,
        CancellationToken cancellationToken) =>
        SubmitAsync(sourceImageUrl, prompt, model, seed, cancellationToken);

    Result<ImageGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds);
}

internal interface IAsyncImagePreprocessingQueue
{
    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string originalImageUrl,
        string model,
        string prompt,
        CancellationToken cancellationToken);

    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string originalImageUrl,
        string model,
        string prompt,
        string callbackToken,
        CancellationToken cancellationToken) =>
        SubmitAsync(originalImageUrl, model, prompt, cancellationToken);

    Result<ImagePreprocessResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds);
}

internal interface IAsyncVideoMotionGenerationQueue
{
    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken);

    Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        string callbackToken,
        CancellationToken cancellationToken) =>
        SubmitAsync(
            normalizedImageUrl,
            referenceVideoUrl,
            characterOrientation,
            keepOriginalSound,
            prompt,
            model,
            seed,
            cancellationToken);

    Result<VideoMotionGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds);
}
