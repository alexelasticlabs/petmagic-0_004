using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

public sealed class TemplatesDesignTimeDbContextFactory : IDesignTimeDbContextFactory<TemplatesDbContext>
{
    public TemplatesDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<TemplatesDbContext>();
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_TEMPLATES_MIGRATIONS_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "PETMAGIC_TEMPLATES_MIGRATIONS_CONNECTION_STRING is required for design-time migrations.");
        }

        optionsBuilder.UseNpgsql(connectionString);
        return new TemplatesDbContext(optionsBuilder.Options);
    }
}
