using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

using IdentityModuleDbContext = PetMagic.Modules.Identity.Infrastructure.Data.IdentityDbContext;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityServiceEmailFlowTests
{
    private const string CurrentLegalVersion = "2026-05-20";

    [Fact]
    public async Task RegisterAsync_ShouldPersistPreferences_And_RequireEmailVerificationBeforeLogin()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("demo.user@petmagic.app", "StrongPassword123", "Demo User", true, true, CurrentLegalVersion, CurrentLegalVersion, true),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);
        Assert.False(registerResult.Value.EmailConfirmed);
        Assert.Equal("PendingEmailVerification", registerResult.Value.AccountStatus);
        Assert.True(registerResult.Value.TermsOfUseAccepted);
        Assert.True(registerResult.Value.PrivacyPolicyAccepted);
        Assert.True(registerResult.Value.MarketingEmailsEnabled);
        Assert.False(registerResult.Value.LegalAcceptance.RequiresAcceptance);

        var persistedUser = await dbContext.Users.SingleAsync();
        Assert.False(persistedUser.EmailConfirmed);
        Assert.True(persistedUser.TermsOfUseAccepted);
        Assert.NotNull(persistedUser.TermsOfUseAcceptedAtUtc);
        Assert.Equal(CurrentLegalVersion, persistedUser.TermsOfUseAcceptedVersion);
        Assert.True(persistedUser.PrivacyPolicyAccepted);
        Assert.NotNull(persistedUser.PrivacyPolicyAcceptedAtUtc);
        Assert.Equal(CurrentLegalVersion, persistedUser.PrivacyPolicyAcceptedVersion);
        Assert.True(persistedUser.MarketingEmailsEnabled);
        Assert.NotNull(persistedUser.MarketingEmailsUpdatedAtUtc);
        Assert.Single(await dbContext.UserEmailCodes.ToListAsync());
        Assert.Single(await dbContext.EmailDispatchJobs.ToListAsync());

        var loginResult = await service.LoginAsync(
            new LoginCommand("demo.user@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsFailure);
    }

    [Fact]
    public async Task AuthFlows_ShouldWriteStructuredBusinessLogsWithoutCredentials()
    {
        await using var dbContext = CreateDbContext();
        var logger = new CapturingLogger<IdentityService>();
        var service = await CreateServiceAsync(dbContext, logger: logger);

        using var correlationScope = CorrelationContext.Push("auth-business-correlation");
        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("logs.user@petmagic.app", "StrongPassword123", "Logs User", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var loginResult = await service.LoginAsync(
            new LoginCommand("logs.user@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsSuccess);

        var invalidLoginResult = await service.LoginAsync(
            new LoginCommand("missing.user@petmagic.app", "WrongPassword123"),
            CancellationToken.None);

        Assert.True(invalidLoginResult.IsFailure);

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Information
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "registration")
            && entry.Properties.TryGetValue("Result", out var result)
            && Equals(result, "pending_email_verification")
            && entry.Properties.TryGetValue("CorrelationId", out var correlationId)
            && Equals(correlationId, "auth-business-correlation"));

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Information
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "login")
            && entry.Properties.TryGetValue("Result", out var result)
            && Equals(result, "succeeded"));

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Warning
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "login")
            && entry.Properties.TryGetValue("Reason", out var reason)
            && Equals(reason, "invalid_credentials"));

        var serializedLogs = string.Join('\n', logger.Entries.Select(entry => entry.Message));
        Assert.DoesNotContain("logs.user@petmagic.app", serializedLogs);
        Assert.DoesNotContain("missing.user@petmagic.app", serializedLogs);
        Assert.DoesNotContain("StrongPassword123", serializedLogs);
        Assert.DoesNotContain("WrongPassword123", serializedLogs);
    }

    [Fact]
    public async Task RegisterAsync_ShouldQueueRussianEmail_WhenAcceptLanguageIsRussian()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(
            dbContext,
            acceptLanguage: "ru-RU,ru;q=0.9",
            emailTemplateRenderer: CreateRealEmailTemplateRenderer());

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("locale.ru@petmagic.app", "StrongPassword123", "Анна", true, true, CurrentLegalVersion, CurrentLegalVersion, true),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var queuedEmail = await dbContext.EmailDispatchJobs.SingleAsync();
        Assert.Equal("Подтвердите email в PetMagic", queuedEmail.Subject);
        Assert.Contains("Здравствуйте Анна", queuedEmail.HtmlBody);
    }

    [Fact]
    public async Task RequestEmailConfirmationAsync_ShouldIssueCode_ForPendingRegistration()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("confirm.me@petmagic.app", "StrongPassword123", "Confirm Me", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var requestResult = await service.RequestEmailConfirmationAsync(
            new RequestEmailConfirmationCommand("confirm.me@petmagic.app"),
            CancellationToken.None);

        Assert.True(requestResult.IsSuccess);

        var persistedUser = await dbContext.Users.SingleAsync();
        Assert.False(persistedUser.EmailConfirmed);
        Assert.NotEmpty(await dbContext.UserEmailCodes.ToListAsync());
        Assert.NotEmpty(await dbContext.EmailDispatchJobs.ToListAsync());

        var loginResult = await service.LoginAsync(
            new LoginCommand("confirm.me@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsFailure);
    }

    [Fact]
    public async Task ConfirmPasswordResetAsync_ShouldUpdatePassword_And_RevokeRefreshTokens()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("reset.me@petmagic.app", "StrongPassword123", "Reset Me", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var initialLogin = await service.LoginAsync(
            new LoginCommand("reset.me@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(initialLogin.IsSuccess);
        Assert.Single(await dbContext.RefreshTokenSessions.Where(x => x.UserId == user.Id && x.RevokedAtUtc == null).ToListAsync());

        var requestReset = await service.RequestPasswordResetAsync(
            new RequestPasswordResetCommand("reset.me@petmagic.app"),
            CancellationToken.None);

        Assert.True(requestReset.IsSuccess);

        var resetCode = await dbContext.UserEmailCodes
            .Where(x => x.Purpose == EmailCodePurpose.PasswordReset)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstAsync();
        resetCode.CodeHash = HashValue("654321");
        await dbContext.SaveChangesAsync();

        var confirmReset = await service.ConfirmPasswordResetAsync(
            new ConfirmPasswordResetCommand("reset.me@petmagic.app", "654321", "AnotherStrong123"),
            CancellationToken.None);

        Assert.True(confirmReset.IsSuccess);

        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == user.Id)
            .ToListAsync();
        Assert.NotEmpty(sessions);
        Assert.All(sessions, session => Assert.NotNull(session.RevokedAtUtc));

        var oldPasswordLogin = await service.LoginAsync(
            new LoginCommand("reset.me@petmagic.app", "StrongPassword123"),
            CancellationToken.None);
        Assert.True(oldPasswordLogin.IsFailure);

        var newPasswordLogin = await service.LoginAsync(
            new LoginCommand("reset.me@petmagic.app", "AnotherStrong123"),
            CancellationToken.None);
        Assert.True(newPasswordLogin.IsSuccess);
    }

    [Fact]
    public async Task ConfirmCurrentPasswordChangeAsync_ShouldKeepCurrentSession_And_RevokeOtherSessions()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("inapp.change@petmagic.app", "StrongPassword123", "In App", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var deviceOneSession = await service.LoginAsync(
            new LoginCommand("inapp.change@petmagic.app", "StrongPassword123"),
            CancellationToken.None);
        var deviceTwoSession = await service.LoginAsync(
            new LoginCommand("inapp.change@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(deviceOneSession.IsSuccess);
        Assert.True(deviceTwoSession.IsSuccess);

        var requestCode = await service.RequestCurrentPasswordChangeCodeAsync(user.Id, CancellationToken.None);
        Assert.True(requestCode.IsSuccess);

        var resetCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id && x.Purpose == EmailCodePurpose.PasswordReset)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstAsync();
        resetCode.CodeHash = HashValue("456789");
        await dbContext.SaveChangesAsync();

        var confirmChange = await service.ConfirmCurrentPasswordChangeAsync(
            user.Id,
            new ConfirmCurrentPasswordChangeCommand("456789", "AnotherStrong123", deviceOneSession.Value.RefreshToken),
            CancellationToken.None);

        Assert.True(confirmChange.IsSuccess);

        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == user.Id)
            .ToListAsync();

        Assert.Equal(2, sessions.Count);

        var currentSession = sessions.Single(x => x.TokenHash == HashValue(deviceOneSession.Value.RefreshToken));
        var otherSession = sessions.Single(x => x.TokenHash == HashValue(deviceTwoSession.Value.RefreshToken));

        Assert.Null(currentSession.RevokedAtUtc);
        Assert.NotNull(otherSession.RevokedAtUtc);

        var oldPasswordLogin = await service.LoginAsync(
            new LoginCommand("inapp.change@petmagic.app", "StrongPassword123"),
            CancellationToken.None);
        Assert.True(oldPasswordLogin.IsFailure);

        var newPasswordLogin = await service.LoginAsync(
            new LoginCommand("inapp.change@petmagic.app", "AnotherStrong123"),
            CancellationToken.None);
        Assert.True(newPasswordLogin.IsSuccess);
    }

    [Fact]
    public async Task RequestCurrentPasswordChangeCodeAsync_ShouldSucceed_ForExternalOnlyAccountWithEmail()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "external.user@petmagic.app",
            UserName = "external.user@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            PasswordHash = null,
            CreatedAtUtc = DateTime.UtcNow
        };

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        var result = await service.RequestCurrentPasswordChangeCodeAsync(user.Id, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var code = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id && x.Purpose == EmailCodePurpose.PasswordReset)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync();
        Assert.NotNull(code);
    }

    [Fact]
    public async Task ConfirmCurrentPasswordChangeAsync_ShouldSetPassword_ForAppleOnlyAccount()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var appleLogin = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand(
                "Apple",
                "apple-password-link-sub",
                "apple.password@petmagic.app",
                "Apple User",
                true),
            CancellationToken.None);
        Assert.True(appleLogin.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        Assert.Null(user.PasswordHash);
        Assert.Single(await dbContext.ExternalAuthProviders.Where(x => x.Provider == "Apple").ToListAsync());

        var requestCode = await service.RequestCurrentPasswordChangeCodeAsync(user.Id, CancellationToken.None);
        Assert.True(requestCode.IsSuccess);

        var resetCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id && x.Purpose == EmailCodePurpose.PasswordReset)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstAsync();
        resetCode.CodeHash = HashValue("789123");
        await dbContext.SaveChangesAsync();

        var confirmChange = await service.ConfirmCurrentPasswordChangeAsync(
            user.Id,
            new ConfirmCurrentPasswordChangeCommand("789123", "StrongLinked123", appleLogin.Value.RefreshToken),
            CancellationToken.None);

        Assert.True(confirmChange.IsSuccess);
        Assert.NotNull((await dbContext.Users.SingleAsync()).PasswordHash);

        var passwordLogin = await service.LoginAsync(
            new LoginCommand("apple.password@petmagic.app", "StrongLinked123"),
            CancellationToken.None);

        Assert.True(passwordLogin.IsSuccess);
        Assert.Equal(user.Id, passwordLogin.Value.User.UserId);
    }

    [Fact]
    public async Task SendBulkEmailAsync_ShouldQueueOnlyMatchingConfirmedRecipients()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        dbContext.Users.AddRange(
            new AppUser
            {
                Id = Guid.NewGuid(),
                Email = "free@petmagic.app",
                UserName = "free@petmagic.app",
                EmailConfirmed = true,
                IsActive = true,
                IsPremium = false,
                CreatedAtUtc = DateTime.UtcNow
            },
            new AppUser
            {
                Id = Guid.NewGuid(),
                Email = "premium@petmagic.app",
                UserName = "premium@petmagic.app",
                EmailConfirmed = true,
                IsActive = true,
                IsPremium = true,
                CreatedAtUtc = DateTime.UtcNow
            },
            new AppUser
            {
                Id = Guid.NewGuid(),
                Email = "pending@petmagic.app",
                UserName = "pending@petmagic.app",
                EmailConfirmed = false,
                IsActive = true,
                IsPremium = true,
                CreatedAtUtc = DateTime.UtcNow
            });
        await dbContext.SaveChangesAsync();

        var result = await service.SendBulkEmailAsync(
            new SendBulkEmailCommand(EmailAudiences.Premium, "Premium update", "Hello premium users", null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var jobs = await dbContext.EmailDispatchJobs
            .Where(x => x.Kind == EmailDispatchKind.Broadcast)
            .ToListAsync();

        var queuedJob = Assert.Single(jobs);
        Assert.Equal("premium@petmagic.app", queuedJob.RecipientEmail);
    }

    private static IdentityModuleDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new IdentityModuleDbContext(options);
    }

    private static async Task<IdentityService> CreateServiceAsync(
        IdentityModuleDbContext dbContext,
        string? acceptLanguage = null,
        IIdentityEmailTemplateRenderer? emailTemplateRenderer = null,
        ILogger<IdentityService>? logger = null)
    {
        await dbContext.Database.EnsureCreatedAsync();
        var economyDbContext = CreateEconomyDbContext();
        await economyDbContext.Database.EnsureCreatedAsync();

        var identityOptions = new IdentityOptions();
        identityOptions.Password.RequiredLength = 10;
        identityOptions.Password.RequireDigit = true;
        identityOptions.Password.RequireUppercase = true;
        identityOptions.Password.RequireLowercase = true;
        identityOptions.Password.RequireNonAlphanumeric = false;
        identityOptions.User.RequireUniqueEmail = true;

        var normalizer = new UpperInvariantLookupNormalizer();
        var userStore = new UserStore<AppUser, IdentityRole<Guid>, IdentityModuleDbContext, Guid>(dbContext);
        var userManager = new UserManager<AppUser>(
            userStore,
            Options.Create(identityOptions),
            new PasswordHasher<AppUser>(),
            [new UserValidator<AppUser>()],
            [new PasswordValidator<AppUser>()],
            normalizer,
            new IdentityErrorDescriber(),
            new ServiceCollection().AddLogging().BuildServiceProvider(),
            NullLogger<UserManager<AppUser>>.Instance);

        var roleStore = new RoleStore<IdentityRole<Guid>, IdentityModuleDbContext, Guid>(dbContext);
        var roleManager = new RoleManager<IdentityRole<Guid>>(
            roleStore,
            [new RoleValidator<IdentityRole<Guid>>()],
            normalizer,
            new IdentityErrorDescriber(),
            NullLogger<RoleManager<IdentityRole<Guid>>>.Instance);

        foreach (var role in SystemRoles.All)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole<Guid>(role));
            }
        }

        var httpContext = string.IsNullOrWhiteSpace(acceptLanguage)
            ? null
            : new DefaultHttpContext();
        if (!string.IsNullOrWhiteSpace(acceptLanguage))
        {
            httpContext!.Request.Headers["Accept-Language"] = acceptLanguage;
        }

        IHttpContextAccessor httpContextAccessor = new StaticHttpContextAccessor(httpContext);

        return new IdentityService(
            userManager,
            roleManager,
            dbContext,
            new ServiceCollection()
                .AddSingleton(CreateEconomyService(economyDbContext))
                .BuildServiceProvider(),
            httpContextAccessor,
            new FakeLegalDocumentsCatalog(),
            emailTemplateRenderer ?? new StubEmailTemplateRenderer(),
            new InMemoryAvatarStorage(),
            new EmailOptions
            {
                DispatchWorkerEnabled = false,
                FromAddress = "no-reply@petmagic.app",
                FromName = "PetMagic",
                VerificationCodeLength = 6,
                VerificationCodeTtlMinutes = 10,
                PasswordResetCodeTtlMinutes = 10
            },
            new AvatarStorageOptions(),
            Options.Create(new JwtOptions()),
            logger);
    }

    private static IIdentityEmailTemplateRenderer CreateRealEmailTemplateRenderer()
    {
        var rendererType = typeof(IIdentityEmailTemplateRenderer)
            .Assembly
            .GetType("PetMagic.Modules.Identity.Infrastructure.IdentityEmailTemplateRenderer");

        Assert.NotNull(rendererType);

        var instance = Activator.CreateInstance(rendererType!, nonPublic: true);

        return Assert.IsAssignableFrom<IIdentityEmailTemplateRenderer>(instance);
    }

    private sealed class StaticHttpContextAccessor(HttpContext? context) : IHttpContextAccessor
    {
        public HttpContext? HttpContext { get; set; } = context;
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values
                    .Where(x => !string.Equals(x.Key, "{OriginalFormat}", StringComparison.Ordinal))
                    .ToDictionary(x => x.Key, x => x.Value)
                : [];

            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), properties));
        }

        private sealed class NullScope : IDisposable
        {
            public static readonly NullScope Instance = new();

            public void Dispose()
            {
            }
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class FakeLegalDocumentsCatalog : ILegalDocumentsCatalog
    {
        public string CurrentTermsOfUseVersion => CurrentLegalVersion;

        public string CurrentPrivacyPolicyVersion => CurrentLegalVersion;

        public LegalDocumentsResponse GetCurrentDocuments(string? locale)
        {
            return new LegalDocumentsResponse(
                new LegalDocumentResponse(
                    LegalDocumentKinds.TermsOfUse,
                    "Terms",
                    CurrentLegalVersion,
                    DateTime.UtcNow,
                    "Summary",
                    []),
                new LegalDocumentResponse(
                    LegalDocumentKinds.PrivacyPolicy,
                    "Privacy",
                    CurrentLegalVersion,
                    DateTime.UtcNow,
                    "Summary",
                    []));
        }

        public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
        {
            return string.Equals(termsOfUseVersion, CurrentLegalVersion, StringComparison.Ordinal)
                && string.Equals(privacyPolicyVersion, CurrentLegalVersion, StringComparison.Ordinal);
        }
    }

    private static IEconomyService CreateEconomyService(EconomyDbContext dbContext)
    {
        return new EconomyService(
            dbContext,
            new FakePaymentGateway(),
            new FakeStoreSubscriptionVerifier(),
            Options.Create(new EconomyOptions
            {
                WeeklyFreeSpark = 100,
                WeeklyPremiumSpark = 250,
                AdRewardSpark = 15,
                AdRewardDailyLimit = 5,
                StripeSecretKey = "test_stripe_secret_key",
                StripeWebhookSecret = "test_webhook_secret",
                StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
                StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
            }));
    }

    private static EconomyDbContext CreateEconomyDbContext()
    {
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new EconomyDbContext(options);
    }

    private static string HashValue(string value)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(bytes);
    }

    private sealed class StubEmailTemplateRenderer : IIdentityEmailTemplateRenderer
    {
        public RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
        {
            return new RenderedEmailMessage("Confirm", $"<p>{code}</p>", code);
        }

        public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
        {
            return new RenderedEmailMessage("Reset", $"<p>{code}</p>", code);
        }
    }

    private sealed class InMemoryAvatarStorage : IAvatarStorage
    {
        public Task<Result<StoredAvatarResponse>> StoreAsync(AvatarUploadCommand avatar, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredAvatarResponse(
                $"http://localhost:5000/user-avatars/{Guid.NewGuid():N}/{avatar.FileName}",
                $"user-avatars/{avatar.FileName}",
                avatar.FileName,
                avatar.ContentType,
                avatar.Content?.LongLength ?? avatar.ContentLengthBytes ?? 0,
                null)));
        }

        public Task<Result> DeleteAsync(string? avatarUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }
    }

    private sealed class FakePaymentGateway : IPaymentGateway
    {
        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCreateResponse($"cs_test_{request.OrderId:N}", $"https://checkout.stripe.com/pay/{request.OrderId:N}")));
        }

        public Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
            SubscriptionCheckoutCreateRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new SubscriptionCheckoutCreateResponse($"cs_sub_{request.UserId:N}", $"https://checkout.stripe.com/pay/{request.UserId:N}")));
        }

        public Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCustomerCreateResponse($"cus_{request.UserId:N}")));
        }

        public Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
            BillingPortalCreateRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new BillingPortalCreateResponse("https://billing.stripe.com/session/test")));
        }

        public Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(PaymentMethodSetupCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentMethodSetupCreateResponse($"cs_setup_{request.UserId:N}", $"https://checkout.stripe.com/setup/{request.UserId:N}")));
        }

        public Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(PaymentMethodResolveRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentMethodDetailsResponse($"pm_{request.ExternalSetupId}", "visa", "4242", 12, 2030)));
        }

        public Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(PaymentSavedMethodCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCreateResponse($"pi_{request.OrderId:N}", string.Empty)));
        }

        public Task<Result<PaymentRefundResponse>> RefundPaymentAsync(PaymentRefundRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentRefundResponse($"re_{request.OrderId:N}", "succeeded")));
        }
    }

    private sealed class FakeStoreSubscriptionVerifier : IStoreSubscriptionVerifier
    {
        public Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
            StoreSubscriptionVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreSubscriptionVerificationResponse(true, DateTime.UtcNow.AddDays(30), "active", request.PurchaseId)));
        }

        public Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
            StoreProductVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreProductVerificationResponse(true, "purchased", request.PurchaseId)));
        }
    }
}
