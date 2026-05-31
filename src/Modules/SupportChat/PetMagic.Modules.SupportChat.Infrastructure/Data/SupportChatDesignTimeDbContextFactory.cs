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
            throw new InvalidOperationException(
                "PETMAGIC_SUPPORTCHAT_MIGRATIONS_CONNECTION_STRING is required for design-time migrations.");
        }

        var optionsBuilder = new DbContextOptionsBuilder<SupportChatDbContext>();
        optionsBuilder.UseNpgsql(connectionString);
        return new SupportChatDbContext(optionsBuilder.Options);
    }
}
