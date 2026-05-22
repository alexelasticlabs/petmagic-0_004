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
