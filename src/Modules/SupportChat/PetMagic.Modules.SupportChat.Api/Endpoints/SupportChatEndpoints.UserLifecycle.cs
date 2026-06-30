using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> MarkUserReadAsync(
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

        var command = new MarkSupportConversationReadCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.MarkConversationReadAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> ResolveUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<ResolveSupportConversationCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new ResolveSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ResolveConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> CloseUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<CloseSupportConversationCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new CloseSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CloseConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> ReopenUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<ReopenSupportConversationCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new ReopenSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ReopenConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> SubmitUserConversationFeedbackAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SubmitSupportConversationFeedbackRequest request,
        [FromServices] IValidator<SubmitSupportConversationFeedbackCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SubmitSupportConversationFeedbackCommand(conversationId, userId, request.Rating, request.Comment);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SubmitConversationFeedbackAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext httpContext,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] ISupportPushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await pushTokenService.RegisterAsync(
            new RegisterSupportPushTokenCommand(
                userId,
                request.Token,
                request.Platform,
                request.DeviceId,
                request.AppVersion,
                request.Locale),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext httpContext,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] ISupportPushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await pushTokenService.UnregisterAsync(
            new UnregisterSupportPushTokenCommand(userId, request.Token),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }
}
