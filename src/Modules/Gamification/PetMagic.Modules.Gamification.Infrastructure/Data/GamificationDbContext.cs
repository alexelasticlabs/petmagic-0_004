using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Gamification.Infrastructure.Entities;

namespace PetMagic.Modules.Gamification.Infrastructure.Data;

public sealed class GamificationDbContext(DbContextOptions<GamificationDbContext> options) : DbContext(options)
{
    public DbSet<PetProgress> PetProgresses => Set<PetProgress>();
    public DbSet<AchievementDefinition> AchievementDefinitions => Set<AchievementDefinition>();
    public DbSet<UserAchievement> UserAchievements => Set<UserAchievement>();
    public DbSet<DailyStreak> DailyStreaks => Set<DailyStreak>();
    public DbSet<WeeklyChallenge> WeeklyChallenges => Set<WeeklyChallenge>();
    public DbSet<UserChallengeProgress> UserChallengeProgresses => Set<UserChallengeProgress>();
    public DbSet<GamificationGenerationEvent> GenerationEvents => Set<GamificationGenerationEvent>();
    public DbSet<GamificationShareEvent> ShareEvents => Set<GamificationShareEvent>();
    public DbSet<PushOutboxMessage> PushOutboxMessages => Set<PushOutboxMessage>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ConfigurePushOutbox(modelBuilder, "gamification_push_outbox");

        modelBuilder.Entity<PetProgress>(entity =>
        {
            entity.ToTable("gamification_pet_progress");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.UserId, x.PetId }).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.Property(x => x.EvolutionStage).HasMaxLength(20).IsRequired();
        });

        modelBuilder.Entity<AchievementDefinition>(entity =>
        {
            entity.ToTable("gamification_achievement_definitions");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Key).IsUnique();
            entity.Property(x => x.Key).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(30).IsRequired();
            entity.Property(x => x.Rarity).HasMaxLength(20).IsRequired();
            entity.Property(x => x.TitleKey).HasMaxLength(200).IsRequired();
            entity.Property(x => x.DescriptionKey).HasMaxLength(200).IsRequired();
            entity.Property(x => x.IconEmoji).HasMaxLength(10);
            entity.Property(x => x.RequirementType).HasMaxLength(50).IsRequired();
        });

        modelBuilder.Entity<UserAchievement>(entity =>
        {
            entity.ToTable("gamification_user_achievements");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.UserId, x.AchievementKey }).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.Property(x => x.AchievementKey).HasMaxLength(100).IsRequired();
        });

        modelBuilder.Entity<DailyStreak>(entity =>
        {
            entity.ToTable("gamification_daily_streaks");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.UserId).IsUnique();
        });

        modelBuilder.Entity<WeeklyChallenge>(entity =>
        {
            entity.ToTable("gamification_weekly_challenges");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.WeekStartDate, x.ChallengeType }).IsUnique();
            entity.Property(x => x.ChallengeType).HasMaxLength(50).IsRequired();
            entity.Property(x => x.TitleKey).HasMaxLength(200).IsRequired();
            entity.Property(x => x.DescriptionKey).HasMaxLength(200).IsRequired();
            entity.Property(x => x.IconEmoji).HasMaxLength(10);
        });

        modelBuilder.Entity<UserChallengeProgress>(entity =>
        {
            entity.ToTable("gamification_user_challenge_progress");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.UserId, x.ChallengeId }).IsUnique();
            entity.HasIndex(x => x.UserId);
        });

        modelBuilder.Entity<GamificationGenerationEvent>(entity =>
        {
            entity.ToTable("gamification_generation_events");
            entity.HasKey(x => x.GenerationId);
            entity.HasIndex(x => new { x.UserId, x.WeekStartDate, x.TemplateId });
            entity.HasIndex(x => new { x.UserId, x.PetId, x.OccurredAtUtc });
        });

        modelBuilder.Entity<GamificationShareEvent>(entity =>
        {
            entity.ToTable("gamification_share_events");
            entity.HasKey(x => x.GenerationId);
            entity.HasIndex(x => new { x.UserId, x.WeekStartDate });
        });
    }

    private static void ConfigurePushOutbox(ModelBuilder builder, string tableName)
    {
        builder.Entity<PushOutboxMessage>(entity =>
        {
            entity.ToTable(tableName);
            entity.HasKey(x => x.Id);
            entity.Property(x => x.DeduplicationKey).HasMaxLength(256).IsRequired();
            entity.Property(x => x.Kind).HasMaxLength(64).IsRequired();
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.Property(x => x.LockId).IsConcurrencyToken();
            entity.Property(x => x.LastErrorCode).HasMaxLength(128);
            entity.HasIndex(x => x.DeduplicationKey).IsUnique();
            entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.LockExpiresAtUtc });
            entity.HasIndex(x => x.UserId);
        });
    }
}
