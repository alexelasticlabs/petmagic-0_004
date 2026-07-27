using System.Net;
using System.Net.Http.Headers;
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
    [InlineData("GET", "/api/templates/generation-results/{resultId:guid}/compatible-templates", "templates")]
    [InlineData("POST", "/api/templates/generations/from-pet", "generation-create")]
    [InlineData("POST", "/api/templates/generations/from-result", "generation-create")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/generate-similar", "generation-create")]
    [InlineData("GET", "/api/templates/generations", "generation-status")]
    [InlineData("GET", "/api/templates/generations/{generationId:guid}", "generation-status")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/remove-watermark", "templates")]
    [InlineData("GET", "/api/templates/generations/{generationId:guid}/download", "templates")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/share", "templates")]
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

    [Fact]
    public async Task TemplatesAdminMutationEndpoints_ShouldRequireAdminOnlyPolicy()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        var endpoints = new[]
        {
            ("POST", "/api/admin/templates/image"),
            ("PUT", "/api/admin/templates/image/{templateId:guid}"),
            ("POST", "/api/admin/templates/video"),
            ("PUT", "/api/admin/templates/video/{templateId:guid}"),
            ("PUT", "/api/admin/templates/{templateId:guid}/status"),
            ("DELETE", "/api/admin/templates/{templateId:guid}"),
            ("POST", "/api/admin/templates/{templateId:guid}/test"),
            ("POST", "/api/admin/templates/media/upload"),
            ("GET", "/api/admin/templates/generations"),
            ("GET", "/api/admin/templates/generations/metrics"),
            ("GET", "/api/admin/templates/generations/{generationId:guid}"),
            ("POST", "/api/admin/templates/moderation/{eventId:guid}/handoff"),
            ("GET", "/api/admin/templates/monetization/watermark"),
            ("PUT", "/api/admin/templates/monetization/watermark"),
            ("POST", "/api/admin/templates/generations/{generationId:guid}/grant-clean-download"),
            ("POST", "/api/templates/qa/generation-fixtures"),
            ("DELETE", "/api/templates/qa/generation-fixtures"),
            ("GET", "/api/admin/templates/categories/diagnostics"),
            ("POST", "/api/admin/templates/categories/"),
            ("PUT", "/api/admin/templates/categories/{categoryId:guid}"),
            ("PUT", "/api/admin/templates/categories/{categoryId:guid}/archive"),
            ("DELETE", "/api/admin/templates/categories/{categoryId:guid}")
        };

        foreach (var (method, routePattern) in endpoints)
        {
            Assert.Contains("AdminOnly", app.GetAuthorizationPolicies(method, routePattern));
        }
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
    [InlineData("GET", "/api/admin/templates/analytics")]
    [InlineData("GET", "/api/admin/templates/moderation")]
    [InlineData("POST", "/api/admin/templates/moderation/{eventId:guid}/claim")]
    [InlineData("POST", "/api/admin/templates/moderation/{eventId:guid}/release")]
    [InlineData("POST", "/api/admin/templates/moderation/{eventId:guid}/decision")]
    public async Task TemplatesModeratorReadAndModerationEndpoints_ShouldKeepModeratorPolicy(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Contains("ModeratorOrAdmin", app.GetAuthorizationPolicies(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/templates/generations/from-result")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/generate-similar")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/remove-watermark")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/share")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/mark-read")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/cancel")]
    [InlineData("DELETE", "/api/templates/generations/{generationId:guid}")]
    [InlineData("POST", "/api/templates/generations/{generationId:guid}/feedback")]
    [InlineData("DELETE", "/api/templates/qa/generation-fixtures")]
    [InlineData("PUT", "/api/templates/notifications/push-token")]
    [InlineData("DELETE", "/api/templates/notifications/push-token")]
    public async Task TemplateGenerationJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(16 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/templates/{templateId:guid}/generations", 26L * 1024 * 1024)]
    [InlineData("POST", "/api/templates/qa/generation-fixtures", 64L * 1024)]
    [InlineData("POST", "/api/templates/provider/fal/webhook", 256L * 1024)]
    public async Task TemplateGenerationPayloadEndpoints_ShouldLimitRequestBodiesBeforeReadingPayload(
        string method,
        string routePattern,
        long expectedBytes)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(expectedBytes, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/pets")]
    [InlineData("PUT", "/api/pets/{petId:guid}")]
    [InlineData("DELETE", "/api/pets/{petId:guid}")]
    [InlineData("POST", "/api/pets/{petId:guid}/photos/{photoId:guid}/set-avatar")]
    [InlineData("POST", "/api/pets/{petId:guid}/photos/{photoId:guid}/favorite")]
    [InlineData("DELETE", "/api/pets/{petId:guid}/photos/{photoId:guid}")]
    [InlineData("POST", "/api/templates/generations/from-pet")]
    [InlineData("POST", "/api/admin/users/{userId:guid}/pets/{petId:guid}/status")]
    [InlineData("POST", "/api/admin/users/{userId:guid}/pets/{petId:guid}/photos/{photoId:guid}/status")]
    public async Task PetJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(16 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/admin/templates/image")]
    [InlineData("PUT", "/api/admin/templates/image/{templateId:guid}")]
    [InlineData("POST", "/api/admin/templates/video")]
    [InlineData("PUT", "/api/admin/templates/video/{templateId:guid}")]
    public async Task AdminTemplateDefinitionMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(128 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("POST", "/api/admin/templates/moderation/{eventId:guid}/decision")]
    [InlineData("PUT", "/api/admin/templates/monetization/watermark")]
    [InlineData("POST", "/api/admin/templates/generations/{generationId:guid}/grant-clean-download")]
    [InlineData("POST", "/api/admin/templates/generations/{generationId:guid}/cancel")]
    [InlineData("POST", "/api/admin/templates/generations/{generationId:guid}/retry")]
    [InlineData("POST", "/api/admin/templates/generations/{generationId:guid}/retry-refund")]
    [InlineData("PUT", "/api/admin/templates/{templateId:guid}/status")]
    [InlineData("DELETE", "/api/admin/templates/{templateId:guid}")]
    [InlineData("POST", "/api/admin/templates/categories/")]
    [InlineData("PUT", "/api/admin/templates/categories/{categoryId:guid}")]
    [InlineData("PUT", "/api/admin/templates/categories/{categoryId:guid}/archive")]
    [InlineData("DELETE", "/api/admin/templates/categories/{categoryId:guid}")]
    [InlineData("POST", "/api/admin/template-of-the-day")]
    [InlineData("PUT", "/api/admin/template-of-the-day/settings")]
    [InlineData("PUT", "/api/admin/template-of-the-day/{id:guid}")]
    [InlineData("DELETE", "/api/admin/template-of-the-day/{id:guid}")]
    [InlineData("POST", "/api/admin/template-of-the-day/auto-pick")]
    public async Task AdminTemplateSmallJsonMutationEndpoints_ShouldLimitRequestBodiesBeforeBinding(
        string method,
        string routePattern)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        Assert.Equal(16 * 1024, app.GetRequestSizeLimit(method, routePattern));
    }

    [Theory]
    [InlineData("/api/admin/templates/generations?status=queued", "templates.invalid_status")]
    [InlineData("/api/admin/templates/generations?status=processing", "templates.invalid_status")]
    [InlineData("/api/admin/templates/generations?status=success", "templates.invalid_status")]
    [InlineData("/api/admin/templates/generations?status=canceled", "templates.invalid_status")]
    public async Task TemplatesAdminGenerationsEndpoint_ShouldRejectLegacyStatusAliasesBeforeServiceResolution(
        string path,
        string _)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        using var response = await app.Client.GetAsync(path);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/admin/templates/analytics?templateType=gif")]
    [InlineData("/api/admin/templates/analytics?status=visible")]
    [InlineData("/api/admin/templates/analytics?access=paid")]
    [InlineData("/api/admin/templates/analytics?sort=random")]
    public async Task TemplatesAdminAnalyticsEndpoint_ShouldRejectInvalidFiltersBeforeServiceResolution(string path)
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        using var response = await app.Client.GetAsync(path);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task TemplatesAdminAnalyticsEndpoint_ShouldRejectMoreThanOneHundredTemplateIdsBeforeServiceResolution()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();
        var query = string.Join(
            "&",
            Enumerable.Range(0, 101).Select(_ => $"templateIds={Guid.NewGuid():D}"));

        using var response = await app.Client.GetAsync($"/api/admin/templates/analytics?{query}");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("templates.too_many_template_ids", body);
    }

    [Fact]
    public async Task TemplatesAdminTemplateFeedbackEndpoint_ShouldRejectInvalidTypeBeforeServiceResolution()
    {
        await using var app = await TemplatesApiStartupTestApplication.CreateAsync();

        using var response = await app.Client.GetAsync(
            "/api/admin/templates/11111111-1111-1111-1111-111111111111/statistics/feedback?type=view");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private sealed class TemplatesApiStartupTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;
        private readonly HttpClient client;

        private TemplatesApiStartupTestApplication(WebApplication app)
        {
            this.app = app;
            client = app.GetTestClient();
            client.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
        }

        public HttpClient Client => client;

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
                options.AddPolicy("templates-analytics", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("templates-events", _ => RateLimitPartition.GetNoLimiter("tests"));
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
