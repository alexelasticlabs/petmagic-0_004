using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.Gamification.Infrastructure.Data;

public sealed class GamificationDesignTimeDbContextFactory : IDesignTimeDbContextFactory<GamificationDbContext>
{
    public GamificationDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_GAMIFICATION_MIGRATIONS_CONNECTION_STRING")
            ?? Environment.GetEnvironmentVariable("PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING")
            ?? string.Empty;

        var optionsBuilder = new DbContextOptionsBuilder<GamificationDbContext>();
        optionsBuilder.UseNpgsql(connectionString);

        return new GamificationDbContext(optionsBuilder.Options);
    }
}
