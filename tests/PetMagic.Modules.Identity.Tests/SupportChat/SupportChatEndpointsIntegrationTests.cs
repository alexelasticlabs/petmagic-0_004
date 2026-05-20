using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using PetMagic.BuildingBlocks.Results;
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

        Assert.Equal("Open", openResponse.Status);
        Assert.Equal("High", openResponse.Priority);
        Assert.Single(openResponse.Messages);

        var fetched = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(UserId, "User"),
            "/api/support/conversation");

        Assert.Equal(openResponse.ConversationId, fetched.ConversationId);
        Assert.Equal("Need help with premium", fetched.Messages[0].Body);

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
        Assert.Equal("Open", conversation.Status);
        Assert.Equal("user@petmagic.test", conversation.UserEmail);
        Assert.False(conversation.LastMessageIsInternalNote);
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

        var internalNote = await PostAsJsonAsync<SupportMessageResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/notes",
            new SendSupportMessageRequest("Suspect stale auth refresh session"));

        Assert.True(internalNote.IsInternalNote);

        var assigned = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/assignment",
            new AssignSupportConversationRequest(AdminId));

        Assert.Equal(AdminId, assigned.AssignedAdminId);

        var updated = await PutAsJsonAsync<SupportConversationDetailResponse>(
            adminClient,
            $"/api/admin/support/conversations/{created.ConversationId}/status",
            new UpdateSupportConversationStatusRequest("Resolved"));

        Assert.Equal("Resolved", updated.Status);
        Assert.Equal(AdminId, updated.AssignedAdminId);

        using var markAdminReadResponse = await adminClient.PostAsync($"/api/admin/support/conversations/{created.ConversationId}/read", content: null);
        Assert.Equal(HttpStatusCode.NoContent, markAdminReadResponse.StatusCode);

        var beforeUserRead = await GetFromJsonAsync<SupportConversationDetailResponse>(
            userClient,
            "/api/support/conversation");

        Assert.DoesNotContain(beforeUserRead.Messages, x => x.IsInternalNote);
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

        Assert.Equal("Open", afterReopen.Status);
        Assert.Equal(1, afterReopen.AdminUnreadCount);
        Assert.Equal(0, afterReopen.UserUnreadCount);
        Assert.Equal(4, afterReopen.Messages.Count);
        Assert.Contains(afterReopen.Messages, x => x.IsInternalNote);
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
        var fileContent = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47]);
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

        var conversation = await GetFromJsonAsync<SupportConversationDetailResponse>(
            application.CreateClient(AdminId, "Admin"),
            $"/api/admin/support/conversations/{created.ConversationId}");

        var attachmentMessage = Assert.Single(conversation.Messages, x => x.AttachmentUrl is not null);
        Assert.Equal("issue.png", attachmentMessage.AttachmentFileName);
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
                "Reply",
                true,
                99));

        Assert.Equal("Custom reply", created.Title);
        Assert.Equal("Reply", created.Kind);

        var updated = await PutAsJsonAsync<SupportReplyTemplateResponse>(
            adminClient,
            $"/api/admin/support/templates/{created.TemplateId}",
            new UpsertSupportReplyTemplateRequest(
                "Escalate note",
                "Escalate this case to backend if repro persists.",
                "InternalNote",
                true,
                15));

        Assert.Equal("Escalate note", updated.Title);
        Assert.Equal("InternalNote", updated.Kind);

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

            builder.Services.AddSingleton<ISupportAttachmentStorage, FakeSupportAttachmentStorage>();
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

    private sealed record SendSupportMessageRequest(string Body);

    private sealed record UpdateSupportConversationStatusRequest(string Status);

    private sealed record AssignSupportConversationRequest(Guid? AssignedAdminId);

    private sealed record UpsertSupportReplyTemplateRequest(string Title, string Body, string Kind, bool IsEnabled, int SortOrder);

    private sealed record SupportConversationUpdatedEvent(Guid ConversationId, Guid InitiatorUserId, DateTime UpdatedAtUtc);

    private sealed class FakeSupportAttachmentStorage : ISupportAttachmentStorage
    {
        public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
            SupportAttachmentUploadCommand attachment,
            CancellationToken cancellationToken)
        {
            var url = $"http://localhost:5000/support-attachments/test/{Guid.NewGuid():N}-{attachment.FileName}";
            return Task.FromResult(Result.Success(new StoredSupportAttachmentResponse(
                url,
                url,
                attachment.FileName,
                attachment.ContentType,
                attachment.Content.LongLength,
                null)));
        }
    }

    private static string EncodeHubAccessToken(Guid userId, params string[] roles)
    {
        var suffix = roles.Length > 0 ? $";roles={string.Join(',', roles)}" : string.Empty;
        return $"{userId:D}{suffix}";
    }
}