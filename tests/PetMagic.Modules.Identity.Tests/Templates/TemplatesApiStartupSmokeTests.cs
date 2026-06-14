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

using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesApiStartupSmokeTests
{
    [Fact]
    public async Task TemplatesApiModule_ShouldStartHostWithoutEndpointInferenceErrors()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.NotNull(app);
    }

    [Theory]
    [InlineData("POST", "/api/templates/{templateId:guid}/generations", "generation-create")]
    [InlineData("GET", "/api/templates/generations", "generation-status")]
    [InlineData("GET", "/api/templates/generations/{generationId:guid}", "generation-status")]
    [InlineData("GET", "/api/generations/{generationId:guid}", "generation-status")]
    [InlineData("POST", "/api/generations/{generationId:guid}/remove-watermark", "templates")]
    [InlineData("GET", "/api/generations/{generationId:guid}/download", "templates")]
    [InlineData("POST", "/api/generations/{generationId:guid}/share", "templates")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/feedback", "templates")]
    public async Task TemplateGenerationEndpoints_ShouldUseExpectedRateLimitPolicies(
        string method,
        string routePattern,
        string expectedPolicy)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedPolicy, app.GetRateLimitPolicy(method, routePattern));
    }

    [Fact]
    public async Task TemplatesApiEndpoints_ShouldAllDeclareRateLimitPolicies()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimit());
    }

    [Fact]
    public async Task TemplatesApiEndpoints_ShouldAllDeclareAccessPolicy()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task TemplatesAdminEndpoints_ShouldRequireAdminOrModeratorPolicy()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    [Theory]
    [InlineData("POST", "/api/admin/templates/image")]
    [InlineData("PUT", "/api/admin/templates/image/{templateId:guid}")]
    [InlineData("POST", "/api/admin/templates/video")]
    [InlineData("PUT", "/api/admin/templates/video/{templateId:guid}")]
    [InlineData("PUT", "/api/admin/templates/{templateId:guid}/status")]
    [InlineData("DELETE", "/api/admin/templates/{templateId:guid}")]
    [InlineData("POST", "/api/admin/templates/{templateId:guid}/test")]
    [InlineData("POST", "/api/admin/templates/media/upload")]
    [InlineData("GET", "/api/admin/templates/monetization/watermark")]
    [InlineData("PUT", "/api/admin/templates/monetization/watermark")]
    [InlineData("POST", "/api/admin/templates/generations/{generationId:guid}/grant-clean-download")]
    [InlineData("POST", "/api/admin/templates/categories/")]
    [InlineData("PUT", "/api/admin/templates/categories/{categoryId:guid}")]
    [InlineData("PUT", "/api/admin/templates/categories/{categoryId:guid}/archive")]
    [InlineData("DELETE", "/api/admin/templates/categories/{categoryId:guid}")]
    public async Task TemplatesAdminMutationEndpoints_ShouldRequireAdminOnlyPolicy(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Contains("AdminOnly", app.GetAuthorizationPolicies(method, routePattern));
    }

    [Theory]
    [InlineData("GET", "/api/admin/template-of-the-day")]
    [InlineData("GET", "/api/admin/template-of-the-day/current")]
    [InlineData("GET", "/api/admin/template-of-the-day/schedule")]
    [InlineData("GET", "/api/admin/template-of-the-day/settings")]
    [InlineData("PUT", "/api/admin/template-of-the-day/settings")]
    [InlineData("POST", "/api/admin/template-of-the-day")]
    [InlineData("PUT", "/api/admin/template-of-the-day/{id:guid}")]
    [InlineData("DELETE", "/api/admin/template-of-the-day/{id:guid}")]
    [InlineData("POST", "/api/admin/template-of-the-day/auto-pick")]
    public async Task TemplateOfTheDayAdminEndpoints_ShouldRequireAdminOnlyPolicy(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Contains("AdminOnly", app.GetAuthorizationPolicies(method, routePattern));
    }

    [Theory]
    [InlineData("GET", "/api/admin/templates/categories/")]
    [InlineData("GET", "/api/admin/templates/moderation")]
    [InlineData("POST", "/api/admin/templates/moderation/{eventId:guid}/decision")]
    public async Task TemplatesModeratorReadAndModerationEndpoints_ShouldKeepModeratorPolicy(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Contains("ModeratorOrAdmin", app.GetAuthorizationPolicies(method, routePattern));
    }

    private sealed class TemplatesApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private TemplatesApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<TemplatesApiStartupTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(TemplatesApiStartupSmokeTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("templates", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("generation-create", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("generation-status", _ => RateLimitPartition.GetNoLimiter("tests"));
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

            builder.Services.AddScoped<ITemplatesService>(_ =>
                throw new NotSupportedException("ITemplatesService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ITemplateFeedRealtimeService>(_ =>
                throw new NotSupportedException("ITemplateFeedRealtimeService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IMediaStorage>(_ =>
                throw new NotSupportedException("IMediaStorage should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ITemplateMediaUploadPolicy>(_ =>
                throw new NotSupportedException("ITemplateMediaUploadPolicy should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ITemplateGenerationService>(_ =>
                throw new NotSupportedException("ITemplateGenerationService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ITemplatePushTokenService>(_ =>
                throw new NotSupportedException("ITemplatePushTokenService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<ITemplateMediaLifecycleService>(_ =>
                throw new NotSupportedException("ITemplateMediaLifecycleService should not be resolved during startup smoke test."));
            builder.Services.AddScoped<IMediaMetadataReader>(_ =>
                throw new NotSupportedException("IMediaMetadataReader should not be resolved during startup smoke test."));

            builder.Services.AddTemplatesApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapTemplatesApiModule();

            await app.StartAsync();

            return new TemplatesApiStartupTestApplication(app);
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

            return endpoint.Metadata
                .GetOrderedMetadata<IAuthorizeData>()
                .Select(metadata => metadata.Policy)
                .Where(policy => !string.IsNullOrWhiteSpace(policy))
                .Cast<string>()
                .ToArray();
        }

        private static string NormalizeRoutePattern(string? routePattern)
        {
            if (string.IsNullOrWhiteSpace(routePattern) || routePattern == "/")
            {
                return routePattern ?? string.Empty;
            }

            return routePattern.TrimEnd('/');
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
