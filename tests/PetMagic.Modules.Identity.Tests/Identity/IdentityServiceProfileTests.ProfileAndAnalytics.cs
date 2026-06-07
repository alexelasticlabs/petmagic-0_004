using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
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
    public async Task DeleteCurrentUserAsync_ShouldRemoveUserAndIdentityArtifacts()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var avatarStorage = new TrackingAvatarStorage();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, avatarStorage);

        var userId = Guid.NewGuid();
        identityDb.Users.Add(new AppUser
        {
            Id = userId,
            Email = "delete@petmagic.app",
            UserName = "delete@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            AvatarUrl = "http://localhost:5000/user-avatars/delete.png",
            AvatarFileName = "delete.png",
            AvatarContentType = "image/png",
            AvatarFileSizeBytes = 128,
            AvatarUpdatedAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow
        });

        identityDb.RefreshTokenSessions.Add(new RefreshTokenSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TokenHash = "hash",
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(7)
        });

        identityDb.UserEmailCodes.Add(new UserEmailCode
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Email = "delete@petmagic.app",
            Purpose = EmailCodePurpose.EmailConfirmation,
            CodeHash = "code-hash",
            RequestedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(15)
        });

        identityDb.EmailDispatchJobs.Add(new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            RecipientEmail = "delete@petmagic.app",
            Kind = EmailDispatchKind.EmailConfirmation,
            Status = EmailDispatchStatus.Queued,
            Subject = "Confirm",
            HtmlBody = "<p>Confirm</p>",
            TextBody = "Confirm",
            AttemptCount = 0,
            QueuedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });

        await identityDb.SaveChangesAsync();

        var result = await service.DeleteCurrentUserAsync(
            new DeleteCurrentUserCommand(userId),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(await identityDb.Users.AnyAsync(x => x.Id == userId));
        Assert.True(await identityDb.RefreshTokenSessions.AnyAsync(x => x.UserId == userId && x.RevokedAtUtc != null));
        Assert.False(await identityDb.UserEmailCodes.AnyAsync(x => x.UserId == userId));
        Assert.False(await identityDb.EmailDispatchJobs.AnyAsync(x => x.UserId == userId));
        Assert.Contains("delete.png", avatarStorage.DeletedUrls.Single());
        Assert.True(await identityDb.AuditEvents.AnyAsync(x => x.SubjectUserId == userId && x.Action == "user.deleted"));
    }

    [Fact]
    public async Task DeleteCurrentUserAsync_ShouldReturnNotFound_WhenUserMissing()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var result = await service.DeleteCurrentUserAsync(
            new DeleteCurrentUserCommand(Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(IdentityErrors.UserNotFound.Code, result.Error.Code);
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
        economyDb.WalletLedgerEntries.AddRange(
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                Delta = 300,
                BalanceAfter = 300,
                Source = "pack_purchase",
                Reason = "purchase",
                CreatedAtUtc = DateTime.UtcNow.AddDays(-2)
            },
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                Delta = 150,
                BalanceAfter = 450,
                Source = "admin_grant",
                Reason = "retention",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-4)
            },
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = targetUserId,
                Delta = -30,
                BalanceAfter = 420,
                Source = "admin_debit",
                Reason = "manual correction",
                CreatedAtUtc = DateTime.UtcNow.AddHours(-3)
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
                LastErrorCode = "templates.failed",
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
        Assert.Equal(450, result.Value.Summary.TotalTokensCredited);
        Assert.Equal(30, result.Value.Summary.TotalTokensSpent);
        Assert.Equal(150, result.Value.Summary.ManualTokensGranted);
        Assert.Equal(30, result.Value.Summary.ManualTokensDebited);
        Assert.Equal(1, result.Value.Summary.TotalPurchases);
        Assert.Equal(300, result.Value.Summary.TotalPurchasedSpark);
        Assert.Equal(2, result.Value.Summary.TotalGenerations);
        Assert.Equal(1, result.Value.Summary.CompletedGenerations);
        Assert.Equal(1, result.Value.Summary.FailedGenerations);
        Assert.Equal(1, result.Value.Summary.TotalViews);
        Assert.Equal(0, result.Value.Summary.TotalVideoViews);
        Assert.Equal(3, result.Value.RecentWalletLedger.Count);
        Assert.Single(result.Value.FailureBreakdown);
        Assert.Single(result.Value.RecentTemplateEvents);
    }

    [Fact]
    public async Task AdjustAdminUserWalletAsync_ShouldCreditAndDebitWalletWithAdminSources()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var userId = Guid.NewGuid();
        identityDb.Users.Add(new AppUser
        {
            Id = userId,
            Email = "wallet@petmagic.app",
            UserName = "wallet@petmagic.app",
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            CreatedAtUtc = DateTime.UtcNow
        });
        await identityDb.SaveChangesAsync();

        var credit = await service.AdjustAdminUserWalletAsync(
            new AdminAdjustUserWalletCommand(userId, "credit", 80, "bonus"),
            CancellationToken.None);
        var debit = await service.AdjustAdminUserWalletAsync(
            new AdminAdjustUserWalletCommand(userId, "debit", 30, "correction"),
            CancellationToken.None);

        Assert.True(credit.IsSuccess);
        Assert.True(debit.IsSuccess);
        Assert.Equal(80, credit.Value.NewBalance);
        Assert.Equal(50, debit.Value.NewBalance);
        Assert.Equal("admin_grant", credit.Value.Source);
        Assert.Equal("admin_debit", debit.Value.Source);

        var ledger = await economyDb.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync();

        Assert.Equal(2, ledger.Count);
        Assert.Equal("admin_grant", ledger[0].Source);
        Assert.Equal("admin_debit", ledger[1].Source);
    }

}
