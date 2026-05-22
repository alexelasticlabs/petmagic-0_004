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
