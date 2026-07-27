using System.Security.Cryptography;
using System.Text;

using Microsoft.Data.Sqlite;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Caching.Memory;
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
    public async Task RegisterAsync_ForExistingPendingEmail_ShouldNotOverwriteAccountCredentialsOrProfile()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var initialResult = await service.RegisterAsync(
            new RegisterUserCommand(
                "pending.owner@petmagic.app",
                "OriginalPassword123",
                "Original Owner",
                true,
                true,
                CurrentLegalVersion,
                CurrentLegalVersion,
                true),
            CancellationToken.None);
        Assert.True(initialResult.IsSuccess);

        var original = await dbContext.Users.SingleAsync();
        var originalPasswordHash = original.PasswordHash;
        var originalSecurityStamp = original.SecurityStamp;
        var originalAccountStatusUpdatedAtUtc = original.AccountStatusUpdatedAtUtc;

        var repeatedResult = await service.RegisterAsync(
            new RegisterUserCommand(
                "pending.owner@petmagic.app",
                "AttackerPassword123",
                "Attacker Name",
                false,
                false,
                "attacker-terms-version",
                "attacker-privacy-version",
                false),
            CancellationToken.None);

        Assert.True(repeatedResult.IsSuccess);
        var persisted = await dbContext.Users.SingleAsync();
        Assert.Equal("Original Owner", persisted.DisplayName);
        Assert.Equal(originalPasswordHash, persisted.PasswordHash);
        Assert.Equal(originalSecurityStamp, persisted.SecurityStamp);
        Assert.Equal(originalAccountStatusUpdatedAtUtc, persisted.AccountStatusUpdatedAtUtc);
        Assert.True(persisted.TermsOfUseAccepted);
        Assert.True(persisted.PrivacyPolicyAccepted);
        Assert.True(persisted.MarketingEmailsEnabled);
        Assert.Equal(AccountStatus.PendingEmailVerification, persisted.AccountStatus);

        persisted.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var ownerLogin = await service.LoginAsync(
            new LoginCommand("pending.owner@petmagic.app", "OriginalPassword123"),
            CancellationToken.None);
        var attackerLogin = await service.LoginAsync(
            new LoginCommand("pending.owner@petmagic.app", "AttackerPassword123"),
            CancellationToken.None);

        Assert.True(ownerLogin.IsSuccess);
        Assert.True(attackerLogin.IsFailure);
        Assert.Equal(IdentityErrors.InvalidCredentials.Code, attackerLogin.Error.Code);
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
        var expectedUserIdHash = SafeLogValues.StableHash(user.Id.ToString("D"));
        var expectedCorrelationIdHash = SafeLogValues.StableHash("auth-business-correlation");

        var invalidLoginResult = await service.LoginAsync(
            new LoginCommand("missing.user@petmagic.app", "WrongPassword123"),
            CancellationToken.None);

        Assert.True(invalidLoginResult.IsFailure);

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Information
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "registration")
            && entry.Properties.TryGetValue("UserIdHash", out var userIdHash)
            && Equals(userIdHash, expectedUserIdHash)
            && !entry.Properties.ContainsKey("UserId")
            && entry.Properties.TryGetValue("Result", out var result)
            && Equals(result, "pending_email_verification")
            && !entry.Properties.ContainsKey("CorrelationId")
            && entry.Properties.TryGetValue("CorrelationIdHash", out var correlationIdHash)
            && Equals(correlationIdHash, expectedCorrelationIdHash));

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Information
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "login")
            && entry.Properties.TryGetValue("UserIdHash", out var userIdHash)
            && Equals(userIdHash, expectedUserIdHash)
            && !entry.Properties.ContainsKey("UserId")
            && entry.Properties.TryGetValue("Result", out var result)
            && Equals(result, "succeeded")
            && !entry.Properties.ContainsKey("CorrelationId")
            && entry.Properties.TryGetValue("CorrelationIdHash", out var correlationIdHash)
            && Equals(correlationIdHash, expectedCorrelationIdHash));

        Assert.Contains(logger.Entries, entry =>
            entry.Level == LogLevel.Warning
            && entry.Properties.TryGetValue("Operation", out var operation)
            && Equals(operation, "login")
            && entry.Properties.TryGetValue("UserIdHash", out var userIdHash)
            && userIdHash is null
            && !entry.Properties.ContainsKey("UserId")
            && entry.Properties.TryGetValue("Reason", out var reason)
            && Equals(reason, "invalid_credentials")
            && !entry.Properties.ContainsKey("CorrelationId")
            && entry.Properties.TryGetValue("CorrelationIdHash", out var correlationIdHash)
            && Equals(correlationIdHash, expectedCorrelationIdHash));

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
    public async Task AcceptLegalDocumentsAsync_ShouldInvalidateLegalAcceptanceCacheImmediately()
    {
        await using var dbContext = CreateDbContext();
        using var legalAcceptanceCache = new MemoryCache(new MemoryCacheOptions());
        var service = await CreateServiceAsync(dbContext, legalAcceptanceCache: legalAcceptanceCache);

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "legal.accept@petmagic.app",
            UserName = "legal.accept@petmagic.app",
            SecurityStamp = Guid.NewGuid().ToString("N"),
            ConcurrencyStamp = Guid.NewGuid().ToString("N"),
            EmailConfirmed = true,
            IsActive = true,
            TermsOfUseAccepted = false,
            PrivacyPolicyAccepted = false,
            CreatedAtUtc = DateTime.UtcNow
        };
        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        var cacheKey = LegalAcceptanceRequirementCache.BuildKey(user.Id);
        legalAcceptanceCache.Set(cacheKey, true);

        var result = await service.AcceptLegalDocumentsAsync(
            user.Id,
            new AcceptLegalDocumentsCommand(CurrentLegalVersion, CurrentLegalVersion),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.LegalAcceptance.RequiresAcceptance);
        Assert.False(legalAcceptanceCache.TryGetValue(cacheKey, out _));
    }

    [Fact]
    public async Task VerifyEmailCodeAsync_ShouldActivateAccount_AndIssueAuthSession()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("verify.session@petmagic.app", "StrongPassword123", "Verify Session", true, true, CurrentLegalVersion, CurrentLegalVersion, true),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        var verificationCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id && x.Purpose == EmailCodePurpose.EmailConfirmation)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstAsync();
        verificationCode.CodeHash = HashValue("123456");
        await dbContext.SaveChangesAsync();

        var verifyResult = await service.VerifyEmailCodeAsync(
            new VerifyEmailCodeCommand("verify.session@petmagic.app", "123456"),
            CancellationToken.None);

        Assert.True(verifyResult.IsSuccess);
        Assert.False(string.IsNullOrWhiteSpace(verifyResult.Value.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(verifyResult.Value.RefreshToken));
        Assert.True(verifyResult.Value.User.EmailConfirmed);
        Assert.Equal("Active", verifyResult.Value.User.AccountStatus);
        Assert.True(verifyResult.Value.User.MarketingEmailsEnabled);

        var persistedUser = await dbContext.Users.SingleAsync();
        Assert.True(persistedUser.EmailConfirmed);
        Assert.Equal(AccountStatus.Active, persistedUser.AccountStatus);
        Assert.NotNull(verificationCode.ConsumedAtUtc);
        Assert.Single(await dbContext.RefreshTokenSessions.Where(x => x.UserId == user.Id && x.RevokedAtUtc == null).ToListAsync());
    }

    [Fact]
    public async Task ConfirmEmailAsync_ShouldRejectAlreadyConfirmedAccountWithoutValidCode()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("confirmed.state@petmagic.app", "StrongPassword123", "Confirmed State", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        var verificationCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id && x.Purpose == EmailCodePurpose.EmailConfirmation)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstAsync();
        verificationCode.CodeHash = HashValue("123456");
        await dbContext.SaveChangesAsync();

        var confirmResult = await service.ConfirmEmailAsync(
            new ConfirmEmailCommand("confirmed.state@petmagic.app", "123456"),
            CancellationToken.None);

        Assert.True(confirmResult.IsSuccess);

        var repeatedResult = await service.ConfirmEmailAsync(
            new ConfirmEmailCommand("confirmed.state@petmagic.app", "000000"),
            CancellationToken.None);

        Assert.True(repeatedResult.IsFailure);
        Assert.Equal("auth.email_code_invalid", repeatedResult.Error.Code);
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
    public async Task LogoutAsync_ShouldRevokeRefreshToken_AndRejectReuse()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("logout.reuse@petmagic.app", "StrongPassword123", "Logout Reuse", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var loginResult = await service.LoginAsync(
            new LoginCommand("logout.reuse@petmagic.app", "StrongPassword123"),
            CancellationToken.None);

        Assert.True(loginResult.IsSuccess);

        var logoutResult = await service.LogoutAsync(
            new LogoutCommand(user.Id, loginResult.Value.RefreshToken),
            CancellationToken.None);

        Assert.True(logoutResult.IsSuccess);

        var refreshResult = await service.RefreshAsync(
            new RefreshTokenCommand(loginResult.Value.RefreshToken),
            CancellationToken.None);

        Assert.True(refreshResult.IsFailure);
        Assert.Equal("auth.invalid_refresh", refreshResult.Error.Code);

        var persistedSession = await dbContext.RefreshTokenSessions.SingleAsync(x => x.UserId == user.Id);
        Assert.NotNull(persistedSession.RevokedAtUtc);
    }

    [Fact]
    public async Task LogoutByRefreshTokenAsync_ShouldRevokeRefreshTokenWithoutAuthenticatedUser()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var registerResult = await service.RegisterAsync(
            new RegisterUserCommand("logout.cookie@petmagic.app", "StrongPassword123", "Cookie Logout", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);
        Assert.True(registerResult.IsSuccess);

        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();

        var loginResult = await service.LoginAsync(
            new LoginCommand(user.Email!, "StrongPassword123"),
            CancellationToken.None);
        Assert.True(loginResult.IsSuccess);

        var logoutResult = await service.LogoutByRefreshTokenAsync(
            new RefreshTokenCommand(loginResult.Value.RefreshToken),
            CancellationToken.None);
        Assert.True(logoutResult.IsSuccess);

        var refreshResult = await service.RefreshAsync(
            new RefreshTokenCommand(loginResult.Value.RefreshToken),
            CancellationToken.None);
        Assert.True(refreshResult.IsFailure);
        Assert.Equal("auth.invalid_refresh", refreshResult.Error.Code);
    }

    [Fact]
    public async Task RefreshAsync_ShouldRollbackRotationWhenSuccessAuditCannotBePersisted()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseSqlite(connection)
            .AddInterceptors(new FailRefreshSuccessAuditInterceptor())
            .Options;
        await using var dbContext = new IdentityModuleDbContext(options);
        var service = await CreateServiceAsync(dbContext);

        Assert.True((await service.RegisterAsync(
            new RegisterUserCommand(
                "refresh.audit@petmagic.app",
                "StrongPassword123",
                "Refresh Audit",
                true,
                true,
                CurrentLegalVersion,
                CurrentLegalVersion,
                false),
            CancellationToken.None)).IsSuccess);
        var user = await dbContext.Users.SingleAsync();
        user.EmailConfirmed = true;
        await dbContext.SaveChangesAsync();
        var login = await service.LoginAsync(
            new LoginCommand(user.Email!, "StrongPassword123"),
            CancellationToken.None);
        Assert.True(login.IsSuccess);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.RefreshAsync(
            new RefreshTokenCommand(login.Value.RefreshToken),
            CancellationToken.None));

        dbContext.ChangeTracker.Clear();
        var sessions = await dbContext.RefreshTokenSessions.AsNoTracking().ToListAsync();
        var original = Assert.Single(sessions);
        Assert.Null(original.RevokedAtUtc);
        Assert.Equal(HashValue(login.Value.RefreshToken), original.TokenHash);
    }

    [Fact]
    public async Task LogoutAsync_ShouldRejectRefreshTokenOwnedByAnotherUser()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        var firstRegister = await service.RegisterAsync(
            new RegisterUserCommand("logout.owner.one@petmagic.app", "StrongPassword123", "Owner One", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);
        var secondRegister = await service.RegisterAsync(
            new RegisterUserCommand("logout.owner.two@petmagic.app", "StrongPassword123", "Owner Two", true, true, CurrentLegalVersion, CurrentLegalVersion, false),
            CancellationToken.None);

        Assert.True(firstRegister.IsSuccess);
        Assert.True(secondRegister.IsSuccess);

        var users = await dbContext.Users.OrderBy(x => x.Email).ToListAsync();
        foreach (var user in users)
        {
            user.EmailConfirmed = true;
        }
        await dbContext.SaveChangesAsync();

        var owner = users.Single(x => x.Email == "logout.owner.one@petmagic.app");
        var attacker = users.Single(x => x.Email == "logout.owner.two@petmagic.app");

        var ownerLogin = await service.LoginAsync(
            new LoginCommand(owner.Email!, "StrongPassword123"),
            CancellationToken.None);

        Assert.True(ownerLogin.IsSuccess);

        var logoutResult = await service.LogoutAsync(
            new LogoutCommand(attacker.Id, ownerLogin.Value.RefreshToken),
            CancellationToken.None);

        Assert.True(logoutResult.IsFailure);
        Assert.Equal("auth.refresh_token_not_owned", logoutResult.Error.Code);

        var ownerSession = await dbContext.RefreshTokenSessions.SingleAsync(x => x.UserId == owner.Id);
        Assert.Null(ownerSession.RevokedAtUtc);
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
            new SendBulkEmailCommand(
                EmailAudiences.Premium,
                "Premium update",
                "Hello premium users",
                null,
                "bulk-email:premium-update-1"),
            CancellationToken.None);

        var replay = await service.SendBulkEmailAsync(
            new SendBulkEmailCommand(
                EmailAudiences.Premium,
                "Premium update",
                "Hello premium users",
                null,
                "bulk-email:premium-update-1"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(replay.IsSuccess);
        Assert.Equal(result.Value.BroadcastId, replay.Value.BroadcastId);
        Assert.Equal(1, result.Value.RecipientCount);
        Assert.Equal(AdminEmailBroadcastStatuses.Queued, result.Value.Status);

        var jobs = await dbContext.EmailDispatchJobs
            .Where(x => x.Kind == EmailDispatchKind.Broadcast)
            .ToListAsync();

        var queuedJob = Assert.Single(jobs);
        Assert.Equal("premium@petmagic.app", queuedJob.RecipientEmail);
        Assert.Equal(result.Value.BroadcastId, queuedJob.BroadcastId);
        var broadcast = await dbContext.AdminEmailBroadcasts.SingleAsync();
        Assert.Equal(result.Value.BroadcastId, broadcast.Id);
        Assert.Equal(1, broadcast.RecipientCount);
        Assert.Equal(AdminEmailBroadcastStatus.Queued, broadcast.Status);
        Assert.Single(await dbContext.AuditEvents
            .Where(x => x.Action == "admin.bulk_email.queued")
            .ToListAsync());
    }

    [Fact]
    public async Task SendBulkEmailAsync_ShouldRejectReusedIdempotencyKeyForDifferentPayload()
    {
        await using var dbContext = CreateDbContext();
        var service = await CreateServiceAsync(dbContext);

        dbContext.Users.Add(new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "premium@petmagic.app",
            UserName = "premium@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            IsPremium = true,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var first = await service.SendBulkEmailAsync(
            new SendBulkEmailCommand(
                EmailAudiences.Premium,
                "Premium update",
                "Original body",
                null,
                "bulk-email:conflict-1"),
            CancellationToken.None);
        var conflictingReplay = await service.SendBulkEmailAsync(
            new SendBulkEmailCommand(
                EmailAudiences.Premium,
                "Premium update",
                "Changed body",
                null,
                "bulk-email:conflict-1"),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(conflictingReplay.IsFailure);
        Assert.Equal(IdentityErrors.BulkEmailIdempotencyConflict, conflictingReplay.Error);
        Assert.Single(await dbContext.EmailDispatchJobs
            .Where(x => x.Kind == EmailDispatchKind.Broadcast)
            .ToListAsync());
    }

    [Fact]
    public async Task SendBulkEmailAsync_ShouldRollbackBroadcastJobsAndAuditTogether()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseSqlite(connection)
            .AddInterceptors(new FailBulkEmailAuditInterceptor())
            .Options;
        await using var dbContext = new IdentityModuleDbContext(options);
        var service = await CreateServiceAsync(dbContext);
        dbContext.Users.Add(new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "broadcast.atomic@petmagic.app",
            UserName = "broadcast.atomic@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            IsPremium = true,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.SendBulkEmailAsync(
            new SendBulkEmailCommand(
                EmailAudiences.Premium,
                "Atomic broadcast",
                "Atomic body",
                null,
                "bulk-email:atomic-1"),
            CancellationToken.None));

        dbContext.ChangeTracker.Clear();
        Assert.Empty(await dbContext.AdminEmailBroadcasts.AsNoTracking().ToListAsync());
        Assert.Empty(await dbContext.EmailDispatchJobs.AsNoTracking()
            .Where(x => x.Kind == EmailDispatchKind.Broadcast)
            .ToListAsync());
        Assert.Empty(await dbContext.AuditEvents.AsNoTracking()
            .Where(x => x.Action == "admin.bulk_email.queued")
            .ToListAsync());
    }

    [Fact]
    public async Task AdminEmailBroadcastQueriesAndRetry_ShouldExposeOnlyAggregateProgress()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseSqlite(connection)
            .Options;
        await using var dbContext = new IdentityModuleDbContext(options);
        var service = await CreateServiceAsync(dbContext);
        var broadcastId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.AdminEmailBroadcasts.Add(new AdminEmailBroadcast
        {
            Id = broadcastId,
            Audience = EmailAudiences.Premium,
            Subject = "Premium update",
            RequestHash = new string('A', 64),
            Status = AdminEmailBroadcastStatus.PartiallyFailed,
            RecipientCount = 2,
            SentCount = 1,
            FailedCount = 1,
            CreatedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now.AddMinutes(-1),
            CompletedAtUtc = now.AddMinutes(-1)
        });
        dbContext.EmailDispatchJobs.Add(new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            BroadcastId = broadcastId,
            UserId = Guid.NewGuid(),
            RecipientEmail = "private-recipient@petmagic.app",
            Kind = EmailDispatchKind.Broadcast,
            Status = EmailDispatchStatus.Failed,
            Subject = "Premium update",
            HtmlBody = "<p>private-body</p>",
            TextBody = "private-body",
            AttemptCount = 3,
            QueuedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now.AddMinutes(-1),
            FailureCode = "email.smtp_failed",
            FailureMessage = "private-provider-message"
        });
        await dbContext.SaveChangesAsync();

        var page = await service.ListAdminEmailBroadcastsAsync(0, 50, "partially-failed", CancellationToken.None);
        var detail = await service.GetAdminEmailBroadcastAsync(broadcastId, CancellationToken.None);
        var retry = await service.RetryFailedAdminEmailBroadcastAsync(broadcastId, CancellationToken.None);

        Assert.True(page.IsSuccess);
        var pageItem = Assert.Single(page.Value.Items);
        Assert.Equal(broadcastId, pageItem.BroadcastId);
        Assert.Equal(0, pageItem.PendingCount);
        Assert.True(detail.IsSuccess);
        Assert.Equal(1, detail.Value.RetryableFailedCount);
        Assert.True(retry.IsSuccess);
        Assert.Equal(1, retry.Value.RetriedCount);
        Assert.Equal(AdminEmailBroadcastStatuses.Processing, retry.Value.Status);
        Assert.Equal(1, retry.Value.PendingCount);
        Assert.Equal(0, retry.Value.FailedCount);

        var retriedJob = await dbContext.EmailDispatchJobs.AsNoTracking().SingleAsync();
        Assert.Equal(EmailDispatchStatus.Queued, retriedJob.Status);
        Assert.Equal(0, retriedJob.AttemptCount);
        Assert.Null(retriedJob.FailureCode);
        Assert.Null(retriedJob.FailureMessage);
        Assert.Single(await dbContext.AuditEvents
            .Where(x => x.Action == "admin.bulk_email.retry_failed")
            .ToListAsync());

        var noOpReplay = await service.RetryFailedAdminEmailBroadcastAsync(broadcastId, CancellationToken.None);
        Assert.True(noOpReplay.IsSuccess);
        Assert.Equal(0, noOpReplay.Value.RetriedCount);
        Assert.Single(await dbContext.AuditEvents
            .Where(x => x.Action == "admin.bulk_email.retry_failed")
            .ToListAsync());
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
        ILogger<IdentityService>? logger = null,
        IMemoryCache? legalAcceptanceCache = null)
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
            new AvatarReadUrlSigner(
                new AvatarStorageOptions(),
                new AvatarReadUrlSigningOptions
                {
                    SigningKey = new string('t', 64),
                    ReadUrlTtlMinutes = 60
                }),
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
            Options.Create(new JwtOptions
            {
                Issuer = "petmagic-tests",
                Audience = "petmagic-tests",
                SigningKey = new string('t', 64),
                AccessTokenMinutes = 30,
                RefreshTokenDays = 30
            }),
            logger,
            legalAcceptanceCache);
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

    private sealed class FailRefreshSuccessAuditInterceptor : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (eventData.Context?.ChangeTracker.Entries<AuditEvent>().Any(entry =>
                    entry.State == EntityState.Added
                    && entry.Entity.Action == "auth.refresh.succeeded") == true)
            {
                throw new InvalidOperationException("refresh audit persistence failed");
            }

            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }
    }

    private sealed class FailBulkEmailAuditInterceptor : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (eventData.Context?.ChangeTracker.Entries<AuditEvent>().Any(entry =>
                    entry.State == EntityState.Added
                    && entry.Entity.Action == "admin.bulk_email.queued") == true)
            {
                throw new InvalidOperationException("bulk email audit persistence failed");
            }

            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }
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
                StripeTestSecretKey = "test_stripe_secret_key",
                StripeTestWebhookSecret = "test_webhook_secret",
                StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
                StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
            }),
            new MemoryCache(new MemoryCacheOptions()));
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
