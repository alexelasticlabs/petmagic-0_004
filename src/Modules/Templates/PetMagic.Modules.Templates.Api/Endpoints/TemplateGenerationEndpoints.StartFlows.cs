using System.Security.Cryptography;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private static async Task<Results<Ok<CompatibleGenerationTemplatesResponse>, ProblemHttpResult>> GetCompatibleTemplatesAsync(
        HttpContext context,
        Guid resultId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await generationService.GetCompatibleTemplatesAsync(userId!.Value, resultId, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartGenerationFromResultAsync(
        HttpContext context,
        [FromBody] StartGenerationFromResultRequest request,
        [FromServices] ITemplateGenerationService generationService,
        [FromServices] ITemplatesService templatesService,
        [FromServices] IValidator<StartTemplateGenerationFromResultCommand> validator,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var templateLookup = await templatesService.GetAdminAsync(request.TemplateId, cancellationToken);
        if (templateLookup.IsFailure)
        {
            return ToClientGenerationProblem(templateLookup.Error);
        }

        var hasPremiumAccess = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        if (templateLookup.Value.IsPremium && !hasPremiumAccess)
        {
            return ToClientGenerationProblem(new Error(
                PremiumRequiredCode,
                PremiumRequiredMessage));
        }

        var command = new StartTemplateGenerationFromResultCommand(
            userId!.Value,
            request.ParentGenerationResultId,
            request.TemplateId,
            NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault()),
            await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken),
            await ResolveQueueTierAsync(context, userId.Value, cancellationToken),
            request.ExpectedTemplateVersion,
            hasPremiumAccess);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await generationService.StartFromResultAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
    }

    private static async Task<Results<Accepted<GenerateSimilarResponse>, ProblemHttpResult, ValidationProblem>> GenerateSimilarAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] GenerateSimilarRequest? request,
        [FromServices] ITemplateGenerationService generationService,
        [FromServices] IValidator<StartSimilarTemplateGenerationCommand> validator,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var command = new StartSimilarTemplateGenerationCommand(
            userId!.Value,
            generationId,
            string.IsNullOrWhiteSpace(request?.VariationStrength) ? "medium" : request!.VariationStrength!,
            NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault()),
            await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken),
            await ResolveQueueTierAsync(context, userId.Value, cancellationToken),
            await HasPremiumTemplateAccessAsync(context, userId.Value, cancellationToken));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await generationService.StartSimilarAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        var response = new GenerateSimilarResponse(result.Value.GenerationId, result.Value.Status);
        return TypedResults.Accepted($"/api/templates/generations/{response.GenerationId}", response);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartGenerationAsync(
        HttpContext context,
        Guid templateId,
        [FromForm] IFormFile? sourceImage,
        [FromForm] long? expectedTemplateVersion,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] IImagePreviewGenerator imagePreviewGenerator,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] ITemplatesService templatesService,
        [FromServices] IValidator<StartTemplateGenerationCommand> validator,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var templateLookup = await templatesService.GetAdminAsync(templateId, cancellationToken);
        if (templateLookup.IsFailure)
        {
            return ToClientGenerationProblem(templateLookup.Error);
        }

        var hasPremiumAccess = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        if (templateLookup.Value.IsPremium && !hasPremiumAccess)
        {
            return ToClientGenerationProblem(new Error(
                PremiumRequiredCode,
                PremiumRequiredMessage));
        }

        var uploadValidation = await ValidateSourceImageAsync(
            sourceImage,
            uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview),
            cancellationToken);
        var idempotencyKey = NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault());
        if (idempotencyKey?.Length > MaxIdempotencyKeyLength)
        {
            uploadValidation["Idempotency-Key"] = ["templates.idempotency_key_invalid"];
        }

        if (uploadValidation.Count > 0)
        {
            return TypedResults.ValidationProblem(uploadValidation);
        }

        var sourceImageHash = await ComputeSha256HexAsync(sourceImage!, cancellationToken);
        var requestHash = ComputeRequestHash(userId!.Value, templateId, sourceImageHash);
        var activeGenerationLimit = await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken);

        var detectedContentType = (await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage!, cancellationToken))!;
        await using var stream = sourceImage!.OpenReadStream();
        var storeResult = await mediaStorage.StoreAsync(
            new MediaUploadCommand(
                Path.GetFileName(sourceImage.FileName),
                detectedContentType,
                stream,
                sourceImage.Length),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            return ToClientGenerationProblem(storeResult.Error);
        }

        var stored = storeResult.Value;
        var preview = await imagePreviewGenerator.CreatePreviewAsync(
            stored,
            $"{Path.GetFileNameWithoutExtension(stored.FileName)}-preview.webp",
            preferredStorageKey: null,
            cancellationToken);
        try
        {
            var command = new StartTemplateGenerationCommand(
                UserId: userId!.Value,
                TemplateId: templateId,
                SourceImageAsset: new TemplateAssetCommand(stored.Url, stored.FileName, stored.ContentType, stored.FileSizeBytes, null),
                SourceImagePreviewAsset: preview is null
                    ? null
                    : new TemplateAssetCommand(preview.Url, preview.FileName, preview.ContentType, preview.FileSizeBytes, null),
                IdempotencyKey: idempotencyKey,
                RequestHash: requestHash,
                ActiveGenerationLimit: activeGenerationLimit,
                QueueTier: await ResolveQueueTierAsync(context, userId.Value, cancellationToken),
                ExpectedTemplateVersion: expectedTemplateVersion,
                HasPremiumAccess: hasPremiumAccess);

            var validation = await validator.ValidateAsync(command, cancellationToken);
            if (!validation.IsValid)
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
                return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
            }

            var result = await generationService.StartAsync(command, cancellationToken);
            if (result.IsFailure)
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
                return ToClientGenerationProblem(result.Error);
            }

            if (!string.Equals(result.Value.SourceImageAsset?.FileName, stored.FileName, StringComparison.Ordinal)
                || !string.Equals(result.Value.SourceImageAsset?.ContentType, stored.ContentType, StringComparison.OrdinalIgnoreCase))
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
            }

            return TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
        }
        catch
        {
            await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
            throw;
        }
    }

    private static async Task DeleteUploadedGenerationMediaAsync(
        IMediaStorage mediaStorage,
        StoredMediaResponse stored,
        StoredMediaResponse? preview)
    {
        IEnumerable<string> urls = preview is null
            ? [stored.Url]
            : new[] { stored.Url, preview.Url }.Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var url in urls)
        {
            await mediaStorage.DeleteAsync(url, CancellationToken.None);
        }
    }

    private static async Task<Dictionary<string, string[]>> ValidateSourceImageAsync(
        IFormFile? sourceImage,
        long maxSizeBytes,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        if (sourceImage is null || sourceImage.Length == 0)
        {
            errors[nameof(sourceImage)] = ["templates.source_image_empty"];
            return errors;
        }

        if (sourceImage.Length > maxSizeBytes)
        {
            errors[nameof(sourceImage)] = ["templates.source_image_too_large"];
        }

        if (errors.Count > 0)
        {
            return errors;
        }

        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage, cancellationToken);
        if (detectedContentType is null
            || !IsAllowedSourceImageContentType(detectedContentType)
            || !TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, sourceImage.ContentType))
        {
            errors[nameof(sourceImage)] = ["templates.source_image_type_not_allowed"];
        }

        return errors;
    }

    private static bool IsAllowedSourceImageContentType(string contentType)
    {
        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<string> ComputeSha256HexAsync(IFormFile file, CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        using var sha256 = SHA256.Create();
        var hashBytes = await sha256.ComputeHashAsync(stream, cancellationToken);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private static string ComputeRequestHash(Guid userId, Guid templateId, string sourceImageHash)
    {
        var material = $"{userId:N}:{templateId:N}:{sourceImageHash}";
        var hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(material));
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private sealed record StartGenerationFromResultRequest(
        Guid ParentGenerationResultId,
        Guid TemplateId,
        long? ExpectedTemplateVersion = null);
}
