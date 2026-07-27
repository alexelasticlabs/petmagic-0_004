using System.Net;
using System.Security.Claims;

using Microsoft.AspNetCore.Http;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Gamification.Application.Contracts;
using PetMagic.Modules.Gamification.Domain.Constants;
using PetMagic.Modules.Gamification.Infrastructure;
using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationAdminServiceTests
{
    [Fact]
    public async Task GetAdminDashboardMetricsAsync_ShouldReportCurrentWeekUsage()
    {
        await using var dbContext = CreateDbContext();
        var weekStart = GetCurrentWeekStart();
        var userId = Guid.NewGuid();

        dbContext.AchievementDefinitions.Add(new AchievementDefinition
        {
            Id = Guid.NewGuid(),
            Key = "first_magic",
            Category = "generation",
            Rarity = "common",
            TitleKey = "achievementFirstMagic",
            DescriptionKey = "achievementFirstMagicDesc",
            IconEmoji = "✨",
            RequirementType = "generation_count",
            RequirementValue = 1,
            RewardSpark = 10,
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.PetProgresses.Add(new PetProgress
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PetId = Guid.NewGuid(),
            Xp = 120,
            Level = 3,
            EvolutionStage = "baby",
            TotalGenerations = 4,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.DailyStreaks.Add(new DailyStreak
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CurrentStreak = 3,
            LongestStreak = 3,
            LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        var challengeId = Guid.NewGuid();
        dbContext.WeeklyChallenges.Add(new WeeklyChallenge
        {
            Id = challengeId,
            WeekStartDate = weekStart,
            ChallengeType = "generate_images",
            TargetValue = 5,
            TitleKey = "gamificationChallengeGenerateImages",
            DescriptionKey = "gamificationChallengeGenerateImagesDesc",
            RewardSpark = 25,
            SortOrder = 0,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.UserChallengeProgresses.Add(new UserChallengeProgress
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            ChallengeId = challengeId,
            CurrentValue = 5,
            Completed = true,
            CompletedAtUtc = DateTime.UtcNow
        });
        dbContext.UserAchievements.Add(new UserAchievement
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            AchievementKey = "first_magic",
            UnlockedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateAdminService(dbContext);

        var result = await service.GetAdminDashboardMetricsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.TotalUsersWithProgress);
        Assert.Equal(1, result.Value.TotalPetsTracked);
        Assert.Equal(1, result.Value.TotalAchievementDefinitions);
        Assert.Equal(1, result.Value.TotalAchievementsUnlocked);
        Assert.Equal(1, result.Value.UsersWithActiveStreak);
        Assert.Equal(DefaultChallenges.Templates.Length, result.Value.CurrentWeekChallenges);
        Assert.Equal(1, result.Value.CurrentWeekChallengeParticipants);
        Assert.Equal(1, result.Value.CurrentWeekChallengeCompletions);
    }

    [Fact]
    public async Task ListAdminAchievementsAsync_ShouldIncludeUnlockedUserCounts()
    {
        await using var dbContext = CreateDbContext();
        dbContext.AchievementDefinitions.Add(new AchievementDefinition
        {
            Id = Guid.NewGuid(),
            Key = "first_magic",
            Category = "generation",
            Rarity = "common",
            TitleKey = "achievementFirstMagic",
            DescriptionKey = "achievementFirstMagicDesc",
            IconEmoji = "✨",
            RequirementType = "generation_count",
            RequirementValue = 1,
            RewardSpark = 10,
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.UserAchievements.AddRange(
            new UserAchievement
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                AchievementKey = "first_magic",
                UnlockedAtUtc = DateTime.UtcNow
            },
            new UserAchievement
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                AchievementKey = "first_magic",
                UnlockedAtUtc = DateTime.UtcNow
            });
        await dbContext.SaveChangesAsync();

        var service = CreateAdminService(dbContext);

        var result = await service.ListAdminAchievementsAsync(CancellationToken.None);

        var achievement = Assert.Single(result.Value);
        Assert.Equal("first_magic", achievement.Key);
        Assert.Equal(2, achievement.UnlockedUsersCount);
    }

    [Fact]
    public async Task GetAdminUserOverviewAndResetStreakAsync_ShouldExposeUserStateAndAllowReset()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();

        dbContext.AchievementDefinitions.Add(new AchievementDefinition
        {
            Id = Guid.NewGuid(),
            Key = "first_magic",
            Category = "generation",
            Rarity = "common",
            TitleKey = "achievementFirstMagic",
            DescriptionKey = "achievementFirstMagicDesc",
            IconEmoji = "✨",
            RequirementType = "generation_count",
            RequirementValue = 1,
            RewardSpark = 10,
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var userService = new GamificationService(dbContext);
        await userService.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            userId,
            petId,
            templateId,
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var auditLog = new RecordingAdminAuditLog();
        var service = CreateAdminService(dbContext, auditLog);

        var overview = await service.GetAdminUserOverviewAsync(userId, CancellationToken.None);
        var adminUserId = Guid.NewGuid();
        var resetResult = await service.ResetAdminUserStreakAsync(
            new AdminResetUserStreakCommand(adminUserId, userId, "Verified duplicate test profile."),
            CancellationToken.None);

        Assert.True(overview.IsSuccess);
        Assert.Equal(userId, overview.Value.UserId);
        Assert.NotNull(overview.Value.Streak);
        Assert.Single(overview.Value.Pets);
        Assert.Single(overview.Value.Achievements, x => x.Key == "first_magic" && x.IsUnlocked);
        Assert.NotEmpty(overview.Value.CurrentChallenges);
        Assert.Contains(
            overview.Value.History,
            item => item.Kind == "achievement_reward"
                && item.Label == "first_magic"
                && item.DefinitionVersion == 1);
        Assert.Contains(
            overview.Value.History,
            item => item.Kind == "challenge_reward"
                && item.DefinitionVersion == 1);
        Assert.Contains(
            overview.Value.History,
            item => item.Kind == "streak_activity"
                && item.Status == "recorded");
        Assert.True(resetResult.IsSuccess);
        Assert.Null(await dbContext.DailyStreaks.FirstOrDefaultAsync(x => x.UserId == userId));
        var audit = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.gamification.streak.reset", audit.Action);
        Assert.Equal(userId, audit.SubjectUserId);
        Assert.Equal(adminUserId, audit.ActorUserId);
        Assert.Equal("Verified duplicate test profile.", audit.Details);
        Assert.NotNull(audit.EventId);
        var queuedAudit = Assert.Single(dbContext.PushOutboxMessages);
        Assert.Equal(PushOutboxStatus.Queued, queuedAudit.Status);
        Assert.Contains(audit.EventId.Value.ToString("D"), queuedAudit.DeduplicationKey, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ResetAdminUserStreakAsync_ShouldRejectMissingAuditReason()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        dbContext.DailyStreaks.Add(new DailyStreak
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CurrentStreak = 3,
            LongestStreak = 3,
            LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var auditLog = new RecordingAdminAuditLog();
        var service = CreateAdminService(dbContext, auditLog);
        var result = await service.ResetAdminUserStreakAsync(
            new AdminResetUserStreakCommand(Guid.NewGuid(), userId, " "),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("gamification.admin_streak_reset_reason_required", result.Error.Code);
        Assert.NotNull(await dbContext.DailyStreaks.FirstOrDefaultAsync(x => x.UserId == userId));
        Assert.Empty(auditLog.Entries);
    }

    [Fact]
    public async Task ResetAdminUserStreakAsync_ShouldCommitAndQueueAuditWhenImmediateAuditSinkFails()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        dbContext.DailyStreaks.Add(new DailyStreak
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CurrentStreak = 5,
            LongestStreak = 8,
            LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var requestStartedAtUtc = DateTime.UtcNow;
        var httpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.Role, "Admin")],
                authenticationType: "test"))
        };
        httpContext.Connection.RemoteIpAddress = IPAddress.Parse("203.0.113.12");
        httpContext.Request.Headers.UserAgent = "PetMagicAdmin/1.0 authorization=worker-secret";
        var service = CreateAdminService(
            dbContext,
            new ThrowingAdminAuditLog(),
            new HttpContextAccessor { HttpContext = httpContext });
        var result = await service.ResetAdminUserStreakAsync(
            new AdminResetUserStreakCommand(Guid.NewGuid(), userId, "Confirmed support correction."),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Null(await dbContext.DailyStreaks.FirstOrDefaultAsync(x => x.UserId == userId));
        var queuedAudit = Assert.Single(dbContext.PushOutboxMessages);
        Assert.Equal(PushOutboxStatus.Queued, queuedAudit.Status);
        Assert.DoesNotContain("worker-secret", queuedAudit.PayloadJson, StringComparison.Ordinal);

        var failedAttemptStartedAtUtc = DateTime.UtcNow;
        var failingProcessor = new GamificationAdminAuditOutboxProcessor(
            dbContext,
            new ThrowingAdminAuditLog(),
            NullLogger<GamificationAdminAuditOutboxProcessor>.Instance);

        Assert.True(await failingProcessor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(PushOutboxStatus.Queued, queuedAudit.Status);
        Assert.Equal(1, queuedAudit.AttemptCount);
        Assert.Equal("admin_audit.write_failed", queuedAudit.LastErrorCode);
        Assert.Null(queuedAudit.LockId);
        Assert.Null(queuedAudit.LockExpiresAtUtc);
        Assert.True(queuedAudit.NextAttemptAtUtc > failedAttemptStartedAtUtc);

        queuedAudit.NextAttemptAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();
        var retryAuditLog = new RecordingAdminAuditLog();
        var retryProcessor = new GamificationAdminAuditOutboxProcessor(
            dbContext,
            retryAuditLog,
            NullLogger<GamificationAdminAuditOutboxProcessor>.Instance);

        Assert.True(await retryProcessor.ProcessNextAsync(CancellationToken.None));

        Assert.Equal(PushOutboxStatus.Sent, queuedAudit.Status);
        Assert.Equal(2, queuedAudit.AttemptCount);
        var retriedAudit = Assert.Single(retryAuditLog.Entries);
        Assert.Equal("admin.gamification.streak.reset", retriedAudit.Action);
        Assert.Equal(userId, retriedAudit.SubjectUserId);
        Assert.Equal("Confirmed support correction.", retriedAudit.Details);
        Assert.NotNull(retriedAudit.EventId);
        Assert.Equal("Admin", retriedAudit.ActorRole);
        Assert.Equal("203.0.113.12", retriedAudit.IpAddress);
        Assert.Equal("PetMagicAdmin/1.0 authorization= ***", retriedAudit.UserAgent);
        Assert.NotNull(retriedAudit.OccurredAtUtc);
        Assert.InRange(retriedAudit.OccurredAtUtc.Value, requestStartedAtUtc, DateTime.UtcNow);
    }

    [Fact]
    public async Task ResetAdminUserStreakAsync_ShouldRollbackDeletionWhenDurableAuditCannotBeQueued()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<GamificationDbContext>()
            .UseSqlite(connection)
            .Options;
        await using var dbContext = new GamificationDbContext(options);
        await dbContext.Database.EnsureCreatedAsync();

        var userId = Guid.NewGuid();
        dbContext.DailyStreaks.Add(new DailyStreak
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CurrentStreak = 4,
            LongestStreak = 6,
            LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        await dbContext.Database.ExecuteSqlRawAsync(
            """
            CREATE TRIGGER reject_gamification_audit_outbox
            BEFORE INSERT ON gamification_push_outbox
            BEGIN
                SELECT RAISE(ABORT, 'audit outbox unavailable');
            END;
            """);

        var auditLog = new RecordingAdminAuditLog();
        var service = CreateAdminService(dbContext, auditLog);

        await Assert.ThrowsAsync<DbUpdateException>(() => service.ResetAdminUserStreakAsync(
            new AdminResetUserStreakCommand(Guid.NewGuid(), userId, "Confirmed support correction."),
            CancellationToken.None));

        dbContext.ChangeTracker.Clear();
        Assert.NotNull(await dbContext.DailyStreaks.FirstOrDefaultAsync(x => x.UserId == userId));
        Assert.Empty(await dbContext.PushOutboxMessages.ToListAsync());
        Assert.Empty(auditLog.Entries);
    }

    private static GamificationAdminService CreateAdminService(
        GamificationDbContext dbContext,
        IAdminAuditLog? auditLog = null,
        IHttpContextAccessor? httpContextAccessor = null)
    {
        var userService = new GamificationService(dbContext);
        return new GamificationAdminService(
            dbContext,
            userService,
            auditLog ?? new RecordingAdminAuditLog(),
            httpContextAccessor ?? new HttpContextAccessor(),
            NullLogger<GamificationAdminService>.Instance);
    }

    private sealed class RecordingAdminAuditLog : IAdminAuditLog
    {
        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            Entries.Add(entry);
            return Task.CompletedTask;
        }
    }

    private sealed class ThrowingAdminAuditLog : IAdminAuditLog
    {
        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("audit sink unavailable");
    }

    private static GamificationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<GamificationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new GamificationDbContext(options);
    }

    private static DateOnly GetCurrentWeekStart()
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        return today.DayOfWeek == DayOfWeek.Sunday ? today.AddDays(-6) : startOfWeek;
    }
}
