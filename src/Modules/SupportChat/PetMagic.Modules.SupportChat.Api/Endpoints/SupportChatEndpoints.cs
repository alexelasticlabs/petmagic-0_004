using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private const int AttachmentBatchMaxCount = 5;

    public static IEndpointRouteBuilder MapSupportChatEndpoints(this IEndpointRouteBuilder endpoints)
    {
        MapUserRoutes(endpoints);
        MapAdminRoutes(endpoints);

        return endpoints;
    }

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
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.OpenConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
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
                Take: take ?? 60,
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc,
                BeforeMessageId: beforeMessageId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }


    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromForm] IFormFile? file,
        [FromForm] string? body,
        [FromForm] string? replyToMessageId,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var formValidationErrors = ValidateSingleAttachmentFormFields(body, replyToMessageId, out var parsedReplyToMessageId);
        if (formValidationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(formValidationErrors);
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";
        var normalizedBody = string.IsNullOrWhiteSpace(body)
            ? Path.GetFileName(file.FileName)
            : body.Trim();

        var createMessageResult = await service.CreateAttachmentMessageAsync(
            new CreateSupportAttachmentMessageCommand(
                conversationId,
                userId,
                normalizedBody,
                IsAdmin: true,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType,
                ReplyToMessageId: parsedReplyToMessageId),
            cancellationToken);

        if (createMessageResult.IsFailure)
        {
            return ToProblem(createMessageResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                file.ContentType ?? "application/octet-stream",
                stream,
                file.Length),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: completeStatusResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(completeStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
        }

        return TypedResults.Ok(SignAttachmentUrls(completeStatusResult.Value, attachmentReadUrlSigner));
    }

    private static Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminAttachmentsAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<SendSupportAttachmentsCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return SendAttachmentsCoreAsync(
            httpContext,
            conversationId,
            isAdmin: true,
            validator,
            attachmentStorage,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }


    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAttachmentsCoreAsync(
        HttpContext httpContext,
        Guid conversationId,
        bool isAdmin,
        IValidator<SendSupportAttachmentsCommand> validator,
        ISupportAttachmentStorage attachmentStorage,
        ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var form = await httpContext.Request.ReadFormAsync(cancellationToken);
        var files = form.Files.Where(file => file.Length > 0).ToList();
        if (files.Count == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["files"] = ["At least one support attachment file is required."]
            });
        }

        if (files.Count > AttachmentBatchMaxCount)
        {
            return ToProblem(new Error(
                "support.attachment_batch_limit_exceeded",
                $"Cannot upload more than {AttachmentBatchMaxCount} attachments in a single message."));
        }

        var rawBody = form.TryGetValue("body", out var bodyValue)
            ? bodyValue.ToString()
            : string.Empty;
        var locale = form.TryGetValue("locale", out var localeValue)
            ? localeValue.ToString()
            : null;
        var validationErrors = new Dictionary<string, string[]>();
        if (rawBody.Length > 4000)
        {
            validationErrors["body"] = ["Support message body must be at most 4000 characters."];
        }

        Guid? replyToMessageId = null;
        if (form.TryGetValue("replyToMessageId", out var replyToMessageValue)
            && !string.IsNullOrWhiteSpace(replyToMessageValue.ToString()))
        {
            if (Guid.TryParse(replyToMessageValue.ToString(), out var parsedReplyToMessageId))
            {
                replyToMessageId = parsedReplyToMessageId;
            }
            else
            {
                validationErrors["replyToMessageId"] = ["Reply target message id must be a valid GUID."];
            }
        }

        if (validationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(validationErrors);
        }

        var storedAttachments = new List<StoredSupportAttachmentResponse>(files.Count);
        foreach (var file in files)
        {
            await using var stream = file.OpenReadStream();
            var storeResult = await attachmentStorage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    Path.GetFileName(file.FileName),
                    file.ContentType ?? "application/octet-stream",
                    stream,
                    file.Length),
                cancellationToken);

            if (storeResult.IsFailure)
            {
                await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
                return ToProblem(storeResult.Error);
            }

            storedAttachments.Add(storeResult.Value);
        }

        var command = new SendSupportAttachmentsCommand(
            conversationId,
            userId,
            rawBody.Trim(),
            isAdmin,
            storedAttachments
                .Select(attachment => new SupportMessageAttachmentInput(
                    attachment.Url,
                    attachment.ContentType,
                    attachment.FileName,
                    attachment.FileSizeBytes,
                    StorageKey: attachment.StorageKey))
                .ToList(),
            ReplyToMessageId: replyToMessageId,
            Locale: isAdmin ? null : ResolvePreferredLocale(locale, httpContext));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var sendResult = await service.SendMessageWithAttachmentsAsync(command, cancellationToken);
        if (sendResult.IsFailure)
        {
            await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
            return ToProblem(sendResult.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(sendResult.Value, attachmentReadUrlSigner));
    }

    private static Dictionary<string, string[]> ValidateSingleAttachmentFormFields(
        string? body,
        string? rawReplyToMessageId,
        out Guid? replyToMessageId)
    {
        replyToMessageId = null;
        var validationErrors = new Dictionary<string, string[]>();

        if ((body ?? string.Empty).Length > 4000)
        {
            validationErrors["body"] = ["Support message body must be at most 4000 characters."];
        }

        if (string.IsNullOrWhiteSpace(rawReplyToMessageId))
        {
            return validationErrors;
        }

        if (Guid.TryParse(rawReplyToMessageId, out var parsedReplyToMessageId))
        {
            replyToMessageId = parsedReplyToMessageId;
        }
        else
        {
            validationErrors["replyToMessageId"] = ["Reply target message id must be a valid GUID."];
        }

        return validationErrors;
    }

    private static async Task CleanupStoredAttachmentsAsync(
        IReadOnlyList<StoredSupportAttachmentResponse> storedAttachments,
        ISupportAttachmentStorage attachmentStorage)
    {
        if (storedAttachments.Count == 0)
        {
            return;
        }

        foreach (var attachment in storedAttachments)
        {
            await attachmentStorage.DeleteAsync(attachment.Url, CancellationToken.None);
        }
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> RetryAdminAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromRoute] Guid messageId,
        [FromForm] IFormFile? file,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";

        var retryStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Retry,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (retryStatusResult.IsFailure)
        {
            return ToProblem(retryStatusResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                requestedContentType,
                stream,
                file.Length),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    messageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
            return ToProblem(completeStatusResult.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(completeStatusResult.Value, attachmentReadUrlSigner));
    }


    private static async Task<Results<Ok<SupportConversationInboxPageResponse>, ProblemHttpResult>> ListAdminInboxAsync(
        HttpContext httpContext,
        [FromQuery] string[]? status,
        [FromQuery] string? assignment,
        [FromQuery] Guid? assignedTo,
        [FromQuery] string? source,
        [FromQuery] string? priority,
        [FromQuery] string? search,
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] string? sort,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var normalizedAssignment = assignment?.Trim().ToLowerInvariant();
        if (normalizedAssignment is not null && normalizedAssignment is not ("all" or "mine" or "unassigned"))
        {
            return TypedResults.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "support.assignment_invalid",
                detail: "Support inbox assignment filter is not supported.");
        }

        var requestedPage = page is null or <= 0 ? 1 : page.Value;
        var requestedPageSize = pageSize is null or <= 0 ? 50 : pageSize.Value;
        var query = normalizedAssignment switch
        {
            "mine" => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                AssignedAdminId: userId,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status),
            "unassigned" => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                UnassignedOnly: true,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status),
            _ => new ListAdminSupportInboxQuery(
                status?.FirstOrDefault(),
                AssignedAdminId: assignedTo,
                Source: source,
                Priority: priority,
                Search: search,
                Page: requestedPage,
                PageSize: requestedPageSize,
                Sort: sort,
                Statuses: status)
        };

        var result = await service.ListAdminInboxAsync(query, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminSupportInboxMetricsResponse>> GetAdminInboxMetricsAsync(
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminInboxMetricsAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> GetAdminConversationAsync(
        [FromRoute] Guid conversationId,
        [FromQuery] int? take,
        [FromQuery] DateTime? beforeMessageCreatedAtUtc,
        [FromQuery] Guid? beforeMessageId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminConversationAsync(
            conversationId,
            new SupportConversationMessagesQuery(
                Take: take ?? 60,
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc,
                BeforeMessageId: beforeMessageId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminMessageAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SendSupportMessageRequest request,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SendSupportMessageCommand(
            conversationId,
            userId,
            request.Body,
            IsAdmin: true,
            ReplyToMessageId: request.ReplyToMessageId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SendMessageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

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
            return TypedResults.ValidationProblem(validation.ToDictionary());
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
            return TypedResults.Problem(
                title: "support.status_invalid",
                detail: "Support conversation status is not supported.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var command = new UpdateSupportConversationStatusCommand(conversationId, userId, status);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
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

        var command = new AssignSupportConversationCommand(conversationId, userId, request.AssignedAdminId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
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
            return TypedResults.Problem(
                title: "support.priority_invalid",
                detail: "Support conversation priority is not supported.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var command = new UpdateSupportConversationMetadataCommand(
            conversationId,
            userId,
            priority,
            request.Tags ?? []);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
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

        return Enum.TryParse<TEnum>(trimmed, ignoreCase: true, out value)
            && Enum.IsDefined(value);
    }

    private static bool IsIntegerLiteral(string value)
    {
        var start = value[0] is '+' or '-' ? 1 : 0;
        return start < value.Length
            && value[start..].All(static character => character is >= '0' and <= '9');
    }

    private static async Task<Results<Ok<SupportTicketContextResponse>, ProblemHttpResult>> GetAdminTicketContextAsync(
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTicketContextAsync(conversationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

}
