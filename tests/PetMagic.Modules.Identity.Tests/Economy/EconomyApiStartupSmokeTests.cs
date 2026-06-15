using System.Net;
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

using PetMagic.Modules.Economy.Api;
using PetMagic.Modules.Economy.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyApiStartupSmokeTests
{
    [Fact]
    public async Task EconomyApiModule_ShouldStartHostWithoutEndpointInferenceErrors()
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.NotNull(app);
    }

    [Theory]
    [InlineData("POST", "/api/economy/webhooks/stripe", "webhooks")]
    [InlineData("POST", "/api/economy/webhooks/app-store", "webhooks")]
    [InlineData("POST", "/api/economy/webhooks/google-play", "webhooks")]
    [InlineData("POST", "/api/payments/stripe/token-purchase", "economy")]
    [InlineData("GET", "/api/admin/economy/ledger", "admin")]
    public async Task EconomyEndpoints_ShouldUseExpectedRateLimitPolicies(
        string method,
        string routePattern,
        string expectedPolicy)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedPolicy, app.GetRateLimitPolicy(method, routePattern));
    }

    [Fact]
    public async Task EconomyApiEndpoints_ShouldAllDeclareRateLimitPolicies()
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimit());
    }

    [Fact]
    public async Task EconomyApiEndpoints_ShouldAllDeclareAccessPolicy()
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task EconomyAdminEndpoints_ShouldRequireAdminOrModeratorPolicy()
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    [Theory]
    [InlineData("/api/admin/economy/purchases?status=chargeback", "economy.purchase_status_invalid")]
    [InlineData("/api/admin/economy/purchases?provider=paypal", "economy.payment_provider_invalid")]
    [InlineData("/api/admin/economy/subscriptions?status=paused", "economy.subscription_status_invalid")]
    [InlineData("/api/admin/economy/subscriptions?provider=apple", "economy.payment_provider_invalid")]
    [InlineData("/api/admin/economy/subscription-events?status=ignored", "economy.subscription_event_status_invalid")]
    [InlineData("/api/admin/economy/subscription-events?provider=paypal", "economy.payment_provider_invalid")]
    public async Task AdminEconomyListEndpoints_ShouldRejectInvalidFiltersBeforeServiceResolution(
        string path,
        string expectedProblemTitle)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        using var response = await app.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(expectedProblemTitle, body, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("/api/admin/economy/redeem-codes?status=deleted", "economy.redeem_code_status_invalid")]
    [InlineData("/api/admin/economy/redeem-codes?rewardKind=premium_days", "economy.redeem_code_reward_kind_invalid")]
    [InlineData("/api/admin/economy/redeem-codes?sort=random", "economy.redeem_code_sort_invalid")]
    [InlineData("/api/admin/economy/redeem-codes/metrics?status=deleted", "economy.redeem_code_status_invalid")]
    [InlineData("/api/admin/economy/redeem-codes/metrics?rewardKind=premium_days", "economy.redeem_code_reward_kind_invalid")]
    public async Task AdminRedeemCodeEndpoints_ShouldRejectInvalidFiltersBeforeServiceResolution(
        string path,
        string expectedProblemTitle)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        using var response = await app.GetAsync(path);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(expectedProblemTitle, body, StringComparison.Ordinal);
    }

    private sealed class EconomyApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private EconomyApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<EconomyApiStartupTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(EconomyApiStartupSmokeTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("economy", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("admin", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("webhooks", _ => RateLimitPartition.GetNoLimiter("tests"));
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

            builder.Services.AddScoped<IEconomyService>(_ =>
                throw new NotSupportedException("IEconomyService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IStoreWebhookSecurityValidator>(_ =>
                throw new NotSupportedException("IStoreWebhookSecurityValidator should not be resolved during startup smoke test."));

            builder.Services.AddEconomyApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapEconomyApiModule();

            await app.StartAsync();

            return new EconomyApiStartupTestApplication(app);
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

        public Task<HttpResponseMessage> GetAsync(string path) =>
            app.GetTestClient().GetAsync(path);

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
