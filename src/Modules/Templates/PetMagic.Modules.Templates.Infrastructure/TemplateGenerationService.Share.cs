using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private string CreateGenerationShareToken(Guid ownerUserId, Guid generationId, bool cleanAccess)
    {
        var payload = new GenerationShareTokenPayload(generationId, ownerUserId, cleanAccess, DateTime.UtcNow);
        var protectedPayload = _generationShareProtector.Protect(
            Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload)));
        return EncodeShareToken(protectedPayload);
    }

    private Result<GenerationShareTokenPayload> TryReadGenerationShareToken(string shareToken)
    {
        if (string.IsNullOrWhiteSpace(shareToken))
        {
            return Result.Failure<GenerationShareTokenPayload>(TemplatesErrors.GenerationJobNotFound);
        }

        try
        {
            var protectedPayload = DecodeShareToken(shareToken);
            var payloadJson = Encoding.UTF8.GetString(_generationShareProtector.Unprotect(protectedPayload));
            var payload = JsonSerializer.Deserialize<GenerationShareTokenPayload>(payloadJson);
            return payload is null
                    || payload.GenerationId == Guid.Empty
                    || payload.OwnerUserId == Guid.Empty
                ? Result.Failure<GenerationShareTokenPayload>(TemplatesErrors.GenerationJobNotFound)
                : Result.Success(payload);
        }
        catch (Exception ex) when (ex is CryptographicException or JsonException or ArgumentException or FormatException)
        {
            return Result.Failure<GenerationShareTokenPayload>(TemplatesErrors.GenerationJobNotFound);
        }
    }

    private static string EncodeShareToken(byte[] protectedPayload)
    {
        return Convert.ToBase64String(protectedPayload)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static byte[] DecodeShareToken(string shareToken)
    {
        var token = Uri.UnescapeDataString(shareToken.Trim())
            .Replace('-', '+')
            .Replace('_', '/');

        token = token.PadRight(token.Length + ((4 - token.Length % 4) % 4), '=');
        return Convert.FromBase64String(token);
    }

    private string BuildGenerationShareUrl(string shareToken)
    {
        var publicBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        return $"{publicBaseUrl}/share/generation/{Uri.EscapeDataString(shareToken)}";
    }

    public async Task<Result<PublicGalleryShareResponse>> GetPublicShareAsync(
        string shareToken,
        CancellationToken cancellationToken)
    {
        var token = TryReadGenerationShareToken(shareToken);
        if (token.IsFailure)
        {
            return Result.Failure<PublicGalleryShareResponse>(token.Error);
        }

        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Include(x => x.MediaRecords)
            .FirstOrDefaultAsync(
                x => x.Id == token.Value.GenerationId
                    && x.UserId == token.Value.OwnerUserId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (job is null)
        {
            return Result.Failure<PublicGalleryShareResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        var signedResponse = await MapResponseWithQueueMetricsAsync(
            job,
            cancellationToken,
            token.Value.CleanAccess);
        var media = await MapGalleryMediaAsync(job, signedResponse, cancellationToken);
        var exposesResult = media.State == GalleryMediaState.resultReady;
        var fileName = exposesResult
            ? BuildSharedGenerationFileName(job, media.MediaType)
            : null;
        var contentType = exposesResult
            ? ResolveSharedGenerationContentType(media.MediaType)
            : null;

        return Result.Success(new PublicGalleryShareResponse(
            shareToken,
            media.State.ToString(),
            media.MediaType,
            signedResponse.TemplateTitle,
            exposesResult ? media.ResultUrl : null,
            exposesResult ? media.ResultExpiresAtUtc : null,
            media.HasWatermark,
            fileName,
            contentType,
            media.ReasonCode,
            media.UserMessageKey));
    }

    private static string BuildSharedGenerationFileName(TemplateGenerationJob job, string mediaType)
    {
        var extension = mediaType.Equals("video", StringComparison.OrdinalIgnoreCase)
            ? "mp4"
            : "png";
        return $"petmagic-{job.Id:N}.{extension}";
    }

    private static string ResolveSharedGenerationContentType(string mediaType)
    {
        return mediaType.Equals("video", StringComparison.OrdinalIgnoreCase)
            ? "video/mp4"
            : "image/png";
    }

    private sealed record GenerationShareTokenPayload(
        Guid GenerationId,
        Guid OwnerUserId,
        bool CleanAccess,
        DateTime CreatedAtUtc);
}
