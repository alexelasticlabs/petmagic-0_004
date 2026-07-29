using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalImagePreprocessor(FalQueueClient queueClient) : IImagePreprocessor, IAsyncImagePreprocessingQueue
{
    public async Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
    {
        var input = new
        {
            prompt,
            image_urls = new[] { originalImageUrl },
            num_images = 1,
            output_format = "png"
        };

        var result = await queueClient.RunAsync(
            model,
            input,
            new FalQueueStageKind("image", FalQueueStages.ImagePreprocessing),
            cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<ImagePreprocessResult>(result.Error);
        }

        using var document = result.Value.Response;
        return Complete(document.RootElement, result.Value.RequestId, result.Value.InferenceTimeSeconds);
    }

    public async Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string originalImageUrl,
        string model,
        string prompt,
        CancellationToken cancellationToken) =>
        await SubmitAsync(originalImageUrl, model, prompt, callbackToken: null, cancellationToken);

    public async Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string originalImageUrl,
        string model,
        string prompt,
        string? callbackToken,
        CancellationToken cancellationToken)
    {
        var input = BuildInput(originalImageUrl, prompt);
        var result = await queueClient.SubmitAsync(
            model,
            input,
            new FalQueueStageKind("image", FalQueueStages.ImagePreprocessing),
            callbackToken,
            cancellationToken);
        return result.IsFailure
            ? Result.Failure<ProviderQueueSubmission>(result.Error)
            : Result.Success(new ProviderQueueSubmission(
                result.Value.RequestId,
                result.Value.StatusUrl.ToString(),
                result.Value.ResponseUrl.ToString(),
                result.Value.CancelUrl.ToString()));
    }

    public Result<ImagePreprocessResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
    {
        if (FalGenerationResponseParser.TryReadFirstImageUrl(response, out var imageUrl))
        {
            return Result.Success(new ImagePreprocessResult(imageUrl, requestId, inferenceTimeSeconds));
        }

        TemplateGenerationMetrics.RecordAiProviderError("fal", "response.parse", TemplatesErrors.AiProviderFailed.Code, "image_preprocessing");
        return Result.Failure<ImagePreprocessResult>(TemplatesErrors.AiProviderFailed);
    }

    private static object BuildInput(string originalImageUrl, string prompt)
    {
        return new
        {
            prompt,
            image_urls = new[] { originalImageUrl },
            num_images = 1,
            output_format = "png"
        };
    }
}
