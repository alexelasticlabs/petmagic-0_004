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

using PetMagic.Modules.Gamification.Api;
using PetMagic.Modules.Gamification.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationApiStartupSmokeTests
{
    [Fact]
    public async Task GamificationApiModule_ShouldStartHostWithoutEndpointInferenceErrors()
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.NotNull(app);
    }

    [Theory]
    [InlineData("GET", "/api/gamification/summary", "economy")]
    [InlineData("GET", "/api/gamification/achievements", "economy")]
    [InlineData("POST", "/api/gamification/streaks/freeze", "economy")]
    [InlineData("GET", "/api/admin/gamification/dashboard/metrics", "admin")]
    [InlineData("DELETE", "/api/admin/gamification/users/{userId:guid}/streak", "admin")]
    public async Task GamificationEndpoints_ShouldUseExpectedRateLimitPolicies(
        string method,
        string routePattern,
        string expectedPolicy)
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedPolicy, app.GetRateLimitPolicy(method, routePattern));
    }

    [Fact]
    public async Task GamificationApiEndpoints_ShouldAllDeclareRateLimitPolicies()
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimit());
    }

    [Fact]
    public async Task GamificationApiEndpoints_ShouldAllDeclareAccessPolicy()
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task GamificationAdminEndpoints_ShouldRequireAdminRolePolicy()
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    [Theory]
    [InlineData("GET", "/api/admin/gamification/dashboard/metrics")]
    [InlineData("GET", "/api/admin/gamification/achievements")]
    [InlineData("GET", "/api/admin/gamification/challenges/current")]
    [InlineData("GET", "/api/admin/gamification/users/{userId:guid}")]
    [InlineData("DELETE", "/api/admin/gamification/users/{userId:guid}/streak")]
    public async Task GamificationAdminEndpoints_ShouldRequireAdminOnlyPolicy(
        string method,
        string routePattern)
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();
        var policies = app.GetAuthorizationPolicies(method, routePattern);

        Assert.Contains("AdminOnly", policies, StringComparer.Ordinal);
        Assert.DoesNotContain("ModeratorOrAdmin", policies, StringComparer.Ordinal);
    }

    [Theory]
    [InlineData("POST", "/api/gamification/streaks/freeze")]
    [InlineData("DELETE", "/api/admin/gamification/users/{userId:guid}/streak")]
    public async Task GamificationMutationEndpoints_ShouldLimitRequestBodiesBeforeHandlerExecution(
        string method,
        string routePattern)
    {
        await using var app = await GamificationApiStartupTestApplication.CreateAsync();

        Assert.Equal(8 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    private sealed class GamificationApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private GamificationApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<GamificationApiStartupTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(GamificationApiStartupSmokeTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("economy", _ => RateLimitPartition.GetNoLimiter("tests"));
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

            builder.Services.AddScoped<IGamificationService>(_ =>
                throw new NotSupportedException("IGamificationService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IGamificationAdminService>(_ =>
                throw new NotSupportedException("IGamificationAdminService should not be resolved during startup smoke test."));

            builder.Services.AddGamificationApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapGamificationApiModule();

            await app.StartAsync();

            return new GamificationApiStartupTestApplication(app);
        }

        public string? GetRateLimitPolicy(string method, string routePattern)
        {
            var endpoint = app.Services
                .GetRequiredService<EndpointDataSource>()
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

        public string[] GetAuthorizationPolicies(string method, string routePattern)
        {
            var endpoint = app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Single(endpoint =>
                    string.Equals(endpoint.RoutePattern.RawText, routePattern, StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));

            return endpoint.Metadata
                .GetOrderedMetadata<IAuthorizeData>()
                .Select(metadata => metadata.Policy)
                .Where(policy => !string.IsNullOrWhiteSpace(policy))
                .ToArray()!;
        }

        public long? GetRequestSizeLimit(string method, string routePattern)
        {
            var endpoint = app.Services
                .GetRequiredService<EndpointDataSource>()
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
            var identity = new ClaimsIdentity(
                [
                    new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                    new Claim(ClaimTypes.Role, "Admin")
                ],
                SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
