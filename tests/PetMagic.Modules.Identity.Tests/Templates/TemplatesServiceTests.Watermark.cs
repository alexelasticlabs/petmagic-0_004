using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using System.Text;
using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task GetAsync_ShouldReturnWatermarkedForFreeAndCleanForPremium()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var service = CreateGenerationService(dbContext);

        var free = await service.GetAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var premium = await service.GetAsync(userId, job.Id, isPremium: true, CancellationToken.None);
        var otherUser = await service.GetAsync(otherUserId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(free.IsSuccess);
        Assert.Equal(job.WatermarkedResultUrl, free.Value.OutputUrl);
        Assert.True(free.Value.HasWatermark);
        Assert.True(free.Value.CanRemoveWatermark);
        Assert.False(free.Value.IsWatermarkRemoved);

        Assert.True(premium.IsSuccess);
        Assert.Equal(job.ResultUrl, premium.Value.OutputUrl);
        Assert.False(premium.Value.HasWatermark);
        Assert.False(premium.Value.CanRemoveWatermark);

        Assert.True(otherUser.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, otherUser.Error.Code);
    }

    [Fact]
    public async Task ListAsync_ShouldReturnWatermarkedForFreeAndCleanForPremium()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var service = CreateGenerationService(dbContext);

        var free = await service.ListAsync(
            userId,
            new TemplateGenerationHistoryQuery("completed", null, 10),
            isPremium: false,
            CancellationToken.None);
        var premium = await service.ListAsync(
            userId,
            new TemplateGenerationHistoryQuery("completed", null, 10),
            isPremium: true,
            CancellationToken.None);

        Assert.True(free.IsSuccess);
        var freeItem = Assert.Single(free.Value);
        Assert.Equal(job.WatermarkedResultUrl, freeItem.OutputUrl);
        Assert.True(freeItem.HasWatermark);
        Assert.True(freeItem.CanRemoveWatermark);
        Assert.Equal("free", freeItem.UserPlan);

        Assert.True(premium.IsSuccess);
        var premiumItem = Assert.Single(premium.Value);
        Assert.Equal(job.ResultUrl, premiumItem.OutputUrl);
        Assert.False(premiumItem.HasWatermark);
        Assert.False(premiumItem.CanRemoveWatermark);
        Assert.Equal("premium", premiumItem.UserPlan);
    }

    [Fact]
    public async Task ListPetGenerationsAsync_ShouldReturnWatermarkedForFreeAndCleanForPremium()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Milo",
            Type = "dog",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        job.PetId = petId;
        await dbContext.SaveChangesAsync();
        var service = new PetsService(
            dbContext,
            new RecordingMediaStorage(signReadUrls: true),
            CreateTemplatesOptions(),
            NullLogger<PetsService>.Instance);

        var free = await service.ListGenerationsAsync(userId, petId, isPremium: false, CancellationToken.None);
        var premium = await service.ListGenerationsAsync(userId, petId, isPremium: true, CancellationToken.None);

        Assert.True(free.IsSuccess);
        var freeItem = Assert.Single(free.Value);
        Assert.Equal($"{job.WatermarkedResultUrl}?signed=1", freeItem.OutputUrl);
        Assert.True(freeItem.HasWatermark);
        Assert.Equal("free", freeItem.UserPlan);

        Assert.True(premium.IsSuccess);
        var premiumItem = Assert.Single(premium.Value);
        Assert.Equal($"{job.ResultUrl}?signed=1", premiumItem.OutputUrl);
        Assert.False(premiumItem.HasWatermark);
        Assert.Equal("premium", premiumItem.UserPlan);
    }

    [Fact]
    public async Task RemoveWatermarkAsync_ShouldSpendCreditOnceAndKeepCleanAccess()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var billing = new CountingWatermarkBilling(remainingCredits: 7);
        var service = new TemplateGenerationService(
            dbContext,
            billing,
            new RecordingMediaStorage(),
            CreateTemplatesOptions());
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var command = new RemoveGenerationWatermarkCommand(userId, job.Id, "credit", IsPremium: false);

        var first = await service.RemoveWatermarkAsync(command, CancellationToken.None);
        var second = await service.RemoveWatermarkAsync(command, CancellationToken.None);
        var download = await service.GetDownloadAsync(userId, job.Id, isPremium: false, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.True(download.IsSuccess);
        Assert.True(first.Value.WatermarkRemoved);
        Assert.True(second.Value.WatermarkRemoved);
        Assert.Equal(1, first.Value.CreditsSpent);
        Assert.Equal(1, second.Value.CreditsSpent);
        Assert.Equal(7, first.Value.RemainingCredits);
        Assert.Null(second.Value.RemainingCredits);
        Assert.Equal(1, billing.SpendCalls);
        Assert.Equal(job.ResultUrl, first.Value.MediaUrl);
        Assert.Equal(job.ResultUrl, second.Value.MediaUrl);
        Assert.Equal(job.ResultUrl, download.Value.MediaUrl);
        Assert.False(download.Value.HasWatermark);

        var persisted = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .SingleAsync(x => x.Id == job.Id);
        Assert.True(persisted.IsWatermarkRemoved);
        var unlock = Assert.Single(persisted.WatermarkUnlocks);
        Assert.Equal(TemplateWatermarkUnlockMethod.Credit, unlock.UnlockMethod);
        Assert.Equal(userId, unlock.UnlockedByUserId);
        Assert.Equal(1, unlock.CreditsSpent);

        var eventTypes = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == job.Id)
            .OrderBy(x => x.CreatedAtUtc)
            .Select(x => x.EventType)
            .ToArrayAsync();
        Assert.Contains(TemplateAnalyticsEventTypes.RemovedCredit, eventTypes);
        Assert.Contains(TemplateAnalyticsEventTypes.DownloadClean, eventTypes);

        var removedCredit = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .SingleAsync(x => x.GenerationId == job.Id && x.EventType == TemplateAnalyticsEventTypes.RemovedCredit);
        AssertWatermarkAnalyticsMetadata(
            removedCredit.MetadataJson,
            job.Id,
            job.TemplateId,
            "image",
            "free",
            "credit",
            1);
    }

    [Fact]
    public async Task RemoveWatermarkAsync_ShouldNotPersistPermanentUnlockForPremiumAccess()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var billing = new CountingWatermarkBilling(remainingCredits: 7);
        var service = new TemplateGenerationService(
            dbContext,
            billing,
            new RecordingMediaStorage(),
            CreateTemplatesOptions());
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);

        var premiumRemove = await service.RemoveWatermarkAsync(
            new RemoveGenerationWatermarkCommand(userId, job.Id, "premium", IsPremium: true),
            CancellationToken.None);
        var afterPremiumExpiredDownload = await service.GetDownloadAsync(
            userId,
            job.Id,
            isPremium: false,
            CancellationToken.None);

        Assert.True(premiumRemove.IsSuccess);
        Assert.Equal(job.ResultUrl, premiumRemove.Value.MediaUrl);
        Assert.Equal(0, premiumRemove.Value.CreditsSpent);
        Assert.Null(premiumRemove.Value.RemainingCredits);
        Assert.Equal(0, billing.SpendCalls);

        Assert.True(afterPremiumExpiredDownload.IsSuccess);
        Assert.Equal(job.WatermarkedResultUrl, afterPremiumExpiredDownload.Value.MediaUrl);
        Assert.True(afterPremiumExpiredDownload.Value.HasWatermark);

        var persisted = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .SingleAsync(x => x.Id == job.Id);
        Assert.False(persisted.IsWatermarkRemoved);
        Assert.Empty(persisted.WatermarkUnlocks);

        var eventTypes = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == job.Id)
            .Select(x => x.EventType)
            .ToArrayAsync();
        Assert.Contains(TemplateAnalyticsEventTypes.RemovedPremium, eventTypes);
        Assert.Contains(TemplateAnalyticsEventTypes.DownloadWatermarked, eventTypes);

        var removedPremium = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .SingleAsync(x => x.GenerationId == job.Id && x.EventType == TemplateAnalyticsEventTypes.RemovedPremium);
        AssertWatermarkAnalyticsMetadata(
            removedPremium.MetadataJson,
            job.Id,
            job.TemplateId,
            "image",
            "premium",
            "premium",
            0);
    }

    [Fact]
    public async Task GrantAdminCleanDownloadAsync_ShouldPersistAdminUnlockAndRemainIdempotent()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var firstAdminId = Guid.NewGuid();
        var secondAdminId = Guid.NewGuid();
        var service = CreateGenerationService(dbContext);
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);

        var first = await service.GrantAdminCleanDownloadAsync(firstAdminId, job.Id, CancellationToken.None);
        var second = await service.GrantAdminCleanDownloadAsync(secondAdminId, job.Id, CancellationToken.None);
        var download = await service.GetDownloadAsync(userId, job.Id, isPremium: false, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.True(download.IsSuccess);
        Assert.True(first.Value.WatermarkRemoved);
        Assert.True(second.Value.WatermarkRemoved);
        Assert.Equal(0, first.Value.CreditsSpent);
        Assert.Equal(0, second.Value.CreditsSpent);
        Assert.Equal(job.ResultUrl, first.Value.MediaUrl);
        Assert.Equal(job.ResultUrl, second.Value.MediaUrl);
        Assert.Equal(job.ResultUrl, download.Value.MediaUrl);
        Assert.False(download.Value.HasWatermark);

        var persisted = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .SingleAsync(x => x.Id == job.Id);
        Assert.True(persisted.IsWatermarkRemoved);
        var unlock = Assert.Single(persisted.WatermarkUnlocks);
        Assert.Equal(TemplateWatermarkUnlockMethod.Admin, unlock.UnlockMethod);
        Assert.Equal(firstAdminId, unlock.UnlockedByUserId);
        Assert.Equal(0, unlock.CreditsSpent);

        var eventTypes = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == job.Id)
            .Select(x => x.EventType)
            .ToArrayAsync();
        Assert.Equal(1, eventTypes.Count(x => x == TemplateAnalyticsEventTypes.RemovedPremium));
        Assert.Contains(TemplateAnalyticsEventTypes.DownloadClean, eventTypes);
    }

    [Fact]
    public async Task UpdateAdminWatermarkSettingsAsync_ShouldPersistPositionAndSize()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var updated = await service.UpdateAdminWatermarkSettingsAsync(
            new UpdateAdminWatermarkSettingsCommand(
                Enabled: true,
                Text: "PetMagic",
                LogoUrl: null,
                Opacity: 0.6,
                Position: "top-left",
                Size: "large",
                CostCredits: 2,
                ApplyToImages: true,
                ApplyToVideos: true),
            CancellationToken.None);
        var fetched = await service.GetAdminWatermarkSettingsAsync(CancellationToken.None);

        Assert.True(updated.IsSuccess);
        Assert.True(fetched.IsSuccess);
        Assert.Equal("top-left", updated.Value.Position);
        Assert.Equal("large", updated.Value.Size);
        Assert.Equal("top-left", fetched.Value.Position);
        Assert.Equal("large", fetched.Value.Size);

        var persisted = await dbContext.TemplateWatermarkSettings.SingleAsync();
        Assert.Equal("top-left", persisted.Position);
        Assert.Equal("large", persisted.Size);
    }

    [Fact]
    public async Task ListAdminGenerationsAsync_ShouldExposeWatermarkUnlockActor()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var unlockedAt = DateTime.UtcNow.AddMinutes(-1);
        job.IsWatermarkRemoved = true;
        dbContext.TemplateGenerationWatermarkUnlocks.Add(new TemplateGenerationWatermarkUnlock
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            GenerationJobId = job.Id,
            UnlockedByUserId = adminId,
            UnlockMethod = TemplateWatermarkUnlockMethod.Credit,
            CreditsSpent = 1,
            CreatedAtUtc = unlockedAt
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(dbContext);

        var page = await service.ListAdminGenerationsAsync(
            new AdminTemplateGenerationsQuery(null, null, userId.ToString(), job.Id.ToString(), 0, 10),
            CancellationToken.None);

        Assert.True(page.IsSuccess);
        var item = Assert.Single(page.Value.Items);
        Assert.Equal(adminId, item.WatermarkUnlockedByUserId);
        Assert.Equal("credit", item.WatermarkUnlockMethod);
        Assert.Equal(1, item.WatermarkCreditsSpent);
        Assert.Equal(unlockedAt, item.WatermarkUnlockedAtUtc);
    }

    [Fact]
    public async Task GetDownloadAndShareAsync_ShouldRecordWatermarkedAndCleanEvents()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var service = CreateGenerationService(dbContext);

        var freeDownload = await service.GetDownloadAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var freeShare = await service.GetShareAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var premiumDownload = await service.GetDownloadAsync(userId, job.Id, isPremium: true, CancellationToken.None);
        var premiumShare = await service.GetShareAsync(userId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(freeDownload.IsSuccess);
        Assert.True(freeShare.IsSuccess);
        Assert.True(premiumDownload.IsSuccess);
        Assert.True(premiumShare.IsSuccess);
        Assert.Equal(job.WatermarkedResultUrl, freeDownload.Value.MediaUrl);
        Assert.Equal(job.WatermarkedResultUrl, freeShare.Value.MediaUrl);
        Assert.True(freeDownload.Value.HasWatermark);
        Assert.True(freeShare.Value.HasWatermark);
        Assert.Equal(job.ResultUrl, premiumDownload.Value.MediaUrl);
        Assert.Equal(job.ResultUrl, premiumShare.Value.MediaUrl);
        Assert.NotEmpty(premiumShare.Value.ShareToken);
        Assert.StartsWith("http://localhost:5000/share/generation/", premiumShare.Value.ShareUrl);
        Assert.DoesNotContain("cdn.example.com", premiumShare.Value.ShareUrl, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("image/png", premiumShare.Value.ContentType);
        Assert.Equal(GalleryMediaState.resultReady.ToString(), premiumShare.Value.MediaState);
        Assert.False(premiumDownload.Value.HasWatermark);
        Assert.False(premiumShare.Value.HasWatermark);

        var eventTypes = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == job.Id)
            .Select(x => x.EventType)
            .ToArrayAsync();
        Assert.Contains(TemplateAnalyticsEventTypes.DownloadWatermarked, eventTypes);
        Assert.Contains(TemplateAnalyticsEventTypes.ShareWatermarked, eventTypes);
        Assert.Contains(TemplateAnalyticsEventTypes.DownloadClean, eventTypes);
        Assert.Contains(TemplateAnalyticsEventTypes.ShareClean, eventTypes);

        var events = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.GenerationId == job.Id)
            .ToArrayAsync();
        AssertWatermarkAnalyticsMetadata(
            events.Single(x => x.EventType == TemplateAnalyticsEventTypes.DownloadWatermarked).MetadataJson,
            job.Id,
            job.TemplateId,
            "Image",
            "free");
        AssertWatermarkAnalyticsMetadata(
            events.Single(x => x.EventType == TemplateAnalyticsEventTypes.ShareWatermarked).MetadataJson,
            job.Id,
            job.TemplateId,
            "Image",
            "free");
        AssertWatermarkAnalyticsMetadata(
            events.Single(x => x.EventType == TemplateAnalyticsEventTypes.DownloadClean).MetadataJson,
            job.Id,
            job.TemplateId,
            "Image",
            "premium");
        AssertWatermarkAnalyticsMetadata(
            events.Single(x => x.EventType == TemplateAnalyticsEventTypes.ShareClean).MetadataJson,
            job.Id,
            job.TemplateId,
            "Image",
            "premium");
    }

    [Fact]
    public async Task GetDownloadAndShareAsync_ShouldReturnSignedShortLivedUrlsForResolvedVersion()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var mediaStorage = new RecordingMediaStorage(signReadUrls: true);
        var options = CreateTemplatesOptions();
        var service = new TemplateGenerationService(
            dbContext,
            new PassiveGenerationBilling(),
            mediaStorage,
            options);
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);

        var freeDownload = await service.GetDownloadAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var premiumShare = await service.GetShareAsync(userId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(freeDownload.IsSuccess);
        Assert.True(premiumShare.IsSuccess);
        Assert.Equal($"{job.WatermarkedResultUrl}?signed=1", freeDownload.Value.MediaUrl);
        Assert.Equal($"{job.ResultUrl}?signed=1", premiumShare.Value.MediaUrl);
        Assert.StartsWith($"{options.PublicBaseUrl}/share/generation/", premiumShare.Value.ShareUrl);
        Assert.NotEqual(premiumShare.Value.MediaUrl, premiumShare.Value.ShareUrl);
        Assert.NotNull(job.WatermarkedResultUrl);
        Assert.NotNull(job.ResultUrl);
        Assert.Contains(job.WatermarkedResultUrl, mediaStorage.ReadUrls);
        Assert.Contains(job.ResultUrl, mediaStorage.ReadUrls);
        Assert.All(
            mediaStorage.ReadTtls,
            ttl => Assert.Equal(TimeSpan.FromSeconds(options.UserMediaReadUrlTtlSeconds), ttl));
    }

    [Fact]
    public async Task GetShareAsync_ShouldRecordShareChallengeProgress()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var gamification = new RecordingGamificationService();
        var service = new TemplateGenerationService(
            dbContext,
            new PassiveGenerationBilling(),
            new RecordingMediaStorage(),
            CreateTemplatesOptions(),
            gamificationService: gamification);
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);

        var share = await service.GetShareAsync(userId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(share.IsSuccess);
        Assert.Equal([userId], gamification.SharedUsers);
    }

    [Fact]
    public async Task GetPublicShareAsync_ShouldReturnFreshMediaForVisibleGenerationToken()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var service = CreateGenerationService(dbContext);
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);

        var share = await service.GetShareAsync(userId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(share.IsSuccess);
        var publicShare = await service.GetPublicShareAsync(share.Value.ShareToken, CancellationToken.None);

        Assert.True(publicShare.IsSuccess);
        Assert.Equal(share.Value.ShareToken, publicShare.Value.ShareToken);
        Assert.Equal(GalleryMediaState.resultReady.ToString(), publicShare.Value.MediaState);
        Assert.Equal(job.ResultUrl, publicShare.Value.MediaUrl);
        Assert.Equal("image", publicShare.Value.MediaType);
        Assert.Equal("image/png", publicShare.Value.ContentType);
        Assert.False(publicShare.Value.HasWatermark);
    }

    [Fact]
    public async Task GetPublicShareAsync_ShouldReturnNotFoundForInvalidOrHiddenToken()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var service = CreateGenerationService(dbContext);
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var share = await service.GetShareAsync(userId, job.Id, isPremium: true, CancellationToken.None);
        Assert.True(share.IsSuccess);

        var invalid = await service.GetPublicShareAsync("not-a-valid-token", CancellationToken.None);
        Assert.True(invalid.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, invalid.Error.Code);

        job.HiddenByUserAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var hidden = await service.GetPublicShareAsync(share.Value.ShareToken, CancellationToken.None);
        Assert.True(hidden.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, hidden.Error.Code);
    }

    [Theory]
    [InlineData("<script>alert(1)</script>")]
    [InlineData("not a valid token")]
    [InlineData("%zz")]
    [InlineData("%E0%A4%A")]
    [InlineData("%2F")]
    [InlineData("%5C")]
    [InlineData("%00")]
    public async Task GetPublicShareAsync_ShouldRejectMalformedShareToken(string shareToken)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateGenerationService(dbContext);

        var result = await service.GetPublicShareAsync(shareToken, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, result.Error.Code);
    }

    [Fact]
    public async Task GetPublicShareAsync_ShouldRejectOversizedShareToken()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateGenerationService(dbContext);

        var result = await service.GetPublicShareAsync(new string('A', 4097), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationJobNotFound.Code, result.Error.Code);
    }

    [Fact]
    public async Task GetPublicShareAsync_ShouldKeepOlderShareTokenDurableWhileGenerationIsVisible()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var dataProtectionProvider = new EphemeralDataProtectionProvider();
        var options = CreateTemplatesOptions(generationShareTokenTtlDays: 1);
        var service = new TemplateGenerationService(
            dbContext,
            new PassiveGenerationBilling(),
            new RecordingMediaStorage(),
            options,
            dataProtectionProvider: dataProtectionProvider);
        var olderToken = CreateGenerationShareToken(
            dataProtectionProvider,
            userId,
            job.Id,
            cleanAccess: true,
            DateTime.UtcNow.AddDays(-2));

        var share = await service.GetPublicShareAsync(olderToken, CancellationToken.None);

        Assert.True(share.IsSuccess);
        Assert.Equal(GalleryMediaState.resultReady.ToString(), share.Value.MediaState);
        Assert.Equal(job.ResultUrl, share.Value.MediaUrl);
    }

    [Fact]
    public async Task GetPublicShareAsync_ShouldReturnMediaForValidShareToken()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        var dataProtectionProvider = new EphemeralDataProtectionProvider();
        var service = new TemplateGenerationService(
            dbContext,
            new PassiveGenerationBilling(),
            new RecordingMediaStorage(),
            CreateTemplatesOptions(generationShareTokenTtlDays: 1),
            dataProtectionProvider: dataProtectionProvider);
        var shareToken = CreateGenerationShareToken(
            dataProtectionProvider,
            userId,
            job.Id,
            cleanAccess: true,
            DateTime.UtcNow.AddMinutes(-10));

        var share = await service.GetPublicShareAsync(shareToken, CancellationToken.None);

        Assert.True(share.IsSuccess);
        Assert.Equal(shareToken, share.Value.ShareToken);
        Assert.Equal(job.ResultUrl, share.Value.MediaUrl);
        Assert.False(share.Value.HasWatermark);
    }

    [Fact]
    public async Task MarkReadAsync_ShouldRecordResultViewedAnalyticsOnce()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId, TemplateType.Video);
        var service = CreateGenerationService(dbContext);

        var first = await service.MarkReadAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var second = await service.MarkReadAsync(userId, job.Id, isPremium: false, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);

        var persisted = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == job.Id);
        Assert.NotNull(persisted.ResultViewedAtUtc);

        var resultViewedEvents = await dbContext.TemplateAnalyticsEvents
            .Where(x => x.GenerationId == job.Id && x.EventType == TemplateAnalyticsEventTypes.ResultViewed)
            .ToArrayAsync();
        var resultViewed = Assert.Single(resultViewedEvents);
        Assert.Equal(job.TemplateId, resultViewed.TemplateId);
        Assert.NotNull(resultViewed.MetadataJson);

        using var metadata = JsonDocument.Parse(resultViewed.MetadataJson!);
        Assert.Equal(job.Id, metadata.RootElement.GetProperty("generationId").GetGuid());
        Assert.Equal(job.TemplateId, metadata.RootElement.GetProperty("templateId").GetGuid());
        Assert.Equal("video", metadata.RootElement.GetProperty("mediaType").GetString());
        Assert.Equal("free", metadata.RootElement.GetProperty("userPlan").GetString());
    }

    [Fact]
    public async Task GetDownloadAsync_ShouldNotExposeCleanUrlWhenWatermarkedCopyIsPreparing()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var job = await SeedCompletedWatermarkedGenerationAsync(dbContext, userId);
        job.WatermarkedResultUrl = null;
        job.WatermarkFailureCode = TemplatesErrors.WatermarkRenderFailed.Code;
        await dbContext.SaveChangesAsync();
        var service = CreateGenerationService(dbContext);

        var generation = await service.GetAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var download = await service.GetDownloadAsync(userId, job.Id, isPremium: false, CancellationToken.None);
        var premiumDownload = await service.GetDownloadAsync(userId, job.Id, isPremium: true, CancellationToken.None);

        Assert.True(generation.IsSuccess);
        Assert.Null(generation.Value.OutputUrl);
        Assert.False(generation.Value.HasWatermark);
        Assert.True(generation.Value.CanRemoveWatermark);
        Assert.Equal("Preparing result...", generation.Value.WatermarkMessage);

        Assert.True(download.IsFailure);
        Assert.Equal(TemplatesErrors.WatermarkNotReady.Code, download.Error.Code);

        Assert.True(premiumDownload.IsSuccess);
        Assert.Equal(job.ResultUrl, premiumDownload.Value.MediaUrl);
        Assert.False(premiumDownload.Value.HasWatermark);
    }

    private static async Task<TemplateGenerationJob> SeedCompletedWatermarkedGenerationAsync(
        TemplatesDbContext dbContext,
        Guid userId,
        TemplateType templateType = TemplateType.Image)
    {
        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            Title = "Watermark Test",
            ShortDescription = "Watermark test template",
            Category = "Test",
            Tags = "test",
            TemplateType = templateType,
            Status = TemplateStatus.Active,
            TokenCost = 20,
            IsPremium = false,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = template.TokenCost,
            SourceImageUrl = "storage/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = templateType == TemplateType.Video ? "storage/clean.mp4" : "storage/clean.png",
            WatermarkedResultUrl = templateType == TemplateType.Video
                ? "storage/watermarked.mp4"
                : "storage/watermarked.png",
            IsWatermarkRequired = true,
            IsWatermarkRemoved = false,
            CreatedAtUtc = now.AddMinutes(-2),
            QueuedAtUtc = now.AddMinutes(-2),
            StartedAtUtc = now.AddMinutes(-1),
            CompletedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();
        return job;
    }

    private static void AssertWatermarkAnalyticsMetadata(
        string? metadataJson,
        Guid generationId,
        Guid templateId,
        string mediaType,
        string userPlan,
        string? unlockMethod = null,
        int? creditsSpent = null)
    {
        Assert.NotNull(metadataJson);
        using var metadata = JsonDocument.Parse(metadataJson!);
        Assert.Equal(generationId, metadata.RootElement.GetProperty("generationId").GetGuid());
        Assert.Equal(templateId, metadata.RootElement.GetProperty("templateId").GetGuid());
        Assert.Equal(mediaType.ToLowerInvariant(), metadata.RootElement.GetProperty("mediaType").GetString());
        Assert.Equal(userPlan, metadata.RootElement.GetProperty("userPlan").GetString());

        if (unlockMethod is null)
        {
            Assert.Equal(JsonValueKind.Null, metadata.RootElement.GetProperty("unlockMethod").ValueKind);
        }
        else
        {
            Assert.Equal(unlockMethod, metadata.RootElement.GetProperty("unlockMethod").GetString());
        }

        if (creditsSpent is null)
        {
            Assert.Equal(JsonValueKind.Null, metadata.RootElement.GetProperty("creditsSpent").ValueKind);
        }
        else
        {
            Assert.Equal(creditsSpent.Value, metadata.RootElement.GetProperty("creditsSpent").GetInt32());
        }
    }

    private static string CreateGenerationShareToken(
        IDataProtectionProvider dataProtectionProvider,
        Guid ownerUserId,
        Guid generationId,
        bool cleanAccess,
        DateTime createdAtUtc)
    {
        var payload = new
        {
            GenerationId = generationId,
            OwnerUserId = ownerUserId,
            CleanAccess = cleanAccess,
            CreatedAtUtc = createdAtUtc
        };
        var protector = dataProtectionProvider.CreateProtector("PetMagic.Templates.GenerationShare.v1");
        var protectedPayload = protector.Protect(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload)));
        return Convert.ToBase64String(protectedPayload);
    }

    private sealed class CountingWatermarkBilling(int remainingCredits) : ITemplateGenerationBilling
    {
        public int SpendCalls { get; private set; }

        public Task<Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            SpendCalls++;
            return Task.FromResult(Result.Success(remainingCredits));
        }
    }

    private sealed class RecordingGamificationService : IGamificationService
    {
        public List<Guid> SharedUsers { get; } = [];

        public Task<GenerationProcessResult> ProcessGenerationCompletedAsync(Guid userId, Guid petId, Guid templateId, bool isTemplateOfTheDay, bool isPremium, CancellationToken cancellationToken)
        {
            return Task.FromResult(new GenerationProcessResult(0, null, null, false, [], 0));
        }

        public Task<PetProgressResponse?> GetPetProgressAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
        {
            return Task.FromResult<PetProgressResponse?>(null);
        }

        public Task<IReadOnlyList<AchievementResponse>> GetAchievementsAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<AchievementResponse>>([]);
        }

        public Task<IReadOnlyList<AchievementResponse>> GetRecentAchievementsAsync(Guid userId, int count, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<AchievementResponse>>([]);
        }

        public Task<StreakResponse?> GetStreakAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<StreakResponse?>(null);
        }

        public Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(new UseFreezeResult(false, 0));
        }

        public Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult<IReadOnlyList<ChallengeResponse>>([]);
        }

        public Task<GamificationSummaryResponse> GetSummaryAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(new GamificationSummaryResponse(null, [], [], []));
        }

        public Task RecordCreationSharedAsync(Guid userId, CancellationToken cancellationToken)
        {
            SharedUsers.Add(userId);
            return Task.CompletedTask;
        }
    }
}
