using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        return await SignUserMediaUrlsAsync(mediaStorage, options, response, cancellationToken);
    }

    internal static async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        IMediaStorage mediaStorage,
        TemplatesOptions options,
        TemplateGenerationResponse response,
        CancellationToken cancellationToken,
        bool includeProviderDiagnostics = false)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var sourceImageAsset = response.SourceImageAsset;
        if (sourceImageAsset is not null)
        {
            var signedSourceUrl = await TryCreateReadUrlAsync(mediaStorage, sourceImageAsset.Url, ttl, cancellationToken);
            sourceImageAsset = signedSourceUrl is null
                ? null
                : sourceImageAsset with { Url = signedSourceUrl };
        }

        var signedResponse = response with
        {
            SourceImageAsset = sourceImageAsset,
            NormalizedImageUrl = await TryCreateReadUrlAsync(mediaStorage, response.NormalizedImageUrl, ttl, cancellationToken),
            OutputUrl = await TryCreateReadUrlAsync(mediaStorage, response.OutputUrl, ttl, cancellationToken),
            InputPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.InputPreviewUrl, ttl, cancellationToken),
            ResultPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.ResultPreviewUrl, ttl, cancellationToken)
        };

        return includeProviderDiagnostics
            ? signedResponse
            : signedResponse with
            {
                PreprocessingProviderRequestId = null,
                MotionProviderRequestId = null,
                MotionProviderCostUsd = null
            };
    }

    private async Task<string?> TryCreateReadUrlAsync(string? assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        return await TryCreateReadUrlAsync(mediaStorage, assetUrl, ttl, cancellationToken);
    }

    private static async Task<string?> TryCreateReadUrlAsync(
        IMediaStorage mediaStorage,
        string? assetUrl,
        TimeSpan ttl,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return null;
        }

        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }
}
