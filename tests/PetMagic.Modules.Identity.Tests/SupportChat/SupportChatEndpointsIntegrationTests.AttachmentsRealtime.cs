using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed partial class SupportChatEndpointsIntegrationTests
{
    [Fact]
    public async Task UserAttachmentEndpoint_ShouldUploadImageAndExposeAttachmentMetadata()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with screenshot", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "file", "issue.png");
        form.Add(new StringContent("Screenshot of the payment error"), "body");

        using var response = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            form);

        await AssertSuccessAsync(response);

        var message = (await response.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.False(message.IsFromAdmin);
        Assert.Equal("Screenshot of the payment error", message.Body);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);
        Assert.Null(message.AttachmentUploadErrorCode);
        Assert.Null(message.PendingAttachment);
        var uploadedAttachment = Assert.Single(message.Attachments);
        Assert.Equal("issue.png", uploadedAttachment.FileName);
        Assert.Equal("image/png", uploadedAttachment.MimeType);
        Assert.False(string.IsNullOrWhiteSpace(uploadedAttachment.FileUrl));
        AssertSignedSupportAttachmentUrl(uploadedAttachment.FileUrl);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.Attachments.Count > 0);
        var conversationAttachment = Assert.Single(attachmentMessage.Attachments);
        Assert.Equal("issue.png", conversationAttachment.FileName);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
        AssertSignedSupportAttachmentUrl(conversationAttachment.FileUrl);
    }

    [Fact]
    public async Task UserAttachmentEndpoint_ShouldUploadVideoAndExposeAttachmentMetadata()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with uploaded video", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("video/mp4");
        form.Add(fileContent, "file", "issue.mp4");
        form.Add(new StringContent("Video of the issue"), "body");

        using var response = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            form);

        await AssertSuccessAsync(response);

        var message = (await response.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.False(message.IsFromAdmin);
        Assert.Equal("Video of the issue", message.Body);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);
        Assert.Null(message.AttachmentUploadErrorCode);
        Assert.Null(message.PendingAttachment);
        var uploadedAttachment = Assert.Single(message.Attachments);
        Assert.Equal("issue.mp4", uploadedAttachment.FileName);
        Assert.Equal("video/mp4", uploadedAttachment.MimeType);
        Assert.False(string.IsNullOrWhiteSpace(uploadedAttachment.FileUrl));
        AssertSignedSupportAttachmentUrl(uploadedAttachment.FileUrl);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.Attachments.Count > 0);
        var conversationAttachment = Assert.Single(attachmentMessage.Attachments);
        Assert.Equal("issue.mp4", conversationAttachment.FileName);
        Assert.Equal("video/mp4", conversationAttachment.MimeType);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
        AssertSignedSupportAttachmentUrl(conversationAttachment.FileUrl);
    }

    [Fact]
    public async Task AttachmentBatchEndpoint_ShouldValidateCheapFormFieldsBeforeStoringFiles()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with batch upload", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "files", "issue.png");
        form.Add(new StringContent(new string('x', 4001)), "body");
        form.Add(new StringContent("not-a-guid"), "replyToMessageId");

        using var response = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/messages/attachments",
            form);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("body", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("replyToMessageId", body, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, application.AttachmentStorage.StoreCallCount);
    }

    [Fact]
    public async Task UserSingleAttachmentEndpoint_ShouldValidateCheapFormFieldsBeforeStoringFiles()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with single upload", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "file", "issue.png");
        form.Add(new StringContent(new string('x', 4001)), "body");
        form.Add(new StringContent("not-a-guid"), "replyToMessageId");

        using var response = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            form);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("body", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("replyToMessageId", body, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, application.AttachmentStorage.StoreCallCount);
    }

    [Fact]
    public async Task UserAttachmentEndpoint_ShouldSanitizeStorageFailureCode()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        application.AttachmentStorage.FailNextStore("support.attachment_storage_failed token=attachment-storage-secret");

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need failed upload proof", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "file", "issue.png");
        form.Add(new StringContent("Upload should fail safely"), "body");

        using var response = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            form);

        await AssertSuccessAsync(response);
        var message = (await response.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.Equal("Failed", message.AttachmentUploadStatus);
        Assert.Equal("support.attachment_storage_failed", message.AttachmentUploadErrorCode);
        Assert.DoesNotContain("attachment-storage-secret", message.AttachmentUploadErrorCode, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(message.Attachments);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}");
        var persistedMessage = Assert.Single(conversation.Messages, item => item.MessageId == message.MessageId);
        Assert.Equal("support.attachment_storage_failed", persistedMessage.AttachmentUploadErrorCode);
        Assert.DoesNotContain("attachment-storage-secret", persistedMessage.AttachmentUploadErrorCode, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task UserMessageEndpoint_ShouldAppendLocalizedAutomaticReply_ForFirstMessage()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest(null, SupportConversationPriority.Normal));

        var sent = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Bonjour", "fr-FR"));

        Assert.False(sent.IsFromAdmin);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation");

        var userMessage = Assert.Single(conversation.Messages, message => message.SenderType == "User");
        Assert.Equal("Bonjour", userMessage.Body);
        var botMessage = Assert.Single(conversation.Messages, message => message.SenderType == "Bot");
        Assert.Equal(
            "Message reçu. Le support répondra dans ce chat.",
            botMessage.Body);
        Assert.True(botMessage.IsFromAdmin);
        Assert.True(botMessage.IsRead);
    }

    [Fact]
    public async Task AdminSingleAttachmentEndpoint_ShouldValidateCheapFormFieldsBeforeStoringFiles()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Need admin upload review", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "file", "admin-screenshot.png");
        form.Add(new StringContent(new string('x', 4001)), "body");
        form.Add(new StringContent("not-a-guid"), "replyToMessageId");

        using var response = await application.CreateClient(AdminId, "Admin").PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/attachments",
            form);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("body", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("replyToMessageId", body, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, application.AttachmentStorage.StoreCallCount);
    }

    [Fact]
    public async Task AdminAttachmentEndpoint_ShouldUploadImageAndExposeAttachmentMetadata()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Need screenshot review", SupportConversationPriority.Normal));

        using var form = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(fileContent, "file", "admin-screenshot.png");
        form.Add(new StringContent("Screenshot attached"), "body");

        using var response = await application.CreateClient(AdminId, "Admin").PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/attachments",
            form);

        await AssertSuccessAsync(response);

        var message = (await response.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.True(message.IsFromAdmin);
        Assert.Equal("Screenshot attached", message.Body);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);
        Assert.Null(message.PendingAttachment);
        var uploadedAttachment = Assert.Single(message.Attachments);
        Assert.Equal("admin-screenshot.png", uploadedAttachment.FileName);
        Assert.Equal("image/png", uploadedAttachment.MimeType);
        Assert.False(string.IsNullOrWhiteSpace(uploadedAttachment.FileUrl));
        AssertSignedSupportAttachmentUrl(uploadedAttachment.FileUrl);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.Attachments.Count > 0);
        var conversationAttachment = Assert.Single(attachmentMessage.Attachments);
        Assert.Equal("admin-screenshot.png", conversationAttachment.FileName);
        Assert.Equal("image/png", conversationAttachment.MimeType);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
        AssertSignedSupportAttachmentUrl(conversationAttachment.FileUrl);
    }

    [Fact]
    public async Task UserAttachmentRetryEndpoint_ShouldRetryFailedAttachmentAndUploadImage()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need retry flow", SupportConversationPriority.Normal));

        using var failedForm = new MultipartFormDataContent();
        var failedContent = new ByteArrayContent([0x25, 0x50, 0x44, 0x46]);
        failedContent.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        failedForm.Add(failedContent, "file", "invoice.pdf");
        failedForm.Add(new StringContent("First upload should fail"), "body");

        using var failedResponse = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            failedForm);

        await AssertSuccessAsync(failedResponse);
        var failedMessage = (await failedResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.Equal("Failed", failedMessage.AttachmentUploadStatus);
        Assert.Equal("support.attachment_content_type_not_allowed", failedMessage.AttachmentUploadErrorCode);
        Assert.Empty(failedMessage.Attachments);
        Assert.NotNull(failedMessage.PendingAttachment);
        Assert.Equal("invoice.pdf", failedMessage.PendingAttachment!.FileName);
        Assert.Equal("application/pdf", failedMessage.PendingAttachment.MimeType);

        using var retryForm = new MultipartFormDataContent();
        var retryContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        retryContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        retryForm.Add(retryContent, "file", "fixed.png");

        using var retryResponse = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/messages/{failedMessage.MessageId}/attachment/retry",
            retryForm);

        await AssertSuccessAsync(retryResponse);
        var retriedMessage = (await retryResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.Equal(failedMessage.MessageId, retriedMessage.MessageId);
        Assert.Equal("Uploaded", retriedMessage.AttachmentUploadStatus);
        Assert.Null(retriedMessage.AttachmentUploadErrorCode);
        Assert.Null(retriedMessage.PendingAttachment);
        var retriedAttachment = Assert.Single(retriedMessage.Attachments);
        Assert.Equal("fixed.png", retriedAttachment.FileName);
        Assert.False(string.IsNullOrWhiteSpace(retriedAttachment.FileUrl));
    }

    [Fact]
    public async Task UserAttachmentRetryEndpoint_WhenFinalizeFails_ShouldDeleteStoredFileAndKeepFailedState()
    {
        await using var application = await SupportChatTestApplication.CreateAsync(services =>
        {
            services.RemoveAll<ISupportChatService>();
            services.AddScoped<ISupportChatService>(serviceProvider =>
                new FailUploadedAttachmentStatusSupportChatService(serviceProvider.GetRequiredService<SupportChatService>()));
        });

        var userClient = application.CreateClient(UserId, "User");
        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need retry finalize fallback", SupportConversationPriority.Normal));

        using var failedForm = new MultipartFormDataContent();
        var failedContent = new ByteArrayContent([0x25, 0x50, 0x44, 0x46]);
        failedContent.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        failedForm.Add(failedContent, "file", "invoice.pdf");
        failedForm.Add(new StringContent("First upload should fail"), "body");

        using var failedResponse = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/attachments",
            failedForm);

        await AssertSuccessAsync(failedResponse);
        var failedMessage = (await failedResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;

        using var retryForm = new MultipartFormDataContent();
        var retryContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        retryContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        retryForm.Add(retryContent, "file", "fixed.png");

        using var retryResponse = await userClient.PostAsync(
            $"/api/support/conversation/{created.ConversationId}/messages/{failedMessage.MessageId}/attachment/retry",
            retryForm);

        await AssertSuccessAsync(retryResponse);
        var retriedMessage = (await retryResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.Equal("Failed", retriedMessage.AttachmentUploadStatus);
        Assert.Equal("support.attachment_finalize_failed", retriedMessage.AttachmentUploadErrorCode);
        Assert.Empty(retriedMessage.Attachments);
        Assert.NotNull(retriedMessage.PendingAttachment);
        Assert.Equal("fixed.png", retriedMessage.PendingAttachment!.FileName);
        Assert.Equal("image/png", retriedMessage.PendingAttachment.MimeType);
        Assert.Equal(2, application.AttachmentStorage.StoreCallCount);
        Assert.Equal(1, application.AttachmentStorage.DeleteCallCount);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/tickets/{created.ConversationId}");
        var persistedMessage = Assert.Single(conversation.Messages, message => message.MessageId == failedMessage.MessageId);
        Assert.Equal("Failed", persistedMessage.AttachmentUploadStatus);
        Assert.Equal("support.attachment_finalize_failed", persistedMessage.AttachmentUploadErrorCode);
        Assert.Empty(persistedMessage.Attachments);
    }

    [Fact]
    public async Task AdminAttachmentRetryEndpoint_WhenFinalizeFails_ShouldDeleteStoredFileAndKeepFailedState()
    {
        await using var application = await SupportChatTestApplication.CreateAsync(services =>
        {
            services.RemoveAll<ISupportChatService>();
            services.AddScoped<ISupportChatService>(serviceProvider =>
                new FailUploadedAttachmentStatusSupportChatService(serviceProvider.GetRequiredService<SupportChatService>()));
        });

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Need admin retry finalize fallback", SupportConversationPriority.Normal));

        using var failedForm = new MultipartFormDataContent();
        var failedContent = new ByteArrayContent([0x25, 0x50, 0x44, 0x46]);
        failedContent.Headers.ContentType = new MediaTypeHeaderValue("application/pdf");
        failedForm.Add(failedContent, "file", "invoice.pdf");
        failedForm.Add(new StringContent("First admin upload should fail"), "body");

        using var failedResponse = await application.CreateClient(AdminId, "Admin").PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/attachments",
            failedForm);

        await AssertSuccessAsync(failedResponse);
        var failedMessage = (await failedResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;

        using var retryForm = new MultipartFormDataContent();
        var retryContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        retryContent.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        retryForm.Add(retryContent, "file", "fixed.png");

        using var retryResponse = await application.CreateClient(AdminId, "Admin").PostAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/messages/{failedMessage.MessageId}/attachment/retry",
            retryForm);

        await AssertSuccessAsync(retryResponse);
        var retriedMessage = (await retryResponse.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.Equal("Failed", retriedMessage.AttachmentUploadStatus);
        Assert.Equal("support.attachment_finalize_failed", retriedMessage.AttachmentUploadErrorCode);
        Assert.Empty(retriedMessage.Attachments);
        Assert.NotNull(retriedMessage.PendingAttachment);
        Assert.Equal("fixed.png", retriedMessage.PendingAttachment!.FileName);
        Assert.Equal("image/png", retriedMessage.PendingAttachment.MimeType);
        Assert.Equal(2, application.AttachmentStorage.StoreCallCount);
        Assert.Equal(1, application.AttachmentStorage.DeleteCallCount);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation");
        var persistedMessage = Assert.Single(conversation.Messages, message => message.MessageId == failedMessage.MessageId);
        Assert.Equal("Failed", persistedMessage.AttachmentUploadStatus);
        Assert.Equal("support.attachment_finalize_failed", persistedMessage.AttachmentUploadErrorCode);
        Assert.Empty(persistedMessage.Attachments);
    }

    [Theory]
    [InlineData("NotARealStatus")]
    [InlineData("1")]
    [InlineData("-1")]
    public async Task UpdateStatusEndpoint_ShouldRejectInvalidStatusValues(string status)
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Wrong charge", SupportConversationPriority.Normal));

        using var invalidStatusResponse = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest(status));

        Assert.Equal(HttpStatusCode.BadRequest, invalidStatusResponse.StatusCode);
    }

    [Theory]
    [InlineData("1")]
    [InlineData("-1")]
    public async Task UpdateMetadataEndpoint_ShouldRejectNumericPriorityValues(string priority)
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Wrong charge", SupportConversationPriority.Normal));

        using var invalidPriorityResponse = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/tickets/{created.ConversationId}/metadata",
            new { priority, tags = Array.Empty<string>() });

        Assert.Equal(HttpStatusCode.BadRequest, invalidPriorityResponse.StatusCode);

        var body = await invalidPriorityResponse.Content.ReadAsStringAsync();
        Assert.Contains("support.priority_invalid", body);
    }

    [Fact]
    public async Task ReplyTemplateEndpoints_ShouldSupportCrudFlow()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();
        var adminClient = application.CreateClient(AdminId, "Admin");

        var seededTemplates = await GetFromJsonAsync<IReadOnlyList<SupportReplyTemplateResponse>>(
            adminClient,
            "/api/admin/support/templates");
        var initialTemplateCount = seededTemplates.Count;

        var created = await PostAsJsonAsync<SupportReplyTemplateResponse>(
            adminClient,
            "/api/admin/support/templates",
            new UpsertSupportReplyTemplateRequest(
                "Custom reply",
                "Please reinstall the app and try again.",
                true,
                99));

        Assert.Equal("Custom reply", created.Title);

        var updated = await PutAsJsonAsync<SupportReplyTemplateResponse>(
            adminClient,
            $"/api/admin/support/templates/{created.TemplateId}",
            new UpsertSupportReplyTemplateRequest(
                "Escalate case",
                "Escalate this case to backend if repro persists.",
                true,
                15));

        Assert.Equal("Escalate case", updated.Title);

        using var deleteResponse = await adminClient.DeleteAsync($"/api/admin/support/templates/{created.TemplateId}");
        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        var afterDelete = await GetFromJsonAsync<IReadOnlyList<SupportReplyTemplateResponse>>(
            adminClient,
            "/api/admin/support/templates");

        Assert.DoesNotContain(afterDelete, x => x.TemplateId == created.TemplateId);
        Assert.Equal(initialTemplateCount, afterDelete.Count);
    }

    [Fact]
    public async Task SupportHub_ShouldRequireAuthentication_AndBroadcastConversationUpdates()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        await Assert.ThrowsAnyAsync<Exception>(async () =>
        {
            var anonymousConnection = application.CreateHubConnection();
            try
            {
                await anonymousConnection.StartAsync();
            }
            finally
            {
                await anonymousConnection.DisposeAsync();
            }
        });

        var adminConnection = application.CreateHubConnection(AdminId, "Admin");
        var eventReceived = new TaskCompletionSource<SupportConversationUpdatedEvent>(TaskCreationOptions.RunContinuationsAsynchronously);
        adminConnection.On<SupportConversationUpdatedEvent>("conversation-updated", payload => eventReceived.TrySetResult(payload));

        await adminConnection.StartAsync();
        try
        {
            var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
                application.CreateClient(UserId, "User"),
                "/api/support/conversation/open",
                new OpenConversationRequest("Realtime issue", SupportConversationPriority.Normal));

            var notification = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));
            Assert.Equal(created.ConversationId, notification.ConversationId);
            Assert.Equal(UserId, notification.InitiatorUserId);
        }
        finally
        {
            await adminConnection.DisposeAsync();
        }
    }
}
