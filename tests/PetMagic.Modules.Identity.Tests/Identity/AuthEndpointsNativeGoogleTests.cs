using System.Net;
using System.Net.Http.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
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
            FakeIdentityService service)
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
            builder.Services.AddAuthorization();
            builder.Services.AddIdentityApiModule();
            builder.Services.AddSingleton(verifier);
            builder.Services.AddSingleton<ILegalDocumentsCatalog>(new FakeLegalDocumentsCatalog());
            builder.Services.AddSingleton<IIdentityService>(service);

            var app = builder.Build();
            app.UseRateLimiter();
            app.MapAuthEndpoints();

            await app.StartAsync();
            return new TestApplication(app, app.GetTestClient());
        }

        public async ValueTask DisposeAsync()
        {
            Client.Dispose();
            await app.StopAsync();
            await app.DisposeAsync();
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

        public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken) => NotSupported<LegalDocumentsResponse>();
        public Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();

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

        public Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken) => NotSupported<IReadOnlyList<UserListItemResponse>>();
        public Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserDetailResponse>();
        public Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserAnalyticsResponse>();
        public Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken) => NotSupported<AdminUserWalletOperationResponse>();
        public Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken) => NotSupported();

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
