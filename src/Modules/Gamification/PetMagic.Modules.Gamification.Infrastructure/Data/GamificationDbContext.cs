using Microsoft.EntityFrameworkCore;

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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
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
            entity.HasIndex(x => x.WeekStartDate);
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
    }
}
