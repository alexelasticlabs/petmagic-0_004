using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PetMagic.Modules.SupportChat.Infrastructure.Data;

public sealed class SupportChatDesignTimeDbContextFactory : IDesignTimeDbContextFactory<SupportChatDbContext>
{
    public SupportChatDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_SUPPORTCHAT_MIGRATIONS_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            connectionString = "Host=localhost;Port=5432;Database=petmagic_db;Username=petmagic_user;Password=PetMagic_DevPassword123";
        }

        var optionsBuilder = new DbContextOptionsBuilder<SupportChatDbContext>();
        optionsBuilder.UseNpgsql(connectionString);
        return new SupportChatDbContext(optionsBuilder.Options);
    }
}
