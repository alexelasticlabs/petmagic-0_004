using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.Identity.Infrastructure.Data;

public sealed class IdentityDesignTimeDbContextFactory : IDesignTimeDbContextFactory<IdentityDbContext>
{
    public IdentityDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_IDENTITY_MIGRATIONS_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "PETMAGIC_IDENTITY_MIGRATIONS_CONNECTION_STRING is required for design-time migrations.");
        }

        var optionsBuilder = new DbContextOptionsBuilder<IdentityDbContext>();
        optionsBuilder.UseNpgsql(connectionString);
        return new IdentityDbContext(optionsBuilder.Options);
    }
}
