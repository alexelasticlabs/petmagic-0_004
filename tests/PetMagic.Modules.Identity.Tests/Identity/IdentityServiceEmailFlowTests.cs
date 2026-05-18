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
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.Templates.Infrastructure.Data;

using IdentityModuleDbContext = PetMagic.Modules.Identity.Infrastructure.Data.IdentityDbContext;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityServiceEmailFlowTests
{
    [Fact]
    public async Task RegisterAsync_ShouldQueueEmailConfirmation_And_BlockLoginUntilConfirmed()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("demo.user@petmagic.app", "StrongPassword123", "Demo User"),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);
        Assert.False(registerResult.Value.EmailConfirmed);

        var persistedUser = await dbContext.Users.SingleAsync();
        Assert.False(persistedUser.EmailConfirmed);

        var queuedCode = await dbContext.UserEmailCodes.SingleAsync();
        Assert.Equal(EmailCodePurpose.EmailConfirmation, queuedCode.Purpose);

        var emailJob = await dbContext.EmailDispatchJobs.SingleAsync();
        Assert.Equal(EmailDispatchKind.EmailConfirmation, emailJob.Kind);
        Assert.Equal("demo.user@petmagic.app", emailJob.RecipientEmail);

        var loginResult = await service.LoginAsync(
            new LoginCommand("demo.user@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsFailure);
        Assert.Equal(IdentityErrors.EmailNotConfirmed.Code, loginResult.Error.Code);
    }

    [Fact]
    public async Task ConfirmEmailAsync_ShouldMarkUserConfirmed_And_AllowLogin()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("confirm.me@petmagic.app", "StrongPassword123", "Confirm Me"),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var queuedCode = await dbContext.UserEmailCodes.SingleAsync();
        queuedCode.CodeHash = HashValue("123456");
        await dbContext.SaveChangesAsync();

        var confirmResult = await service.ConfirmEmailAsync(
            new ConfirmEmailCommand("confirm.me@petmagic.app", "123456"),
            CancellationToken.None);

        Assert.True(confirmResult.IsSuccess);

        var persistedUser = await dbContext.Users.SingleAsync();
        Assert.True(persistedUser.EmailConfirmed);

        var loginResult = await service.LoginAsync(
            new LoginCommand("confirm.me@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsSuccess);
    }

    [Fact]
    public async Task ConfirmPasswordResetAsync_ShouldUpdatePassword_And_RevokeRefreshTokens()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("reset.me@petmagic.app", "StrongPassword123", "Reset Me"),
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
        var templatesDbContext = CreateTemplatesDbContext();
        await economyDbContext.Database.EnsureCreatedAsync();
        await templatesDbContext.Database.EnsureCreatedAsync();

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
            economyDbContext,
            CreateEconomyService(economyDbContext),
            templatesDbContext,
            new StubEmailTemplateRenderer(),
            new InMemoryAvatarStorage(),
            new EmailOptions
            {
                DispatchWorkerEnabled = false,
                FromAddress = "no-reply@petmagic.app",
                FromName = "PetMagic",
                VerificationCodeLength = 6,
                VerificationCodeTtlMinutes = 15,
                PasswordResetCodeTtlMinutes = 15
            },
            new AvatarStorageOptions(),
            Options.Create(new JwtOptions()));
    }

    private static IEconomyService CreateEconomyService(EconomyDbContext dbContext)
    {
        return new EconomyService(
            dbContext,
            new FakePaymentGateway(),
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

    private static TemplatesDbContext CreateTemplatesDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new TemplatesDbContext(options);
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
    }
}
