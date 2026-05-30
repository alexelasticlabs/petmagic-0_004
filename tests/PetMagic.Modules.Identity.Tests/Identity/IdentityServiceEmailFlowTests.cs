using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

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

    private static async Task<IdentityService> CreateServiceAsync(IdentityModuleDbContext dbContext)
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

        return new IdentityService(
            userManager,
            roleManager,
            dbContext,
            new ServiceCollection()
                .AddSingleton(CreateEconomyService(economyDbContext))
                .BuildServiceProvider(),
            new FakeLegalDocumentsCatalog(),
            new StubEmailTemplateRenderer(),
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
            Options.Create(new JwtOptions()));
    }

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
        public RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc)
        {
            return new RenderedEmailMessage("Confirm", $"<p>{code}</p>", code);
        }

        public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc)
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
                avatar.Content.LongLength,
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
