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
    [InlineData("GET", "/api/payments/stripe/diagnostics", "economy")]
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
    [InlineData("GET", "/api/economy/premium/stripe-diagnostics")]
    [InlineData("GET", "/api/payments/stripe/diagnostics")]
    public async Task StripeDiagnosticsEndpoints_ShouldRequireAdminOnlyPolicy(string method, string routePattern)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Contains(
            "AdminOnly",
            app.GetAuthorizationPolicies(method, routePattern),
            StringComparer.Ordinal);
    }

    [Theory]
    [InlineData("POST", "/api/economy/wallet/spend")]
    [InlineData("POST", "/api/economy/wallet/redeem")]
    [InlineData("PUT", "/api/economy/notifications/push-token")]
    [InlineData("DELETE", "/api/economy/notifications/push-token")]
    [InlineData("POST", "/api/economy/referrals/activate")]
    [InlineData("POST", "/api/economy/premium/checkout")]
    [InlineData("POST", "/api/economy/premium/manage")]
    [InlineData("POST", "/api/economy/premium/cancel")]
    [InlineData("POST", "/api/economy/premium/store/verify")]
    [InlineData("POST", "/api/billing/google/validate")]
    [InlineData("POST", "/api/billing/apple/validate")]
    [InlineData("POST", "/api/economy/premium/verify-stripe")]
    [InlineData("POST", "/api/economy/payment-methods/setup")]
    [InlineData("POST", "/api/economy/purchases/create")]
    [InlineData("POST", "/api/economy/purchases/{orderId:guid}/verify-stripe")]
    [InlineData("POST", "/api/economy/purchases/{orderId:guid}/verify-store")]
    [InlineData("POST", "/api/payments/stripe/token-purchase")]
    [InlineData("POST", "/api/payments/stripe/subscription")]
    [InlineData("POST", "/api/payments/stripe/customer-portal")]
    public async Task EconomyJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Equal(32 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/economy/webhooks/stripe")]
    [InlineData("POST", "/api/economy/webhooks/app-store")]
    [InlineData("POST", "/api/webhooks/apple-app-store")]
    [InlineData("POST", "/api/economy/webhooks/google-play")]
    [InlineData("POST", "/api/webhooks/google-play")]
    public async Task EconomyWebhookEndpoints_ShouldLimitRequestBodiesBeforeReadingPayload(
        string method,
        string routePattern)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Equal(256 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/admin/economy/purchases/{orderId:guid}/refund")]
    [InlineData("PUT", "/api/admin/economy/users/{userId:guid}/premium/revoke")]
    [InlineData("PUT", "/api/admin/economy/packs/{packId:guid}")]
    [InlineData("PUT", "/api/admin/economy/subscription-plans/{planId}")]
    [InlineData("POST", "/api/admin/economy/redeem-codes")]
    [InlineData("PUT", "/api/admin/economy/redeem-codes/{redeemCodeId:guid}")]
    public async Task AdminEconomyJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Equal(32 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/admin/economy/payment-provider-configs")]
    [InlineData("POST", "/api/admin/economy/payment-provider-configs/{configurationId:guid}/clone")]
    [InlineData("POST", "/api/admin/economy/payment-provider-configs/test-match")]
    [InlineData("PUT", "/api/admin/economy/payment-provider-configs/{configurationId:guid}")]
    public async Task AdminEconomyProviderConfigurationMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await EconomyApiStartupTestApplication.CreateAsync();

        Assert.Equal(64 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("/api/admin/economy/purchases?status=chargeback", "economy.purchase_status_invalid")]
    [InlineData("/api/admin/economy/purchases?provider=paypal", "economy.payment_provider_invalid")]
    [InlineData("/api/admin/economy/subscriptions?status=paused", "economy.subscription_status_invalid")]
    [InlineData("/api/admin/economy/subscriptions?status=cancelled", "economy.subscription_status_invalid")]
    [InlineData("/api/admin/economy/subscriptions?provider=apple", "economy.payment_provider_invalid")]
    [InlineData("/api/admin/economy/subscription-events?status=ignored", "economy.subscription_event_status_invalid")]
    [InlineData("/api/admin/economy/subscription-events?status=cancelled", "economy.subscription_event_status_invalid")]
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
            builder.Configuration["AllowedHosts"] = "*";
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
                .Select(policy => policy!)
                .ToArray();
        }

        public Task<HttpResponseMessage> GetAsync(string path)
        {
            var client = app.GetTestClient();
            client.BaseAddress = new Uri("http://localhost");
            return client.GetAsync(path);
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
