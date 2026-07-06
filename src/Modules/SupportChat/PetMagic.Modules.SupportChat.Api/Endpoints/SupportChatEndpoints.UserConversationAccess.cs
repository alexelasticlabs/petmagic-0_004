using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> OpenConversationAsync(
        HttpContext httpContext,
        [FromBody] OpenConversationRequest? request,
        [FromServices] IValidator<OpenSupportConversationCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new OpenSupportConversationCommand(
            userId,
            request?.InitialMessage,
            request?.Priority ?? SupportConversationPriority.Normal,
            request?.Source ?? SupportConversationSource.MobileChat,
            request?.AssistantScenario,
            request?.RelatedGenerationId,
            request?.RelatedPaymentId,
            request?.RelatedSubscriptionId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.OpenConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToUserProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> GetUserConversationAsync(
        HttpContext httpContext,
        [FromQuery] int? take,
        [FromQuery] DateTime? beforeMessageCreatedAtUtc,
        [FromQuery] Guid? beforeMessageId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.GetUserConversationAsync(
            userId,
            new SupportConversationMessagesQuery(
                Take: NormalizeConversationMessagesTake(take),
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc,
                BeforeMessageId: beforeMessageId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToUserProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }
}
