using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.Economy.Infrastructure.Data;

public sealed class EconomyDesignTimeDbContextFactory : IDesignTimeDbContextFactory<EconomyDbContext>
{
    public EconomyDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            connectionString = "Host=localhost;Port=5432;Database=petmagic_db;Username=petmagic_user;Password=PetMagic_DevPassword123";
        }

        var optionsBuilder = new DbContextOptionsBuilder<EconomyDbContext>();
        optionsBuilder.UseNpgsql(connectionString);
        return new EconomyDbContext(optionsBuilder.Options);
    }
}
