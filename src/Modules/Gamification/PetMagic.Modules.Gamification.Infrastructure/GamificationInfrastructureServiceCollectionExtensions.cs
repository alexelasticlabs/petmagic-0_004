using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Gamification.Infrastructure;

public static class GamificationInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddGamificationInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddDbContextPool<GamificationDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddScoped<IGamificationService, GamificationService>();
        services.AddScoped<IGamificationAdminService, GamificationAdminService>();

        return services;
    }

    public static async Task EnsureGamificationSeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<GamificationDbContext>();
        await dbContext.Database.MigrateAsync();

        await SeedAchievementDefinitionsAsync(dbContext);
    }

    private static async Task SeedAchievementDefinitionsAsync(GamificationDbContext dbContext)
    {
        if (await dbContext.AchievementDefinitions.AnyAsync())
        {
            return;
        }

        var now = DateTime.UtcNow;
        var achievements = new[]
        {
            Create("first_magic", "generation", "common", "achievementFirstMagic", "achievementFirstMagicDesc", "✨", "generation_count", 1, 10, false, 1, now),
            Create("apprentice_10", "generation", "common", "achievementApprentice10", "achievementApprentice10Desc", "🔮", "generation_count", 10, 20, false, 2, now),
            Create("magician_100", "generation", "rare", "achievementMagician100", "achievementMagician100Desc", "🎩", "generation_count", 100, 100, false, 3, now),
            Create("archmage_500", "generation", "epic", "achievementArchmage500", "achievementArchmage500Desc", "⚡", "generation_count", 500, 250, false, 4, now),
            Create("streak_3", "streak", "common", "achievementStreak3", "achievementStreak3Desc", "🔥", "streak_days", 3, 15, false, 5, now),
            Create("streak_7", "streak", "rare", "achievementStreak7", "achievementStreak7Desc", "🔥", "streak_days", 7, 30, false, 6, now),
            Create("streak_14", "streak", "epic", "achievementStreak14", "achievementStreak14Desc", "🔥", "streak_days", 14, 50, false, 7, now),
            Create("streak_30", "streak", "legendary", "achievementStreak30", "achievementStreak30Desc", "🔥", "streak_days", 30, 100, false, 8, now),
            Create("pack_leader", "collection", "rare", "achievementPackLeader", "achievementPackLeaderDesc", "🐾", "pet_count", 5, 50, false, 9, now),
            Create("evolution_baby", "special", "common", "achievementEvolutionBaby", "achievementEvolutionBabyDesc", "🐣", "pet_level", 3, 20, false, 10, now),
            Create("evolution_legendary", "special", "legendary", "achievementEvolutionLegendary", "achievementEvolutionLegendaryDesc", "🐉", "pet_level", 9, 200, false, 11, now),
            Create("trendsetter", "special", "common", "achievementTrendsetter", "achievementTrendsetterDesc", "⭐", "generation_count", 1, 15, false, 12, now),
            Create("daily_ritual", "special", "rare", "achievementDailyRitual", "achievementDailyRitualDesc", "🌅", "generation_count", 5, 30, true, 13, now),
            Create("template_collector", "special", "epic", "achievementTemplateCollector", "achievementTemplateCollectorDesc", "🎨", "generation_count", 20, 60, true, 14, now),
            Create("night_owl", "special", "rare", "achievementNightOwl", "achievementNightOwlDesc", "🦉", "generation_count", 1, 15, true, 15, now),
        };

        dbContext.AchievementDefinitions.AddRange(achievements);
        await dbContext.SaveChangesAsync();
    }

    private static AchievementDefinition Create(
        string key, string category, string rarity, string titleKey, string descriptionKey,
        string iconEmoji, string requirementType, int requirementValue, int rewardSpark,
        bool isSecret, int sortOrder, DateTime now) => new()
    {
        Id = Guid.NewGuid(),
        Key = key,
        Category = category,
        Rarity = rarity,
        TitleKey = titleKey,
        DescriptionKey = descriptionKey,
        IconEmoji = iconEmoji,
        RequirementType = requirementType,
        RequirementValue = requirementValue,
        RewardSpark = rewardSpark,
        IsSecret = isSecret,
        SortOrder = sortOrder,
        CreatedAtUtc = now
    };
}
