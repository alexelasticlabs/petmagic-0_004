using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatApiStartupSmokeTests
{
    [Fact]
    public async Task SupportChatApiModule_ShouldStartHostWithoutEndpointInferenceErrors()
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.NotNull(app);
    }

    [Theory]
    [InlineData("/api/support/conversation/{conversationId:guid}/read")]
    [InlineData("/api/support/conversation/{conversationId:guid}/resolve")]
    [InlineData("/api/support/conversation/{conversationId:guid}/close")]
    [InlineData("/api/support/conversation/{conversationId:guid}/reopen")]
    public async Task SupportChatUserStateChangeEndpoints_ShouldRequireSupportRateLimit(string routePattern)
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.True(app.HasRateLimit(routePattern, "support-chat"));
    }

    [Theory]
    [InlineData("POST", "/api/support/conversation/open", "support-chat")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/messages", "support-chat")]
    [InlineData("GET", "/api/admin/support/tickets", "admin")]
    [InlineData("GET", "/api/admin/users/{userId:guid}/support/tickets", "admin")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/messages", "support-chat")]
    [InlineData("GET", "/api/admin/support/templates", "admin")]
    public async Task SupportChatEndpoints_ShouldUseExpectedRateLimitPolicies(
        string method,
        string routePattern,
        string expectedPolicy)
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedPolicy, app.GetRateLimitPolicy(method, routePattern));
    }

    [Fact]
    public async Task SupportChatApiEndpoints_ShouldAllDeclareRateLimitPolicies()
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimit());
    }

    [Fact]
    public async Task SupportChatApiEndpoints_ShouldAllDeclareAccessPolicy()
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task SupportChatAdminEndpoints_ShouldRequireAdminOrModeratorPolicy()
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    [Theory]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/messages/attachments", 255L * 1024 * 1024)]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/attachments", 51L * 1024 * 1024)]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", 51L * 1024 * 1024)]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/messages/attachments", 255L * 1024 * 1024)]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/attachments", 51L * 1024 * 1024)]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", 51L * 1024 * 1024)]
    public async Task SupportChatAttachmentEndpoints_ShouldLimitRequestBodiesBeforeFormBinding(
        string method,
        string routePattern,
        long expectedBytes)
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedBytes, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/support/conversation/open")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/messages")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/read")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/resolve")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/close")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/reopen")]
    [InlineData("POST", "/api/support/conversation/{conversationId:guid}/feedback")]
    [InlineData("PUT", "/api/support/notifications/push-token")]
    [InlineData("DELETE", "/api/support/notifications/push-token")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/assign-to-me")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/unassign")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/mark-waiting-for-user")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/mark-in-progress")]
    [InlineData("PUT", "/api/admin/support/tickets/{conversationId:guid}/status")]
    [InlineData("PUT", "/api/admin/support/tickets/{conversationId:guid}/assignment")]
    [InlineData("PUT", "/api/admin/support/tickets/{conversationId:guid}/metadata")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/close")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/reopen")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/messages")]
    [InlineData("POST", "/api/admin/support/tickets/{conversationId:guid}/read")]
    [InlineData("POST", "/api/admin/support/templates")]
    [InlineData("PUT", "/api/admin/support/templates/{templateId:guid}")]
    [InlineData("DELETE", "/api/admin/support/templates/{templateId:guid}")]
    public async Task SupportChatSmallMutationEndpoints_ShouldLimitRequestBodiesBeforeHandlerExecution(
        string method,
        string routePattern)
    {
        await using var app = await SupportChatApiStartupTestApplication.CreateAsync();

        Assert.Equal(16 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    private sealed class SupportChatApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private SupportChatApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<SupportChatApiStartupTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(SupportChatApiStartupSmokeTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("support-chat", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("admin", _ => RateLimitPartition.GetNoLimiter("tests"));
            });

            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });

            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
            });

            builder.Services.AddScoped<ISupportChatService>(_ =>
                throw new NotSupportedException("ISupportChatService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ISupportAttachmentStorage>(_ =>
                throw new NotSupportedException("ISupportAttachmentStorage should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ISupportReplyTemplateCatalogService>(_ =>
                throw new NotSupportedException("ISupportReplyTemplateCatalogService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IIdentityUserLookupService, StartupSmokeIdentityUserLookupService>();

            builder.Services.AddSupportChatApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapSupportChatApiModule();

            await app.StartAsync();

            return new SupportChatApiStartupTestApplication(app);
        }

        public async ValueTask DisposeAsync()
        {
            await app.StopAsync();
            await app.DisposeAsync();
        }

        public bool HasRateLimit(string routePattern, string policyName)
        {
            return app.Services.GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Where(endpoint => string.Equals(endpoint.RoutePattern.RawText, routePattern, StringComparison.Ordinal))
                .Any(endpoint => endpoint.Metadata
                    .GetOrderedMetadata<EnableRateLimitingAttribute>()
                    .Any(metadata => string.Equals(metadata.PolicyName, policyName, StringComparison.Ordinal)));
        }

        public string? GetRateLimitPolicy(string method, string routePattern)
        {
            var endpoint = app.Services.GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Single(endpoint =>
                    string.Equals(endpoint.RoutePattern.RawText, routePattern, StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));

            return endpoint.Metadata.GetMetadata<EnableRateLimitingAttribute>()?.PolicyName;
        }

        public long? GetRequestSizeLimit(string method, string routePattern)
        {
            var endpoint = app.Services.GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Single(endpoint =>
                    string.Equals(endpoint.RoutePattern.RawText, routePattern, StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));

            return endpoint.Metadata.GetMetadata<IRequestSizeLimitMetadata>()?.MaxRequestBodySize;
        }

        public string[] GetApiRoutesWithoutRateLimit()
        {
            return app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/", StringComparison.Ordinal) == true)
                .Where(endpoint => endpoint.Metadata.GetMetadata<EnableRateLimitingAttribute>() is null)
                .Select(endpoint => endpoint.RoutePattern.RawText!)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }

        public string[] GetApiRoutesWithoutAccessPolicy()
        {
            return app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/", StringComparison.Ordinal) == true)
                .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null)
                .Where(endpoint => endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>().Count == 0)
                .Select(endpoint => endpoint.RoutePattern.RawText!)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }

        public string[] GetAdminRoutesWithoutRolePolicy()
        {
            return app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/admin/", StringComparison.Ordinal) == true)
                .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null)
                .Where(endpoint => !endpoint.Metadata
                    .GetOrderedMetadata<IAuthorizeData>()
                    .Any(metadata => metadata.Policy is "AdminOnly" or "ModeratorOrAdmin"))
                .Select(endpoint => endpoint.RoutePattern.RawText!)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }
    }

    private sealed class StartupSmokeIdentityUserLookupService : IIdentityUserLookupService
    {
        public Task<IReadOnlyList<Guid>> GetActiveUserIdsInRolesAsync(
            IReadOnlyCollection<string> roles,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<Guid>>([]);

        public Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
            IReadOnlyCollection<Guid> userIds,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyDictionary<Guid, IdentityUserLookup>>(
                new Dictionary<Guid, IdentityUserLookup>());

        public Task<IdentityUserLookup?> GetUserByIdAsync(
            Guid userId,
            CancellationToken cancellationToken) =>
            Task.FromResult<IdentityUserLookup?>(null);
    }

    private sealed class TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Role, "Admin")
            };

            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
