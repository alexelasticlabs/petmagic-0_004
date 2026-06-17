using System.Net;
using System.Net.Http.Json;
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

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Api.Endpoints;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AuthEndpointsNativeGoogleTests
{
    [Fact]
    public async Task GoogleMobileConfig_ShouldReturnServerClientId_WhenConfigured()
    {
        await using var app = await TestApplication.CreateAsync(
            new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id"),
            new FakeIdentityService());

        var response = await app.Client.GetAsync("/api/auth/external/google/mobile-config");
        var payload = await response.Content.ReadFromJsonAsync<GoogleMobileConfigResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("google-web-client-id", payload!.ServerClientId);
    }

    [Fact]
    public async Task GoogleNativeLogin_ShouldReturnSession_WhenTokenVerificationSucceeds()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(
            isConfigured: true,
            clientId: "google-web-client-id",
            verifiedCommand: new ExternalLoginCallbackCommand(
                "Google",
                "google-subject-1",
                "pet@example.com",
                "Pet Parent"));
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service);

        var response = await app.Client.PostAsJsonAsync(
            "/api/auth/external/google/native",
            new GoogleNativeLoginCommand("native-google-id-token"));
        var payload = await response.Content.ReadFromJsonAsync<TokenPairResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("pet@example.com", payload!.User.Email);
        Assert.NotNull(service.LastExternalLoginCommand);
        Assert.Equal("Google", service.LastExternalLoginCommand!.Provider);
        Assert.Equal("google-subject-1", service.LastExternalLoginCommand.ProviderSubject);
        Assert.True(response.Headers.TryGetValues("Set-Cookie", out var setCookieValues));
        var refreshCookie = Assert.Single(
            setCookieValues,
            value => value.Contains("petmagic_refresh_token=refresh-token", StringComparison.Ordinal));
        AssertRefreshCookieSecurity(refreshCookie, expectSecure: false);
    }

    [Fact]
    public async Task GoogleSocialLogin_ShouldReturnSession_WhenTokenVerificationSucceeds()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(
            isConfigured: true,
            clientId: "google-web-client-id",
            verifiedCommand: new ExternalLoginCallbackCommand(
                "Google",
                "google-subject-2",
                "pet@example.com",
                "Pet Parent"));
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service);

        var response = await app.Client.PostAsJsonAsync(
            "/api/auth/google",
            new GoogleSocialLoginCommand("native-google-id-token", "server-auth-code"));
        var payload = await response.Content.ReadFromJsonAsync<TokenPairResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("pet@example.com", payload!.User.Email);
        Assert.NotNull(service.LastExternalLoginCommand);
        Assert.Equal("Google", service.LastExternalLoginCommand!.Provider);
        Assert.Equal("google-subject-2", service.LastExternalLoginCommand.ProviderSubject);
    }

    [Fact]
    public async Task GoogleSocialLogin_ShouldReturnUnauthorized_WhenTokenVerificationFails()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service);

        var response = await app.Client.PostAsJsonAsync(
            "/api/auth/google",
            new GoogleSocialLoginCommand("invalid-google-id-token", "server-auth-code"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Null(service.LastExternalLoginCommand);
    }

    [Fact]
    public async Task AppleSocialLogin_ShouldReturnSession_WhenTokenVerificationSucceeds()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var appleVerifier = new FakeAppleIdentityTokenVerifier(
            verifiedCommand: new ExternalLoginCallbackCommand(
                "Apple",
                "apple-subject-1",
                "relay@privaterelay.appleid.com",
                null));
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service, appleVerifier: appleVerifier);

        var response = await app.Client.PostAsJsonAsync(
            "/api/auth/apple",
            new AppleSocialLoginCommand("apple-identity-token", "apple-auth-code"));
        var payload = await response.Content.ReadFromJsonAsync<TokenPairResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("relay@privaterelay.appleid.com", payload!.User.Email);
        Assert.NotNull(service.LastExternalLoginCommand);
        Assert.Equal("Apple", service.LastExternalLoginCommand!.Provider);
        Assert.Equal("apple-subject-1", service.LastExternalLoginCommand.ProviderSubject);
    }

    [Fact]
    public async Task AppleSocialLogin_ShouldReturnUnauthorized_WhenTokenVerificationFails()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var appleVerifier = new FakeAppleIdentityTokenVerifier();
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service, appleVerifier: appleVerifier);

        var response = await app.Client.PostAsJsonAsync(
            "/api/auth/apple",
            new AppleSocialLoginCommand("invalid-apple-identity-token", "apple-auth-code"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Null(service.LastExternalLoginCommand);
    }

    [Fact]
    public async Task Refresh_ShouldUseCookieToken_WhenRequestBodyDoesNotContainToken()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service);
        app.Client.DefaultRequestHeaders.Add("Cookie", "petmagic_refresh_token=cookie-refresh-token");

        var response = await app.Client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = string.Empty });
        var payload = await response.Content.ReadFromJsonAsync<TokenPairResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(service.LastRefreshCommand);
        Assert.Equal("cookie-refresh-token", service.LastRefreshCommand!.RefreshToken);
        Assert.NotNull(payload);
        Assert.Equal("rotated-refresh-token", payload!.RefreshToken);
        Assert.True(response.Headers.TryGetValues("Set-Cookie", out var setCookieValues));
        var refreshCookie = Assert.Single(
            setCookieValues,
            value => value.Contains("petmagic_refresh_token=rotated-refresh-token", StringComparison.Ordinal));
        AssertRefreshCookieSecurity(refreshCookie, expectSecure: false);
    }

    [Fact]
    public async Task Refresh_ShouldSetSecureRefreshCookie_WhenRequestIsHttps()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(
            verifier,
            service,
            baseAddress: new Uri("https://localhost"));
        app.Client.DefaultRequestHeaders.Add("Cookie", "petmagic_refresh_token=cookie-refresh-token");

        var response = await app.Client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = string.Empty });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.TryGetValues("Set-Cookie", out var setCookieValues));
        var refreshCookie = Assert.Single(
            setCookieValues,
            value => value.Contains("petmagic_refresh_token=rotated-refresh-token", StringComparison.Ordinal));
        AssertRefreshCookieSecurity(refreshCookie, expectSecure: true);
    }

    [Fact]
    public async Task UpdateAvatar_ShouldRejectDeclaredImageWithInvalidMagicBytes()
    {
        var verifier = new FakeGoogleIdentityTokenVerifier(isConfigured: true, clientId: "google-web-client-id");
        var service = new FakeIdentityService();

        await using var app = await TestApplication.CreateAsync(verifier, service);
        using var content = new MultipartFormDataContent();
        using var file = new ByteArrayContent("not-an-image"u8.ToArray());
        file.Headers.ContentType = new("image/png");
        content.Add(file, "file", "../avatar.png");

        var response = await app.Client.PutAsync("/api/auth/me/avatar", content);
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("Avatar content type is not allowed", body, StringComparison.Ordinal);
        Assert.Null(service.LastUpdateAvatarCommand);
    }

    private static void AssertRefreshCookieSecurity(string setCookie, bool expectSecure)
    {
        Assert.Contains("httponly", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("path=/api/auth", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(expectSecure ? "samesite=none" : "samesite=lax", setCookie, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(expectSecure, setCookie.Contains("secure", StringComparison.OrdinalIgnoreCase));
    }

    private sealed class GoogleMobileConfigResponse
    {
        public string ServerClientId { get; set; } = string.Empty;
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

        public static async Task<TestApplication> CreateAsync(
            IGoogleIdentityTokenVerifier verifier,
            FakeIdentityService service,
            Uri? baseAddress = null,
            IAppleIdentityTokenVerifier? appleVerifier = null)
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(AuthEndpointsNativeGoogleTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddMemoryCache();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("auth", _ =>
                    RateLimitPartition.GetNoLimiter("tests"));
            });
            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
            builder.Services.AddAuthorization();
            builder.Services.AddIdentityApiModule();
            builder.Services.AddSingleton(verifier);
            builder.Services.AddSingleton(appleVerifier ?? new FakeAppleIdentityTokenVerifier());
            builder.Services.AddSingleton<ILegalDocumentsCatalog>(new FakeLegalDocumentsCatalog());
            builder.Services.AddSingleton<IIdentityService>(service);

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapAuthEndpoints();

            await app.StartAsync();
            var client = app.GetTestClient();
            if (baseAddress is not null)
            {
                client.BaseAddress = baseAddress;
            }

            return new TestApplication(app, client);
        }

        public async ValueTask DisposeAsync()
        {
            Client.Dispose();
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
                new Claim("sub", Guid.NewGuid().ToString()),
            };
            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }

    private sealed class FakeAppleIdentityTokenVerifier(
        ExternalLoginCallbackCommand? verifiedCommand = null) : IAppleIdentityTokenVerifier
    {
        public bool IsConfigured => true;

        public Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(string identityToken, CancellationToken cancellationToken)
        {
            if (verifiedCommand is null)
            {
                return Task.FromResult(Result.Failure<ExternalLoginCallbackCommand>(
                    new Error("auth.external_token_invalid", "External identity token is invalid.")));
            }

            return Task.FromResult(Result.Success(verifiedCommand));
        }
    }

    private sealed class FakeGoogleIdentityTokenVerifier(
        bool isConfigured,
        string? clientId,
        ExternalLoginCallbackCommand? verifiedCommand = null) : IGoogleIdentityTokenVerifier
    {
        public bool IsConfigured { get; } = isConfigured;

        public string? ClientId { get; } = clientId;

        public Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(string idToken, CancellationToken cancellationToken)
        {
            if (verifiedCommand is null)
            {
                return Task.FromResult(Result.Failure<ExternalLoginCallbackCommand>(
                    new Error("auth.external_token_invalid", "External identity token is invalid.")));
            }

            return Task.FromResult(Result.Success(verifiedCommand));
        }
    }

    private sealed class FakeIdentityService : IIdentityService
    {
        private static readonly LegalAcceptanceStatusResponse DefaultLegalAcceptance = new(
            true,
            "2026-05-20",
            DateTime.UtcNow,
            true,
            "2026-05-20",
            DateTime.UtcNow,
            "2026-05-20",
            "2026-05-20",
            false);

        public ExternalLoginCallbackCommand? LastExternalLoginCommand { get; private set; }

        public RefreshTokenCommand? LastRefreshCommand { get; private set; }

        public UpdateUserAvatarCommand? LastUpdateAvatarCommand { get; private set; }

        public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken) => NotSupported<LegalDocumentsResponse>();
        public Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> VerifyEmailCodeAsync(VerifyEmailCodeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ResendEmailVerificationCodeAsync(ResendEmailVerificationCodeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> VerifyPasswordResetCodeAsync(VerifyPasswordResetCodeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ResetPasswordAsync(ResetPasswordCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestCurrentPasswordChangeCodeAsync(Guid userId, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmCurrentPasswordChangeAsync(Guid userId, ConfirmCurrentPasswordChangeCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
        {
            LastExternalLoginCommand = command;

            return Task.FromResult(Result.Success(new TokenPairResponse(
                "access-token",
                "refresh-token",
                DateTime.UtcNow.AddMinutes(30),
                new UserProfileResponse(
                    Guid.NewGuid(),
                    command.Email ?? "pet@example.com",
                    command.DisplayName,
                    false,
                    true,
                    "Active",
                    true,
                    false,
                    false,
                    DefaultLegalAcceptance,
                    ["user"],
                    null))));
        }

        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> GetLinkedAccountsAsync(Guid userId, CancellationToken cancellationToken)
            => NotSupported<IReadOnlyList<LinkedAccountResponse>>();

        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> LinkExternalLoginAsync(Guid userId, ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
            => NotSupported<IReadOnlyList<LinkedAccountResponse>>();

        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> UnlinkExternalLoginAsync(Guid userId, string provider, CancellationToken cancellationToken)
            => NotSupported<IReadOnlyList<LinkedAccountResponse>>();

        public Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken)
        {
            LastRefreshCommand = command;

            return Task.FromResult(Result.Success(new TokenPairResponse(
                "access-token-rotated",
                "rotated-refresh-token",
                DateTime.UtcNow.AddMinutes(30),
                new UserProfileResponse(
                    Guid.NewGuid(),
                    "pet@example.com",
                    "Pet Parent",
                    false,
                    true,
                    "Active",
                    true,
                    false,
                    false,
                    DefaultLegalAcceptance,
                    ["user"],
                    null))));
        }
        public Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateCurrentUserProfileAsync(Guid userId, UpdateCurrentUserProfileCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken)
        {
            LastUpdateAvatarCommand = command;
            return NotSupported<UserProfileResponse>();
        }
        public Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserListPageResponse>> ListUsersAsync(int skip, int take, string? search, string? role, string? status, bool? isPremium, CancellationToken cancellationToken) => NotSupported<UserListPageResponse>();
        public Task<Result<AdminUserDashboardMetricsResponse>> GetAdminUserDashboardMetricsAsync(CancellationToken cancellationToken) => NotSupported<AdminUserDashboardMetricsResponse>();
        public Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserDetailResponse>();
        public Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserAnalyticsResponse>();
        public Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken) => NotSupported<AdminUserWalletOperationResponse>();
        public Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteAdminUserAsync(DeleteAdminUserCommand command, CancellationToken cancellationToken) => NotSupported();

        private static Task<Result> NotSupported() => Task.FromException<Result>(new NotSupportedException());
        private static Task<Result<T>> NotSupported<T>() => Task.FromException<Result<T>>(new NotSupportedException());
    }

    private sealed class FakeLegalDocumentsCatalog : ILegalDocumentsCatalog
    {
        public string CurrentTermsOfUseVersion => "2026-05-20";

        public string CurrentPrivacyPolicyVersion => "2026-05-20";

        public LegalDocumentsResponse GetCurrentDocuments(string? locale)
        {
            return new LegalDocumentsResponse(
                new LegalDocumentResponse(
                    LegalDocumentKinds.TermsOfUse,
                    "Terms",
                    CurrentTermsOfUseVersion,
                    DateTime.UtcNow,
                    "Summary",
                    []),
                new LegalDocumentResponse(
                    LegalDocumentKinds.PrivacyPolicy,
                    "Privacy",
                    CurrentPrivacyPolicyVersion,
                    DateTime.UtcNow,
                    "Summary",
                    []));
        }

        public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
        {
            return string.Equals(termsOfUseVersion, CurrentTermsOfUseVersion, StringComparison.Ordinal)
                && string.Equals(privacyPolicyVersion, CurrentPrivacyPolicyVersion, StringComparison.Ordinal);
        }
    }
}
