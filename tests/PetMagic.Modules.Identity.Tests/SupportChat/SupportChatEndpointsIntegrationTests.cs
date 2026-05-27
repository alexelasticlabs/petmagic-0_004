using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;

using FluentValidation;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatEndpointsIntegrationTests
{
    private static readonly Guid UserId = Guid.Parse("A61F6697-8254-45F0-9C24-B6941A92D8E1");
    private static readonly Guid OtherUserId = Guid.Parse("6C0F443A-BAFC-4D80-A7F2-130839E95C35");
    private static readonly Guid ModeratorId = Guid.Parse("1CEAF6B8-E3BA-4CF7-B6E0-5F0B0F480D34");
    private static readonly Guid AdminId = Guid.Parse("7B8B172E-3308-4B7F-9F49-D98B6629A6AA");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task UserConversationEndpoints_ShouldRequireAuthentication_AndEnforceOwnership()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        using var anonymousResponse = await application.AnonymousClient.GetAsync("/api/support/conversation");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousResponse.StatusCode);

        var openResponse = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help with premium", SupportConversationPriority.High));

        Assert.Equal("New", openResponse.Status);
        Assert.Equal("High", openResponse.Priority);
        Assert.Contains(
            openResponse.Messages,
            message => message.SenderType == "User" && message.Body == "Need help with premium");

        var fetched = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation");

        Assert.Equal(openResponse.ConversationId, fetched.ConversationId);
        Assert.Contains(
            fetched.Messages,
            message => message.SenderType == "User" && message.Body == "Need help with premium");

        using var forbiddenResponse = await application.CreateClient(OtherUserId, "User").PostAsJsonAsync(
            $"/api/support/conversation/{openResponse.ConversationId}/messages",
            new SendSupportMessageRequest("I should not be here"));

        Assert.Equal(HttpStatusCode.Forbidden, forbiddenResponse.StatusCode);
    }

    [Fact]
    public async Task AdminEndpoints_ShouldRejectRegularUser_AndAllowModeratorInboxAccess()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("I need billing help", SupportConversationPriority.Normal));

        using var regularUserInbox = await application.CreateClient(UserId, "User").GetAsync("/api/admin/support/conversations");
        Assert.Equal(HttpStatusCode.Forbidden, regularUserInbox.StatusCode);

        var moderatorInbox = await GetFromJsonAsync<IReadOnlyList<SupportConversationSummaryResponse>>(
            application.CreateClient(ModeratorId, "Moderator"),
            "/api/admin/support/conversations");

        var conversation = Assert.Single(moderatorInbox);
        Assert.Equal(created.ConversationId, conversation.ConversationId);
        Assert.Equal("New", conversation.Status);
        Assert.Equal("user@petmagic.test", conversation.UserEmail);
    }

    [Fact]
    public async Task AdminInbox_ShouldFilterByAssignmentScope()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var mine = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Assigned case", SupportConversationPriority.Normal));

        await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{mine.ConversationId}/assignment",
            new AssignSupportConversationRequest(AdminId));

        var unassignedApplication = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(OtherUserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Unassigned case", SupportConversationPriority.Normal));

        var mineInbox = await GetFromJsonAsync<IReadOnlyList<SupportConversationSummaryResponse>>(
            adminClient,
            "/api/admin/support/conversations?assignment=mine");

        var unassignedInbox = await GetFromJsonAsync<IReadOnlyList<SupportConversationSummaryResponse>>(
            adminClient,
            "/api/admin/support/conversations?assignment=unassigned");

        Assert.Single(mineInbox);
        Assert.Single(unassignedInbox);
        Assert.Equal(mine.ConversationId, mineInbox[0].ConversationId);
        Assert.Equal(unassignedApplication.ConversationId, unassignedInbox[0].ConversationId);
    }

    [Fact]
    public async Task AdminReplyStatusAndReadEndpoints_ShouldRoundTripConversationState()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("App crashes on startup", SupportConversationPriority.High));

        var replied = await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/messages",
            new SendSupportMessageRequest("We have started investigating"));

        Assert.True(replied.IsFromAdmin);
        Assert.Equal("System Admin", replied.SenderDisplayName);

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(AdminId));

        Assert.Equal(AdminId, assigned.AssignedAdminId);

        var updated = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", updated.Status);
        Assert.Equal(AdminId, updated.AssignedAdminId);

        using var markAdminReadResponse = await adminClient.PostAsync($"/api/admin/support/conversations/{created.ConversationId}/read", content: null);
        Assert.Equal(HttpStatusCode.NoContent, markAdminReadResponse.StatusCode);

        var beforeUserRead = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation");

        Assert.Equal(1, beforeUserRead.UserUnreadCount);
        Assert.Equal(0, beforeUserRead.AdminUnreadCount);

        using var markUserReadResponse = await userClient.PostAsync($"/api/support/conversation/{created.ConversationId}/read", content: null);
        Assert.Equal(HttpStatusCode.NoContent, markUserReadResponse.StatusCode);

        var reopenedMessage = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Still broken after update"));

        Assert.False(reopenedMessage.IsFromAdmin);

        var afterReopen = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}");

        Assert.Equal("New", afterReopen.Status);
        Assert.Equal(1, afterReopen.AdminUnreadCount);
        Assert.Equal(0, afterReopen.UserUnreadCount);
        Assert.Contains(
            afterReopen.Messages,
            message => message.SenderType == "System" && message.Body == "Ticket reopened by user message.");
    }

    [Fact]
    public async Task AdminStatusEndpoint_ShouldRejectInvalidStatusTransition()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help", SupportConversationPriority.Normal));

        var closed = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", closed.Status);

        using var invalidTransitionResponse = await adminClient.PutAsJsonAsync(
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("WaitingForUser"));

        Assert.Equal(HttpStatusCode.BadRequest, invalidTransitionResponse.StatusCode);

        var body = await invalidTransitionResponse.Content.ReadAsStringAsync();
        Assert.Contains("support.status_transition_invalid", body);
    }

    [Fact]
    public async Task UserMessageEndpoint_ShouldReopenClosedConversation_AndAppendSystemEvent()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var userClient = application.CreateClient(UserId, "User");
        var adminClient = application.CreateClient(AdminId, "Admin");

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation/open",
            new OpenConversationRequest("Need help", SupportConversationPriority.Normal));

        var closed = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Closed"));

        Assert.Equal("Closed", closed.Status);

        var reopenedMessage = await PostAsJsonAsync<SupportMessageResponse>(
            userClient,
            $"/api/support/conversation/{created.ConversationId}/messages",
            new SendSupportMessageRequest("Still broken after the last update"));

        Assert.False(reopenedMessage.IsFromAdmin);
        Assert.Equal("User", reopenedMessage.SenderType);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}");

        Assert.Equal("New", conversation.Status);
        var reopenedEvent = Assert.Single(
            conversation.Messages.Where(message =>
                message.SenderType == "System" && message.Body == "Ticket reopened by user message."));
        Assert.Equal("Ticket reopened by user message.", reopenedEvent.Body);
    }

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
        Assert.Equal("issue.png", message.AttachmentFileName);
        Assert.Equal("image/png", message.AttachmentContentType);
        Assert.NotNull(message.AttachmentUrl);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);
        Assert.Null(message.AttachmentUploadErrorCode);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/conversations/{created.ConversationId}");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.AttachmentUrl is not null);
        Assert.Equal("issue.png", attachmentMessage.AttachmentFileName);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
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
        Assert.Equal("issue.mp4", message.AttachmentFileName);
        Assert.Equal("video/mp4", message.AttachmentContentType);
        Assert.NotNull(message.AttachmentUrl);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);
        Assert.Null(message.AttachmentUploadErrorCode);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/conversations/{created.ConversationId}");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.AttachmentUrl is not null);
        Assert.Equal("issue.mp4", attachmentMessage.AttachmentFileName);
        Assert.Equal("video/mp4", attachmentMessage.AttachmentContentType);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
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

        var userMessage = Assert.Single(conversation.Messages.Where(message => message.SenderType == "User"));
        Assert.Equal("Bonjour", userMessage.Body);
        var botMessage = Assert.Single(conversation.Messages.Where(message => message.SenderType == "Bot"));
        Assert.Equal(
            "Message recu. Le support repondra dans ce chat.",
            botMessage.Body);
        Assert.True(botMessage.IsFromAdmin);
        Assert.True(botMessage.IsRead);
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
            $"/api/admin/support/conversations/{created.ConversationId}/attachments",
            form);

        await AssertSuccessAsync(response);

        var message = (await response.Content.ReadFromJsonAsync<SupportMessageResponse>(JsonOptions))!;
        Assert.True(message.IsFromAdmin);
        Assert.Equal("Screenshot attached", message.Body);
        Assert.Equal("admin-screenshot.png", message.AttachmentFileName);
        Assert.Equal("image/png", message.AttachmentContentType);
        Assert.NotNull(message.AttachmentUrl);
        Assert.Equal("Uploaded", message.AttachmentUploadStatus);

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.AttachmentUrl is not null);
        Assert.Equal("admin-screenshot.png", attachmentMessage.AttachmentFileName);
        Assert.Equal("image/png", attachmentMessage.AttachmentContentType);
        Assert.Equal("Uploaded", attachmentMessage.AttachmentUploadStatus);
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
        Assert.Null(failedMessage.AttachmentUrl);

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
        Assert.NotNull(retriedMessage.AttachmentUrl);
    }

    [Fact]
    public async Task UpdateStatusEndpoint_ShouldRejectInvalidStatusValues()
    {
        await using var application = await SupportChatTestApplication.CreateAsync();

        var created = await PostAsJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation/open",
            new OpenConversationRequest("Wrong charge", SupportConversationPriority.Normal));

        using var invalidStatusResponse = await application.CreateClient(AdminId, "Admin").PutAsJsonAsync(
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("NotARealStatus"));

        Assert.Equal(HttpStatusCode.BadRequest, invalidStatusResponse.StatusCode);
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

    private static async Task<TResponse> GetFromJsonAsync<TResponse>(HttpClient client, string url)
    {
        using var response = await client.GetAsync(url);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static async Task<TResponse> PostAsJsonAsync<TResponse>(HttpClient client, string url, object payload)
    {
        using var response = await client.PostAsJsonAsync(url, payload);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static async Task<TResponse> PutAsJsonAsync<TResponse>(HttpClient client, string url, object payload)
    {
        using var response = await client.PutAsJsonAsync(url, payload);
        await AssertSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions))!;
    }

    private static async Task AssertSuccessAsync(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var body = await response.Content.ReadAsStringAsync();
        throw new Xunit.Sdk.XunitException($"Expected success status code but got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
    }

    private sealed class SupportChatTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private SupportChatTestApplication(WebApplication app, HttpClient anonymousClient)
        {
            this.app = app;
            AnonymousClient = anonymousClient;
        }

        public HttpClient AnonymousClient { get; }

        public TestServer Server => app.GetTestServer();

        public static async Task<SupportChatTestApplication> CreateAsync()
        {
            var supportDatabaseRoot = new InMemoryDatabaseRoot();
            var identityDatabaseRoot = new InMemoryDatabaseRoot();
            var supportDatabaseName = $"support-chat-api-tests-{Guid.NewGuid():N}";
            var identityDatabaseName = $"support-chat-identity-api-tests-{Guid.NewGuid():N}";

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(SupportChatEndpointsIntegrationTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();

            builder.Services.AddAuthentication(SupportChatTestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, SupportChatTestAuthHandler>(SupportChatTestAuthHandler.SchemeName, _ => { });

            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
            });

            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddFixedWindowLimiter("support-chat", limiterOptions =>
                {
                    limiterOptions.PermitLimit = 1_000;
                    limiterOptions.Window = TimeSpan.FromMinutes(1);
                    limiterOptions.QueueLimit = 0;
                });
            });

            builder.Services.AddDbContext<SupportChatDbContext>(options =>
                options.UseInMemoryDatabase(supportDatabaseName, supportDatabaseRoot));

            builder.Services.AddDbContext<IdentityDbContext>(options =>
                options.UseInMemoryDatabase(identityDatabaseName, identityDatabaseRoot));

            builder.Services.AddScoped<IIdentityUserLookupService, TestIdentityUserLookupService>();
            builder.Services.AddSingleton<ISupportAttachmentStorage, FakeSupportAttachmentStorage>();
            builder.Services.AddSingleton<ISupportChatPushNotificationSender, NoopSupportChatPushNotificationSender>();
            builder.Services.AddScoped<ISupportChatService, SupportChatService>();
            builder.Services.AddScoped<ISupportReplyTemplateCatalogService, SupportReplyTemplateCatalogService>();
            builder.Services.AddSupportChatApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapSupportChatApiModule();

            await SeedUsersAsync(app.Services);
            await app.StartAsync();

            return new SupportChatTestApplication(app, app.GetTestClient());
        }

        public HttpClient CreateClient(Guid userId, params string[] roles)
        {
            var client = app.GetTestClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(SupportChatTestAuthHandler.SchemeName);
            client.DefaultRequestHeaders.Add(SupportChatTestAuthHandler.UserIdHeaderName, userId.ToString());
            if (roles.Length > 0)
            {
                client.DefaultRequestHeaders.Add(SupportChatTestAuthHandler.RolesHeaderName, string.Join(',', roles));
            }

            return client;
        }

        public HubConnection CreateHubConnection(Guid? userId = null, params string[] roles)
        {
            return new HubConnectionBuilder()
                .WithUrl(new Uri(new Uri("http://localhost"), "/hubs/support-chat"), options =>
                {
                    options.HttpMessageHandlerFactory = _ => Server.CreateHandler();
                    options.Transports = HttpTransportType.LongPolling;
                    if (userId.HasValue)
                    {
                        options.AccessTokenProvider = () => Task.FromResult<string?>(EncodeHubAccessToken(userId.Value, roles));
                    }
                })
                .Build();
        }

        public async ValueTask DisposeAsync()
        {
            AnonymousClient.Dispose();
            await app.StopAsync();
            await app.DisposeAsync();
        }

        private static async Task SeedUsersAsync(IServiceProvider services)
        {
            using var scope = services.CreateScope();
            var identityDbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            await identityDbContext.Database.EnsureCreatedAsync();

            identityDbContext.Users.AddRange(
                CreateUser(UserId, "user@petmagic.test", "Pet User"),
                CreateUser(OtherUserId, "other@petmagic.test", "Other User"),
                CreateUser(ModeratorId, "moderator@petmagic.test", "Moderator Jane"),
                CreateUser(AdminId, "admin@petmagic.test", "System Admin"));

            await identityDbContext.SaveChangesAsync();

            var supportChatDbContext = scope.ServiceProvider.GetRequiredService<SupportChatDbContext>();
            await supportChatDbContext.Database.EnsureCreatedAsync();
        }

        private static AppUser CreateUser(Guid id, string email, string displayName)
        {
            return new AppUser
            {
                Id = id,
                UserName = email,
                NormalizedUserName = email.ToUpperInvariant(),
                Email = email,
                NormalizedEmail = email.ToUpperInvariant(),
                EmailConfirmed = true,
                DisplayName = displayName,
                IsActive = true,
            };
        }

        private sealed class TestIdentityUserLookupService(IdentityDbContext identityDbContext) : IIdentityUserLookupService
        {
            public async Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
                IReadOnlyCollection<Guid> userIds,
                CancellationToken cancellationToken)
            {
                if (userIds.Count == 0)
                {
                    return new Dictionary<Guid, IdentityUserLookup>();
                }

                var distinctUserIds = userIds.Distinct().ToArray();
                var users = await identityDbContext.Users
                    .AsNoTracking()
                    .Where(x => distinctUserIds.Contains(x.Id))
                    .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
                    .ToListAsync(cancellationToken);

                return users.ToDictionary(x => x.UserId);
            }

            public async Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
            {
                return await identityDbContext.Users
                    .AsNoTracking()
                    .Where(x => x.Id == userId)
                    .Select(x => new IdentityUserLookup(x.Id, x.Email ?? string.Empty, x.DisplayName))
                    .FirstOrDefaultAsync(cancellationToken);
            }
        }
    }

    private sealed class SupportChatTestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";
        public const string UserIdHeaderName = "X-Test-UserId";
        public const string RolesHeaderName = "X-Test-Roles";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (TryCreatePrincipalFromBearerToken(Request.Headers.Authorization, out var bearerPrincipal))
            {
                return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(bearerPrincipal, Scheme.Name)));
            }

            if (TryCreatePrincipalFromBearerToken(Request.Query["access_token"], out bearerPrincipal))
            {
                return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(bearerPrincipal, Scheme.Name)));
            }

            if (!Request.Headers.TryGetValue("Authorization", out var authorizationHeader) ||
                !string.Equals(authorizationHeader.ToString(), SchemeName, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            var userId = Request.Headers.TryGetValue(UserIdHeaderName, out var userIdHeader) && Guid.TryParse(userIdHeader, out var parsedUserId)
                ? parsedUserId
                : UserId;

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId.ToString()),
                new("sub", userId.ToString()),
                new(ClaimTypes.Name, $"test-user-{userId:N}"),
            };

            if (Request.Headers.TryGetValue(RolesHeaderName, out var rolesHeader))
            {
                foreach (var role in rolesHeader.ToString().Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                {
                    claims.Add(new Claim(ClaimTypes.Role, role));
                }
            }

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }

        private static bool TryCreatePrincipalFromBearerToken(string? rawHeader, out ClaimsPrincipal principal)
        {
            principal = null!;
            if (string.IsNullOrWhiteSpace(rawHeader))
            {
                return false;
            }

            var token = rawHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? rawHeader[7..]
                : rawHeader;

            var parts = token.Split(';', 2, StringSplitOptions.TrimEntries);
            if (parts.Length == 0 || !Guid.TryParse(parts[0], out var userId))
            {
                return false;
            }

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, userId.ToString()),
                new("sub", userId.ToString()),
                new(ClaimTypes.Name, $"signalr-user-{userId:N}"),
            };

            if (parts.Length == 2 && parts[1].StartsWith("roles=", StringComparison.OrdinalIgnoreCase))
            {
                foreach (var role in parts[1][6..].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                {
                    claims.Add(new Claim(ClaimTypes.Role, role));
                }
            }

            principal = new ClaimsPrincipal(new ClaimsIdentity(claims, SchemeName));
            return true;
        }
    }

    private sealed record OpenConversationRequest(string? InitialMessage, SupportConversationPriority Priority);

    private sealed record SendSupportMessageRequest(string Body, string? Locale = null);

    private sealed record UpdateSupportConversationStatusRequest(string Status);

    private sealed record AssignSupportConversationRequest(Guid? AssignedAdminId);

    private sealed record UpsertSupportReplyTemplateRequest(string Title, string Body, bool IsEnabled, int SortOrder);

    private sealed record SupportConversationUpdatedEvent(Guid ConversationId, Guid InitiatorUserId, DateTime UpdatedAtUtc);

    private sealed class FakeSupportAttachmentStorage : ISupportAttachmentStorage
    {
        private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp",
            "video/mp4",
            "video/quicktime",
            "video/webm"
        };

        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken)
        {
            var normalizedContentType = NormalizeContentType(attachment.ContentType);
            if (!AllowedContentTypes.Contains(normalizedContentType))
            {
                return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                    new Error("support.attachment_content_type_not_allowed", "Content type is not allowed.")));
            }

            if (!MatchesFileSignature(normalizedContentType, attachment.Content))
            {
                return Task.FromResult(Result.Failure<StoredSupportAttachmentResponse>(
                    new Error("support.attachment_mime_mismatch", "MIME type does not match file signature.")));
            }

            if (string.Equals(normalizedContentType, "image/jpg", StringComparison.OrdinalIgnoreCase))
            {
                normalizedContentType = "image/jpeg";
            }

            var url = $"http://localhost:5000/support-attachments/test/{Guid.NewGuid():N}-{attachment.FileName}";
            return Task.FromResult(Result.Success(new StoredSupportAttachmentResponse(
                url,
                url,
                attachment.FileName,
                normalizedContentType,
                attachment.Content.LongLength,
                null)));
        }

        private static string NormalizeContentType(string contentType)
        {
            if (string.IsNullOrWhiteSpace(contentType))
            {
                return string.Empty;
            }

            var separatorIndex = contentType.IndexOf(';');
            return (separatorIndex >= 0 ? contentType[..separatorIndex] : contentType).Trim();
        }

        private static bool MatchesFileSignature(string normalizedContentType, byte[] payload)
        {
            return normalizedContentType switch
            {
                "image/jpeg" or "image/jpg" => payload.Length >= 3
                    && payload[0] == 0xFF
                    && payload[1] == 0xD8
                    && payload[2] == 0xFF,
                "image/png" => payload.Length >= 8
                    && payload[0] == 0x89
                    && payload[1] == 0x50
                    && payload[2] == 0x4E
                    && payload[3] == 0x47
                    && payload[4] == 0x0D
                    && payload[5] == 0x0A
                    && payload[6] == 0x1A
                    && payload[7] == 0x0A,
                "image/webp" => payload.Length >= 12
                    && payload[0] == 0x52
                    && payload[1] == 0x49
                    && payload[2] == 0x46
                    && payload[3] == 0x46
                    && payload[8] == 0x57
                    && payload[9] == 0x45
                    && payload[10] == 0x42
                    && payload[11] == 0x50,
                "video/mp4" or "video/quicktime" => payload.Length >= 12
                    && payload[4] == 0x66
                    && payload[5] == 0x74
                    && payload[6] == 0x79
                    && payload[7] == 0x70,
                "video/webm" => payload.Length >= 4
                    && payload[0] == 0x1A
                    && payload[1] == 0x45
                    && payload[2] == 0xDF
                    && payload[3] == 0xA3,
                _ => false,
            };
        }
    }

    private sealed class NoopSupportChatPushNotificationSender : ISupportChatPushNotificationSender
    {
        public Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }

    private static string EncodeHubAccessToken(Guid userId, params string[] roles)
    {
        var suffix = roles.Length > 0 ? $";roles={string.Join(',', roles)}" : string.Empty;
        return $"{userId:D}{suffix}";
    }
}
