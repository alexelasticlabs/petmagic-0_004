using FluentValidation;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.WebUtilities;

using PetMagic.BuildingBlocks.Images;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static partial class AuthEndpoints
{

    private static async Task<Results<Ok<UserProfileResponse>, ProblemHttpResult>> MeAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.GetCurrentUserAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> UpdateMeProfileAsync(
        HttpContext context,
        UpdateCurrentUserProfileCommand command,
        IValidator<UpdateCurrentUserProfileCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.UpdateCurrentUserProfileAsync(userId, command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteMeAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.DeleteCurrentUserAsync(new DeleteCurrentUserCommand(userId), cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        DeleteRefreshTokenCookie(context);
        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> AcceptCurrentLegalDocumentsAsync(
        HttpContext context,
        AcceptLegalDocumentsCommand command,
        IValidator<AcceptLegalDocumentsCommand> validator,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.AcceptLegalDocumentsAsync(userId, command, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<LinkedAccountResponse>>, ProblemHttpResult>> GetLinkedAccountsAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.GetLinkedAccountsAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status404NotFound);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<ExternalLinkPreparationResponse>, ProblemHttpResult>> PrepareLinkedAccountAsync(
        string provider,
        HttpContext context,
        [FromServices] IExternalAccountLinkStore linkStore,
        IAuthenticationSchemeProvider authenticationSchemes,
        CancellationToken cancellationToken)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return IdentityClientProblems.ExternalProviderInvalid();
        }

        if (await authenticationSchemes.GetSchemeAsync(normalizedProvider) is null)
        {
            return ToExternalAuthProblem("auth.external_not_configured", StatusCodes.Status404NotFound);
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(new ExternalLinkPreparationResponse(
            await linkStore.CreateAsync(userId, cancellationToken)));
    }

    private static async Task<Results<Ok<IReadOnlyList<LinkedAccountResponse>>, ValidationProblem, ProblemHttpResult>> GoogleNativeLinkAsync(
        HttpContext context,
        GoogleNativeLinkCommand command,
        IValidator<GoogleNativeLinkCommand> validator,
        IGoogleIdentityTokenVerifier verifier,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var verification = await verifier.VerifyIdTokenAsync(command.IdToken, cancellationToken);
        if (verification.IsFailure)
        {
            var statusCode = string.Equals(verification.Error.Code, "auth.external_not_configured", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status401Unauthorized;

            return ToExternalAuthProblem(verification.Error.Code, statusCode);
        }

        var result = await service.LinkExternalLoginAsync(userId, verification.Value, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<LinkedAccountResponse>>, ProblemHttpResult>> UnlinkLinkedAccountAsync(
        string provider,
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        var normalizedProvider = NormalizeExternalProvider(provider);
        if (normalizedProvider is null)
        {
            return IdentityClientProblems.ExternalProviderInvalid();
        }

        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.UnlinkExternalLoginAsync(userId, normalizedProvider, cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<UserProfileResponse>, ValidationProblem, ProblemHttpResult>> UpdateAvatarAsync(
        HttpContext context,
        IIdentityService service,
        [FromForm] IFormFile? file,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var validation = await ValidateAvatarFileAsync(file, cancellationToken);
        if (validation.Errors.Count > 0)
        {
            return ToAvatarValidationProblem(validation.Errors);
        }

        await using var stream = file!.OpenReadStream();
        var result = await service.UpdateUserAvatarAsync(
            new UpdateUserAvatarCommand(
                userId,
                Path.GetFileName(file.FileName),
                validation.DetectedContentType!,
                stream,
                file.Length),
            cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static ValidationProblem ToAvatarValidationProblem(Dictionary<string, string[]> errors)
    {
        return TypedResults.ValidationProblem(errors.ToDictionary(
            pair => pair.Key,
            pair => pair.Value.Select(ToSafeAvatarValidationCode).ToArray()));
    }

    private static string ToSafeAvatarValidationCode(string code)
    {
        return code switch
        {
            "users.avatar_file_required" => code,
            "users.avatar_file_too_large" => code,
            "users.avatar_content_type_not_allowed" => code,
            _ => "validation.invalid"
        };
    }

    private static async Task<(Dictionary<string, string[]> Errors, string? DetectedContentType)> ValidateAvatarFileAsync(
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        if (file is null || file.Length == 0)
        {
            errors[nameof(file)] = ["users.avatar_file_required"];
            return (errors, null);
        }

        if (file.Length > UploadedMediaPolicies.Avatar.MaxFileSizeBytes)
        {
            errors[nameof(file)] = ["users.avatar_file_too_large"];
            return (errors, null);
        }

        var detectedContentType = await DetectAvatarContentTypeAsync(file, cancellationToken);
        if (detectedContentType is null
            || !IsAllowedAvatarContentType(detectedContentType)
            || !MatchesDeclaredAvatarContentType(detectedContentType, file.ContentType))
        {
            errors[nameof(file)] = ["users.avatar_content_type_not_allowed"];
        }

        return (errors, detectedContentType);
    }

    private static async Task<string?> DetectAvatarContentTypeAsync(IFormFile file, CancellationToken cancellationToken)
    {
        const int headerBytesToRead = 16;
        var buffer = new byte[Math.Min(headerBytesToRead, (int)Math.Min(file.Length, headerBytesToRead))];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
        return DetectAvatarContentType(buffer.AsSpan(0, read));
    }

    private static string? DetectAvatarContentType(ReadOnlySpan<byte> header)
    {
        if (header.Length >= 3
            && header[0] == 0xFF
            && header[1] == 0xD8
            && header[2] == 0xFF)
        {
            return "image/jpeg";
        }

        if (header.Length >= 8
            && header[0] == 0x89
            && header[1] == 0x50
            && header[2] == 0x4E
            && header[3] == 0x47
            && header[4] == 0x0D
            && header[5] == 0x0A
            && header[6] == 0x1A
            && header[7] == 0x0A)
        {
            return "image/png";
        }

        if (header.Length >= 12
            && header[0] == 0x52
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x46
            && header[8] == 0x57
            && header[9] == 0x45
            && header[10] == 0x42
            && header[11] == 0x50)
        {
            return "image/webp";
        }

        if (header.Length >= 6
            && header[0] == 0x47
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x38
            && (header[4] == 0x37 || header[4] == 0x39)
            && header[5] == 0x61)
        {
            return "image/gif";
        }

        if (header.Length >= 12
            && header[4] == 0x66
            && header[5] == 0x74
            && header[6] == 0x79
            && header[7] == 0x70)
        {
            var brand = string.Create(4, header, static (chars, bytes) =>
            {
                for (var i = 0; i < chars.Length; i++)
                {
                    chars[i] = (char)bytes[8 + i];
                }
            });

            if (string.Equals(brand, "heic", StringComparison.OrdinalIgnoreCase)
                || string.Equals(brand, "heix", StringComparison.OrdinalIgnoreCase)
                || string.Equals(brand, "hevc", StringComparison.OrdinalIgnoreCase)
                || string.Equals(brand, "hevx", StringComparison.OrdinalIgnoreCase)
                || string.Equals(brand, "heif", StringComparison.OrdinalIgnoreCase)
                || string.Equals(brand, "mif1", StringComparison.OrdinalIgnoreCase))
            {
                return "image/heic";
            }
        }

        return null;
    }

    private static bool IsAllowedAvatarContentType(string contentType)
    {
        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/gif", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/heic", StringComparison.OrdinalIgnoreCase);
    }

    private static bool MatchesDeclaredAvatarContentType(string detectedContentType, string? declaredContentType)
    {
        var normalizedDeclared = NormalizeContentType(declaredContentType);
        if (string.IsNullOrWhiteSpace(normalizedDeclared)
            || string.Equals(normalizedDeclared, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(detectedContentType, normalizedDeclared, StringComparison.OrdinalIgnoreCase)
            || (string.Equals(detectedContentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "image/jpg", StringComparison.OrdinalIgnoreCase))
            || (string.Equals(detectedContentType, "image/heic", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "image/heif", StringComparison.OrdinalIgnoreCase));
    }

    private static string NormalizeContentType(string? contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return string.Empty;
        }

        var semicolonIndex = contentType.IndexOf(';');
        var normalized = semicolonIndex >= 0 ? contentType[..semicolonIndex] : contentType;
        return normalized.Trim().ToLowerInvariant();
    }

    private static async Task<Results<Ok<UserProfileResponse>, ProblemHttpResult>> RemoveAvatarAsync(
        HttpContext context,
        IIdentityService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(context, out var userId, out var invalidSubjectProblem))
        {
            return invalidSubjectProblem!;
        }

        var result = await service.RemoveUserAvatarAsync(new RemoveUserAvatarCommand(userId), cancellationToken);
        if (result.IsFailure)
        {
            return IdentityClientProblems.ToProblem(result.Error, StatusCodes.Status400BadRequest);
        }

        ApplySensitiveNoStoreHeaders(context);
        return TypedResults.Ok(result.Value);
    }

}
