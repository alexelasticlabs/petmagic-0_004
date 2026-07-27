using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityApiStartupSmokeTests
{
    [Fact]
    public async Task IdentityApiModule_ShouldStartHostWithoutEndpointInferenceErrors()
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.NotNull(app);
    }

    [Theory]
    [InlineData("POST", "/api/auth/register", "auth-register")]
    [InlineData("POST", "/api/auth/login", "auth")]
    [InlineData("POST", "/api/auth/email-confirmation/request", "auth-email-verification")]
    [InlineData("POST", "/api/auth/email-confirmation/confirm", "auth-email-verification")]
    [InlineData("POST", "/api/auth/resend-email-verification-code", "auth-email-verification")]
    [InlineData("POST", "/api/auth/verify-email-code", "auth-email-verification")]
    [InlineData("POST", "/api/auth/password-reset/request", "auth-password-reset")]
    [InlineData("POST", "/api/auth/verify-password-reset-code", "auth-password-reset")]
    [InlineData("POST", "/api/auth/me/password-change/request", "auth-password-reset")]
    [InlineData("GET", "/api/auth/external/{provider}", "auth-external")]
    [InlineData("GET", "/api/auth/external/google/mobile-config", "auth-external")]
    [InlineData("GET", "/api/auth/external/callback", "auth-external")]
    [InlineData("POST", "/api/auth/external/exchange", "auth-external")]
    [InlineData("POST", "/api/auth/external/google/native", "auth-external")]
    [InlineData("POST", "/api/auth/google", "auth-external")]
    [InlineData("POST", "/api/auth/apple", "auth-external")]
    [InlineData("GET", "/api/auth/me", "auth")]
    [InlineData("GET", "/api/admin/users", "admin")]
    public async Task IdentityEndpoints_ShouldUseExpectedRateLimitPolicies(
        string method,
        string routePattern,
        string expectedPolicy)
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedPolicy, app.GetRateLimitPolicy(method, routePattern));
    }

    [Fact]
    public async Task IdentityApiEndpoints_ShouldAllDeclareRateLimitPolicies()
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimit());
    }

    [Fact]
    public async Task IdentityApiEndpoints_ShouldAllDeclareAccessPolicy()
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task IdentityAdminEndpoints_ShouldRequireAdminOrModeratorPolicy()
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    [Theory]
    [InlineData("POST", "/api/auth/register")]
    [InlineData("POST", "/api/auth/login")]
    [InlineData("POST", "/api/auth/email-confirmation/request")]
    [InlineData("POST", "/api/auth/email-confirmation/confirm")]
    [InlineData("POST", "/api/auth/resend-email-verification-code")]
    [InlineData("POST", "/api/auth/verify-email-code")]
    [InlineData("POST", "/api/auth/password-reset/request")]
    [InlineData("POST", "/api/auth/password-reset/confirm")]
    [InlineData("POST", "/api/auth/request-password-reset")]
    [InlineData("POST", "/api/auth/verify-password-reset-code")]
    [InlineData("POST", "/api/auth/reset-password")]
    [InlineData("POST", "/api/auth/me/password-change/request")]
    [InlineData("POST", "/api/auth/me/password-change/confirm")]
    [InlineData("POST", "/api/auth/refresh")]
    [InlineData("POST", "/api/auth/logout")]
    [InlineData("PUT", "/api/auth/me/profile")]
    [InlineData("DELETE", "/api/auth/me")]
    [InlineData("POST", "/api/auth/me/legal-acceptance")]
    [InlineData("POST", "/api/auth/me/linked-accounts/{provider}/prepare")]
    [InlineData("POST", "/api/auth/me/linked-accounts/google/native")]
    [InlineData("DELETE", "/api/auth/me/linked-accounts/{provider}")]
    [InlineData("DELETE", "/api/auth/me/avatar")]
    [InlineData("POST", "/api/auth/external/exchange")]
    [InlineData("POST", "/api/auth/external/google/native")]
    [InlineData("POST", "/api/auth/google")]
    [InlineData("POST", "/api/auth/apple")]
    public async Task AuthJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeJsonBinding(
        string method,
        string routePattern)
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Equal(32 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/admin/users/{userId:guid}/wallet")]
    [InlineData("PUT", "/api/admin/users/{userId:guid}/role")]
    [InlineData("DELETE", "/api/admin/users/{userId:guid}/role")]
    [InlineData("DELETE", "/api/admin/users/{userId:guid}")]
    [InlineData("PUT", "/api/admin/users/{userId:guid}/active")]
    [InlineData("POST", "/api/admin/users/{userId:guid}/sessions/{sessionId:guid}/revoke")]
    [InlineData("POST", "/api/admin/users/{userId:guid}/sessions/revoke-all")]
    public async Task AdminUserSmallMutationEndpoints_ShouldLimitRequestBodiesBeforeHandlerExecution(
        string method,
        string routePattern)
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Equal(8 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Fact]
    public async Task LegalAcceptanceEndpoint_ShouldLimitRequestBodyBeforeJsonBinding()
    {
        await using var app = await IdentityApiStartupTestApplication.CreateAsync();

        Assert.Equal(8 * 1024, app.GetRequestSizeLimit("POST", "/api/legal/accept"));
    }

    private sealed class IdentityApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private IdentityApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<IdentityApiStartupTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(IdentityApiStartupSmokeTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddMemoryCache();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("auth", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-register", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-password-reset", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-email-verification", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-external", _ => RateLimitPartition.GetNoLimiter("tests"));
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

                options.AddPolicy("AdminOnly", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin");
                });
            });

            builder.Services.AddScoped<IIdentityService>(_ =>
                throw new NotSupportedException("IIdentityService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IGoogleIdentityTokenVerifier>(_ =>
                throw new NotSupportedException("IGoogleIdentityTokenVerifier should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ILegalDocumentsCatalog>(_ =>
                throw new NotSupportedException("ILegalDocumentsCatalog should not be resolved during startup smoke test."));

            builder.Services.AddIdentityApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapIdentityApiModule();

            await app.StartAsync();

            return new IdentityApiStartupTestApplication(app);
        }

        public string? GetRateLimitPolicy(string method, string routePattern)
        {
            var normalizedRoutePattern = NormalizeRoutePattern(routePattern);
            var endpoint = app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Single(endpoint =>
                    string.Equals(
                        NormalizeRoutePattern(endpoint.RoutePattern.RawText),
                        normalizedRoutePattern,
                        StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));

            return endpoint.Metadata.GetMetadata<EnableRateLimitingAttribute>()?.PolicyName;
        }

        public long? GetRequestSizeLimit(string method, string routePattern)
        {
            var normalizedRoutePattern = NormalizeRoutePattern(routePattern);
            var endpoint = app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Single(endpoint =>
                    string.Equals(
                        NormalizeRoutePattern(endpoint.RoutePattern.RawText),
                        normalizedRoutePattern,
                        StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));

            return endpoint.Metadata.GetMetadata<IRequestSizeLimitMetadata>()?.MaxRequestBodySize;
        }

        private static string NormalizeRoutePattern(string? routePattern)
        {
            if (string.IsNullOrWhiteSpace(routePattern) || routePattern == "/")
            {
                return routePattern ?? string.Empty;
            }

            return routePattern.TrimEnd('/');
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

        public async ValueTask DisposeAsync()
        {
            await app.StopAsync();
            await app.DisposeAsync();
        }
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
