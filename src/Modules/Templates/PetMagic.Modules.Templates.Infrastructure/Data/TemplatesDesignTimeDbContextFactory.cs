using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

public sealed class TemplatesDesignTimeDbContextFactory : IDesignTimeDbContextFactory<TemplatesDbContext>
{
    public TemplatesDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<TemplatesDbContext>();
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_TEMPLATES_MIGRATIONS_CONNECTION_STRING")
            ?? "Host=localhost;Port=5432;Database=petmagic_db;Username=petmagic_user;Password=PetMagic_DevPassword123";

        optionsBuilder.UseNpgsql(connectionString);
        return new TemplatesDbContext(optionsBuilder.Options);
    }
}