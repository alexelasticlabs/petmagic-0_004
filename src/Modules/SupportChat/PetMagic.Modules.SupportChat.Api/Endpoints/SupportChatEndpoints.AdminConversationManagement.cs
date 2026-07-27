using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> MarkAdminReadAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<MarkSupportConversationReadCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new MarkSupportConversationReadCommand(conversationId, userId, IsAdmin: true);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.MarkConversationReadAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> UpdateConversationStatusAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] UpdateSupportConversationStatusRequest request,
        [FromServices] IValidator<UpdateSupportConversationStatusCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!TryParseNamedEnum<SupportConversationStatus>(request.Status, out var status))
        {
            return ToProblem(new Error(
                "support.status_invalid",
                "Support conversation status is invalid."));
        }

        var command = new UpdateSupportConversationStatusCommand(conversationId, userId, status);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.UpdateConversationStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> AssignConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] AssignSupportConversationRequest request,
        [FromServices] IValidator<AssignSupportConversationCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new AssignSupportConversationCommand(
            conversationId,
            userId,
            request.AssignedAdminId,
            request.Reason,
            request.ExpectedVersion,
            CanAssignOthers: httpContext.User.IsInRole("Admin"));
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.AssignConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> UpdateConversationMetadataAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] UpdateSupportConversationMetadataRequest request,
        [FromServices] IValidator<UpdateSupportConversationMetadataCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!TryParseNamedEnum<SupportConversationPriority>(request.Priority, out var priority))
        {
            return ToProblem(new Error(
                "support.priority_invalid",
                "Support conversation priority is invalid."));
        }

        var command = new UpdateSupportConversationMetadataCommand(
            conversationId,
            userId,
            priority,
            request.Tags ?? []);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.UpdateConversationMetadataAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static bool TryParseNamedEnum<TEnum>(string? raw, out TEnum value)
        where TEnum : struct, Enum
    {
        value = default;

        if (string.IsNullOrWhiteSpace(raw))
        {
            return false;
        }

        var trimmed = raw.Trim();
        if (IsIntegerLiteral(trimmed))
        {
            return false;
        }

        return Enum.TryParse(trimmed, ignoreCase: true, out value)
            && Enum.IsDefined(value);
    }

    private static bool IsIntegerLiteral(string value)
    {
        var start = value[0] is '+' or '-' ? 1 : 0;
        return start < value.Length
            && value[start..].All(static character => character is >= '0' and <= '9');
    }
}
