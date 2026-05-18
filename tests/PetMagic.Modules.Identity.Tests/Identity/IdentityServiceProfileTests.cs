using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

using IdentityModuleDbContext = PetMagic.Modules.Identity.Infrastructure.Data.IdentityDbContext;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityServiceProfileTests
{
    [Fact]
    public async Task UpdateUserAvatarAsync_ShouldReplaceExistingAvatar_AndDeleteOldFile()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var avatarStorage = new TrackingAvatarStorage();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, avatarStorage);

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "avatar@petmagic.app",
            UserName = "avatar@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            AvatarUrl = "http://localhost:5000/user-avatars/old.png",
            AvatarFileName = "old.png",
            AvatarContentType = "image/png",
            AvatarFileSizeBytes = 123,
            AvatarUpdatedAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow
        };
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();

        var result = await service.UpdateUserAvatarAsync(
            new UpdateUserAvatarCommand(user.Id, "new-avatar.jpg", "image/jpeg", "avatar-binary"u8.ToArray()),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(result.Value.Avatar);
        Assert.Equal("new-avatar.jpg", result.Value.Avatar!.FileName);
        Assert.Contains("old.png", avatarStorage.DeletedUrls.Single());
    }

    [Fact]
    public async Task RemoveUserAvatarAsync_ShouldClearAvatarMetadata()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var avatarStorage = new TrackingAvatarStorage();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, avatarStorage);

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "remove@petmagic.app",
            UserName = "remove@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            AvatarUrl = "http://localhost:5000/user-avatars/remove.png",
            AvatarFileName = "remove.png",
            AvatarContentType = "image/png",
            AvatarFileSizeBytes = 222,
            AvatarUpdatedAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow
        };
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();

        var result = await service.RemoveUserAvatarAsync(
            new RemoveUserAvatarCommand(user.Id),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Null(result.Value.Avatar);

        var persisted = await identityDb.Users.SingleAsync();
        Assert.Null(persisted.AvatarUrl);
        Assert.Single(avatarStorage.DeletedUrls);
    }

    [Fact]
    public async Task UpdateUserAvatarAsync_ShouldRejectOversizedUpload()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var avatarStorage = new TrackingAvatarStorage();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, avatarStorage, maxAvatarSizeBytes: 4);

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "oversized@petmagic.app",
            UserName = "oversized@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            CreatedAtUtc = DateTime.UtcNow
        };
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();

        var result = await service.UpdateUserAvatarAsync(
            new UpdateUserAvatarCommand(user.Id, "big.png", "image/png", "12345"u8.ToArray()),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(IdentityErrors.AvatarFileTooLarge.Code, result.Error.Code);
    }

    [Fact]
    public async Task GetAdminUserAnalyticsAsync_ShouldAggregateOnlyTargetUserData()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var targetUserId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        identityDb.Users.AddRange(
            new AppUser
            {
                Id = targetUserId,
                Email = "target@petmagic.app",
                UserName = "target@petmagic.app",
                EmailConfirmed = true,
                IsActive = true,
                SecurityStamp = Guid.NewGuid().ToString("N"),
                CreatedAtUtc = DateTime.UtcNow.AddDays(-10)
            },
            new AppUser
            {
                Id = otherUserId,
                Email = "other@petmagic.app",
                UserName = "other@petmagic.app",
                EmailConfirmed = true,
                IsActive = true,
                SecurityStamp = Guid.NewGuid().ToString("N"),
                CreatedAtUtc = DateTime.UtcNow.AddDays(-9)
            });

        identityDb.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = targetUserId,
            Action = "user.login",
            Details = "Signed in.",
            OccurredAtUtc = DateTime.UtcNow.AddHours(-1)
        });

        economyDb.Wallets.Add(new Wallet
        {
            UserId = targetUserId,
            Balance = 420,
            UpdatedAtUtc = DateTime.UtcNow.AddHours(-2)
        });
        economyDb.PurchaseOrders.AddRange(
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                Status = "succeeded",
                PriceAmount = 9.99m,
                CurrencyCode = "USD",
                SparkToGrant = 300,
                PaymentProvider = "stripe",
                CreatedAtUtc = DateTime.UtcNow.AddDays(-2),
                ConfirmedAtUtc = DateTime.UtcNow.AddDays(-2)
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = otherUserId,
                Status = "succeeded",
                PriceAmount = 4.99m,
                CurrencyCode = "USD",
                SparkToGrant = 100,
                PaymentProvider = "stripe",
                CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
                ConfirmedAtUtc = DateTime.UtcNow.AddDays(-1)
            });

        var templateId = Guid.NewGuid();
        templatesDb.TemplateItems.Add(new TemplateItem
        {
            Id = templateId,
            TemplateType = TemplateType.Image,
            Title = "Hero Portrait",
            ShortDescription = "Portrait",
            Category = "Portrait",
            Tags = "hero",
            IsPremium = false,
            TokenCost = 20,
            Status = TemplateStatus.Active,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = DateTime.UtcNow.AddDays(-5),
            UpdatedAtUtc = DateTime.UtcNow.AddDays(-1)
        });
        templatesDb.TemplateGenerationJobs.AddRange(
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "source",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-8),
                QueuedAtUtc = DateTime.UtcNow.AddHours(-8),
                UpdatedAtUtc = DateTime.UtcNow.AddHours(-7),
                CompletedAtUtc = DateTime.UtcNow.AddHours(-7)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Failed,
                TokenCost = 20,
                FailureCode = "templates.failed",
                SourceImageUrl = "source",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-6),
                QueuedAtUtc = DateTime.UtcNow.AddHours(-6),
                UpdatedAtUtc = DateTime.UtcNow.AddHours(-5),
                CompletedAtUtc = DateTime.UtcNow.AddHours(-5)
            },
            new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = otherUserId,
                TemplateId = templateId,
                Status = TemplateGenerationStatus.Completed,
                TokenCost = 20,
                SourceImageUrl = "source",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-4),
                QueuedAtUtc = DateTime.UtcNow.AddHours(-4),
                UpdatedAtUtc = DateTime.UtcNow.AddHours(-3),
                CompletedAtUtc = DateTime.UtcNow.AddHours(-3)
            });
        templatesDb.TemplateAnalyticsEvents.AddRange(
            new TemplateAnalyticsEvent
            {
                Id = Guid.NewGuid(),
                TemplateId = templateId,
                UserId = targetUserId,
                EventType = "view",
                Source = "profile",
                DeviceClass = "ios",
                CountryCode = "US",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-2)
            },
            new TemplateAnalyticsEvent
            {
                Id = Guid.NewGuid(),
                TemplateId = templateId,
                UserId = otherUserId,
                EventType = "view",
                Source = "home",
                DeviceClass = "android",
                CountryCode = "DE",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-1)
            });

        await identityDb.SaveChangesAsync();
        await economyDb.SaveChangesAsync();
        await templatesDb.SaveChangesAsync();

        var result = await service.GetAdminUserAnalyticsAsync(targetUserId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(420, result.Value.Summary.WalletBalance);
        Assert.Equal(1, result.Value.Summary.TotalPurchases);
        Assert.Equal(300, result.Value.Summary.TotalPurchasedSpark);
        Assert.Equal(2, result.Value.Summary.TotalGenerations);
        Assert.Equal(1, result.Value.Summary.CompletedGenerations);
        Assert.Equal(1, result.Value.Summary.FailedGenerations);
        Assert.Single(result.Value.FailureBreakdown);
        Assert.Single(result.Value.RecentTemplateEvents);
    }

    private static IdentityModuleDbContext CreateIdentityDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new IdentityModuleDbContext(options);
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

    private static async Task<IdentityService> CreateServiceAsync(
        IdentityModuleDbContext identityDbContext,
        EconomyDbContext economyDbContext,
        TemplatesDbContext templatesDbContext,
        IAvatarStorage avatarStorage,
        long maxAvatarSizeBytes = 5 * 1024 * 1024)
    {
        await identityDbContext.Database.EnsureCreatedAsync();
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
        var userStore = new UserStore<AppUser, IdentityRole<Guid>, IdentityModuleDbContext, Guid>(identityDbContext);
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

        var roleStore = new RoleStore<IdentityRole<Guid>, IdentityModuleDbContext, Guid>(identityDbContext);
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
            identityDbContext,
            economyDbContext,
            templatesDbContext,
            new StubEmailTemplateRenderer(),
            avatarStorage,
            new EmailOptions
            {
                DispatchWorkerEnabled = false,
                FromAddress = "no-reply@petmagic.app",
                FromName = "PetMagic",
                VerificationCodeLength = 6,
                VerificationCodeTtlMinutes = 15,
                PasswordResetCodeTtlMinutes = 15
            },
            new AvatarStorageOptions
            {
                MaxFileSizeBytes = maxAvatarSizeBytes
            },
            Options.Create(new JwtOptions()));
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

    private sealed class TrackingAvatarStorage : IAvatarStorage
    {
        public List<string> DeletedUrls { get; } = [];

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
            if (!string.IsNullOrWhiteSpace(avatarUrl))
            {
                DeletedUrls.Add(avatarUrl);
            }

            return Task.FromResult(Result.Success());
        }
    }
}
