using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
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
