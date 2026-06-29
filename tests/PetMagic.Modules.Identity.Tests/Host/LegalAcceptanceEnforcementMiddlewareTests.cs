using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Host.Api.Security;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class LegalAcceptanceEnforcementMiddlewareTests
{
    private static readonly Guid TestUserId = Guid.Parse("4C8E68E5-B23E-44F3-A2CC-47D32A8FBAF9");

    [Fact]
    public async Task InvokeAsync_ShouldAllowAnonymousEndpoint_WhenAuthenticatedUserRequiresLegalAcceptance()
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.GetAsync("/api/templates/feed");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_ShouldAllowRegisterEndpoint_WhenAuthenticatedUserRequiresLegalAcceptance()
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.PostAsJsonAsync("/api/auth/register", new { email = "new@example.com" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_ShouldBlockProtectedEndpoint_WhenAuthenticatedUserRequiresLegalAcceptance()
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.GetAsync("/api/templates/generations");
        var problem = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal("auth.legal_acceptance_required", problem?["title"]?.ToString());
    }

    private sealed class TestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private TestApplication(WebApplication app, HttpClient client)
        {
            this.app = app;
            Client = client;
        }

        public HttpClient Client { get; }

        public static async Task<TestApplication> CreateAsync()
        {
            var databaseRoot = new InMemoryDatabaseRoot();
            var databaseName = $"legal-acceptance-middleware-{Guid.NewGuid():N}";

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(LegalAcceptanceEnforcementMiddlewareTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Configuration["AllowedHosts"] = "*";
            builder.Services.AddDbContext<IdentityDbContext>(options =>
                options.UseInMemoryDatabase(databaseName, databaseRoot));
            builder.Services
                .AddIdentityCore<AppUser>()
                .AddRoles<IdentityRole<Guid>>()
                .AddEntityFrameworkStores<IdentityDbContext>();
            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
            builder.Services.AddAuthorization();
            builder.Services.AddMemoryCache();
            builder.Services.AddSingleton<ILegalDocumentsCatalog>(new FakeLegalDocumentsCatalog());

            var app = builder.Build();
            app.UseAuthentication();
            app.UseMiddleware<LegalAcceptanceEnforcementMiddleware>();
            app.UseAuthorization();

            app.MapGet("/api/templates/feed", () => Results.Ok(new { status = "public" }))
                .AllowAnonymous();
            app.MapPost("/api/auth/register", () => Results.Ok(new { status = "register" }))
                .AllowAnonymous();
            app.MapGet("/api/templates/generations", () => Results.Ok(new { status = "protected" }))
                .RequireAuthorization();

            await app.StartAsync();

            await using var scope = app.Services.CreateAsyncScope();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
            var result = await userManager.CreateAsync(new AppUser
            {
                Id = TestUserId,
                UserName = "legal-test@example.com",
                Email = "legal-test@example.com",
                EmailConfirmed = true,
                TermsOfUseAccepted = false,
                PrivacyPolicyAccepted = false,
            });

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", result.Errors.Select(error => error.Description)));
            }

            var client = app.GetTestClient();
            client.BaseAddress = new Uri("http://localhost");
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName);

            return new TestApplication(app, client);
        }

        public async ValueTask DisposeAsync()
        {
            await app.StopAsync();
            await app.DisposeAsync();
        }
    }

    private sealed class FakeLegalDocumentsCatalog : ILegalDocumentsCatalog
    {
        public string CurrentTermsOfUseVersion => "2026-05-20";

        public string CurrentPrivacyPolicyVersion => "2026-05-20";

        public LegalDocumentsResponse GetCurrentDocuments(string? locale)
        {
            throw new NotSupportedException();
        }

        public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
        {
            return string.Equals(termsOfUseVersion, CurrentTermsOfUseVersion, StringComparison.Ordinal)
                && string.Equals(privacyPolicyVersion, CurrentPrivacyPolicyVersion, StringComparison.Ordinal);
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
            if (!Request.Headers.TryGetValue("Authorization", out var authorization)
                || !string.Equals(authorization.ToString(), SchemeName, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, TestUserId.ToString()),
            };

            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
