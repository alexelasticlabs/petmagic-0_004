namespace PetMagic.Modules.Templates.Application.Abstractions;

public sealed record ImagePreprocessResult(
    string ImageUrl,
    string? ProviderRequestId,
    double? InferenceTimeSeconds);

public sealed record ImageGenerationResult(
    string ImageUrl,
    string? ProviderRequestId,
    double? InferenceTimeSeconds);

public sealed record VideoMotionGenerationResult(
    string VideoUrl,
    string? ProviderRequestId,
    double? InferenceTimeSeconds);
