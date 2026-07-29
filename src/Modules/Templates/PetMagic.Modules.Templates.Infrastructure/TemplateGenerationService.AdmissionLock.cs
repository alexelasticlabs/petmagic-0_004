using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationAdmissionLockKeys
{
    internal const int Global = 0x506D4144;
    internal const int User = 0x506D4155;
}

internal sealed partial class TemplateGenerationService
{
    private async Task<IDbContextTransaction?> BeginGenerationAdmissionTransactionAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            return null;
        }

        var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock({0})",
                [TemplateGenerationAdmissionLockKeys.Global],
                cancellationToken);
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock({0}, hashtext({1}))",
                [TemplateGenerationAdmissionLockKeys.User, userId.ToString("D")],
                cancellationToken);
            return transaction;
        }
        catch
        {
            await transaction.DisposeAsync();
            throw;
        }
    }
}
